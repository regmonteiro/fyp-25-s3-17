import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/community_controller.dart';
import '../boundary/post.dart';

class PostDetailsPage extends StatelessWidget {
  final Post post;
  const PostDetailsPage({super.key, required this.post});

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CommunityController>();
    final currentUserId = controller.currentUserId;
    final isLiked = post.likedBy.contains(currentUserId);

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.authorDisplayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_formatTimestamp(post.timestamp),
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          if (post.content.isNotEmpty)
            Text(post.content, style: const TextStyle(fontSize: 16, height: 1.4)),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(post.imageUrl!, fit: BoxFit.cover),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => controller.toggleLike(post),
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey),
                label: Text('${post.likedBy.length}'),
              ),
              const SizedBox(width: 16),
              // Comments count (live)
              StreamBuilder<List<Comment>>(
                stream: controller.getCommentsStream(post.id),
                builder: (context, snap) {
                  final count = (snap.data ?? const []).length;
                  return Row(
                    children: [
                      const Icon(Icons.mode_comment_outlined, size: 20),
                      const SizedBox(width: 6),
                      Text('$count'),
                    ],
                  );
                },
              ),
            ],
          ),

          const Divider(),

          // Comments (live)
          StreamBuilder<List<Comment>>(
            stream: controller.getCommentsStream(post.id),
            builder: (context, snap) {
              final comments = snap.data ?? const <Comment>[];
              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No comments yet.'),
                );
              }
              return Column(
                children: comments.map((c) {
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                    title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.text),
                    trailing: Text(
                      _formatTimestamp(c.timestamp),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 8),

          // Add comment
          _AddCommentBox(post: post),
        ],
      ),
    );
  }
}

class _AddCommentBox extends StatefulWidget {
  final Post post;
  const _AddCommentBox({required this.post});

  @override
  State<_AddCommentBox> createState() => _AddCommentBoxState();
}

class _AddCommentBoxState extends State<_AddCommentBox> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    final cc = context.read<CommunityController>();
    final profile = cc.currentUserProfile; // if you set it via Provider elsewhere
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot comment: user profile not loaded.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await cc.addComment(
        post: widget.post,
        commentText: _controller.text.trim(),
        currentUserProfile: profile,
      );
      _controller.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Add a comment…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
        ),
      ],
    );
  }
}
