// lib/models/chat_message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderUid;
  final String receiverUid;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.receiverUid,
    required this.sentAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['sentAt'];
    return ChatMessage(
      id: doc.id,
      text: (d['text'] as String?) ?? '',
      senderUid: (d['senderUid'] as String?) ?? '',
      receiverUid: (d['receiverUid'] as String?) ?? '',
      sentAt: ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'sentAt': FieldValue.serverTimestamp(),
    };
  }
}
