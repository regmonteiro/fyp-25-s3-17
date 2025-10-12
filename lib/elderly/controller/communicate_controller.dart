import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:elderly_aiassistant/elderly/boundary/models/chat_message.dart';
import 'package:elderly_aiassistant/models/user_profile.dart';

class CommunicateController {
  final UserProfile currentUser;
  CommunicateController({required this.currentUser});

  User? get firebaseUser => FirebaseAuth.instance.currentUser;

  String _convId(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  Stream<List<ChatMessage>> messagesStream({
    required String myUid,
    required String partnerUid,
  }) {
    final convId = _convId(myUid, partnerUid);
    return FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((qs) => qs.docs.map((d) => ChatMessage.fromDoc(d)).toList());
  }

  Future<void> send({
    required String myUid,
    required String partnerUid,
    required String text,
  }) async {
    final convId = _convId(myUid, partnerUid);
    final msgs = FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId)
        .collection('messages');

    await msgs.add({
      'text': text,
      'senderUid': myUid,
      'receiverUid': partnerUid,
      'sentAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId)
        .set({
      'uids': [myUid, partnerUid]..sort(),
      'lastText': text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> resolvePartnerUid(UserProfile me) async {
    final snap = await FirebaseFirestore.instance.collection('users').doc(me.uid).get();
    final data = snap.data() ?? {};
    final key = me.role == 'caregiver' ? 'linkedElders' : 'linkedCaregivers';
    final list = (data[key] as List?) ?? [];
    if (list.isEmpty) return null;
    final first = list.first;
    if (first is String) return first;
    if (first is Map && first['uid'] is String) return first['uid'] as String;
    return null;
  }
}
