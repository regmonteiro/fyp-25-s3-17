import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String userName;
  final String userEmail;
  final String comment;
  final int rating; // 1..5
  final String dateIso; // ISO 8601 string

  FeedbackModel({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.comment,
    required this.rating,
    required this.dateIso,
  });

  DateTime? get date => DateTime.tryParse(dateIso);

  factory FeedbackModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FeedbackModel(
      id: doc.id,
      userName: (d['userName'] ?? '').toString(),
      userEmail: (d['userEmail'] ?? '').toString(),
      comment: (d['comment'] ?? '').toString(),
      rating: int.tryParse((d['rating'] ?? 0).toString()) ?? 0,
      dateIso: (d['date'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userName': userName,
        'userEmail': userEmail,
        'comment': comment,
        'rating': rating,
        'date': dateIso, // keep ISO string (lexicographically sortable)
      };
}
