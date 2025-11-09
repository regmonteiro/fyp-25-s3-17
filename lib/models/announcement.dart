import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String description;
  final List<String> userGroups;
  final DateTime createdAt;
  final Map<String, dynamic> readBy;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.userGroups,
    required this.createdAt,
    required this.readBy,
  });

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    final created = ts is Timestamp
        ? ts.toDate()
        : (ts is String ? DateTime.tryParse(ts) ?? DateTime.now() : DateTime.now());

    return Announcement(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      userGroups: (d['userGroups'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      createdAt: created,
      readBy: Map<String, dynamic>.from(d['readBy'] as Map? ?? {}),
    );
  }
}
