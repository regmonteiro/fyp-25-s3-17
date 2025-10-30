import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Resolve canonical elder id for a given auth uid.
  /// Prefers Account.elderlyId → first of Account.elderlyIds → fallback to uid.
  Future<String> _resolveElderId(String uid) async {
    final snap = await _firestore.collection('Account').doc(uid).get();
    final data = snap.data() ?? {};

    final String? elderlyId = (data['elderlyId'] as String?)?.trim();
    if (elderlyId != null && elderlyId.isNotEmpty) return elderlyId;

    final elderlyIds = data['elderlyIds'];
    if (elderlyIds is List && elderlyIds.isNotEmpty && elderlyIds.first is String) {
      final first = (elderlyIds.first as String).trim();
      if (first.isNotEmpty) return first;
    }
    return uid;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // READS (unchanged for your UI)
  // ─────────────────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> getAppointmentsStream(String uid) {
    return _firestore
        .collection('Account')
        .doc(uid)
        .collection('appointments')
        .orderBy('dateTime')
        .snapshots();
  }

  Stream<QuerySnapshot> getUpcomingEventsStream(String uid) {
    return _firestore
        .collection('Account')
        .doc(uid)
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('dateTime')
        .snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CREATE – write appointment + mirror in /events (elderlyId/caregiverId/start/end)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> createAppointment({
    required String uid,                // account scope where the appointment list lives (your UI passes auth.uid)
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    bool isAllDay = false,
    int durationMinutes = 60,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw StateError('Not signed in');
    }

    // Resolve which elder this item belongs to for the flat /events feed
    final elderId = await _resolveElderId(uid);

    final apptRef = _firestore
        .collection('Account')
        .doc(uid)
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

    // Appointment (drives EventsPage UI)
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

    // Flat /events (drives Home/aggregations)
    batch.set(eventRef, {
      'elderlyId': elderId,                // ← canonical elder id
      'caregiverId': currentUid,           // ← creator (could be the elder themselves)
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
    required String uid,             // scope where the appointment is stored
    required String appointmentId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    bool isAllDay = false,
    int? durationMinutes,
  }) async {
    final apptRef = _firestore
        .collection('Account')
        .doc(uid)
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

    // Update appointment
    batch.update(apptRef, {
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'type': type,
      'isAllDay': isAllDay,
      'durationMinutes': dur,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update/create mirror event so Home stays in sync
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
      // No mirror yet → create one and link back
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

  // ─────────────────────────────────────────────────────────────────────────────
  // DELETE – remove appointment and mirrored /events doc
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> deleteAppointment({
    required String uid,
    required String appointmentId,
  }) async {
    final apptRef = _firestore
        .collection('Account')
        .doc(uid)
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
