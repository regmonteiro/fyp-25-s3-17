import 'package:cloud_firestore/cloud_firestore.dart';

class CreateEventsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a caregiver event for an elder and mirror it under
  /// /Account/{elderlyId}/appointments with a mirrorEventId link.
  Future<void> createAppointment({
    required String elderlyId,
    required String caregiverId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    required bool isAllDay,
    Duration? duration,
  }) async {
    final effectiveDuration = duration ?? const Duration(minutes: 30);

    final DateTime start = isAllDay
        ? DateTime(dateTime.year, dateTime.month, dateTime.day, 0, 0)
        : dateTime;

    final DateTime end = isAllDay
        ? DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59)
        : dateTime.add(effectiveDuration);

    final eventsRef = _firestore.collection('events').doc();
    final apptRef = _firestore
        .collection('Account')
        .doc(elderlyId)
        .collection('appointments')
        .doc();

    final batch = _firestore.batch();

    // Flat /events (your rules require these exact keys)
    batch.set(eventsRef, {
      'elderlyId': elderlyId,
      'caregiverId': caregiverId,
      'title': title,
      'description': description,
      'type': type,              // 'appointment' | 'task' | 'reminder'
      'isAllDay': isAllDay,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': 'caregiver',
    });

    // Mirror under elder
    batch.set(apptRef, {
      'title': title,
      'description': description,
      'type': type,
      'isAllDay': isAllDay,
      'dateTime': Timestamp.fromDate(dateTime),
      'durationMinutes': isAllDay ? 1440 : effectiveDuration.inMinutes,
      'mirrorEventId': eventsRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': 'caregiver',
      'caregiverId': caregiverId,
    });

    await batch.commit();
  }
}
