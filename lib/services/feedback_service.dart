import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('feedback');

  /// Live stream ordered by `date` desc (ISO strings sort correctly).
  Stream<List<FeedbackModel>> streamAll() {
    return _col.orderBy('date', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => FeedbackModel.fromDoc(d)).toList(),
        );
  }

  /// One-time fetch, ordered latest first.
  Future<List<FeedbackModel>> fetchAll() async {
    final snap = await _col.orderBy('date', descending: true).get();
    return snap.docs.map((d) => FeedbackModel.fromDoc(d)).toList();
  }

  /// Create a new feedback doc at /feedback/{id}
  Future<void> addFeedback({
    required String userName,
    required String userEmail,
    required int rating,
    required String comment,
    DateTime? when, // default now
  }) async {
    final iso = (when ?? DateTime.now().toUtc()).toIso8601String();
    final model = FeedbackModel(
      id: '',
      userName: userName.trim(),
      userEmail: userEmail.trim(),
      comment: comment.trim(),
      rating: rating,
      dateIso: iso,
    );
    await _col.add(model.toMap());
  }

  /// (Optional) delete by id
  Future<void> delete(String id) => _col.doc(id).delete();
}
