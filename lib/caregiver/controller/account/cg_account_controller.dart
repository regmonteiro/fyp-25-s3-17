import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CgAccountController {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser?.uid;
    if (u == null) throw StateError('User not signed in');
    return u;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> loadAccount() {
    return _db.collection('Account').doc(_uid).get();
  }

  Future<void> updateAccount(Map<String, dynamic> patch) async {
    await _db.collection('Account').doc(_uid).set(
      patch,
      SetOptions(merge: true),
    );
  }
}
