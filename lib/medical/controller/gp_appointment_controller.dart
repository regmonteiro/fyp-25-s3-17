import 'package:cloud_firestore/cloud_firestore.dart';

class BookingResult {
  final bool ok;
  final String message;
  BookingResult(this.ok, this.message);
}
class _FS {
  static const String account = 'Account';
  static const String events = 'events';
  static const String config = 'config';
}

class GpAppointmentController {
  final FirebaseFirestore _db;
  final bool mirrorToCaregivers;

  GpAppointmentController({
    FirebaseFirestore? db,
    this.mirrorToCaregivers = true,
  }) : _db = db ?? FirebaseFirestore.instance;

  // ───────────────────────── Account helpers (uid-first) ─────────────────────────

  /// Prefer an Account doc keyed by **uid**; if it doesn’t exist, fall back to a query.
  Future<DocumentReference<Map<String, dynamic>>> _accountDocRefByUid(String uid) async {
    // Try uid-keyed document
    final uidRef = _db.collection(_FS.account).doc(uid);
    final uidSnap = await uidRef.get();
    if (uidSnap.exists) return uidRef;

    // Fall back to the email-keyed doc that contains { uid: <uid> }
    final q = await _db
        .collection(_FS.account)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return q.docs.first.reference;

    // As a last resort, return uidRef (caller may choose to create minimal data)
    return uidRef;
  }

  /// Fetches (ref, data) tuple for an Account by uid. Data may be {} if not found.
  Future<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>
      _accountDocAndDataByUid(String uid) async {
    final ref = await _accountDocRefByUid(uid);
    final snap = await ref.get();
    return (ref, snap.data() ?? <String, dynamic>{});
  }

  // ───────────────────────── Caregiver linkage (one-sided write) ─────────────────

  /// Ensures the caregiver doc lists this elder uid in `elderlyIds`.
  ///
  /// ⚠️ Client should NOT write into the elder’s Account doc (rules disallow it).
  Future<void> ensureCaregiverLink({
    required String elderUid,
    required String caregiverUid,
  }) async {
    if (elderUid.trim().isEmpty || caregiverUid.trim().isEmpty) return;

    final cgRef = _db.collection(_FS.account).doc(caregiverUid);
    final cgSnap = await cgRef.get();
    if (!cgSnap.exists) {
      throw StateError('Caregiver account not found for uid=$caregiverUid');
    }

    await cgRef.set(
      {'elderlyIds': FieldValue.arrayUnion([elderUid])},
      SetOptions(merge: true),
    );
  }

  /// Returns all caregiver UIDs who are linked to this elder (caregivers have `elderlyIds`).
  Future<List<String>> fetchLinkedCaregivers(String elderUid) async {
    final q = await _db
        .collection(_FS.account)
        .where('elderlyIds', arrayContains: elderUid)
        .get();

    return q.docs
        .map((d) => (d.data()['uid'] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Picks a "primary" caregiver: currently first caregiver found, with a best-effort name.
  Future<Map<String, String>?> fetchPrimaryCaregiver(String elderUid) async {
    final uids = await fetchLinkedCaregivers(elderUid);
    if (uids.isEmpty) return null;

    final (ref, data) = await _accountDocAndDataByUid(uids.first);
    String? display = (data['displayName'] as String?)?.trim();
    final first = (data['firstName'] as String?)?.trim() ?? (data['firstname'] as String?)?.trim();
    final last  = (data['lastName']  as String?)?.trim() ?? (data['lastname']  as String?)?.trim();

    display = (display != null && display.isNotEmpty)
        ? display
        : [first, last].where((e) => (e ?? '').isNotEmpty).join(' ').trim();

    return {
      'uid': ref.id,
      'name': (display == null || display.isEmpty) ? 'Caregiver' : display,
    };
  }

  // ─────────────────────────── Booking (events + subcollections) ─────────────────

  /// Creates a GP booking event for an elder and mirrors it into:
  ///  • Account/{elderUid}/appointments (allowed for owner or linked caregiver)
  ///  • Account/{caregiverUid}/appointments for each linked caregiver (optional)
  ///
  /// Assumes caller is the elder OR a linked caregiver (per your rules).
  Future<BookingResult> bookFutureGpCall({
    required String elderlyId,      // elder uid
    required String elderlyName,
    required DateTime start,
    required Duration duration,
    required String reason,
    bool invitePrimaryCaregiver = false, // kept for API symmetry (not strictly required here)
  }) async {
    if (reason.trim().isEmpty) {
      return BookingResult(false, 'Please provide a reason for the appointment.');
    }

    try {
      final elderRef = await _accountDocRefByUid(elderlyId);

      // Discover caregivers who already link to this elder
      final caregivers = await fetchLinkedCaregivers(elderlyId);
      final invitedCg = invitePrimaryCaregiver && caregivers.isNotEmpty ? caregivers.first : null;

      final end = start.add(duration);

      // (1) Flat "events" document (simple calendar list)
      final eventRef = _db.collection(_FS.events).doc();
      final eventPayload = {
        'title': 'GP Consultation (Online)',
        'description': reason,
        'type': 'gp_consultation_booking',
        'elderlyId': elderlyId,
        'elderlyName': elderlyName,
        'caregiverId': invitedCg,              // optional
        'linkedCaregivers': caregivers,        // snapshot of links at booking time
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'isAllDay': false,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // (2) Elder subcollection appointment
      final elderApptRef = elderRef.collection('appointments').doc();
      final elderAppt = {
        'title': 'GP Consultation (Online)',
        'description': reason,
        'type': 'gp_consultation_booking',
        'dateTime': Timestamp.fromDate(start),
        'endDateTime': Timestamp.fromDate(end),
        'isAllDay': false,
        'status': 'scheduled',
        'mirrorEventId': eventRef.id,
        'elderUid': elderlyId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();
      batch.set(eventRef, eventPayload);
      batch.set(elderApptRef, elderAppt);

      // (3) Mirror into each caregiver's appointments (optional)
      if (mirrorToCaregivers && caregivers.isNotEmpty) {
        for (final cgUid in caregivers) {
          final cgRef = await _accountDocRefByUid(cgUid);
          final cgApptRef = cgRef.collection('appointments').doc();
          batch.set(cgApptRef, {
            'title': 'Elder: $elderlyName — GP Consultation',
            'description': reason,
            'type': 'elder_gp_consult',
            'dateTime': Timestamp.fromDate(start),
            'endDateTime': Timestamp.fromDate(end),
            'isAllDay': false,
            'status': 'scheduled',
            'elderUid': elderlyId,
            'mirrorEventId': eventRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // (4) Commit
      await batch.commit();
      return BookingResult(true, 'Appointment booked and synced to calendar.');
    } on FirebaseException catch (e) {
      return BookingResult(false, e.message ?? e.code);
    } catch (e) {
      return BookingResult(false, e.toString());
    }
  }

  // ───────────────────────────── Config / Quick reasons ──────────────────────────

  /// Stream of quick reasons from /config/quickReasons { reasons: [..] }
  Stream<List<String>> quickReasonsStream() {
    return _db.collection(_FS.config).doc('quickReasons').snapshots().map((snap) {
      final data = snap.data();
      final raw = data?['reasons'];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const <String>[];
    });
  }
}
