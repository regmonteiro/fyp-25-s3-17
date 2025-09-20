import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverDashboardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to get all alerts for a specific elderly user
  Stream<QuerySnapshot> getAlertsStream(String elderlyId) {
    return _firestore
        .collection('alerts')
        .where('elderlyId', isEqualTo: elderlyId)
        .orderBy('ts', descending: true)
        .snapshots();
  }

  // Stream to get tasks for a specific elderly user, filtered by a date range
  Stream<QuerySnapshot> getTasksStream(String elderlyId, DateTime startDate, DateTime endDate) {
    return _firestore
        .collection('tasks')
        .where('elderlyId', isEqualTo: elderlyId)
        .where('dueAt', isGreaterThanOrEqualTo: startDate)
        .where('dueAt', isLessThanOrEqualTo: endDate)
        .snapshots();
  }

  // Stream to get medication logs for a specific elderly user
  Stream<QuerySnapshot> getMedLogsStream(String elderlyId) {
    return _firestore
        .collection('med_logs')
        .where('elderlyId', isEqualTo: elderlyId)
        .orderBy('ts', descending: true)
        .snapshots();
  }

  // Stream to get the next upcoming appointment
  Stream<QuerySnapshot> getNextAppointmentStream(String elderlyId) {
    return _firestore
        .collection('appointments')
        .where('elderlyId', isEqualTo: elderlyId)
        .where('start', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('start')
        .limit(1)
        .snapshots();
  }

  // Method to acknowledge an alert
  Future<void> acknowledgeAlert(String alertId, String caregiverId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'ack.by': caregiverId,
      'ack.ts': FieldValue.serverTimestamp(),
    });
  }
}
