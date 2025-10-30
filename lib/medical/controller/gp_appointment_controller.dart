import 'package:cloud_firestore/cloud_firestore.dart';

class BookingResult {
  final bool ok;
  final String message;
  BookingResult(this.ok, this.message);
}

class GpAppointmentController {
  final FirebaseFirestore _db;
  final bool mirrorToCaregivers;

  GpAppointmentController({
    FirebaseFirestore? db,
    this.mirrorToCaregivers = true,
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Robustly normalize caregivers to a list of UIDs from Account/{elder}.linkedCaregivers
  /// Accepts either:
  /// - ['uid1','uid2'] OR
  /// - [{'uid':'x','displayName':...}, {...}]
  Future<List<String>> fetchLinkedCaregivers(String elderUid) async {
    final doc = await _db.collection('Account').doc(elderUid).get();
    final data = doc.data() ?? const <String, dynamic>{};
    final raw = data['linkedCaregivers'];

    if (raw is List) {
      return raw.map<String>((e) {
        if (e is String) return e.trim();
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final id = (m['uid'] as String?)?.trim();
          return id ?? '';
        }
        return '';
      }).where((s) => s.isNotEmpty).toList(growable: false);
    }
    return const <String>[];
  }

  /// Primary caregiver = first in linkedCaregivers list (if present).
  /// Returns minimal map: { 'uid': <uid>, 'name': <best-effort name> }
  Future<Map<String, String>?> fetchPrimaryCaregiver(String elderUid) async {
    final caregivers = await fetchLinkedCaregivers(elderUid);
    if (caregivers.isEmpty) return null;

    final firstUid = caregivers.first;
    final cgDoc = await _db.collection('Account').doc(firstUid).get();
    final cgData = cgDoc.data() ?? const <String, dynamic>{};

    // Try displayName, then firstName + lastName, then fallback
    final displayName = (cgData['displayName'] as String?)?.trim();
    final firstName = (cgData['firstName'] as String?)?.trim();
    final lastName  = (cgData['lastName'] as String?)?.trim();

    final bestName = displayName?.isNotEmpty == true
        ? displayName!
        : [
            if (firstName != null && firstName.isNotEmpty) firstName,
            if (lastName != null && lastName.isNotEmpty) lastName,
          ].join(' ').trim();

    return {'uid': firstUid, 'name': bestName.isEmpty ? 'Caregiver' : bestName};
  }

  /// Book a future GP call for an elder.
  ///
  /// Creates:
  /// 1) Global event in /events with fields your controllers expect (elderlyId, start, end)
  /// 2) Appointment under Account/{elder}/appointments
  /// 3) (Optional) Mirrors an appointment doc under each caregiver’s Account/{cg}/appointments
  /// 4) (Optional) A top-level /appointments doc for notification/Cloud Function triggers
  Future<BookingResult> bookFutureGpCall({
    required String elderlyId,
    required String elderlyName,
    required DateTime start,
    required Duration duration,
    required String reason,
    bool invitePrimaryCaregiver = false,
  }) async {
    if (reason.trim().isEmpty) {
      return BookingResult(false, 'Please provide a reason for the appointment.');
    }

    try {
      final caregivers = await fetchLinkedCaregivers(elderlyId);

      String? invitedCaregiverUid;
      if (invitePrimaryCaregiver && caregivers.isNotEmpty) {
        invitedCaregiverUid = caregivers.first;
      }

      final end = start.add(duration);

      // ── 1) GLOBAL EVENT (/events)  ───────────────────────────────
      // Use the same field names your UI/controllers use: elderlyId, start, end
      final eventPayload = {
        'title': 'GP Consultation (Online)',
        'description': reason,
        'type': 'gp_consultation_booking',
        'elderlyId': elderlyId,                 // <- your controllers/rules expect this
        'elderlyName': elderlyName,
        'linkedCaregivers': caregivers,         // FYI: optional convenience
        'invitedCaregiverUid': invitedCaregiverUid,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'isAllDay': false,
        'creatorUid': elderlyId,
        'status': 'scheduled', // scheduled | canceled | done
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('events').add(eventPayload);

      // ── 2) Elder’s appointments subcollection (Account/{elderlyId}/appointments) ──
      final elderAppt = {
        'title': 'GP Consultation (Online)',
        'description': reason,
        'type': 'gp_consultation_booking',
        'dateTime': Timestamp.fromDate(start),
        'endDateTime': Timestamp.fromDate(end),
        'isAllDay': false,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db
          .collection('Account')
          .doc(elderlyId)
          .collection('appointments')
          .add(elderAppt);

      // ── 3) Mirror to caregivers’ subcollections ──────────────────
      if (mirrorToCaregivers && caregivers.isNotEmpty) {
        final batch = _db.batch();
        for (final cgUid in caregivers) {
          final ref = _db
              .collection('Account')
              .doc(cgUid)
              .collection('appointments')
              .doc();
          batch.set(ref, {
            'title': 'Elder: $elderlyName — GP Consultation',
            'description': reason,
            'type': 'elder_gp_consult',
            'dateTime': Timestamp.fromDate(start),
            'endDateTime': Timestamp.fromDate(end),
            'isAllDay': false,
            'status': 'scheduled',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // ── 4) (Optional) Top-level /appointments doc for notifications/CF ─────
      if (invitePrimaryCaregiver && invitedCaregiverUid != null) {
        await _db.collection('appointments').add({
          'elderlyUid': elderlyId,                // <- your rules check this
          'caregiverUid': invitedCaregiverUid,
          'timestamp': FieldValue.serverTimestamp(),
          'scheduledAt': Timestamp.fromDate(start),
          'type': 'GP Consultation',
          'notifyCaregiver': true,               // for Cloud Function trigger
        });
      }

      return BookingResult(true, 'Appointment booked. We’ll remind you before the call.');
    } on FirebaseException catch (e) {
      return BookingResult(false, e.message ?? e.code);
    } catch (e) {
      return BookingResult(false, e.toString());
    }
  }

  /// Optional: quick reasons (chips) from Firestore config.
  Stream<List<String>> quickReasonsStream() {
    return _db
        .collection('config')
        .doc('quickReasons')
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return const <String>[];
      final raw = data['reasons'];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const <String>[];
    });
  }
}
