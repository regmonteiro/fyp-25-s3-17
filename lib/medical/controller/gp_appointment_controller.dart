import 'package:cloud_firestore/cloud_firestore.dart';

// 🔹 Get Account/{docRef} by real Firebase uid stored in field 'uid'
Future<DocumentReference<Map<String, dynamic>>> _accountDocRefByUid(
  FirebaseFirestore db,
  String uid,
) async {
  final q = await db.collection('Account').where('uid', isEqualTo: uid).limit(1).get();
  if (q.docs.isNotEmpty) return q.docs.first.reference;
  // fallback for old docs keyed by uid directly
  return db.collection('Account').doc(uid);
}

/// 🔹 Get both the DocumentReference and its data as a tuple
Future<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>
    _accountDocAndDataByUid(FirebaseFirestore db, String uid) async {
  final ref = await _accountDocRefByUid(db, uid);
  final snap = await ref.get();
  return (ref, snap.data() ?? <String, dynamic>{});
}

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

  // ---- linking --------------------------------------------------------------

  Future<List<String>> fetchLinkedCaregivers(String elderUid) async {
    final (elderRef, elder) = await _accountDocAndDataByUid(_db, elderUid);
    final raw = elder['linkedCaregiverUids'] ?? elder['linkedCaregivers'];
    if (raw is List) {
      return raw.map<String>((e) {
        if (e is String) return e.trim();
        if (e is Map) return (e['uid'] as String? ?? '').trim();
        return '';
      }).where((s) => s.isNotEmpty).toList(growable: false);
    }
    return const <String>[];
  }

  Future<Map<String, String>?> fetchPrimaryCaregiver(String elderUid) async {
    final cgs = await fetchLinkedCaregivers(elderUid);
    if (cgs.isEmpty) return null;
    final (ref, data) = await _accountDocAndDataByUid(_db, cgs.first);
    final display = (data['displayName'] as String?)?.trim();
    final first   = (data['firstName'] as String?)?.trim() ?? (data['firstname'] as String?)?.trim();
    final last    = (data['lastName']  as String?)?.trim() ?? (data['lastname']  as String?)?.trim();
    final best    = display?.isNotEmpty == true ? display! : [first, last].where((x) => (x ?? '').isNotEmpty).join(' ').trim();
    return {'uid': cgs.first, 'name': best.isEmpty ? 'Caregiver' : best};
  }

  /// Ensure **bi-directional** link:
  /// caregiver.Account.elderlyIds += elderUid
  /// elder.Account.linkedCaregiverUids += caregiverUid
  Future<void> ensureCaregiverLink({
    required String elderUid,
    required String caregiverUid,
  }) async {
    final cgRef = await _accountDocRefByUid(_db, caregiverUid);
    final elderRef = await _accountDocRefByUid(_db, elderUid);

    final batch = _db.batch();
    batch.set(cgRef, {'elderlyIds': FieldValue.arrayUnion([elderUid])}, SetOptions(merge: true));
    batch.set(elderRef, {'linkedCaregiverUids': FieldValue.arrayUnion([caregiverUid])}, SetOptions(merge: true));
    await batch.commit();
  }

  // ---- booking -------------------------------------------------------------

  /// 1) /events (flat)  2) Account/{elder}/appointments
  /// 3) mirror to each Account/{caregiver}/appointments
  /// 4) (optional) top-level /appointments (for CF or notifications)
  Future<BookingResult> bookFutureGpCall({
    required String elderlyId,
    required String elderlyName,
    required DateTime start,
    required Duration duration,
    required String reason,
    bool linkPrimaryCaregiverIfAny = true,
    bool invitePrimaryCaregiver   = false,
  }) async {
    if (reason.trim().isEmpty) {
      return BookingResult(false, 'Please provide a reason for the appointment.');
    }

    try {
      // resolve elder & caregivers
      final elderRef = await _accountDocRefByUid(_db, elderlyId);
      final caregivers = await fetchLinkedCaregivers(elderlyId);

      String? invitedCg;
      if (invitePrimaryCaregiver && caregivers.isNotEmpty) {
        invitedCg = caregivers.first;
        if (linkPrimaryCaregiverIfAny) {
          await ensureCaregiverLink(elderUid: elderlyId, caregiverUid: invitedCg);
        }
      }

      final end = start.add(duration);

      // (1) flat event
      final eventRef = _db.collection('events').doc();
      final eventPayload = {
        'title': 'GP Consultation (Online)',
        'description': reason,
        'type': 'gp_consultation_booking',
        'elderlyId': elderlyId,
        'elderlyName': elderlyName,
        'caregiverId': invitedCg,                 // creator/primary (optional)
        'linkedCaregivers': caregivers,
        'invitedCaregiverUid': invitedCg,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'isAllDay': false,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // (2) elder subcollection
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
        'createdAt': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();
      batch.set(eventRef, eventPayload);
      batch.set(elderApptRef, elderAppt);

      // (3) mirror into each caregiver's subcollection
      if (mirrorToCaregivers && caregivers.isNotEmpty) {
        for (final cgUid in caregivers) {
          final cgRef = await _accountDocRefByUid(_db, cgUid);
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

      // (4) optional top-level marker for CF/notifications
      if (invitedCg != null) {
        final top = _db.collection('appointments').doc();
        batch.set(top, {
          'elderlyUid': elderlyId,
          'caregiverUid': invitedCg,
          'scheduledAt': Timestamp.fromDate(start),
          'status': 'scheduled',
          'type': 'GP Consultation',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return BookingResult(true, 'Appointment booked and synced to calendar.');
    } on FirebaseException catch (e) {
      return BookingResult(false, e.message ?? e.code);
    } catch (e) {
      return BookingResult(false, e.toString());
    }
  }

  // Optional quick reasons
  Stream<List<String>> quickReasonsStream() {
    return _db.collection('config').doc('quickReasons').snapshots().map((d) {
      final data = d.data();
      final raw = data?['reasons'];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const <String>[];
    });
  }
}
