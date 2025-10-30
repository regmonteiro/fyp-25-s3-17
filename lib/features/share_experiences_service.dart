import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// ======================== Helpers ========================

String normalizeEmail(String? email) {
  if (email == null || email.isEmpty) return '';
  return email.trim().toLowerCase().replaceAll('.', '_');
}

DateTime _parseDate(dynamic ts) {
  if (ts == null) return DateTime.now();
  if (ts is String) {
    final d = DateTime.tryParse(ts);
    return d ?? DateTime.now();
  }
  return DateTime.now();
}

List<T> _listFromMap<T>(
  Object? value,
  T Function(String id, Map<dynamic, dynamic> data) mapper,
) {
  final map = (value as Map?)?.cast<dynamic, dynamic>() ?? {};
  final out = <T>[];
  map.forEach((k, v) {
    if (v is Map) out.add(mapper(k.toString(), v));
  });
  return out;
}

/// ======================== Models ========================

class Experience {
  final String id;
  final String user; // normalized key (email with underscores)
  final String title;
  final String description;
  final DateTime sharedAt;
  final int likes;
  final int comments;

  Experience({
    required this.id,
    required this.user,
    required this.title,
    required this.description,
    required this.sharedAt,
    required this.likes,
    required this.comments,
  });

  Map<String, dynamic> toMap() => {
        'user': user,
        'title': title,
        'description': description,
        'sharedAt': sharedAt.toIso8601String(),
        'likes': likes,
        'comments': comments,
      };

  static Experience fromRTDB(String id, Map data) => Experience(
        id: id,
        user: (data['user'] ?? 'anonymous').toString(),
        title: (data['title'] ?? '').toString(),
        description: (data['description'] ?? '').toString(),
        sharedAt: _parseDate(data['sharedAt']),
        likes: int.tryParse('${data['likes'] ?? 0}') ?? 0,
        comments: int.tryParse('${data['comments'] ?? 0}') ?? 0,
      );
}

class CommentModel {
  final String id;
  final String experienceId;
  final String userId; // normalized key
  final String content;
  final DateTime timestamp;
  final String? userName;

  CommentModel({
    required this.id,
    required this.experienceId,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.userName,
  });

  Map<String, dynamic> toMap() => {
        'experienceId': experienceId,
        'userId': userId,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'userName': userName,
      };

  static CommentModel fromRTDB(String id, Map data) => CommentModel(
        id: id,
        experienceId: (data['experienceId'] ?? '').toString(),
        userId: (data['userId'] ?? '').toString(),
        content: (data['content'] ?? '').toString(),
        timestamp: _parseDate(data['timestamp']),
        userName: data['userName']?.toString(),
      );
}

class MessageModel {
  final String id;
  final String fromUser; // normalized or raw email (we normalize when comparing)
  final String toUser;
  final String content; // JSON string {content, attachments}
  final DateTime timestamp;
  final bool read;

  MessageModel({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.content,
    required this.timestamp,
    required this.read,
  });

  Map<String, dynamic> toMap() => {
        'fromUser': fromUser,
        'toUser': toUser,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'read': read,
      };

  static MessageModel fromRTDB(String id, Map data) => MessageModel(
        id: id,
        fromUser: (data['fromUser'] ?? '').toString(),
        toUser: (data['toUser'] ?? '').toString(),
        content: (data['content'] ?? '').toString(),
        timestamp: _parseDate(data['timestamp']),
        read: data['read'] == true,
      );
}

class NotificationModel {
  final String id;
  final String toUser;
  final String fromUser;
  final String type; // message | like | comment | new_post | general
  final String title;
  final String message;
  final String? relatedId;
  final DateTime timestamp;
  final bool read;

  NotificationModel({
    required this.id,
    required this.toUser,
    required this.fromUser,
    required this.type,
    required this.title,
    required this.message,
    required this.relatedId,
    required this.timestamp,
    required this.read,
  });

  Map<String, dynamic> toMap() => {
        'toUser': toUser,
        'fromUser': fromUser,
        'type': type,
        'title': title,
        'message': message,
        'relatedId': relatedId,
        'timestamp': timestamp.toIso8601String(),
        'read': read,
      };

  static NotificationModel fromRTDB(String id, Map data) => NotificationModel(
        id: id,
        toUser: (data['toUser'] ?? '').toString(),
        fromUser: (data['fromUser'] ?? '').toString(),
        type: (data['type'] ?? 'general').toString(),
        title: (data['title'] ?? '').toString(),
        message: (data['message'] ?? '').toString(),
        relatedId: data['relatedId']?.toString(),
        timestamp: _parseDate(data['timestamp']),
        read: data['read'] == true,
      );
}

class FriendRequest {
  final String id;
  final String fromUser;
  final String toUser;
  final String status; // pending | accepted | rejected
  final DateTime timestamp;

  FriendRequest({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.status,
    required this.timestamp,
  });

  static FriendRequest fromRTDB(String id, Map data) => FriendRequest(
        id: id,
        fromUser: (data['fromUser'] ?? '').toString(),
        toUser: (data['toUser'] ?? '').toString(),
        status: (data['status'] ?? 'pending').toString(),
        timestamp: _parseDate(data['timestamp']),
      );
}

class FriendRel {
  final String id;
  final String user1; // normalized or raw; we compare normalized
  final String user2;

  FriendRel({required this.id, required this.user1, required this.user2});

  static FriendRel fromRTDB(String id, Map data) => FriendRel(
        id: id,
        user1: (data['user1'] ?? '').toString(),
        user2: (data['user2'] ?? '').toString(),
      );
}

/// =================== Service ===================
/// - Firestore: reads collection("Account") for account profiles
/// - RTDB: everything else to match your web controller

class ShareExperienceService {
  ShareExperienceService._();
  static final instance = ShareExperienceService._();

  // Firestore for Accounts
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // RTDB for social data
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// --------- Accounts (FIRESTORE) ----------
  /// Returns a map keyed by normalized email to match your React logic
  Future<Map<String, dynamic>> getAccounts() async {
    final snap = await _fs.collection('Account').get();
    final map = <String, dynamic>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      // Expect fields: email, firstname, lastname, userType, uid, phoneNum, elderlyId/elderlyIds etc.
      final email = (data['email'] ?? '').toString();
      final key = normalizeEmail(email);
      map[key] = {
        ...data,
        'email': email,
      };
    }
    return map;
  }

  /// --------- Experiences (RTDB) ----------
  Stream<List<Experience>> streamExperiences({String? onlyForUserKey}) {
    final ref = _db.child('SharedExperiences');
    return ref.onValue.map((event) {
      final list = _listFromMap<Experience>(event.snapshot.value, (id, data) {
        return Experience.fromRTDB(id, data);
      });
      final filtered =
          onlyForUserKey == null ? list : list.where((e) => e.user == onlyForUserKey).toList();
      filtered.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
      return filtered;
    });
  }

  Future<void> addExperience({
    required String userKey,
    required String title,
    required String description,
  }) async {
    await _db.child('SharedExperiences').push().set(Experience(
              id: '',
              user: userKey,
              title: title.trim(),
              description: description.trim(),
              sharedAt: DateTime.now(),
              likes: 0,
              comments: 0,
            ).toMap());
  }

  Future<void> updateExperience(Experience e) async {
    await _db.child('SharedExperiences/${e.id}').set(e.toMap());
  }

  Future<void> deleteExperience(String id) async {
    await _db.child('SharedExperiences/$id').remove();
  }

  Future<Map<String, dynamic>> toggleLike({
    required String experienceId,
    required bool isCurrentlyLiked,
  }) async {
    final ref = _db.child('SharedExperiences/$experienceId');
    final snap = await ref.get();
    final exp = (snap.value as Map?)?.cast<dynamic, dynamic>();
    if (exp == null) throw Exception('Experience not found');
    final currentLikes = int.tryParse('${exp['likes'] ?? 0}') ?? 0;
    final newLikes = isCurrentlyLiked ? (currentLikes - 1).clamp(0, 1 << 31) : currentLikes + 1;
    await ref.set({...exp, 'likes': newLikes});
    return {'newLikes': newLikes, 'liked': !isCurrentlyLiked};
  }

  /// --------- Comments (RTDB) ----------
  Stream<List<CommentModel>> streamComments(String experienceId) {
    final ref = _db.child('Comments');
    return ref.onValue.map((event) {
      final all = _listFromMap<CommentModel>(event.snapshot.value, (id, data) {
        return CommentModel.fromRTDB(id, data);
      });
      final filtered = all.where((c) => c.experienceId == experienceId).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return filtered;
    });
  }

  Future<void> addComment({
    required String experienceId,
    required String userKey,
    required String content,
    String? userName,
  }) async {
    await _db.child('Comments').push().set(CommentModel(
              id: '',
              experienceId: experienceId,
              userId: userKey,
              content: content.trim(),
              timestamp: DateTime.now(),
              userName: userName,
            ).toMap());

    // bump counter
    final expRef = _db.child('SharedExperiences/$experienceId');
    final snap = await expRef.get();
    final exp = (snap.value as Map?)?.cast<dynamic, dynamic>();
    if (exp != null) {
      final newCount = (int.tryParse('${exp['comments'] ?? 0}') ?? 0) + 1;
      await expRef.set({...exp, 'comments': newCount});
    }
  }

  /// --------- Messaging (RTDB) ----------
  Stream<List<MessageModel>> streamConversation(String aKey, String bKey) {
    final ref = _db.child('Messages');
    final aN = normalizeEmail(aKey);
    final bN = normalizeEmail(bKey);
    return ref.onValue.map((event) {
      final all = _listFromMap<MessageModel>(event.snapshot.value, (id, data) {
        return MessageModel.fromRTDB(id, data);
      });
      final between = all.where((m) {
        final fromN = normalizeEmail(m.fromUser);
        final toN = normalizeEmail(m.toUser);
        return (fromN == aN && toN == bN) || (fromN == bN && toN == aN);
      }).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return between;
    });
  }

  Future<void> sendMessage({
    required String fromUser,
    required String toUser,
    required Map<String, dynamic> contentJson,
  }) async {
    await _db.child('Messages').push().set(MessageModel(
              id: '',
              fromUser: fromUser,
              toUser: toUser,
              content: jsonEncode(contentJson),
              timestamp: DateTime.now(),
              read: false,
            ).toMap());
  }

  Future<void> markMessagesAsRead(String fromUser, String toUser) async {
    final ref = _db.child('Messages');
    final fromN = normalizeEmail(fromUser);
    final toN = normalizeEmail(toUser);
    final snap = await ref.get();
    final map = (snap.value as Map?)?.cast<dynamic, dynamic>() ?? {};
    final futures = <Future>[];
    map.forEach((id, raw) {
      final msg = (raw as Map).cast<dynamic, dynamic>();
      final mFromN = normalizeEmail(msg['fromUser']?.toString() ?? '');
      final mToN = normalizeEmail(msg['toUser']?.toString() ?? '');
      final read = msg['read'] == true;
      final isMatch = (mFromN == fromN && mToN == toN) && !read;
      if (isMatch) {
        futures.add(ref.child(id.toString()).set({...msg, 'read': true}));
      }
    });
    await Future.wait(futures);
  }

  Stream<List<Map<String, dynamic>>> streamUserConversations(String userKey) {
    final ref = _db.child('Messages');
    final meN = normalizeEmail(userKey);
    return ref.onValue.map((event) {
      final all = _listFromMap<MessageModel>(event.snapshot.value, (id, data) {
        return MessageModel.fromRTDB(id, data);
      });
      final conv = <String, MessageModel>{};
      for (final m in all) {
        final fromN = normalizeEmail(m.fromUser);
        final toN = normalizeEmail(m.toUser);
        if (fromN != meN && toN != meN) continue;
        final partner = fromN == meN ? m.toUser : m.fromUser;
        final pN = normalizeEmail(partner);
        final prev = conv[pN];
        if (prev == null || m.timestamp.isAfter(prev.timestamp)) {
          conv[pN] = m;
        }
      }
      final list = conv.entries.map((e) {
        final last = e.value;
        final partner = normalizeEmail(last.fromUser) == meN ? last.toUser : last.fromUser;
        return {
          'partner': partner,
          'lastMessage': last,
        };
      }).toList()
        ..sort((a, b) {
          final am = a['lastMessage'] as MessageModel;
          final bm = b['lastMessage'] as MessageModel;
          return bm.timestamp.compareTo(am.timestamp);
        });
      return list;
    });
  }

  /// --------- Notifications (RTDB) ----------
  Stream<List<NotificationModel>> streamNotifications(String userKey) {
    final meN = normalizeEmail(userKey);
    final ref = _db.child('Notifications');
    return ref.onValue.map((event) {
      final all = _listFromMap<NotificationModel>(event.snapshot.value, (id, data) {
        return NotificationModel.fromRTDB(id, data);
      });
      final mine = all.where((n) {
        final to = (n.toUser).toString();
        return to == userKey || normalizeEmail(to) == meN;
      }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return mine;
    });
  }

  Future<void> sendNotification(NotificationModel n) async {
    await _db.child('Notifications').push().set(n.toMap());
  }

  Future<void> markAllNotificationsRead(String userKey) async {
    final meN = normalizeEmail(userKey);
    final ref = _db.child('Notifications');
    final snap = await ref.get();
    final map = (snap.value as Map?)?.cast<dynamic, dynamic>() ?? {};
    final futures = <Future>[];
    map.forEach((id, raw) {
      final notif = (raw as Map).cast<dynamic, dynamic>();
      final to = notif['toUser']?.toString() ?? '';
      final isMine = to == userKey || normalizeEmail(to) == meN;
      if (isMine && (notif['read'] != true)) {
        futures.add(ref.child(id.toString()).set({...notif, 'read': true}));
      }
    });
    await Future.wait(futures);
  }

  /// --------- Friends & Requests (RTDB) ----------
  Stream<List<FriendRequest>> streamFriendRequests(String userEmail) {
    final meN = normalizeEmail(userEmail);
    return _db.child('FriendRequests').onValue.map((event) {
      final all = _listFromMap<FriendRequest>(event.snapshot.value, (id, data) {
        return FriendRequest.fromRTDB(id, data);
      });
      final mine = all.where((r) {
        final to = r.toUser;
        final from = r.fromUser;
        return to == userEmail || normalizeEmail(to) == meN || from == userEmail || normalizeEmail(from) == meN;
      }).toList();
      return mine;
    });
  }

  Future<String> sendFriendRequest(String fromUser, String toUser) async {
    final requestId = 'friendreq_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
    await _db.child('FriendRequests/$requestId').set({
      'fromUser': fromUser,
      'toUser': toUser,
      'status': 'pending',
      'timestamp': DateTime.now().toIso8601String(),
    });
    return requestId;
  }

  Future<void> respondToFriendRequest(String requestId, String status) async {
    final requestRef = _db.child('FriendRequests/$requestId');
    final snap = await requestRef.get();
    final req = (snap.value as Map?)?.cast<dynamic, dynamic>();
    if (req == null) {
      await requestRef.child('status').set(status);
      return;
    }
    await requestRef.child('status').set(status);
    if (status == 'accepted') {
      final friendId = 'friend_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
      await _db.child('Friends/$friendId').set({
        'user1': req['fromUser'],
        'user2': req['toUser'],
      });
    }
  }

  Stream<List<FriendRel>> streamFriends(String userEmail) {
    final meN = normalizeEmail(userEmail);
    return _db.child('Friends').onValue.map((event) {
      final all = _listFromMap<FriendRel>(event.snapshot.value, (id, data) {
        return FriendRel.fromRTDB(id, data);
      });
      final mine = all.where((f) {
        final u1 = f.user1, u2 = f.user2;
        return u1 == userEmail || normalizeEmail(u1) == meN || u2 == userEmail || normalizeEmail(u2) == meN;
      }).toList();
      return mine;
    });
  }

  /// --------- Firestore Accounts helpers ----------
  String getUserDisplayName(String emailOrKey, Map<String, dynamic> accounts) {
    if (emailOrKey.isEmpty) return 'Anonymous';
    final key = normalizeEmail(emailOrKey);
    final acct = accounts[key] as Map<String, dynamic>?;
    if (acct != null) {
      final f = (acct['firstname'] ?? '').toString();
      final l = (acct['lastname'] ?? '').toString();
      if (f.isNotEmpty && l.isNotEmpty) {
        return '${f[0].toUpperCase()}${f.substring(1)} ${l[0].toUpperCase()}${l.substring(1)}';
      }
    }
    // fall back to local-part of email
    final rawEmail = emailOrKey.replaceAll('_', '.');
    return rawEmail.contains('@') ? rawEmail.split('@').first : rawEmail;
  }

  /// Elderly-only search (friends panel)
  List<Map<String, String>> searchElderlyUsers({
    required String query,
    required String currentUserEmail,
    required Map<String, dynamic> accounts,
  }) {
    final normalizedQuery = query.toLowerCase().trim();
    final meKey = normalizeEmail(currentUserEmail);

    final results = <Map<String, String>>[];
    accounts.forEach((emailKey, raw) {
      final acc = (raw as Map?)?.cast<dynamic, dynamic>() ?? {};
      if (emailKey == meKey) return;
      if ((acc['userType']?.toString() ?? '') != 'elderly') return;

      if (normalizedQuery.isEmpty) {
        results.add({
          'email': (acc['email'] ?? '').toString(),
          'key': emailKey,
          'name': '${acc['firstname'] ?? ''} ${acc['lastname'] ?? ''}'.trim().isEmpty
              ? (acc['email'] ?? '').toString()
              : '${acc['firstname'] ?? ''} ${acc['lastname'] ?? ''}'.trim(),
          'userType': 'elderly',
        });
      } else {
        final first = (acc['firstname'] ?? '').toString().toLowerCase();
        final last = (acc['lastname'] ?? '').toString().toLowerCase();
        final full = '$first $last'.trim();
        final email = (acc['email'] ?? '').toString().toLowerCase();
        if (first.contains(normalizedQuery) || last.contains(normalizedQuery) || full.contains(normalizedQuery) || email.contains(normalizedQuery)) {
          results.add({
            'email': (acc['email'] ?? '').toString(),
            'key': emailKey,
            'name': '${acc['firstname'] ?? ''} ${acc['lastname'] ?? ''}'.trim().isEmpty
                ? (acc['email'] ?? '').toString()
                : '${acc['firstname'] ?? ''} ${acc['lastname'] ?? ''}'.trim(),
            'userType': 'elderly',
          });
        }
      }
    });
    return results;
  }

  /// Caregivers assigned to an elderly based on Firestore Account fields
  List<Map<String, dynamic>> caregiversForElderly(String elderlyEmail, Map<String, dynamic> accounts) {
    final elderlyEmailNormalized = normalizeEmail(elderlyEmail);
    final elderlyAccount = accounts[elderlyEmailNormalized] as Map<String, dynamic>?;
    final elderlyUid = elderlyAccount != null ? elderlyAccount['uid']?.toString() : null;

    bool _checkAssignment(dynamic assignedValue) {
      if (assignedValue == null) return false;
      final assignedStr = assignedValue.toString().toLowerCase().trim();
      final elderlyLower = elderlyEmail.toLowerCase();
      if (assignedStr == elderlyLower) return true;
      if (assignedStr == elderlyEmailNormalized) return true;
      if (elderlyUid != null && assignedStr == elderlyUid) return true;
      if (assignedStr.contains(elderlyLower.replaceAll('.', '_'))) return true;
      if (elderlyUid != null && assignedStr == elderlyUid.toLowerCase()) return true;
      if (assignedStr.length == 28 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(assignedStr)) {
        if (elderlyUid != null && assignedStr == elderlyUid) return true;
      }
      return false;
    }

    final list = <Map<String, dynamic>>[];
    accounts.forEach((key, raw) {
      final acc = (raw as Map?)?.cast<dynamic, dynamic>() ?? {};
      if ((acc['userType'] ?? '') != 'caregiver') return;

      bool isAssigned = false;

      if (!isAssigned && acc['elderlyId'] != null) isAssigned = _checkAssignment(acc['elderlyId']);
      if (!isAssigned && acc['elderlyIds'] is List) {
        for (final v in (acc['elderlyIds'] as List)) {
          if (_checkAssignment(v)) { isAssigned = true; break; }
        }
      }
      if (!isAssigned && acc['linkedElders'] is List) {
        for (final v in (acc['linkedElders'] as List)) {
          if (_checkAssignment(v)) { isAssigned = true; break; }
        }
      } else if (!isAssigned && acc['linkedElders'] is String) {
        isAssigned = _checkAssignment(acc['linkedElders']);
      }
      if (!isAssigned && acc['linkedElderUids'] is List) {
        for (final v in (acc['linkedElderUids'] as List)) {
          if (_checkAssignment(v)) { isAssigned = true; break; }
        }
      }
      if (!isAssigned && acc['uidOfElder'] != null) {
        isAssigned = _checkAssignment(acc['uidOfElder']);
      }

      if (isAssigned) {
        final fullName = acc['lastname'] != null ? '${acc['firstname']} ${acc['lastname']}' : '${acc['firstname']}';
        list.add({
          'name': fullName,
          'email': acc['email'],
          'phoneNum': acc['phoneNum'] ?? 'No phone number',
          'firstname': acc['firstname'],
          'lastname': acc['lastname'],
          'uid': acc['uid'],
          'key': key,
          'assignmentReason': 'Assigned caregiver',
          'confirmed': true,
        });
      }
    });
    return list;
  }
}
