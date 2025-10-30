import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'share_experiences_service.dart';
import 'controller/share_experience_controller.dart';

class ShareExperiencePage extends StatefulWidget {
  const ShareExperiencePage({Key? key}) : super(key: key);

  @override
  State<ShareExperiencePage> createState() => _ShareExperiencePageState();
}

class _ShareExperiencePageState extends State<ShareExperiencePage> {
  final svc = ShareExperienceService.instance;

  

  // STATE
  Map<String, dynamic> accounts = {};
  List<Experience> experiences = [];
  List<Experience> filtered = [];
  String search = '';
  String view = 'newsfeed';

  bool showPostForm = false;
  Experience? editing;

  // Notifications
  List<NotificationModel> notifications = [];
  bool showNotifications = false;

  // Messaging
  List<Map<String, dynamic>> conversations = [];
  String? selectedPartnerKey;
  List<MessageModel> thread = [];
  bool showMessaging = false;

  // Friends
  bool showFriends = false;
  List<FriendRequest> friendRequests = [];
  List<FriendRel> friends = [];

  // Auth (replace with real auth)
  final String loggedInEmail = 'anonymous@example.com';

  String get currentUserKey => normalizeEmail(loggedInEmail);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Firestore: load accounts once
    accounts = await svc.getAccounts();
    setState(() {});
    // Streams
    _listenExperiences();
    _listenNotifications();
    _listenConversations();
    _listenFriendData();
  }

  void _listenExperiences() {
    // switch stream based on view
    svc
        .streamExperiences(
            onlyForUserKey: view == 'myposts' ? currentUserKey : null)
        .listen((list) {
      setState(() {
        experiences = list;
        _applyFilter();
      });
    });
  }

  void _listenNotifications() {
    svc.streamNotifications(currentUserKey).listen((list) {
      setState(() {
        notifications = list;
      });
    });
  }

  void _listenConversations() {
    svc.streamUserConversations(currentUserKey).listen((list) {
      setState(() {
        conversations = list;
      });
    });
  }

  void _listenFriendData() {
    svc.streamFriendRequests(currentUserKey).listen((reqs) {
      setState(() => friendRequests = reqs);
    });
    svc.streamFriends(currentUserKey).listen((rels) {
      setState(() => friends = rels);
    });
  }

  void _applyFilter() {
    var f = experiences;
    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase().trim();
      f = f.where((e) {
        final name = svc.getUserDisplayName(e.user, accounts).toLowerCase();
        return e.title.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q) ||
            name.contains(q);
      }).toList();
    }
    setState(() => filtered = f);
  }

  String _formatAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMd().format(dt);
    }

  // ============ UI Actions ============
  Future<void> _createOrUpdatePost(String title, String body) async {
    if (editing == null) {
      await svc.addExperience(userKey: currentUserKey, title: title, description: body);
    } else {
      await svc.updateExperience(Experience(
        id: editing!.id,
        user: editing!.user,
        title: title,
        description: body,
        sharedAt: editing!.sharedAt,
        likes: editing!.likes,
        comments: editing!.comments,
      ));
    }
    setState(() {
      showPostForm = false;
      editing = null;
    });
  }

  Future<void> _toggleLike(Experience e) async {
    final result = await svc.toggleLike(
      experienceId: e.id,
      isCurrentlyLiked: false, // UI doesn't persist per-user like flag; same as web controller
    );
    // Optional: send notification to owner if not me and like added
    if (e.user != currentUserKey && result['liked'] == true) {
      await svc.sendNotification(NotificationModel(
        id: '',
        toUser: e.user,
        fromUser: currentUserKey,
        type: 'like',
        title: 'New Like',
        message: '${svc.getUserDisplayName(currentUserKey, accounts)} liked your story',
        relatedId: e.id,
        timestamp: DateTime.now(),
        read: false,
      ));
    }
  }

  Future<void> _addComment(Experience e, String text) async {
    await svc.addComment(
      experienceId: e.id,
      userKey: currentUserKey,
      content: text,
      userName: svc.getUserDisplayName(currentUserKey, accounts),
    );
    if (e.user != currentUserKey) {
      await svc.sendNotification(NotificationModel(
        id: '',
        toUser: e.user,
        fromUser: currentUserKey,
        type: 'comment',
        title: 'New Comment',
        message: '${svc.getUserDisplayName(currentUserKey, accounts)} commented on your story',
        relatedId: e.id,
        timestamp: DateTime.now(),
        read: false,
      ));
    }
  }

  Future<void> _deletePost(Experience e) async {
    await svc.deleteExperience(e.id);
  }

  // Messaging
  void _openThread(String partnerKey) {
    setState(() {
      selectedPartnerKey = normalizeEmail(partnerKey);
      showMessaging = true;
    });
  }

  Stream<List<MessageModel>>? get _threadStream {
    final partner = selectedPartnerKey;
    if (partner == null) return null;
    return svc.streamConversation(currentUserKey, partner);
  }

  Future<void> _sendMessage(String text) async {
    final partner = selectedPartnerKey;
    if (partner == null || text.trim().isEmpty) return;
    final payload = {
      'content': text.trim(),
      'attachments': <Map<String, dynamic>>[],
    };
    await svc.sendMessage(
      fromUser: currentUserKey,
      toUser: partner,
      contentJson: payload,
    );
    await svc.sendNotification(NotificationModel(
      id: '',
      toUser: partner,
      fromUser: currentUserKey,
      type: 'message',
      title: 'New Message',
      message: '${svc.getUserDisplayName(currentUserKey, accounts)} sent you a message',
      relatedId: null,
      timestamp: DateTime.now(),
      read: false,
    ));
  }

  // Friends
  Future<void> _sendFriendRequest(String toKey) async {
    await svc.sendFriendRequest(currentUserKey, toKey);
  }

  Future<void> _respondFriendRequest(FriendRequest r, String status) async {
    await svc.respondToFriendRequest(r.id, status);
  }

  // ============ Widgets ============
  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !n.read).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Your Journey'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (unread > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => setState(() => showNotifications = true),
          ),
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => setState(() => showMessaging = true),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search experiences...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      search = v;
                      _applyFilter();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'newsfeed', label: Text('Newsfeed')),
                    ButtonSegment(value: 'myposts', label: Text('My Posts')),
                  ],
                  selected: {view},
                  onSelectionChanged: (s) {
                    setState(() => view = s.first);
                    _listenExperiences();
                  },
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Share Story'),
                  onPressed: () => setState(() {
                    editing = null;
                    showPostForm = true;
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      // Drawers
      endDrawer: showMessaging ? _buildMessagingDrawer(context) : null,
      bottomSheet: showNotifications ? _buildNotificationsSheet() : null,
    );
  }

  Widget _buildBody() {
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          view == 'myposts'
              ? (search.isEmpty
                  ? "You haven't shared any stories yet.\nTap 'Share Story' to post your first."
                  : 'No posts found matching your search.')
              : (search.isEmpty
                  ? 'No community stories yet.\nBe the first to share!'
                  : 'No stories found for your search.'),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final e = filtered[i];
        final userName = svc.getUserDisplayName(e.user, accounts);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(_formatAgo(e.sharedAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (e.user == currentUserKey)
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            setState(() {
                              editing = e;
                              showPostForm = true;
                            });
                          } else if (v == 'delete') {
                            await _deletePost(e);
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(e.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(e.description),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () => _toggleLike(e),
                    ),
                    Text('${e.likes}'),
                    const SizedBox(width: 16),
                    const Icon(Icons.mode_comment_outlined, size: 20),
                    const SizedBox(width: 4),
                    Text('${e.comments}'),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message'),
                      onPressed: () => _openThread(e.user),
                    ),
                  ],
                ),
                const Divider(),
                _CommentsSection(
                  experience: e,
                  onAdd: (text) => _addComment(e, text),
                  svc: svc,
                  accounts: accounts,
                  getUserName: (k) => svc.getUserDisplayName(k, accounts),
                  formatAgo: _formatAgo,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------- Notifications bottom sheet ---------
  Widget _buildNotificationsSheet() {
    return Material(
      elevation: 16,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 420,
          child: Column(
            children: [
              ListTile(
                title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: 'Mark all as read',
                  onPressed: () async {
                    await svc.markAllNotificationsRead(currentUserKey);
                  },
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => showNotifications = false),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(child: Text('No notifications yet'))
                    : ListView.separated(
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final n = notifications[i];
                          return ListTile(
                            leading: Icon(
                              n.type == 'message'
                                  ? Icons.chat_bubble
                                  : n.type == 'like'
                                      ? Icons.favorite
                                      : n.type == 'comment'
                                          ? Icons.mode_comment
                                          : Icons.notifications,
                            ),
                            title: Text(n.title),
                            subtitle: Text(n.message),
                            trailing: Text(_formatAgo(n.timestamp), style: const TextStyle(fontSize: 12)),
                            onTap: () {
                              if (n.type == 'message') {
                                _openThread(n.fromUser);
                              }
                              // could scroll to post if relatedId exists
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------- Messaging end drawer ---------
  Widget _buildMessagingDrawer(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final drawerWidth = w.clamp(320, 500).toDouble();

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => showMessaging = false),
              ),
              title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(
                tooltip: 'Friends',
                icon: const Icon(Icons.group_outlined),
                onPressed: () => setState(() => showFriends = !showFriends),
              ),
            ),
            if (showFriends) Expanded(child: _FriendsPanel(
              svc: svc,
              currentUserKey: currentUserKey,
              accounts: accounts,
              onStartChat: (k) {
                setState(() {
                  selectedPartnerKey = k;
                  showFriends = false;
                });
              },
              friendRequests: friendRequests,
              friends: friends,
            )) else
              Expanded(
              child: Row(
                children: [
                  // Conversations
                  SizedBox(
                    width: 180,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Conversations', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: conversations.isEmpty
                              ? const Center(child: Text('No conversations'))
                              : ListView.separated(
                                  itemCount: conversations.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final item = conversations[i];
                                    final partner = item['partner'] as String;
                                    final lm = item['lastMessage'] as MessageModel;
                                    final partnerName = svc.getUserDisplayName(partner, accounts);
                                    final preview = () {
                                      try {
                                        final data = jsonDecode(lm.content) as Map;
                                        final c = (data['content'] ?? '').toString();
                                        if (c.isNotEmpty) return c.length > 30 ? '${c.substring(0, 30)}…' : c;
                                        final atts = (data['attachments'] as List?) ?? [];
                                        return atts.isEmpty ? 'Message' : 'Sent ${atts.length} attachment(s)';
                                      } catch (_) {
                                        return lm.content.length > 30 ? '${lm.content.substring(0, 30)}…' : lm.content;
                                      }
                                    }();
                                    return ListTile(
                                      dense: true,
                                      leading: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
                                      title: Text(partnerName, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      trailing: Text(DateFormat.Hm().format(lm.timestamp), style: const TextStyle(fontSize: 11)),
                                      selected: normalizeEmail(partner) == selectedPartnerKey,
                                      onTap: () => setState(() => selectedPartnerKey = normalizeEmail(partner)),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // Thread
                  Expanded(
                    child: selectedPartnerKey == null
                        ? const Center(child: Text('Select a conversation'))
                        : _ThreadView(
                            svc: svc,
                            meKey: currentUserKey,
                            partnerKey: selectedPartnerKey!,
                            getUserName: (k) => svc.getUserDisplayName(k, accounts),
                            onSend: _sendMessage,
                            formatTime: (dt) => DateFormat.Hm().format(dt),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= Comments Section =================
class _CommentsSection extends StatefulWidget {
  final Experience experience;
  final Future<void> Function(String text) onAdd;
  final ShareExperienceService svc;
  final Map<String, dynamic> accounts;
  final String Function(String key) getUserName;
  final String Function(DateTime dt) formatAgo;

  const _CommentsSection({
    Key? key,
    required this.experience,
    required this.onAdd,
    required this.svc,
    required this.accounts,
    required this.getUserName,
    required this.formatAgo,
  }) : super(key: key);

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommentModel>>(
      stream: widget.svc.streamComments(widget.experience.id),
      builder: (context, snap) {
        final comments = snap.data ?? [];
        return Column(
          children: [
            for (final c in comments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(widget.getUserName(c.userId)),
                subtitle: Text(c.content),
                trailing: Text(widget.formatAgo(c.timestamp), style: const TextStyle(fontSize: 12)),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Write a comment…'),
                    onSubmitted: (_) => _post(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _post,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _post() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await widget.onAdd(text);
    controller.clear();
  }
}

/// ================= Thread View =================
class _ThreadView extends StatefulWidget {
  final ShareExperienceService svc;
  final String meKey;
  final String partnerKey;
  final String Function(String key) getUserName;
  final Future<void> Function(String text) onSend;
  final String Function(DateTime) formatTime;

  const _ThreadView({
    Key? key,
    required this.svc,
    required this.meKey,
    required this.partnerKey,
    required this.getUserName,
    required this.onSend,
    required this.formatTime,
  }) : super(key: key);

  @override
  State<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<_ThreadView> {
  final input = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(widget.getUserName(widget.partnerKey)),
          subtitle: const Text('Online'),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: widget.svc.streamConversation(widget.meKey, widget.partnerKey),
            builder: (context, snap) {
              final list = snap.data ?? [];
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[i];
                  final isMe = normalizeEmail(m.fromUser) == normalizeEmail(widget.meKey);
                  final text = _renderMessagePreview(m.content);
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue.shade50 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(text),
                          const SizedBox(height: 4),
                          Text(widget.formatTime(m.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: 'Type a message…'), onSubmitted: (_) => _send())),
              IconButton(icon: const Icon(Icons.send), onPressed: _send),
            ],
          ),
        ),
      ],
    );
  }

  String _renderMessagePreview(String content) {
    try {
      final obj = jsonDecode(content) as Map;
      final c = (obj['content'] ?? '').toString();
      final atts = (obj['attachments'] as List?) ?? [];
      if (c.isNotEmpty) return c;
      if (atts.isNotEmpty) return 'Sent ${atts.length} attachment(s)';
      return 'Message';
    } catch (_) {
      return content;
    }
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    await widget.onSend(text);
    input.clear();
  }
}

/// ================= Friends Panel =================
class _FriendsPanel extends StatefulWidget {
  final ShareExperienceService svc;
  final String currentUserKey;
  final Map<String, dynamic> accounts;
  final void Function(String userKey) onStartChat;
  final List<FriendRequest> friendRequests;
  final List<FriendRel> friends;

  const _FriendsPanel({
    Key? key,
    required this.svc,
    required this.currentUserKey,
    required this.accounts,
    required this.onStartChat,
    required this.friendRequests,
    required this.friends,
  }) : super(key: key);

  @override
  State<_FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<_FriendsPanel> {
  String tab = 'add';
  String q = '';
  bool loading = false;
  List<Map<String, String>> results = [];

  @override
  Widget build(BuildContext context) {
    final elderlyResults = results;

    return Column(
      children: [
        Row(
          children: [
            ChoiceChip(label: const Text('Add'), selected: tab == 'add', onSelected: (_) => setState(() => tab = 'add')),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Requests'), selected: tab == 'requests', onSelected: (_) => setState(() => tab = 'requests')),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('My Friends'), selected: tab == 'myfriends', onSelected: (_) => setState(() => tab = 'myfriends')),
          ],
        ),
        const Divider(),
        if (tab == 'add') ...[
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search elderly by name or email'),
            onChanged: (v) async {
              setState(() {
                q = v;
                loading = true;
              });
              final r = widget.svc.searchElderlyUsers(query: v, currentUserEmail: widget.currentUserKey, accounts: widget.accounts);
              setState(() {
                results = r;
                loading = false;
              });
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : elderlyResults.isEmpty
                    ? const Center(child: Text('No matches'))
                    : ListView.separated(
                        itemCount: elderlyResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = elderlyResults[i];
                          final name = u['name'] ?? u['email']!;
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(name),
                            subtitle: const Text('Elderly User'),
                            trailing: FilledButton(
                              onPressed: () async {
                                await widget.svc.sendFriendRequest(widget.currentUserKey, u['key']!);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent')));
                              },
                              child: const Text('Add'),
                            ),
                          );
                        },
                      ),
          ),
        ] else if (tab == 'requests') ...[
          Expanded(
            child: widget.friendRequests.isEmpty
                ? const Center(child: Text('No pending requests'))
                : ListView.separated(
                    itemCount: widget.friendRequests.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = widget.friendRequests[i];
                      final isForMe = normalizeEmail(r.toUser) == widget.currentUserKey;
                      if (!isForMe || r.status != 'pending') return const SizedBox.shrink();
                      final fromName = widget.svc.getUserDisplayName(r.fromUser, widget.accounts);
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(fromName),
                        subtitle: const Text('Wants to be your friend'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => widget.svc.respondToFriendRequest(r.id, 'accepted'),
                              child: const Text('Accept'),
                            ),
                            OutlinedButton(
                              onPressed: () => widget.svc.respondToFriendRequest(r.id, 'rejected'),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ] else ...[
          Expanded(
            child: widget.friends.isEmpty
                ? const Center(child: Text('No friends yet'))
                : ListView.separated(
                    itemCount: widget.friends.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final f = widget.friends[i];
                      final partner = normalizeEmail(f.user1) == widget.currentUserKey ? f.user2 : f.user1;
                      final name = widget.svc.getUserDisplayName(partner, widget.accounts);
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(name),
                        subtitle: const Text('Friend'),
                        trailing: TextButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Message'),
                          onPressed: () => widget.onStartChat(normalizeEmail(partner)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
