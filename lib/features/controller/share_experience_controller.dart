import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore collections used:
/// - Account/{uid}
/// - SharedExperiences/{autoId}
/// - Comments/{autoId}
/// - Notifications/{autoId}
///
/// SharedExperiences fields:
///   user (String uid), title (String), description (String),
///   sharedAt (Timestamp), likes (int), comments (int)
///
/// Comments fields:
///   experienceId (String), userId (String uid),
///   content (String), timestamp (Timestamp), userName (String?)
///
/// Notifications fields:
///   toUser (String uid), fromUser (String uid), type (String),
///   title (String), message (String), relatedId (String?),
///   timestamp (Timestamp), read (bool), imageUrl (String?)

class ShareExperienceController extends ChangeNotifier {
  ShareExperienceController({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// ------------- Helpers -------------
  Future<String> resolveDisplayName(String uid) async {
    try {
      final snap = await _db.collection('Account').doc(uid).get();
      if (!snap.exists) return 'Anonymous';
      final data = snap.data() ?? {};
      final first = (data['firstname'] as String?)?.trim() ?? '';
      final last  = (data['lastname']  as String?)?.trim() ?? '';
      final full  = '$first $last'.trim();
      if (full.isNotEmpty) return full;
      return (data['email'] as String?)?.split('@').first ?? 'Anonymous';
    } catch (_) {
      return 'Anonymous';
    }
  }

  /// ------------- Stories -------------
  Stream<List<ExperienceView>> experiencesStream({String? onlyUid}) {
    Query<Map<String, dynamic>> q = _db
        .collection('SharedExperiences')
        .orderBy('sharedAt', descending: true);

    if (onlyUid != null && onlyUid.isNotEmpty) {
      q = _db
          .collection('SharedExperiences')
          .where('user', isEqualTo: onlyUid)
          .orderBy('sharedAt', descending: true);
    }

    return q.snapshots().asyncMap((snap) async {
      final items = <ExperienceView>[];
      for (final d in snap.docs) {
        final m = d.data();
        final uid = (m['user'] as String?) ?? '';
        final name = await resolveDisplayName(uid);
        items.add(
          ExperienceView(
            id: d.id,
            user: uid,
            userName: name,
            title: (m['title'] as String?) ?? '',
            description: (m['description'] as String?) ?? '',
            sharedAt: (m['sharedAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0),
            likes: (m['likes'] as num?)?.toInt() ?? 0,
            comments: (m['comments'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      return items;
    });
  }

  Future<void> addExperience({
    required String uid,
    required String title,
    required String description,
  }) async {
    final data = {
      'user': uid,
      'title': title.trim(),
      'description': description.trim(),
      'sharedAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'comments': 0,
    };
    await _db.collection('SharedExperiences').add(data);
  }

  Future<void> updateExperience({
    required String experienceId,
    required String uid,
    required String title,
    required String description,
    required DateTime sharedAt,
    int likes = 0,
    int comments = 0,
  }) async {
    await _db.collection('SharedExperiences').doc(experienceId).set({
      'user': uid,
      'title': title.trim(),
      'description': description.trim(),
      'sharedAt': Timestamp.fromDate(sharedAt),
      'likes': likes,
      'comments': comments,
    }, SetOptions(merge: true));
  }

  Future<void> deleteExperience(String id) async {
    await _db.collection('SharedExperiences').doc(id).delete();
    // Optionally remove related comments
    final cmts = await _db
        .collection('Comments')
        .where('experienceId', isEqualTo: id)
        .get();
    for (final c in cmts.docs) {
      await c.reference.delete();
    }
  }

  /// ------------- Likes (counter-only) -------------
  /// Mirrors your web logic: just increments/decrements a count;
  /// it does not store per-user like documents.
  Future<ToggleLikeResult> toggleLike({
    required String experienceId,
    required bool isCurrentlyLiked,
    String? experienceOwnerUid, // pass to optionally notify
    required String currentUid,
  }) async {
    final ref = _db.collection('SharedExperiences').doc(experienceId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Experience not found');
      final m = snap.data() as Map<String, dynamic>;
      final current = (m['likes'] as num?)?.toInt() ?? 0;
      final newLikes = isCurrentlyLiked
          ? (current > 0 ? current - 1 : 0)
          : current + 1;

      tx.update(ref, {'likes': newLikes});

      // Send notification only when liking and not liking own post
      if (!isCurrentlyLiked &&
          experienceOwnerUid != null &&
          experienceOwnerUid.isNotEmpty &&
          experienceOwnerUid != currentUid) {
        await _sendNotification(
          toUser: experienceOwnerUid,
          fromUser: currentUid,
          type: 'like',
          title: 'New Like',
          message:
              '${await resolveDisplayName(currentUid)} liked your story',
          relatedId: experienceId,
        );
      }

      return ToggleLikeResult(liked: !isCurrentlyLiked, newLikes: newLikes);
    });
  }

  /// ------------- Comments -------------
  Stream<List<CommentView>> commentsStream(String experienceId) {
    return _db
        .collection('Comments')
        .where('experienceId', isEqualTo: experienceId)
        .orderBy('timestamp')
        .snapshots()
        .asyncMap((snap) async {
      final items = <CommentView>[];
      for (final d in snap.docs) {
        final m = d.data() as Map<String, dynamic>;
        final uid = (m['userId'] as String?) ?? '';
        final name =
            (m['userName'] as String?)?.trim().isNotEmpty == true
                ? m['userName'] as String
                : await resolveDisplayName(uid);
        items.add(CommentView(
          id: d.id,
          userId: uid,
          displayName: name,
          content: (m['content'] as String?) ?? '',
          timestamp: (m['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ));
      }
      return items;
    });
  }

  Future<void> addComment({
    required String experienceId,
    required String userId,
    required String content,
  }) async {
    final batch = _db.batch();

    // 1) add the comment
    final cRef = _db.collection('Comments').doc();
    batch.set(cRef, {
      'experienceId': experienceId,
      'userId': userId,
      'content': content.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'userName': null, // let UI resolve name or set one if you wish
    });

    // 2) increment comments count on the experience
    final eRef = _db.collection('SharedExperiences').doc(experienceId);
    batch.update(eRef, {'comments': FieldValue.increment(1)});

    await batch.commit();
  }

  /// ------------- Notifications (basic) -------------
  Stream<List<AppNotification>> notificationsStream(String uid) {
    return _db
        .collection('Notifications')
        .where('toUser', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              return AppNotification(
                id: d.id,
                toUser: (m['toUser'] as String?) ?? '',
                fromUser: (m['fromUser'] as String?) ?? '',
                type: (m['type'] as String?) ?? 'general',
                title: (m['title'] as String?) ?? '',
                message: (m['message'] as String?) ?? '',
                relatedId: (m['relatedId'] as String?),
                timestamp: (m['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0),
                read: (m['read'] as bool?) ?? false,
                imageUrl: (m['imageUrl'] as String?),
              );
            }).toList());
  }

  Future<void> markAllNotificationsRead(String uid) async {
    final q = await _db
        .collection('Notifications')
        .where('toUser', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final d in q.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String id) async {
    await _db.collection('Notifications').doc(id).delete();
  }

  Future<void> _sendNotification({
    required String toUser,
    required String fromUser,
    required String type,
    required String title,
    required String message,
    String? relatedId,
    String? imageUrl,
  }) async {
    await _db.collection('Notifications').add({
      'toUser': toUser,
      'fromUser': fromUser,
      'type': type,
      'title': title,
      'message': message,
      'relatedId': relatedId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'imageUrl': imageUrl,
    });
  }
}

/// ----------- View Models (simple) -----------
class ExperienceView {
  final String id;
  final String user;
  final String userName;
  final String title;
  final String description;
  final DateTime sharedAt;
  final int likes;
  final int comments;

  ExperienceView({
    required this.id,
    required this.user,
    required this.userName,
    required this.title,
    required this.description,
    required this.sharedAt,
    required this.likes,
    required this.comments,
  });
}

class ToggleLikeResult {
  final bool liked;
  final int newLikes;
  ToggleLikeResult({required this.liked, required this.newLikes});
}

class CommentView {
  final String id;
  final String userId;
  final String displayName;
  final String content;
  final DateTime timestamp;

  CommentView({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.content,
    required this.timestamp,
  });
}

class AppNotification {
  final String id;
  final String toUser;
  final String fromUser;
  final String type;
  final String title;
  final String message;
  final String? relatedId;
  final DateTime timestamp;
  final bool read;
  final String? imageUrl;

  AppNotification({
    required this.id,
    required this.toUser,
    required this.fromUser,
    required this.type,
    required this.title,
    required this.message,
    required this.relatedId,
    required this.timestamp,
    required this.read,
    required this.imageUrl,
  });
}
