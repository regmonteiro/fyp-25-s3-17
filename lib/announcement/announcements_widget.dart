import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'announcement_controller.dart';
import '../models/announcement.dart';
import 'all_announcement_page.dart';

class AnnouncementsWidget extends StatefulWidget {
  const AnnouncementsWidget({super.key});

  @override
  State<AnnouncementsWidget> createState() => _AnnouncementsWidgetState();
}

class _AnnouncementsWidgetState extends State<AnnouncementsWidget> {
  final _ctrl = AnnouncementController();

  Stream<List<Announcement>>? _stream;
  String? _uid;
  String? _userType;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;

    final email = user?.email?.toLowerCase() ?? '';
    String type = 'elderly';
    if (email.contains('admin') || email.contains('helloworld2')) {
      type = 'admin';
    } else if (email.contains('caregiver')) {
      type = 'caregiver';
    }
    _userType = type;

    if (mounted && _userType != null) {
      setState(() {
        _stream = _ctrl.streamForUserType(_userType!);
      });
    }
  }

  String _short(DateTime dt) => DateFormat('MMM d, y').format(dt);

  Future<void> _markRead(String id) async {
    if (_uid == null) return;
    await _ctrl.markRead(_uid!, id);
  }

  @override
  Widget build(BuildContext context) {
    if (_userType == null || _uid == null) {
      return _shell(child: const Text('User information not available'));
    }
    if (_stream == null) {
      return _shell(child: const Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<Announcement>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return _shell(child: const Center(child: CircularProgressIndicator()));
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return _shell(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.notifications_none, size: 40),
                SizedBox(height: 8),
                Text('No announcements'),
              ],
            ),
          );
        }

        final a = list.first;
        final isRead = a.readBy[_uid!] == true;

        return _shell(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isRead)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(a.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chip(a.userGroups.isEmpty ? 'All users' : a.userGroups.join(', ')),
                        _chip(_short(a.createdAt)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isRead ? 'Read' : 'Mark read',
                onPressed: isRead ? null : () => _markRead(a.id),
                icon: Icon(Icons.check_circle, color: isRead ? Colors.grey : Colors.green),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text),
      );

  Widget _shell({required Widget child}) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
