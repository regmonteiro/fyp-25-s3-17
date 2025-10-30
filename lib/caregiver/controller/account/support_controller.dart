import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupportController {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Public reviews list (or scope to your product)
  Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream() {
    return _db
        .collection('Reviews')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> addReview({required int stars, required String comment}) async {
    await _db.collection('Reviews').add({
      'uid': _uid,
      'stars': stars.clamp(1, 5),
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
