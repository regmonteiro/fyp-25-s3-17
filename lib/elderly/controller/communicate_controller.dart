import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['timestamp'];
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CommunicateController {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final UserProfile currentUser;

  CommunicateController({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    required this.currentUser,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  User? get firebaseUser => _auth.currentUser;

  /// If caregiver → partner is uidOfElder; else find a caregiver linked to this elder.
  Future<String?> resolvePartnerUid(UserProfile user) async {
    if (user.role == 'caregiver') {
      final elder = user.uidOfElder;
      return (elder != null && elder.isNotEmpty) ? elder : null;
    }

    // user is elder → find first caregiver whose uidOfElder == user.uid
    final q = await _db
        .collection('users')
        .where('role', isEqualTo: 'caregiver')
        .where('uidOfElder', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  String _threadId(String a, String b) {
    final s = [a, b]..sort();
    return '${s.first}_${s.last}';
  }

  Stream<List<ChatMessage>> messagesStream({
    required String myUid,
    required String partnerUid,
    int limit = 100,
  }) {
    final threadId = _threadId(myUid, partnerUid);
    return _db
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        )
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> send({
    required String myUid,
    required String partnerUid,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final threadId = _threadId(myUid, partnerUid);
    final msg = {
      'senderId': myUid,
      'text': trimmed,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _db.collection('chats').doc(threadId).collection('messages').add(msg);

    await _db.collection('chats').doc(threadId).set({
      'participants': [myUid, partnerUid],
      'lastMessage': trimmed,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
