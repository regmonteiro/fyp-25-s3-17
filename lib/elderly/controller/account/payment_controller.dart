import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentController {
  final _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Future<Map<String, dynamic>?> fetchSubscription() async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> cardsStream() {
    return _db.collection('users').doc(uid).collection('cards').snapshots();
  }

  Future<void> addOrUpdateCard(Map<String, dynamic> card) async {
    await _db.collection('users').doc(uid).collection('cards').add(card);
  }

  Future<void> deleteCard(String cardId) async {
    await _db.collection('users').doc(uid).collection('cards').doc(cardId).delete();
  }

  Future<void> cancelSubscription() async {
    await _db.collection('users').doc(uid).update({
      'subscriptionStatus': 'canceled',
      'subscriptionEndDate': DateTime.now().toIso8601String(),
    });
  }
}
