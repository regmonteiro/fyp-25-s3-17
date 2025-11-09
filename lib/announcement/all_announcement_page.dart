import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'announcement_controller.dart';
import '../models/announcement.dart';
import 'package:intl/intl.dart';

class AllAnnouncementsPage extends StatefulWidget {
  const AllAnnouncementsPage({super.key});

  @override
  State<AllAnnouncementsPage> createState() => _AllAnnouncementsPageState();
}

class _AllAnnouncementsPageState extends State<AllAnnouncementsPage> {
  final _ctrl = AnnouncementController();
  final _pageSize = 6;

  List<Announcement> _items = [];
  bool _loading = true;
  bool _refreshing = false;
  int _currentPage = 1;

  String? _uid;
  String? _userType; // "admin" | "caregiver" | "elderly"

  @override
  void initState() {
    super.initState();
    _resolveIdentity().then((_) => _load());
  }

  Future<void> _resolveIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;

    // Heuristic like the React code; replace with your Account doc if preferred
    final email = user?.email?.toLowerCase() ?? '';
    String type = 'elderly';
    if (email.contains('admin') || email.contains('helloworld2')) {
      type = 'admin';
    } else if (email.contains('caregiver')) {
      type = 'caregiver';
    } else if (email.contains('elderly') || email.contains('helloworld3')) {
      type = 'elderly';
    }
    _userType = type;
  }

  Future<void> _load() async {
    if (_userType == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _refreshing = true;
    });

    try {
      final list = await _ctrl.fetchForUserType(_userType!);
      setState(() {
        _items = list;
        _currentPage = 1;
      });
    } catch (_) {
      // You can add a SnackBar if needed
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _markRead(String id) async {
    if (_uid == null) return;
    await _ctrl.markRead(_uid!, id);
    setState(() {
      _items = _items.map((a) {
        if (a.id == id) {
          final newRead = Map<String, dynamic>.from(a.readBy)..[ _uid!] = true;
          return Announcement(
            id: a.id,
            title: a.title,
            description: a.description,
            userGroups: a.userGroups,
            createdAt: a.createdAt,
            readBy: newRead,
          );
        }
        return a;
      }).toList();
    });
  }

  Future<void> _markAllRead() async {
    if (_uid == null) return;
    final unread = _items.where((a) => a.readBy[_uid!] != true).toList();
    for (final a in unread) {
      await _ctrl.markRead(_uid!, a.id);
    }
    setState(() {
      _items = _items.map((a) {
        final newRead = Map<String, dynamic>.from(a.readBy)..[ _uid!] = true;
        return Announcement(
          id: a.id,
          title: a.title,
          description: a.description,
          userGroups: a.userGroups,
          createdAt: a.createdAt,
          readBy: newRead,
        );
      }).toList();
    });
  }

  int get _totalPages => (_items.length / _pageSize).ceil();
  List<Announcement> get _paginated {
    final start = (_currentPage - 1) * _pageSize;
    final end = (_currentPage * _pageSize).clamp(0, _items.length);
    return _items.sublist(start, end);
  }

  String _fmt(DateTime dt) => DateFormat('MMM d, y • HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final userType = _userType;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          if (!_loading && _items.any((a) => uid != null && a.readBy[uid] != true))
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all),
              label: const Text('Mark all read'),
            ),
          IconButton(
            onPressed: _refreshing ? null : _load,
            icon: _refreshing
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (userType == null || uid == null)
              ? _buildUserMissing(context)
              : _buildList(context, uid),
    );
  }

  Widget _buildUserMissing(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_outline, size: 48),
        const SizedBox(height: 8),
        const Text('User information needed'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _load,
          child: const Text('Refresh'),
        ),
      ]),
    );
  }

  Widget _chip(String text, {bool primary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary ? Colors.blue.withOpacity(.12) : Colors.grey.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: primary ? Colors.blue[800] : Colors.black87)),
    );
  }

  Widget _buildList(BuildContext context, String uid) {
    final unreadCount = _items.where((a) => a.readBy[uid] != true).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            _chip('${_items.length} announcement${_items.length == 1 ? '' : 's'}', primary: true),
            const SizedBox(width: 8),
            if (unreadCount > 0) _chip('$unreadCount unread'),
            const Spacer(),
          ]),
          const SizedBox(height: 12),

          // Empty state
          if (_items.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.notifications_none, size: 64),
                  SizedBox(height: 8),
                  Text('No announcements right now'),
                ]),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                itemCount: _paginated.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1, // set 2 for wide grid
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3.0,
                ),
                itemBuilder: (context, i) {
                  final a = _paginated[i];
                  final isRead = a.readBy[uid] == true;
                  return Material(
                    color: isRead ? Colors.white : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _markRead(a.id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(a.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium),
                              ),
                              IconButton(
                                tooltip: isRead ? 'Already read' : 'Mark as read',
                                onPressed: isRead ? null : () => _markRead(a.id),
                                icon: Icon(Icons.check_circle,
                                    color: isRead ? Colors.grey : Colors.green),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                a.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _chip('For: ${a.userGroups.isEmpty ? 'All users' : a.userGroups.join(', ')}'),
                                _chip(_fmt(a.createdAt)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Pagination
          if (_totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 1
                      ? () => setState(() => _currentPage = _currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Wrap(
                  spacing: 6,
                  children: List.generate(_totalPages, (i) {
                    final page = i + 1;
                    final active = page == _currentPage;
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: active ? Colors.blue.shade50 : null,
                      ),
                      onPressed: () => setState(() => _currentPage = page),
                      child: Text('$page'),
                    );
                  }),
                ),
                IconButton(
                  onPressed: _currentPage < _totalPages
                      ? () => setState(() => _currentPage = _currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
