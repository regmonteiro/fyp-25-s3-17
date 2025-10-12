import 'dart:async';
import 'dart:math' show min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../boundary/post.dart';
import '../../models/user_profile.dart';

class Comment {
  final String userId;
  final String displayName;
  final String text;
  final Timestamp timestamp;

  Comment({
    required this.userId,
    required this.displayName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'displayName': displayName,
        'text': text,
        'timestamp': timestamp,
      };

  factory Comment.fromMap(Map<String, dynamic> data) {
    return Comment(
      userId: (data['userId'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? 'Unknown',
      text: (data['text'] as String?) ?? '',
      timestamp: (data['timestamp'] as Timestamp?) ?? Timestamp.now(),
    );
  }
}

class CommunityController with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Optional overrides (used only if you wire them in via ProxyProvider)
  String? _overrideUserId;
  UserProfile? _profile;

  // Collections
  static const String POSTS_COLLECTION = 'posts';
  static const String USERS_COLLECTION = 'users';
  static const String CHATS_COLLECTION = 'chats';
  static const String COMMENTS_SUBCOLLECTION = 'comments';

  // Public getters
  String? get currentUserId => _overrideUserId ?? _auth.currentUser?.uid;
  UserProfile? get currentUserProfile => _profile;

  // Optional setters (safe to ignore if you don’t use ProxyProvider)
  set overrideUserId(String? v) {
    _overrideUserId = v;
    notifyListeners();
  }

  set currentUserProfile(UserProfile? p) {
    _profile = p;
    notifyListeners();
  }

  // Normalize a Firestore array that might be List<String> or List<Map>
  List<String> _extractUidList(dynamic raw) {
    final list = (raw as List?) ?? const [];
    final out = <String>[];
    for (final e in list) {
      if (e is String) {
        out.add(e);
      } else if (e is Map && e['uid'] is String) {
        out.add(e['uid'] as String);
      }
    }
    return out;
  }

  // Merge multiple streams and keep results sorted by timestamp desc
  Stream<List<Post>> _combineAndSortPostStreams(List<Stream<List<Post>>> streams) {
    if (streams.isEmpty) return Stream.value(const []);
    final latest = <int, List<Post>>{};
    final controller = StreamController<List<Post>>();
    final subs = <StreamSubscription>[];

    void emit() {
      final combined = latest.values.expand((x) => x).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!controller.isClosed) controller.add(combined);
    }

    for (var i = 0; i < streams.length; i++) {
      final idx = i;
      subs.add(streams[i].listen((posts) {
        latest[idx] = posts;
        emit();
      }, onError: controller.addError, onDone: () {
        latest.remove(idx);
        if (latest.isEmpty && !controller.isClosed) controller.close();
      }));
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  // Stream posts for a list of author IDs, handling whereIn limit 10
  Stream<List<Post>> _getChunkedPostsStream(List<String> authorIds) {
    if (authorIds.isEmpty) return Stream.value(const []);
    final chunks = <List<String>>[];
    for (var i = 0; i < authorIds.length; i += 10) {
      final end = min(i + 10, authorIds.length);
      chunks.add(authorIds.sublist(i, end));
    }
    final streams = chunks.map((chunk) {
      return _firestore
          .collection(POSTS_COLLECTION)
          .where('authorId', whereIn: chunk)
          .snapshots()
          .map((qs) => qs.docs.map(Post.fromFirestore).toList());
    }).toList();

    return _combineAndSortPostStreams(streams);
  }

  // Main feed: current user + linked users, real-time
  Stream<List<Post>> get postsStream {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);

    final userStream = _firestore.collection(USERS_COLLECTION).doc(uid).snapshots();
    final controller = StreamController<List<Post>>();
    StreamSubscription? postsSub;

    userStream.listen((userDoc) {
      postsSub?.cancel();

      final data = userDoc.data();
      if (!userDoc.exists || data == null) {
        controller.add(const []);
        return;
      }

      final elders = _extractUidList(data['linkedElders']);
      final caregivers = _extractUidList(data['linkedCaregivers']);
      final all = <String>{...elders, ...caregivers, uid}.toList();

      postsSub = _getChunkedPostsStream(all).listen(
        controller.add,
        onError: controller.addError,
      );
    }, onError: controller.addError, onDone: () {
      postsSub?.cancel();
      controller.close();
    });

    controller.onCancel = () => postsSub?.cancel();

    return controller.stream.handleError((e) {
      if (kDebugMode) print('postsStream error: $e');
      return <Post>[];
    });
  }

  Future<void> createPost({
  required String content,
  String? imageUrl,
}) async {
  final user = _auth.currentUser;
  if (user == null) return;

  final userDoc = await _firestore.collection(USERS_COLLECTION).doc(user.uid).get();
  final userProfile = UserProfile.fromDocumentSnapshot(userDoc);
  final displayName = userProfile.displayName;

  await _firestore.collection(POSTS_COLLECTION).add({
    'authorId': user.uid,
    'authorDisplayName': displayName,
    'content': content,
    'imageUrl': imageUrl,
    'timestamp': FieldValue.serverTimestamp(),
    'likedBy': <String>[],
  });
}

  Future<void> toggleLike(Post post) async {
    final uid = currentUserId ?? _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _firestore.collection(POSTS_COLLECTION).doc(post.id);
    if (post.likedBy.contains(uid)) {
      await ref.update({'likedBy': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likedBy': FieldValue.arrayUnion([uid])});
    }
  }

  Future<void> addComment({
    required Post post,
    required String commentText,
    required UserProfile currentUserProfile,
  }) async {
    final uid = currentUserId ?? _auth.currentUser?.uid;
    if (uid == null) throw 'Not signed in';

    final comment = Comment(
      userId: uid,
      displayName: currentUserProfile.displayName,
      text: commentText,
      timestamp: Timestamp.now(),
    );

    await _firestore
        .collection(POSTS_COLLECTION)
        .doc(post.id)
        .collection(COMMENTS_SUBCOLLECTION)
        .add(comment.toFirestore());
  }

  Stream<List<Comment>> getCommentsStream(String postId) {
    return _firestore
        .collection(POSTS_COLLECTION)
        .doc(postId)
        .collection(COMMENTS_SUBCOLLECTION)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((qs) => qs.docs.map((d) => Comment.fromMap(d.data())).toList());
  }

  // --- Chat helpers (unchanged) ---
  String _getChatId(String a, String b) {
    final u = [a, b]..sort();
    return '${u[0]}_${u[1]}';
  }

  Stream<QuerySnapshot> getChatStream(String friendUid) {
    final uid = currentUserId ?? _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    final chatId = _getChatId(uid, friendUid);
    return _firestore
        .collection(CHATS_COLLECTION)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(String receiverUid, String text) async {
    final uid = currentUserId ?? _auth.currentUser?.uid;
    if (uid == null) return;
    final chatId = _getChatId(uid, receiverUid);
    await _firestore.collection(CHATS_COLLECTION).doc(chatId).collection('messages').add({
      'senderId': uid,
      'receiverId': receiverUid,
      'text': text,
      'timestamp': Timestamp.now(),
    });
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    final qLower = query.toLowerCase();

    final byName = await _firestore
        .collection(USERS_COLLECTION)
        .where('firstName', isGreaterThanOrEqualTo: query)
        .where('firstName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    final byEmail = await _firestore
        .collection(USERS_COLLECTION)
        .where('email', isGreaterThanOrEqualTo: qLower)
        .where('email', isLessThanOrEqualTo: '$qLower\uf8ff')
        .limit(10)
        .get();

    final seen = <String>{};
    final docs = <DocumentSnapshot>[];

    for (final d in byName.docs) {
      if (seen.add(d.id)) docs.add(d);
    }
    for (final d in byEmail.docs) {
      if (seen.add(d.id)) docs.add(d);
    }

    return docs.map(UserProfile.fromDocumentSnapshot).toList();
  }

  Future<void> linkUserForChat(String friendId) async {
    final uid = currentUserId ?? _auth.currentUser?.uid;
    if (uid == null) throw 'Not signed in';

    await _firestore.collection(USERS_COLLECTION).doc(uid).update({
      'linkedCaregivers': FieldValue.arrayUnion([friendId]),
    });

    await _firestore.collection(USERS_COLLECTION).doc(friendId).update({
      'linkedElders': FieldValue.arrayUnion([uid]),
    });
  }
}
