import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'controller/share_experience_controller.dart';

String displayNameFromEmailKey(String emailKey) {
  if (emailKey.isEmpty) return 'Anonymous';
  final email = emailKey.replaceAll('_', '.');
  final local = email.split('@').first;
  if (local.isEmpty) return 'User';
  return local[0].toUpperCase() + local.substring(1);
}

class ShareExperiencePage extends StatefulWidget {
  const ShareExperiencePage({Key? key}) : super(key: key);

  @override
  State<ShareExperiencePage> createState() => _ShareExperiencePageState();
}

class _ShareExperiencePageState extends State<ShareExperiencePage> {
  late ShareExperienceController ctrl; // set in didChangeDependencies
  bool _wired = false;

  String view = 'newsfeed'; // 'newsfeed' | 'myposts'
  String search = '';
  StreamSubscription? _sub;
  List<Experience> _all = [];
  bool _mounted = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_wired) {
      ctrl = context.read<ShareExperienceController>();
      _wired = true;
      _listen();
    }
  }

  void _listen() {
    _sub?.cancel();
    final stream = (view == 'myposts')
        ? ctrl.myPosts$(nameOf: displayNameFromEmailKey)
        : ctrl.feed$(nameOf: displayNameFromEmailKey);

    _sub = stream.listen((items) {
      if (!_mounted) return;
      setState(() => _all = items);
    });
  }

  @override
  void dispose() {
    _mounted = false;
    _sub?.cancel();
    super.dispose();
  }

  List<Experience> get _filtered {
    var list = _all;
    if (search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q) ||
              e.userName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> _newPost() async {
    final res = await showModalBottomSheet<_PostPayload>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PostSheet(),
    );
    if (res == null) return;
    await ctrl.addExperience(title: res.title, description: res.description);
  }

  Future<void> _editPost(Experience exp) async {
    final res = await showModalBottomSheet<_PostPayload>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PostSheet(initial: exp),
    );
    if (res == null) return;
    await ctrl.updateExperience(
        id: exp.id, title: res.title, description: res.description);
  }

  Future<void> _deletePost(Experience exp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ctrl.deleteExperience(exp.id);
    }
  }

  String _ago(DateTime t) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(t.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final meKey = ctrl.currentUserKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Your Journey'),
        actions: [
          IconButton(
            tooltip: 'New Story',
            onPressed: _newPost,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search experiences…',
                      filled: true,
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => search = v),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'newsfeed',
                        label: Text('Newsfeed'),
                        icon: Icon(Icons.groups)),
                    ButtonSegment(
                        value: 'myposts',
                        label: Text('My Posts'),
                        icon: Icon(Icons.person)),
                  ],
                  selected: {view},
                  onSelectionChanged: (s) {
                    setState(() => view = s.first);
                    _listen();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? _EmptyState(view: view, query: search)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final e = _filtered[i];
                final isOwner = e.user == meKey;
                return Card(
                  elevation: 1,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // header
                        Row(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.userName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(_ago(e.sharedAt),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54)),
                                ],
                              ),
                            ),
                            if (isOwner) ...[
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _editPost(e),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _deletePost(e),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(e.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(e.description),
                        const SizedBox(height: 10),

                        // engagement row
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  ctrl.toggleLike(e.id, e.liked),
                              icon: Icon(
                                e.liked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: e.liked ? Colors.red : null,
                              ),
                            ),
                            Text('${e.likes}'),
                            const SizedBox(width: 16),
                            const Icon(Icons.mode_comment_outlined, size: 22),
                            const SizedBox(width: 6),
                            Text('${e.comments}'),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _openComments(e),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Comments'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openComments(Experience e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(exp: e),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String view;
  final String query;
  const _EmptyState({required this.view, required this.query});

  String get _title {
    if (view == 'myposts' && query.isEmpty) return 'No stories yet';
    return 'No stories found';
  }

  String get _message {
    if (view == 'myposts' && query.isEmpty) {
      return "You haven't shared any stories yet. Share your first story!";
    }
    if (query.isNotEmpty) {
      return 'No stories match your search.';
    }
    return 'Be the first to share!';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite_border, size: 56),
          const SizedBox(height: 8),
          Text(_title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(_message, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _PostPayload {
  final String title;
  final String description;
  _PostPayload(this.title, this.description);
}

class _PostSheet extends StatefulWidget {
  final Experience? initial;
  const _PostSheet({this.initial});

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _title.text = widget.initial!.title;
      _desc.text = widget.initial!.description;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom + 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, pad),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'Share your story' : 'Edit story',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _desc,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Your story'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      setState(() => _busy = true);
                      Navigator.pop(context,
                          _PostPayload(_title.text.trim(), _desc.text.trim()));
                    },
              child: Text(
                  _busy ? 'Saving…' : (widget.initial == null ? 'Share' : 'Update')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final Experience exp;
  const _CommentsSheet({required this.exp});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late ShareExperienceController ctrl; // set later
  final _txt = TextEditingController();
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_wired) {
      ctrl = context.read<ShareExperienceController>();
      _wired = true;
    }
  }

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = ctrl.comments$(widget.exp.id);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline),
                const SizedBox(width: 8),
                Text('Comments', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${widget.exp.comments} total'),
              ],
            ),
            const SizedBox(height: 8),
            // Use a fixed-height box instead of Expanded inside min-height Column
            SizedBox(
              height: 420,
              child: StreamBuilder<List<CommentModel>>(
                stream: stream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return const Center(child: Text('No comments yet.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (_, i) {
                      final c = items[i];
                      final when = DateFormat.yMMMd()
                          .add_jm()
                          .format(c.timestamp.toLocal());
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(c.userName.isEmpty
                            ? displayNameFromEmailKey(c.user)
                            : c.userName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.content),
                            const SizedBox(height: 4),
                            Text(when,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _txt,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final text = _txt.text.trim();
                    if (text.isEmpty) return;
                    await ctrl.addComment(
                      postId: widget.exp.id,
                      content: text,
                      displayName:
                          displayNameFromEmailKey(ctrl.currentUserKey),
                    );
                    _txt.clear();
                  },
                  child: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
