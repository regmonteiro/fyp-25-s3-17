import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String normalizeEmail(String? email) =>
    (email ?? '').trim().toLowerCase().replaceAll('.', '_');

int _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);

class Experience {
  final String id;
  final String title;
  final String description;
  final String user;
  final DateTime sharedAt;
  final int likes;
  final int comments;
  final bool liked;
  final String userName;

  Experience({
    required this.id,
    required this.title,
    required this.description,
    required this.user,
    required this.sharedAt,
    required this.likes,
    required this.comments,
    required this.liked,
    required this.userName,
  });

  static Experience fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String currentUserKey,
    required String Function(String emailKey) nameOf,
  }) {
    final d = doc.data() ?? {};
    final likedBy = (d['likedBy'] as Map<String, dynamic>?) ?? const {};
    final userKey = (d['user'] as String?) ?? '';
    final sharedAtStr =
        (d['sharedAt'] as String?) ?? DateTime.now().toUtc().toIso8601String();
    final parsed =
        DateTime.tryParse(sharedAtStr)?.toUtc() ?? DateTime.now().toUtc();

    return Experience(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      user: userKey,
      sharedAt: parsed,
      likes: _asInt(d['likes']),
      comments: _asInt(d['comments']),
      liked: likedBy[currentUserKey] == true,
      userName: nameOf(userKey),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'title': title,
      'description': description,
      'user': user,
      'sharedAt': sharedAt.toUtc().toIso8601String(),
      'likes': likes,
      'comments': comments,
      // likedBy created separately
    };
  }
}

class CommentModel {
  final String id;
  final String user;      // normalized email key
  final String userName;  // denormalized for faster UI
  final String content;
  final DateTime timestamp;

  CommentModel({
    required this.id,
    required this.user,
    required this.userName,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'user': user,
        'userName': userName,
        'content': content,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  static CommentModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CommentModel(
      id: doc.id,
      user: (d['user'] as String?) ?? '',
      userName: (d['userName'] as String?) ?? '',
      content: (d['content'] as String?) ?? '',
      timestamp: DateTime.tryParse((d['timestamp'] as String?) ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

class ShareExperienceController with ChangeNotifier {
  ShareExperienceController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  String get currentEmail =>
      _auth.currentUser?.email?.trim().toLowerCase() ?? 'anonymous@example.com';
  String get currentUserKey => normalizeEmail(currentEmail);

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('SharedExperiences');

  // ---------- CRUD posts ----------
  Future<String> addExperience({
    required String title,
    required String description,
  }) async {
    final doc = await _col.add(
      Experience(
        id: '',
        title: title.trim(),
        description: description.trim(),
        user: currentUserKey,
        sharedAt: DateTime.now().toUtc(),
        likes: 0,
        comments: 0,
        liked: false,
        userName: '',
      ).toCreateMap(),
    );
    await doc.update({'likedBy': {}});
    return doc.id;
  }

  Future<void> updateExperience({
    required String id,
    required String title,
    required String description,
  }) async {
    await _col.doc(id).update({
      'title': title.trim(),
      'description': description.trim(),
    });
  }

  Future<void> deleteExperience(String id) async {
    final comments = await _col.doc(id).collection('comments').get();
    for (final c in comments.docs) {
      await c.reference.delete();
    }
    await _col.doc(id).delete();
  }

  // ---------- Queries ----------
  Stream<List<Experience>> feed$({
    required String Function(String emailKey) nameOf,
  }) {
    return _col
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Experience.fromDoc(
                  d,
                  currentUserKey: currentUserKey,
                  nameOf: nameOf,
                ))
            .toList());
  }

  Stream<List<Experience>> myPosts$({
    required String Function(String emailKey) nameOf,
  }) {
    return _col
        .where('user', isEqualTo: currentUserKey)
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Experience.fromDoc(
                  d,
                  currentUserKey: currentUserKey,
                  nameOf: nameOf,
                ))
            .toList());
  }

  // ---------- Likes ----------
  Future<void> toggleLike(String id, bool currentlyLiked) async {
    final ref = _col.doc(id);
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = (snap.data() as Map<String, dynamic>);
      final likedBy = Map<String, dynamic>.from(data['likedBy'] ?? {});
      int likes = _asInt(data['likes']);

      if (currentlyLiked) {
        likedBy.remove(currentUserKey);
        likes = likes > 0 ? likes - 1 : 0;
      } else {
        likedBy[currentUserKey] = true;
        likes = likes + 1;
      }
      tx.update(ref, {'likedBy': likedBy, 'likes': likes});
    });
  }

  // ---------- Comments ----------
  Stream<List<CommentModel>> comments$(String postId) {
    return _col
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDoc).toList());
  }

  Future<void> addComment({
    required String postId,
    required String content,
    required String displayName,
  }) async {
    final ref = _col.doc(postId);
    await _fs.runTransaction((tx) async {
      final post = await tx.get(ref);
      if (!post.exists) return;

      final commentRef = ref.collection('comments').doc();
      tx.set(
        commentRef,
        CommentModel(
          id: commentRef.id,
          user: currentUserKey,
          userName: displayName,
          content: content.trim(),
          timestamp: DateTime.now().toUtc(),
        ).toMap(),
      );

      final current = (post.data() as Map<String, dynamic>);
      final comments = _asInt(current['comments']);
      tx.update(ref, {'comments': comments + 1});
    });
  }
}
