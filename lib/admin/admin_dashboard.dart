import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'admin_shell.dart';

class AdminDashboard extends StatefulWidget {
  final UserProfile userProfile;
  const AdminDashboard({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentKey: 'adminDashboard',
      title: 'Dashboard',
      profile: widget.userProfile,
      body: Padding(
        padding: EdgeInsets.all(16),
        child: _buildDashboardContent(),
      ),
      showBackButton: false,
      showDashboardButton: false,
    );
  }

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  List<AdminRow> _rows = [];
  List<AdminRow> _filtered = [];
  final Map<String, bool> _busyMap = {};

  @override
  void initState() {
    super.initState();
    _subscribeAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeAccounts() {
    _db
        .collection('Account')
        .snapshots()
        .listen(
          (snap) {
            final list = snap.docs.map((d) => _docToRow(d)).toList();
            setState(() => _rows = list);
            _performSearch(_searchController.text);
          },
          onError: (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
          },
        );
  }

  AdminRow _docToRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();

    String _s(dynamic v, [String fallback = 'Not provided']) {
      if (v == null) return fallback;
      final t = v.toString().trim();
      return t.isEmpty ? fallback : t;
    }

    final createdAtStr = d['createdAt'];
    final lastLoginStr = d['lastLoginDate'];
    final dobStr = d['dob'];

    return AdminRow(
      id: doc.id,
      firstName: _s(d['firstname']),
      lastName: _s(d['lastname']),
      email: _s(d['email']),
      userType: _s(d['userType'], 'Not specified'),
      phone: _s(d['phoneNum']),
      status: _s(d['status'], 'Active'),
      dob: (dobStr == null || dobStr.toString().isEmpty)
          ? 'Not provided'
          : dobStr.toString(),
      createdAt: DateTime.tryParse(createdAtStr?.toString() ?? ''),
      lastLogin: DateTime.tryParse(lastLoginStr?.toString() ?? ''),
    );
  }

  Widget _buildAppBar(String adminName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.purple.shade500,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Menu clicked'))),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome, $adminName',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications clicked')),
              ),
            ),
            ElevatedButton(
              onPressed: _logoutUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registered Users',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade500,
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildUsersTable(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade500),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade500),
              ),
              hintStyle: TextStyle(color: Colors.purple.shade200),
            ),
            onChanged: _performSearch,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _performSearch(_searchController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade500,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Search', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildUsersTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_tableHeader(), _tableRows()],
        ),
      ),
    );
  }

  Widget _tableHeader() => Container(
    color: Colors.purple.shade200,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        _h('First Name', 120),
        _h('Last Name', 120),
        _h('Email', 220),
        _h('User Type', 120),
        _h('Phone', 150),
        _h('Date of Birth', 120),
        _h('Created At', 170),
        _h('Last Login', 190),
        _h('Status', 100),
        _h('Actions', 120),
      ],
    ),
  );

  Widget _h(String t, double w) => Container(
    width: w,
    padding: const EdgeInsets.all(8),
    child: Text(
      t,
      style: TextStyle(
        color: Colors.purple.shade500,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _tableRows() {
    if (_filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Text(
          'No registered users found.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    return Column(children: _filtered.map(_row).toList());
  }

  Widget _row(AdminRow u) {
    final isActive = u.status.toLowerCase() == 'active';
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _c(u.firstName, 120),
          _c(u.lastName, 120),
          _email(u.email, 220),
          _type(u.userType, 120),
          _c(u.phone, 150),
          _c(u.dob, 120),
          _c(_fmtDate(u.createdAt), 170),
          _c(_fmtDateTime(u.lastLogin), 190),
          _status(u.status, 100),
          _actions(u, isActive, 120),
        ],
      ),
    );
  }

  Widget _c(String t, double w) => Container(
    width: w,
    padding: const EdgeInsets.all(8),
    child: Text(
      t,
      style: const TextStyle(fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _email(String t, double w) => Container(
    width: w,
    padding: const EdgeInsets.all(8),
    child: Text(
      t,
      style: const TextStyle(color: Color(0xFF005f73), fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _type(String userType, double w) {
    Color bg, fg;
    switch (userType.toLowerCase()) {
      case 'admin':
        bg = const Color(0xFFf28482);
        fg = const Color(0xFF4a2c2a);
        break;
      case 'caregiver':
        bg = const Color(0xFF82c0cc);
        fg = const Color(0xFF1e3d47);
        break;
      case 'elderly':
        bg = const Color(0xFFf7ede2);
        fg = const Color(0xFF5f4b3e);
        break;
      default:
        bg = const Color(0xFFccc5b9);
        fg = const Color(0xFF6e6b5a);
        break;
    }
    final nice = userType.isEmpty
        ? 'Not specified'
        : userType[0].toUpperCase() + userType.substring(1).toLowerCase();
    return Container(
      width: w,
      padding: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          nice,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _status(String status, double w) {
    final isInactive =
        status.toLowerCase() == 'inactive' ||
        status.toLowerCase() == 'deactivated';
    return Container(
      width: w,
      padding: const EdgeInsets.all(8),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isInactive ? const Color(0xFFd9534f) : const Color(0xFF3c763d),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _actions(AdminRow u, bool isActive, double w) {
    final loading = _busyMap[u.id] == true;
    return Container(
      width: w,
      padding: const EdgeInsets.all(8),
      child: ElevatedButton(
        onPressed: loading ? null : () => _toggleStatus(u),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color(0xFFd9534f)
              : const Color(0xFF5cb85c),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
        ),
        child: Text(
          loading ? 'Processing...' : (isActive ? 'Deactivate' : 'Activate'),
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
      ),
    );
  }

  // ───────────────────────── Actions ─────────────────────────
  Future<void> _toggleStatus(AdminRow u) async {
    final newStatus = u.status.toLowerCase() == 'active'
        ? 'Inactive'
        : 'Active';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text('Are you sure you want to set ${u.email} to $newStatus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyMap[u.id] = true);
    try {
      await _db.collection('Account').doc(u.id).update({'status': newStatus});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account for ${u.email} has been ${newStatus.toLowerCase()}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyMap.remove(u.id));
    }
  }

  void _performSearch(String term) {
    final q = term.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_rows)
          : _rows.where((u) {
              bool c(String v) => v.toLowerCase().contains(q);
              return c(u.firstName) ||
                  c(u.lastName) ||
                  c(u.email) ||
                  c(u.userType) ||
                  c(u.phone) ||
                  c(u.status) ||
                  c(u.dob);
            }).toList();
    });
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'N/A';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return 'Never logged in';
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
  }

  Future<void> _logoutUser() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out successfully')));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {}
  }
}

class _ADNavigation extends StatefulWidget {
  final void Function(String) onNavigationChanged;
  const _ADNavigation({Key? key, required this.onNavigationChanged})
    : super(key: key);

  @override
  State<_ADNavigation> createState() => _ADNavigationState();
}

class _ADNavigationState extends State<_ADNavigation> {
  final Color _purple = Colors.purple.shade500;
  final Color _white = Colors.white;
  String _current = 'adminDashboard';

  @override
  Widget build(BuildContext context) {
    Widget item(String text, String key, IconData icon, {bool last = false}) {
      final sel = _current == key;
      return Container(
        margin: EdgeInsets.only(right: last ? 16 : 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_current != key) {
                setState(() => _current = key);
                widget.onNavigationChanged(key);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: sel
                  ? BoxDecoration(
                      color: _purple,
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: sel ? _white : _purple),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? _white : _purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            item('Dashboard', 'adminDashboard', Icons.dashboard_outlined),
            item('Profile', 'adminProfile', Icons.person_outline),
            item('Reports', 'adminReports', Icons.assessment_outlined),
            item('Feedback', 'adminFeedback', Icons.chat_bubble_outline),
            item('Roles', 'adminRoles', Icons.admin_panel_settings_outlined),
            item(
              'Safety Measures',
              'adminSafetyMeasures',
              Icons.health_and_safety_outlined,
            ),
            item('Announcement', 'adminAnnouncement', Icons.campaign_outlined),
            item('Manage', 'adminManage', Icons.tune, last: true),
          ],
        ),
      ),
    );
  }
}

class AdminRow {
  final String id; // doc id = emailKey
  final String firstName;
  final String lastName;
  final String email;
  final String userType;
  final String phone;
  final String status;
  final String dob; // "2000-09-09"
  final DateTime? createdAt; // parsed from createdAt string
  final DateTime? lastLogin; // parsed from lastLoginDate string

  AdminRow({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.userType,
    required this.phone,
    required this.status,
    required this.dob,
    required this.createdAt,
    required this.lastLogin,
  });
}
