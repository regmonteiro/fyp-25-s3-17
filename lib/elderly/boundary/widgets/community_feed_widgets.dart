// lib/elderly/boundary/widgets/community_feed_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // for Timestamp
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../controller/community_controller.dart';
import '../post.dart';
import '../../../models/user_profile.dart';

/// A compact, embed-friendly feed preview (e.g., for Home page).
class CommunityFeedSection extends StatelessWidget {
  const CommunityFeedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CommunityController>();
    final currentUserProfile = context.watch<UserProfile?>();
    final currentUserId = controller.currentUserId;

    // Preview the latest 3 posts
    final previewStream = controller.postsStream.map((posts) => posts.take(3).toList());

    return StreamBuilder<List<Post>>(
      stream: previewStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts: ${snapshot.error}'));
        }

        final posts = snapshot.data ?? const <Post>[];
        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'No shared memories yet. Be the first to post!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: posts.length,
          itemBuilder: (_, i) => _PostCardPreview(
            post: posts[i],
            controller: controller,
            currentUserId: currentUserId,
            currentUserProfile: currentUserProfile,
          ),
        );
      },
    );
  }
}

/// A lighter post card used in the preview section.
/// NOTE: No use of post.comments – we stream comments from subcollection.
class _PostCardPreview extends StatelessWidget {
  final Post post;
  final CommunityController controller;
  final String? currentUserId;
  final UserProfile? currentUserProfile;

  const _PostCardPreview({
    required this.post,
    required this.controller,
    required this.currentUserId,
    required this.currentUserProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = post.likedBy.contains(currentUserId);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header(),
          const Divider(height: 16),
          if (post.content.isNotEmpty)
            Text(post.content, style: const TextStyle(fontSize: 16, height: 1.4)),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, prog) {
                  if (prog == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey.shade100,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: (prog.expectedTotalBytes != null)
                            ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: const Center(
                    child: Text('Image failed to load', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _counts(context),
          const Divider(height: 16),
          _actions(context, isLiked),
          _recentComments(context),
        ]),
      ),
    );
  }

  Widget _header() {
    return Row(children: [
      const CircleAvatar(
        backgroundColor: Colors.blueAccent,
        radius: 22,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          post.authorDisplayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
        ),
        Text(_fmt(post.timestamp), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ]),
    ]);
  }

  Widget _counts(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${post.likedBy.length} Likes',
            style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500)),
        // 🔄 Live comment count from subcollection
        StreamBuilder(
          stream: controller.getCommentsStream(post.id),
          builder: (_, AsyncSnapshot<List<Comment>> snap) {
            final count = (snap.data ?? const <Comment>[]).length;
            return Text('$count Comments',
                style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500));
          },
        ),
      ]),
    );
  }

  Widget _actions(BuildContext context, bool isLiked) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      TextButton.icon(
        onPressed: () => controller.toggleLike(post),
        icon: FaIcon(
          isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
          color: isLiked ? Colors.red : Colors.grey.shade700,
          size: 18,
        ),
        label: const Text('Like',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ),
      TextButton.icon(
        onPressed: () => _showCommentSheet(context),
        icon: FaIcon(FontAwesomeIcons.comment, color: Colors.grey.shade700, size: 18),
        label: const Text('Comment',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  /// Show only the last 2 comments (streamed)
  Widget _recentComments(BuildContext context) {
    return StreamBuilder<List<Comment>>(
      stream: controller.getCommentsStream(post.id),
      builder: (_, snap) {
        final all = snap.data ?? const <Comment>[];
        if (all.isEmpty) return const SizedBox.shrink();

        final recent = all.length <= 2 ? all : all.sublist(all.length - 2);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (all.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: GestureDetector(
                  onTap: () => _showCommentSheet(context),
                  child: const Text(
                    'View all comments...',
                    style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ...recent.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                            text: '${c.displayName}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        TextSpan(text: c.text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  void _showCommentSheet(BuildContext parentContext) {
    if (currentUserProfile == null) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(content: Text('Cannot comment: User profile not loaded.')),
      );
      return;
    }

    final input = TextEditingController();

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              const Text('All Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<Comment>>(
                  stream: controller.getCommentsStream(post.id),
                  builder: (_, snap) {
                    final items = (snap.data ?? const <Comment>[]).toList()
                      ..sort((a, b) => a.timestamp.compareTo(b.timestamp)); // oldest → newest
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final c = items[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.person, size: 18, color: Colors.white),
                          ),
                          title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(c.text),
                          trailing: Text(_fmt(c.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onSubmitted: (_) => _submitComment(parentContext, input),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent, size: 28),
                  onPressed: () => _submitComment(parentContext, input),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _submitComment(BuildContext ctx, TextEditingController c) async {
    final text = c.text.trim();
    if (text.isEmpty) return;
    c.clear();
    FocusScope.of(ctx).unfocus();
    try {
      await controller.addComment(
        post: post,
        commentText: text,
        currentUserProfile: currentUserProfile!,
      );
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(const SnackBar(content: Text('Failed to post comment.')));
      }
    }
  }

  String _fmt(Timestamp ts) {
    final now = DateTime.now();
    final d = ts.toDate();
    final diff = now.difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
