import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class TopLearningRecommendationsFS extends StatefulWidget {
  const TopLearningRecommendationsFS({Key? key}) : super(key: key);

  @override
  State<TopLearningRecommendationsFS> createState() => _TopLearningRecommendationsFSState();
}

class _TopLearningRecommendationsFSState extends State<TopLearningRecommendationsFS> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  List<_RecItem> _recs = const [];

  String get _emailKey {
    final e = _auth.currentUser?.email ?? '';
    return e.replaceAll(RegExp(r'[.@]'), '_');
  }

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final path = _fs.collection('learningRecommendations').doc(_emailKey).collection('items');
      final qs = await path.orderBy('score', descending: true).limit(3).get();

      if (qs.docs.isNotEmpty) {
        setState(() {
          _recs = qs.docs.map((d) {
            final m = d.data();
            return _RecItem(
              id: d.id,
              title: (m['title'] ?? '').toString(),
              description: (m['description'] ?? '').toString(),
              category: (m['category'] ?? 'Other').toString(),
              url: (m['url'] ?? '').toString(),
              score: (m['score'] ?? 0).toDouble(),
            );
          }).toList();
          _loading = false;
        });
        return;
      }

      // if empty, fallback to LearningResources collection to build default
      final all = await _fs.collection('LearningResources').get();
      final docs = all.docs.take(3).map((d) {
        final m = d.data();
        return _RecItem(
          id: d.id,
          title: (m['title'] ?? '').toString(),
          description: (m['description'] ?? '').toString(),
          category: (m['category'] ?? 'Other').toString(),
          url: (m['url'] ?? '').toString(),
          score: 0,
        );
      }).toList();

      // Save generated fallback for next time
      final batch = _fs.batch();
      for (final r in docs) {
        final ref = path.doc(r.id);
        batch.set(ref, {
          'title': r.title,
          'description': r.description,
          'category': r.category,
          'url': r.url,
          'score': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      setState(() {
        _recs = docs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load learning recommendations: $e';
        _loading = false;
      });
    }
  }

  Future<void> _open(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    final fixed = (uri == null || !uri.hasScheme) ? Uri.parse('https://$url') : uri;
    final ok = await launchUrl(fixed, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: LinearProgressIndicator());
    if (_error != null) {
      return Card(
        color: const Color(0xFFFFEDEE),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_recs.isEmpty) return const Center(child: Text('No recommendations yet.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _recs.map((r) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.school, color: Colors.green),
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${r.category} • ${r.description}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: ElevatedButton(
              onPressed: () => _open(r.url),
              child: const Text('Start'),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String url;
  final double score;

  const _RecItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.url,
    required this.score,
  });
}
