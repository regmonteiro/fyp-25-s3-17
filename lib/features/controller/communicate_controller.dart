import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../elderly/boundary/models/chat_message.dart';

/// Firestore layout:
/// messages/{conversationId}
///   participants: [uidA, uidB]
///   updatedAt: Timestamp
/// messages/{conversationId}/items/{autoId}
///   senderUid: string
///   text: string
///   ts: Timestamp
///
/// Account/{uid}:
///   // elderly record
///   linkedCaregivers: [
///     // can be strings or maps like { uid: "...", displayName: "...", role: "primary" }
///   ]
///   // caregiver record
///   linkedElderlyIds / elderlyIds / elderlyId (any of these may exist)

class CommunicateController {
  final UserProfile currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CommunicateController({required this.currentUser});

  User? get firebaseUser => _auth.currentUser;

  /// Stable conversation id for a pair of uids (order-independent).
  String conversationIdFor(String a, String b) {
    return (a.compareTo(b) < 0) ? '${a}__${b}' : '${b}__${a}';
  }

  /// Resolve partner uid based on current user type and Account document.
  /// Returns the first reasonable link it finds.
  Future<String?> resolvePartnerUid(UserProfile me) async {
    final acc = await _db.collection('Account').doc(me.uid).get();
    final data = acc.data() ?? const {};

    if (me.userType == 'caregiver') {
      // caregiver -> elder
      // Try elderlyId, elderlyIds, linkedElderlyIds
      final single = (data['elderlyId'] as String?)?.trim();
      if (single != null && single.isNotEmpty) return single;

      final many = [
        ..._asStringList(data['elderlyIds']),
        ..._asStringList(data['linkedElderlyIds']),
      ];
      if (many.isNotEmpty) return many.first;
      return null;
    } else {
      // elderly -> caregiver
      // linkedCaregivers can be strings or maps
      final raw = data['linkedCaregivers'];
      final caregivers = _normalizeCaregivers(raw);
      if (caregivers.isNotEmpty) {
        // Prefer primary if available, else the first
        final primary = caregivers.firstWhere(
          (m) => (m['role'] as String).toLowerCase() == 'primary',
          orElse: () => caregivers.first,
        );
        return primary['uid'] as String;
      }
      return null;
    }
  }

  /// Send a message (creates the conversation container if needed).
  Future<void> send({
    required String myUid,
    required String partnerUid,
    required String text,
  }) async {
    final convoId = conversationIdFor(myUid, partnerUid);
    final convoRef = _db.collection('messages').doc(convoId);
    final itemsRef = convoRef.collection('items');

    final now = FieldValue.serverTimestamp();

    // Upsert conversation header
    await convoRef.set({
      'participants': [myUid, partnerUid],
      'updatedAt': now,
      'lastMessage': text,
      'lastSender': myUid,
    }, SetOptions(merge: true));

    // Add message item
    await itemsRef.add({
      'senderUid': myUid,
      'text': text,
      'ts': now,
    });
  }

  /// Stream messages newest-first for the pair.
  Stream<List<ChatMessage>> messagesStream({
    required String myUid,
    required String partnerUid,
    int limit = 200,
  }) {
    final convoId = conversationIdFor(myUid, partnerUid);
    final q = _db
        .collection('messages')
        .doc(convoId)
        .collection('items')
        .orderBy('ts', descending: true)
        .limit(limit);

    return q.snapshots().map((snap) {
      return snap.docs.map((d) {
        final m = d.data();
        // TODO adapt to your ChatMessage API if different
        return ChatMessage(
          id: d.id,
          senderUid: m['senderUid'] as String? ?? '',
          text: m['text'] as String? ?? '',
          ts: (m['ts'] as Timestamp?)?.toDate(),
        );
      }).toList();
    });
  }

  // ───────────────────────── helpers ─────────────────────────

  List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((e) => (e is String) ? e.trim() : (e?.toString() ?? ''))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Accepts null / List<String> / List<Map>
  List<Map<String, dynamic>> _normalizeCaregivers(Object? raw) {
    final list = (raw is List) ? raw : const [];
    final out = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is String) {
        final uid = e.trim();
        if (uid.isNotEmpty) {
          out.add({'uid': uid, 'displayName': null, 'role': 'caregiver'});
        }
      } else if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final uid = (m['uid'] as String?)?.trim() ?? '';
        if (uid.isNotEmpty) {
          out.add({
            'uid': uid,
            'displayName': (m['displayName'] as String?)?.trim(),
            'role': (m['role'] ?? m['userType'] ?? 'caregiver').toString(),
          });
        }
      }
    }
    return out;
  }
}
