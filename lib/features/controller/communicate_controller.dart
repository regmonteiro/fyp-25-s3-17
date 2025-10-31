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
///   - elderly: linkedCaregivers [uid,...]
///   - caregiver: elderlyIds [uid,...]

class CommunicateController {
  final UserProfile currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CommunicateController({required this.currentUser});

  User? get firebaseUser => _auth.currentUser;

  /// Consistent conversation id (order-independent)
  String conversationIdFor(String a, String b) {
    return (a.compareTo(b) < 0) ? '${a}__${b}' : '${b}__${a}';
  }

  /// Ensure both accounts are linked
  Future<void> ensureLink(String elderUid, String caregiverUid) async {
    final elderRef = _db.collection('Account').doc(elderUid);
    final cgRef = _db.collection('Account').doc(caregiverUid);

    final elderSnap = await elderRef.get();
    final cgSnap = await cgRef.get();
    if (!elderSnap.exists || !cgSnap.exists) return;

    final elderData = elderSnap.data() ?? {};
    final cgData = cgSnap.data() ?? {};

    final elderLinks = _asStringList(elderData['linkedCaregivers']);
    final cgLinks = _asStringList(cgData['elderlyIds']);

    final batch = _db.batch();

    if (!elderLinks.contains(caregiverUid)) {
      batch.set(elderRef, {
        'linkedCaregivers': FieldValue.arrayUnion([caregiverUid])
      }, SetOptions(merge: true));
    }

    if (!cgLinks.contains(elderUid)) {
      batch.set(cgRef, {
        'elderlyIds': FieldValue.arrayUnion([elderUid])
      }, SetOptions(merge: true));
    }

    if (batch is WriteBatch) await batch.commit();
  }

  /// Resolve partner uid via Account link fields.
  Future<String?> resolvePartnerUid(UserProfile me) async {
    final acc = await _db.collection('Account').doc(me.uid).get();
    final data = acc.data() ?? {};

    if (me.userType == 'caregiver') {
      final single = (data['elderlyId'] as String?)?.trim();
      if (single?.isNotEmpty == true) return single;

      final many = [
        ..._asStringList(data['elderlyIds']),
        ..._asStringList(data['linkedElderlyIds']),
      ];
      return many.isNotEmpty ? many.first : null;
    } else {
      // elderly
      final raw = data['linkedCaregivers'];
      final caregivers = _normalizeCaregivers(raw);
      if (caregivers.isNotEmpty) {
        final primary = caregivers.firstWhere(
          (m) => (m['role'] as String?)?.toLowerCase() == 'primary',
          orElse: () => caregivers.first,
        );
        return primary['uid'] as String?;
      }
      return null;
    }
  }

  /// Send chat message
  Future<void> send({
    required String myUid,
    required String partnerUid,
    required String text,
  }) async {
    final convoId = conversationIdFor(myUid, partnerUid);
    final convoRef = _db.collection('messages').doc(convoId);
    final itemsRef = convoRef.collection('items');

    final now = FieldValue.serverTimestamp();

    await convoRef.set({
      'participants': [myUid, partnerUid],
      'updatedAt': now,
      'lastMessage': text,
      'lastSender': myUid,
    }, SetOptions(merge: true));

    await itemsRef.add({
      'senderUid': myUid,
      'text': text,
      'ts': now,
    });
  }

  /// Stream of messages
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
        return ChatMessage(
          id: d.id,
          senderUid: m['senderUid'] ?? '',
          text: m['text'] ?? '',
          ts: (m['ts'] as Timestamp?)?.toDate(),
        );
      }).toList();
    });
  }

  // ─────────────── Helpers ───────────────
  List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((e) => e is String ? e.trim() : e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _normalizeCaregivers(Object? raw) {
    final list = (raw is List) ? raw : const [];
    final out = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is String) {
        out.add({'uid': e.trim(), 'displayName': null, 'role': 'caregiver'});
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
