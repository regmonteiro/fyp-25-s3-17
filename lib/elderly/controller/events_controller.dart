import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<DocumentReference<Map<String, dynamic>>> _accountDocRefByUid(
  FirebaseFirestore db,
  String uid,
) async {
  final q = await db.collection('Account').where('uid', isEqualTo: uid).limit(1).get();
  if (q.docs.isNotEmpty) return q.docs.first.reference;
  // fallback for old docs keyed by uid directly
  return db.collection('Account').doc(uid);
}

Future<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>
    _accountDocAndDataByUid(FirebaseFirestore db, String uid) async {
  final ref = await _accountDocRefByUid(db, uid);
  final snap = await ref.get();
  return (ref, snap.data() ?? <String, dynamic>{});
}

class EventsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> _resolveElderId(String uid) async {
    final (_, data) = await _accountDocAndDataByUid(_firestore, uid);
    final String? elderlyId = (data['elderlyId'] as String?)?.trim();
    if (elderlyId != null && elderlyId.isNotEmpty) return elderlyId;
    final ids = data['elderlyIds'];
    if (ids is List && ids.isNotEmpty && ids.first is String) {
      final first = (ids.first as String).trim();
      if (first.isNotEmpty) return first;
    }
    return uid; // fallback
  }

  // ---- READS ---------------------------------------------------------------

  Stream<QuerySnapshot> getAppointmentsStream(String uid) async* {
    final ref = await _accountDocRefByUid(_firestore, uid);
    yield* ref.collection('appointments').orderBy('dateTime').snapshots();
  }

  Stream<QuerySnapshot> getUpcomingEventsStream(String uid) async* {
    final ref = await _accountDocRefByUid(_firestore, uid);
    yield* ref
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('dateTime')
        .snapshots();
  }

  // ---- CREATE --------------------------------------------------------------

  Future<void> createAppointment({
    required String uid, // auth.uid scope
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    bool isAllDay = false,
    int durationMinutes = 60,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) throw StateError('Not signed in');

    final userRef = await _accountDocRefByUid(_firestore, uid);
    final elderId = await _resolveElderId(uid);

    final apptRef  = userRef.collection('appointments').doc();
    final eventRef = _firestore.collection('events').doc();

    final DateTime start = isAllDay
        ? DateTime(dateTime.year, dateTime.month, dateTime.day, 0, 0, 0)
        : dateTime;
    final DateTime end = isAllDay
        ? DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59)
        : dateTime.add(Duration(minutes: durationMinutes));

    final batch = _firestore.batch();

    batch.set(apptRef, {
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'type': type,
      'isAllDay': isAllDay,
      'durationMinutes': durationMinutes,
      'mirrorEventId': eventRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(eventRef, {
      'elderlyId': elderId,
      'caregiverId': currentUid, // creator (could be elder themself)
      'title': title,
      'description': description,
      'type': type,
      'isAllDay': isAllDay,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ---- UPDATE --------------------------------------------------------------

  Future<void> updateAppointment({
    required String uid,
    required String appointmentId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    bool isAllDay = false,
    int? durationMinutes,
  }) async {
    final userRef = await _accountDocRefByUid(_firestore, uid);
    final apptRef = userRef.collection('appointments').doc(appointmentId);

    final apptSnap = await apptRef.get();
    if (!apptSnap.exists) throw StateError('Appointment not found');

    final data = apptSnap.data() as Map<String, dynamic>;
    final String? mirrorEventId = data['mirrorEventId'] as String?;
    final int dur = durationMinutes ?? (data['durationMinutes'] as int? ?? 60);

    final DateTime start = isAllDay
        ? DateTime(dateTime.year, dateTime.month, dateTime.day, 0, 0, 0)
        : dateTime;
    final DateTime end = isAllDay
        ? DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59)
        : dateTime.add(Duration(minutes: dur));

    final batch = _firestore.batch();

    batch.update(apptRef, {
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'type': type,
      'isAllDay': isAllDay,
      'durationMinutes': dur,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mirrorEventId != null && mirrorEventId.isNotEmpty) {
      final evRef = _firestore.collection('events').doc(mirrorEventId);
      batch.update(evRef, {
        'title': title,
        'description': description,
        'type': type,
        'isAllDay': isAllDay,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // create missing mirror
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) throw StateError('Not signed in');
      final elderId = await _resolveElderId(uid);

      final evRef = _firestore.collection('events').doc();
      batch.set(evRef, {
        'elderlyId': elderId,
        'caregiverId': currentUid,
        'title': title,
        'description': description,
        'type': type,
        'isAllDay': isAllDay,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(apptRef, {'mirrorEventId': evRef.id});
    }

    await batch.commit();
  }

  // ---- DELETE --------------------------------------------------------------

  Future<void> deleteAppointment({
    required String uid,
    required String appointmentId,
  }) async {
    final userRef = await _accountDocRefByUid(_firestore, uid);
    final apptRef = userRef.collection('appointments').doc(appointmentId);

    final apptSnap = await apptRef.get();
    if (!apptSnap.exists) return;

    final data = apptSnap.data() as Map<String, dynamic>;
    final String? mirrorEventId = data['mirrorEventId'] as String?;

    final batch = _firestore.batch();
    batch.delete(apptRef);
    if (mirrorEventId != null && mirrorEventId.isNotEmpty) {
      batch.delete(_firestore.collection('events').doc(mirrorEventId));
    }
    await batch.commit();
  }
}
