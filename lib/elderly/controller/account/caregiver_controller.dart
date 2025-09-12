import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaregiverController {
  final _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> caregiversStream() {
    return _db.collection('users').doc(uid).collection('caregivers').snapshots();
  }

  Future<void> removeCaregiver(String id) async {
    await _db.collection('users').doc(uid).collection('caregivers').doc(id).delete();
  }

  Future<void> addCaregiverAndCharge(Map<String, dynamic> cg) async {
    // In production, you would call your payment provider here.
    await _db.collection('users').doc(uid).collection('caregivers').add({
      ...cg,
      'linkedAt': DateTime.now(),
      'access': {
        'viewReminders': true,
        'createReminders': true,
        'viewHealth': false,
        'chat': true,
      }
    });
  }

  Future<void> updateCaregiverAccess(String id, Map<String, dynamic> access) async {
    await _db.collection('users').doc(uid).collection('caregivers').doc(id).update({'access': access});
  }
}
