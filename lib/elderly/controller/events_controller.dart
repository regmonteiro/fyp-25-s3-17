import 'package:cloud_firestore/cloud_firestore.dart';

class EventsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getAppointmentsStream(String elderlyUserId) {
    return _firestore.collection('users').doc(elderlyUserId).collection('appointments').orderBy('dateTime').snapshots();
  }

  Stream<QuerySnapshot> getUpcomingEventsStream(String elderlyUserId) {
    return _firestore.collection('users').doc(elderlyUserId).collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('dateTime')
        .snapshots();
  }

  Future<void> createAppointment({
    required String elderlyUserId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    bool isAllDay = false,
  }) async {
    try {
      await _firestore.collection('users').doc(elderlyUserId).collection('appointments').add({
        'title': title,
        'description': description,
        'dateTime': Timestamp.fromDate(dateTime),
        'type': type,
        'isAllDay': isAllDay,
      });
    } catch (e) {
      print("Error adding appointment: $e");
    }
  }

  Future<void> updateAppointment({
    required String elderlyUserId,
    required String appointmentId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    bool isAllDay = false,
  }) async {
    try {
      await _firestore.collection('users').doc(elderlyUserId).collection('appointments').doc(appointmentId).update({
        'title': title,
        'description': description,
        'dateTime': Timestamp.fromDate(dateTime),
        'type': type,
        'isAllDay': isAllDay,
      });
    } catch (e) {
      print("Error updating appointment: $e");
    }
  }

  Future<void> deleteAppointment({
    required String elderlyUserId,
    required String appointmentId,
  }) async {
    try {
      await _firestore.collection('users').doc(elderlyUserId).collection('appointments').doc(appointmentId).delete();
    } catch (e) {
      print("Error deleting appointment: $e");
    }
  }
}
