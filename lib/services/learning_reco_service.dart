import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String emailKeyFrom(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local  = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain';
}

class LearningReco {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? url;

  LearningReco({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.url,
  });

  factory LearningReco.fromMap(String id, Map<String, dynamic> m) {
    return LearningReco(
      id: id,
      title: (m['title'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      category: (m['category'] ?? 'Other').toString(),
      url: (m['url'] as String?)?.trim().isEmpty == true ? null : m['url'],
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'category': category,
    if (url != null) 'url': url,
  };
}

class LearningRecommendationsService {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<String?> _key() async {
    final u = _auth.currentUser;
    final email = u?.email;
    if (email == null || email.isEmpty) return null;
    return emailKeyFrom(email);
  }

  Stream<List<LearningReco>> subscribeAll() async* {
    final key = await _key();
    if (key == null) {
      yield const <LearningReco>[];
      return;
    }
    yield* _fs.collection('learningRecommendations').doc(key).snapshots().map((doc) {
      if (!doc.exists) return <LearningReco>[];
      final data = Map<String, dynamic>.from(doc.data() ?? {});
      final items = <LearningReco>[];
      for (final e in data.entries) {
        // skip metadata fields
        if (e.key == 'ownerEmailKey' || e.key == 'ownerUid' || e.key == 'createdAt') continue;
        final v = e.value;
        if (v is Map) {
          items.add(LearningReco.fromMap(e.key, Map<String, dynamic>.from(v)));
        }
      }
      return items;
    });
  }

  
  Stream<List<LearningReco>> subscribeTop(int n) =>
      subscribeAll().map((list) => list.take(n).toList());
  Future<void> upsert(LearningReco r) async {
    final key = await _key();
    if (key == null) throw Exception('Missing emailKey (no signed-in email)');
    final doc = _fs.collection('learningRecommendations').doc(key);
    await doc.set({ r.id: r.toMap() }, SetOptions(merge: true));
  }

  Future<void> delete(String recoId) async {
    final key = await _key();
    if (key == null) throw Exception('Missing emailKey (no signed-in email)');
    await _fs.collection('learningRecommendations').doc(key)
      .update({ recoId: FieldValue.delete() });
  }
}
