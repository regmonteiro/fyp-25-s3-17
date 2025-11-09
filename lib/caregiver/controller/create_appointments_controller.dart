import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateAppointmentsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates an appointment directly in `/Appointments/{id}`
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
    final durationMinutes = (duration ?? const Duration(minutes: 30)).inMinutes;

    // Split date/time for Firestore readability
    final dateStr = DateFormat('yyyy-MM-dd').format(dateTime);
    final timeStr = DateFormat('HH:mm').format(dateTime);

    final docRef = _firestore.collection('Appointments').doc();

    await docRef.set({
      'id': docRef.id,
      'elderlyId': elderlyId,
      'caregiverId': caregiverId,
      'title': title.trim(),
      'notes': description.trim(),
      'type': type, // e.g. 'appointment' | 'task' | 'reminder'
      'isAllDay': isAllDay,
      'durationMinutes': isAllDay ? 1440 : durationMinutes,
      'date': dateStr,
      'time': timeStr,
      'createdBy': 'caregiver',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
