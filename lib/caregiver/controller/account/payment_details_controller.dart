import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentController {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser?.uid;
    if (u == null) throw StateError('User not signed in');
    return u;
  }

  /// One-time load of plan/subscription fields from Account/{uid}
  Future<Map<String, dynamic>?> loadSubscription() async {
    final snap = await _db.collection('Account').doc(_uid).get();
    return snap.data();
  }

  /// Cards under Account/{uid}/cards
  Stream<QuerySnapshot<Map<String, dynamic>>> cardsStream() {
    return _db
        .collection('Account').doc(_uid)
        .collection('cards')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  Future<void> addOrUpdateCard(Map<String, dynamic> payload) async {
    await _db
        .collection('Account').doc(_uid)
        .collection('cards')
        .add(payload);
  }

  Future<void> deleteCard(String cardDocId) async {
    await _db
        .collection('Account').doc(_uid)
        .collection('cards')
        .doc(cardDocId)
        .delete();
  }

  /// Simple local “cancel”: mark on Account doc. Replace with gateway call if needed.
  Future<void> cancelSubscription() async {
    await _db.collection('Account').doc(_uid).set({
      'subscriptionStatus': 'canceled',
      'subscriptionCanceledAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
