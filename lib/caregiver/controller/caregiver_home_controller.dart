import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaregiverHomeController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentCaregiverUid => _auth.currentUser?.uid;

  Stream<DocumentSnapshot<Map<String, dynamic>>> getCaregiverStream() {
    final uid = currentCaregiverUid;
    if (uid == null) {
      return Stream.empty();
    }
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getElderStream(String elderId) {
    return _firestore.collection('users').doc(elderId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getMetricsStream(String elderId, String dayKey) {
    return _firestore.collection('metricsDaily').doc('${elderId}_$dayKey').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getTasksStream(String elderId, DateTime startOfDay, DateTime endOfDay) {
    return _firestore
        .collection('tasks')
        .where('elderId', isEqualTo: elderId)
        .where('dueAt', isGreaterThanOrEqualTo: startOfDay)
        .where('dueAt', isLessThan: endOfDay)
        .orderBy('dueAt')
        .snapshots();
  }

  Future<void> acknowledgeAlert(DocumentReference alertRef) async {
    await alertRef.update({'status': 'ack'});
  }

  Future<void> toggleTaskDone(DocumentReference taskRef, bool wasDone) async {
    final now = DateTime.now();
    await taskRef.update({
      'done': !wasDone,
      'completedAt': !wasDone ? now : null,
    });
  }

  Future<void> linkElder(String elderUid) async {
    final uid = currentCaregiverUid;
    if (uid == null) return;
    
    await _firestore.collection('users').doc(uid).update({
      'linkedElders': FieldValue.arrayUnion([elderUid]),
    });
  }
}