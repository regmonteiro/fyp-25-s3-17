import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorDisplayName;
  final String content;
  final String? imageUrl;
  final Timestamp timestamp;
  final List<String> likedBy;

  Post({
    required this.id,
    required this.authorId,
    required this.authorDisplayName,
    required this.content,
    required this.imageUrl,
    required this.timestamp,
    required this.likedBy,
  });

  factory Post.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Post(
      id: doc.id,
      authorId: (d['authorId'] as String?) ?? (d['authorUid'] as String?) ?? '',
      authorDisplayName: (d['authorDisplayName'] as String?) ?? (d['authorName'] as String?) ?? 'Anonymous',
      content: (d['content'] as String?) ?? '',
      imageUrl: d['imageUrl'] as String?,
      timestamp: (d['timestamp'] as Timestamp?) ?? Timestamp.now(),
      likedBy: ((d['likedBy'] as List?) ?? const []).cast<String>(),
    );
  }
  Map<String, dynamic> toFirestore() => {
    'authorId': authorId,
    'authorDisplayName': authorDisplayName,
    'content': content,
    'imageUrl': imageUrl,
    'timestamp': timestamp,
    'likedBy': likedBy,
  };
}