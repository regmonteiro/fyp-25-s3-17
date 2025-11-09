import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Controls saving cards, deleting cards, and handling subscription metadata.
/// Works with Firestore under `Account/{uid}/cards`.
class PaymentController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Convenience getter for current user’s uid
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Stream of saved cards for the logged-in user
  Stream<QuerySnapshot<Map<String, dynamic>>> cardsStream() {
    return _db.collection('Account').doc(_uid).collection('cards').snapshots();
  }

  /// Add or update a card document (you pass in brand/masked/etc)
  Future<void> addOrUpdateCard(Map<String, dynamic> payload) async {
    await _db.collection('Account').doc(_uid).collection('cards').add(payload);
  }

  /// Delete a card by id
  Future<void> deleteCard(String cardId) async {
    await _db.collection('Account').doc(_uid).collection('cards').doc(cardId).delete();
  }

  /// Fetch subscription metadata (status, endDate, etc.) from the user doc
  Future<Map<String, dynamic>?> fetchSubscription() async {
    final doc = await _db.collection('Account').doc(_uid).get();
    return doc.data();
  }

  /// Cancel subscription by updating status
  Future<void> cancelSubscription() async {
    await _db.collection('Account').doc(_uid).update({
      'subscriptionStatus': 'canceled',
    });
  }
}
