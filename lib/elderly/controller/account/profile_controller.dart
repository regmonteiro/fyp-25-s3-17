import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileController {
  final _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Future<Map<String, dynamic>?> fetchProfile() async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    await _db.collection('users').doc(uid).update(updates);
  }

  Future<Map<String, dynamic>?> fetchPrimaryCaregiver() async {
    final q = await _db.collection('users').doc(uid).collection('caregivers')
      .orderBy('linkedAt', descending: true).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.data();
  }
}
