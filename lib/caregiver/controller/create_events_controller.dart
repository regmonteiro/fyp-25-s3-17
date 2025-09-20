import 'package:cloud_firestore/cloud_firestore.dart';

class CreateEventsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createAppointment({
    required String elderlyId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    required bool isAllDay,
  }) async {
    try {
      await _firestore.collection('elderly').doc(elderlyId).collection('appointments').add({
        'title': title,
        'description': description,
        'dateTime': Timestamp.fromDate(dateTime),
        'type': type,
        'isAllDay': isAllDay,
      });
    } catch (e) {
      print("Error creating event: $e");
    }
  }
}