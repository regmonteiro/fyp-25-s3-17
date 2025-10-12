import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────────
  // READS (unchanged) – still used by EventsPage lists/search
  // ─────────────────────────────────────────────────────────────────────────────
  Stream<QuerySnapshot> getAppointmentsStream(String elderlyUserId) {
    return _firestore
        .collection('users')
        .doc(elderlyUserId)
        .collection('appointments')
        .orderBy('dateTime')
        .snapshots();
  }

  Stream<QuerySnapshot> getUpcomingEventsStream(String elderlyUserId) {
    return _firestore
        .collection('users')
        .doc(elderlyUserId)
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('dateTime')
        .snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CREATE – write appointment + mirror in /events (start/end)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> createAppointment({
    required String elderlyUserId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    bool isAllDay = false,
    int durationMinutes = 60, // NEW: used to build `end`
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    final apptRef = _firestore
        .collection('users')
        .doc(elderlyUserId)
        .collection('appointments')
        .doc();

    final eventRef = _firestore.collection('events').doc();

    final DateTime start = isAllDay
        ? DateTime(dateTime.year, dateTime.month, dateTime.day, 0, 0, 0)
        : dateTime;

    final DateTime end = isAllDay
        ? DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59)
        : dateTime.add(Duration(minutes: durationMinutes));

    final batch = _firestore.batch();

    // appointment doc (keeps your EventsPage UI working)
    batch.set(apptRef, {
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'type': type,
      'isAllDay': isAllDay,
      'durationMinutes': durationMinutes,
      'mirrorEventId': eventRef.id, // link to flat event
      'createdAt': FieldValue.serverTimestamp(),
    });

    // flat /events doc (read by Home)
    batch.set(eventRef, {
      'elderlyUserId': elderlyUserId,
      'caregiverId': uid, // creator (elder or caregiver)
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

  // ─────────────────────────────────────────────────────────────────────────────
  // UPDATE – update appointment and its mirrored /events doc
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> updateAppointment({
    required String elderlyUserId,
    required String appointmentId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    bool isAllDay = false,
    int? durationMinutes, // optional on update
  }) async {
    final apptRef = _firestore
        .collection('users')
        .doc(elderlyUserId)
        .collection('appointments')
        .doc(appointmentId);

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

    // update appointment
    batch.update(apptRef, {
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'type': type,
      'isAllDay': isAllDay,
      'durationMinutes': dur,
    });

    // update/create mirror event
    if (mirrorEventId != null && mirrorEventId.isNotEmpty) {
      final evRef = _firestore.collection('events').doc(mirrorEventId);
      batch.update(evRef, {
        'title': title,
        'description': description,
        'type': type,
        'isAllDay': isAllDay,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
      });
    } else {
      // no mirror yet → create one and store back
      final evRef = _firestore.collection('events').doc();
      batch.set(evRef, {
        'elderlyUserId': elderlyUserId,
        'caregiverId': FirebaseAuth.instance.currentUser?.uid,
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

  // ─────────────────────────────────────────────────────────────────────────────
  // DELETE – remove appointment and mirrored /events doc
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> deleteAppointment({
    required String elderlyUserId,
    required String appointmentId,
  }) async {
    final apptRef = _firestore
        .collection('users')
        .doc(elderlyUserId)
        .collection('appointments')
        .doc(appointmentId);

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
