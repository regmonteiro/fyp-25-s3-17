import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ElderlyHomeController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // The User object from Firebase Authentication.
  User? get currentUser => _auth.currentUser;

  // Stream to listen for real-time announcements.
  Stream<QuerySnapshot> getAnnouncementsStream() {
    return _firestore.collection('announcements').snapshots();
  }

  // Stream to listen for real-time events for the current user.
  Stream<QuerySnapshot> getEventsStream() {
    if (currentUser == null) return const Stream.empty();
    return _firestore
        .collection('events')
        .where('userId', isEqualTo: currentUser!.uid)
        .snapshots();
  }

  // Stream to listen for real-time learning recommendations.
  Stream<QuerySnapshot> getLearningRecommendationsStream() {
    // You could filter these based on user preferences or a learning path.
    return _firestore.collection('learning').snapshots();
  }

  // Fetch the elderly user's data from Firestore.
  Future<DocumentSnapshot> fetchUserData() {
    if (currentUser == null) {
      return Future.error('No user logged in.');
    }
    return _firestore.collection('elderlyUsers').doc(currentUser!.uid).get();
  }
}