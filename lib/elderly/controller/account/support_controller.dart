import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupportController {
  final _db = FirebaseFirestore.instance;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream() {
    return _db.collection('reviews').orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> addReview({required int stars, required String comment}) async {
    await _db.collection('reviews').add({
      'uid': uid,
      'stars': stars,
      'comment': comment,
      'createdAt': DateTime.now(),
    });
  }
}
