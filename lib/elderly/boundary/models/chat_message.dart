import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;         // Firestore doc id of the message item
  final String senderUid;  // who sent it
  final String text;       // message body
  final DateTime? ts;      // server timestamp (nullable while pending)

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.ts,
  });

  /// Build from Firestore doc
  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ChatMessage(
      id: doc.id,
      senderUid: (data['senderUid'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      ts: (data['ts'] as Timestamp?)?.toDate(),
    );
  }

  /// Build from raw map (if you ever need it)
  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    return ChatMessage(
      id: id,
      senderUid: (data['senderUid'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      ts: (data['ts'] is Timestamp) ? (data['ts'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderUid': senderUid,
        'text': text,
        'ts': ts,
      };
}

