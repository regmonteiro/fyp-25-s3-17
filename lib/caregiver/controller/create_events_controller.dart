import 'package:cloud_firestore/cloud_firestore.dart';

class CreateEventsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createAppointment({
    required String elderlyId, // Ensure this is a parameter
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    required bool isAllDay,
    required String caregiverId,
  }) async {
    await _firestore.collection('events').add({
      'elderlyId': elderlyId, // Add this line
      'title': title,
      'description': description,
      'dateTime': dateTime,
      'type': type,
      'isAllDay': isAllDay,
      'caregiverId': caregiverId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}