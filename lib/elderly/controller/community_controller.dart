import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityController {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Stream to get the list of friends for the current user.
  Stream<QuerySnapshot> getFriendsStream() {
    if (currentUserId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .snapshots();
  }

  // Stream to get chat messages between two users.
  Stream<QuerySnapshot> getChatStream(String friendUid) {
    if (currentUserId == null) {
      return const Stream.empty();
    }
    final chatId = _getChatId(currentUserId!, friendUid);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(String friendUid, String message) async {
    if (currentUserId == null) return;
    final chatId = _getChatId(currentUserId!, friendUid);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // New method to search for users by display name or email.
  Future<QuerySnapshot> searchUsers(String query) async {
    // Search by display name
    final nameQuery = _firestore.collection('users').where('displayName', isGreaterThanOrEqualTo: query).where('displayName', isLessThanOrEqualTo: '$query\uf8ff');

    // You could also search by email if you wish
    // final emailQuery = _firestore.collection('users').where('email', isEqualTo: query);
    
    // For simplicity, we only use the display name query
    return await nameQuery.get();
  }

  // New method to add a friend.
  Future<void> addFriend(String friendUid, String friendDisplayName) async {
    if (currentUserId == null) return;

    // Add friend to current user's friends collection
    await _firestore.collection('users').doc(currentUserId).collection('friends').doc(friendUid).set({
      'uid': friendUid,
      'displayName': friendDisplayName,
    });

    // Add current user to friend's friends collection
    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final currentUserName = currentUserDoc['displayName'] ?? 'User';

    await _firestore.collection('users').doc(friendUid).collection('friends').doc(currentUserId).set({
      'uid': currentUserId,
      'displayName': currentUserName,
    });
  }

  String _getChatId(String uid1, String uid2) {
    List<String> sortedUids = [uid1, uid2]..sort();
    return sortedUids.join('_');
  }
}