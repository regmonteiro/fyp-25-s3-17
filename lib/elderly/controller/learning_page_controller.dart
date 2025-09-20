import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LearningPageController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, List<dynamic>>> fetchLearningData() async {
    // This is a placeholder for fetching real data from Firestore
    // You can set up collections like 'learningTopics' and 'activities'
    final List<Map<String, dynamic>> allLearningTopics = [
      {
        'title': 'Managing Chronic Conditions',
        'description': 'Guides and tips for managing common chronic conditions like diabetes, arthritis, and hypertension.',
        'tags': ['Health', 'Guide'],
      },
      {
        'title': 'Nutrition for Seniors',
        'description': 'Nutrition advice and meal planning resources specifically for elderly adults.',
        'tags': ['Wellness', 'Diet'],
      },
      {
        'title': 'Understanding Power of Attorney',
        'description': 'Information about legal rights and appointing someone to make decisions on your behalf.',
        'tags': ['Legal', 'Guide'],
      },
      {
        'title': 'Mental Health Support',
        'description': 'Resources and hotlines for mental health support and counseling.',
        'tags': ['Wellness', 'Support'],
      },
      {
        'title': 'Community Activities for Seniors',
        'description': 'Directory of local clubs, events, and activities to stay active and socially connected.',
        'tags': ['Community', 'Social'],
      },
      {
        'title': 'Fall Prevention Tips',
        'description': 'Practical advice and exercises to reduce the risk of falls at home.',
        'tags': ['Health', 'Safety'],
      },
    ];

    final List<Map<String, dynamic>> allActivities = [
      {
        'image_url': 'https://placehold.co/600x400/808080/FFFFFF?text=Gardening',
        'title': 'Community Gardening',
        'description': 'Join local gardening groups.',
        'tags': ['Community', 'Moderate', '60 min'],
      },
      {
        'image_url': 'https://placehold.co/600x400/808080/FFFFFF?text=Cooking',
        'title': 'Cooking for Health',
        'description': 'Healthy and easy recipes.',
        'tags': ['Wellness', 'Easy', '30 min'],
      },
      {
        'image_url': 'https://placehold.co/600x400/808080/FFFFFF?text=Literacy',
        'title': 'Digital Literacy Workshop',
        'description': 'Learn how to use digital devices.',
        'tags': ['Learning', 'Easy', '45 min'],
      },
    ];

    return {
      'learningTopics': allLearningTopics,
      'activities': allActivities,
    };
  }

  Stream<DocumentSnapshot> getRewardPointsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('users').doc(user.uid).collection('points').doc('rewards').snapshots();
  }

  Future<void> redeemVoucher(int voucherValue) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userPointsDoc = _firestore.collection('users').doc(user.uid).collection('points').doc('rewards');
    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(userPointsDoc);

      if (!doc.exists) {
        throw Exception("Points document does not exist!");
      }

      final data = doc.data() as Map<String, dynamic>;
      int currentPoints = data['currentPoints'] ?? 0;
      // Removed the unused variable 'totalEarned'
      
      if (currentPoints < 50) {
        throw Exception("Not enough points to redeem.");
      }

      final pointsToDeduct = (currentPoints ~/ 50) * 50;

      transaction.update(userPointsDoc, {
        'currentPoints': currentPoints - pointsToDeduct,
        'lastRedeemed': FieldValue.serverTimestamp(),
      });

      // Add a record to redemption history
      _firestore.collection('users').doc(user.uid).collection('redemptionHistory').add({
        'voucherValue': voucherValue,
        'pointsRedeemed': pointsToDeduct,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> completeLearningTopic(String topicTitle) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Add points for completing a learning topic
    final pointsToAdd = 2;
    await _updatePoints(user.uid, pointsToAdd);
  }

  Future<void> completeActivity(String activityTitle) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Add points for completing an activity
    final pointsToAdd = 10;
    await _updatePoints(user.uid, pointsToAdd);
  }

  Future<void> _updatePoints(String uid, int pointsToAdd) async {
    final userPointsDoc = _firestore.collection('users').doc(uid).collection('points').doc('rewards');
    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(userPointsDoc);

      if (!doc.exists) {
        transaction.set(userPointsDoc, {
          'currentPoints': pointsToAdd,
          'totalEarned': pointsToAdd,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data() as Map<String, dynamic>;
        int currentPoints = data['currentPoints'] ?? 0;
        int totalEarned = data['totalEarned'] ?? 0;
        
        // Cap points at 500
        int newPoints = currentPoints + pointsToAdd;
        int newTotalEarned = totalEarned + pointsToAdd;
        if (newPoints > 500) {
          newPoints = 500;
        }

        transaction.update(userPointsDoc, {
          'currentPoints': newPoints,
          'totalEarned': newTotalEarned,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<QuerySnapshot> getPointsHistoryStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('users').doc(user.uid).collection('redemptionHistory').orderBy('timestamp', descending: true).snapshots();
  }
}
