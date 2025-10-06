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

  Future<Map<String, String>?> fetchPrimaryCaregiver(String uidOfElder) async {
    final u = await _db.collection('users').doc(uidOfElder).get();
    final data = u.data() ?? const <String, dynamic>{};
    final caregivers = (data['linkedCaregivers'] is List)
        ? List<String>.from(data['linkedCaregivers'] as List)
        : const <String>[];
    if (caregivers.isEmpty) return null;

    final cgDoc = await _db.collection('users').doc(caregivers.first).get();
    final cgData = cgDoc.data() ?? const <String, dynamic>{};
    final name = (cgData['displayName'] as String?) ??
        (cgData['firstName'] as String? ?? 'Caregiver');
    return {'uid': caregivers.first, 'name': name};
  }

  /// Fetch all linked caregivers (for event audience & mirrored reminders).
  Future<List<String>> fetchLinkedCaregivers(String uidOfElder) async {
    final doc = await _db.collection('users').doc(uidOfElder).get();
    final data = doc.data() ?? const <String, dynamic>{};
    final raw = data['linkedCaregivers'];
    return (raw is List) ? raw.map((e) => e.toString()).toList() : const <String>[];
  }

  Future<BookingResult> bookFutureGpCall({
    required String uidOfElder,
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
      final caregivers = await fetchLinkedCaregivers(uidOfElder);
      String? invitedCaregiverUid;

      if (invitePrimaryCaregiver && caregivers.isNotEmpty) {
        invitedCaregiverUid = caregivers.first;
      }

      final end = start.add(duration);

      // 1) Global event
      final eventPayload = {
        'title': 'GP Consultation (Online)',
        'description': reason,
        'type': 'gp_consultation_booking',
        'elderlyUserId': uidOfElder,
        'elderlyName': elderlyName,
        'linkedCaregivers': caregivers,
        'invitedCaregiverUid': invitedCaregiverUid,
        'dateTime': Timestamp.fromDate(start),
        'endDateTime': Timestamp.fromDate(end),
        'isAllDay': false,
        'creatorUid': uidOfElder,
        'status': 'scheduled', // scheduled | canceled | done
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('events').add(eventPayload);

      // 2) Elder’s appointments subcollection
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
          .collection('users')
          .doc(uidOfElder)
          .collection('appointments')
          .add(elderAppt);

      // 3) Mirror to caregivers (so their Events/appointments streams pick it up)
      if (mirrorToCaregivers && caregivers.isNotEmpty) {
        final batch = _db.batch();
        for (final cgUid in caregivers) {
          final ref = _db
              .collection('users')
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
