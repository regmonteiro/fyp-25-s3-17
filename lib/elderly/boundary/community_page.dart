import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'post.dart';
import '../../models/user_profile.dart';
import '../controller/community_controller.dart';
import 'create_post_page.dart';
import 'find_friends_page.dart';
import 'posts_details_page.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CommunityController>();
    final currentUserProfile = context.watch<UserProfile?>();
    final currentUserId = controller.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.userPlus, color: Colors.white),
            tooltip: 'Find Friends',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindFriendsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'Create Post',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostPage()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: controller.postsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load feed. Please check your connection.',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Error: ${snap.error}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final posts = snap.data ?? const <Post>[];
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No posts yet from you or your linked connections. Start by creating a post or finding friends!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }

        return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: posts.length,
              itemBuilder: (_, i) {
                final post = posts[i];
                return PostCard(
                  post: post,
                  controller: controller,
                  currentUserId: currentUserId,
                  currentUserProfile: currentUserProfile,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PostDetailsPage(post: post)),
                    );
                  },
                );
              },
            );
        },
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  final CommunityController controller;
  final String? currentUserId;
  final UserProfile? currentUserProfile;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.controller,
    required this.currentUserId,
    required this.currentUserProfile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = post.likedBy.contains(currentUserId);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(                      // <— wrap with InkWell for tap + ripple
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header(),
          const Divider(height: 16),
          Text(post.content, style: const TextStyle(fontSize: 16, height: 1.4)),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
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
                    child: Center(child: CircularProgressIndicator(color: Colors.blueAccent, value: (prog.expectedTotalBytes != null)
                        ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes!
                        : null)),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Text('Image failed to load', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _counts(context),
          const Divider(height: 16, thickness: 0.5),
          _actions(context, isLiked),
          _recentComments(context),
        ]),
      ),
      )
    );
  }

  Widget _header() {
    return Row(children: [
      const CircleAvatar(
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(post.authorDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(_formatTimestamp(post.timestamp), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ]),
    ]);
  }

  Widget _counts(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Icon(FontAwesomeIcons.solidHeart, color: Colors.red, size: 14),
          const SizedBox(width: 4),
          Text('${post.likedBy.length}',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        ]),
        StreamBuilder<List<Comment>>(
          stream: controller.getCommentsStream(post.id),
          builder: (_, s) {
            final count = (s.data ?? const []).length;
            return Row(children: [
              const Icon(FontAwesomeIcons.comment, color: Colors.blueAccent, size: 14),
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _actions(BuildContext context, bool isLiked) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      Expanded(
        child: TextButton.icon(
          onPressed: () => controller.toggleLike(post),
          icon: FaIcon(
            isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
            color: isLiked ? Colors.red : Colors.grey.shade600,
            size: 18,
          ),
          label: Text('Like',
              style: TextStyle(
                color: isLiked ? Colors.red : Colors.grey.shade700,
                fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
      Expanded(
        child: TextButton.icon(
          onPressed: () => _showCommentSheet(context),
          icon: FaIcon(FontAwesomeIcons.comment, color: Colors.grey.shade600, size: 18),
          label: Text('Comment', style: TextStyle(color: Colors.grey.shade700)),
        ),
      ),
    ]);
  }

  Widget _recentComments(BuildContext context) {
    return StreamBuilder<List<Comment>>(
      stream: controller.getCommentsStream(post.id),
      builder: (_, s) {
        final comments = s.data ?? const <Comment>[];
        if (comments.isEmpty) return const SizedBox.shrink();

        final recent = comments.length <= 2 ? comments : comments.sublist(comments.length - 2);
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (comments.length > 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: GestureDetector(
                  onTap: () => _showCommentSheet(context),
                  child: const Text('View all comments...',
                      style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ...recent.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(text: '${c.displayName}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        TextSpan(text: c.text, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                )),
          ]),
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

    final entryCtrl = TextEditingController();

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<Comment>>(
                stream: controller.getCommentsStream(post.id),
                builder: (_, s) {
                  final items = (s.data ?? const <Comment>[]).toList()
                    ..sort((a, b) => a.timestamp.compareTo(b.timestamp)); // oldest → newest
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final c = items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(_formatTimestamp(c.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ]),
                              const SizedBox(height: 2),
                              Text(c.text, style: const TextStyle(fontSize: 13)),
                            ]),
                          ),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: entryCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (v) async {
                    if (v.isNotEmpty) await _sendComment(parentContext, v, entryCtrl);
                  },
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final v = entryCtrl.text.trim();
                  if (v.isNotEmpty) await _sendComment(parentContext, v, entryCtrl);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              )
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _sendComment(BuildContext context, String text, TextEditingController toClear) async {
    toClear.clear();
    FocusScope.of(context).unfocus();
    try {
      await controller.addComment(post: post, commentText: text, currentUserProfile: currentUserProfile!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    }
  }

  String _formatTimestamp(Timestamp ts) {
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
