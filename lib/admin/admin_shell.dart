import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // for kIsWeb
import 'dart:io' show Platform; // for Platform.isIOS
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import 'admin_top_nav.dart';
import 'admin_routes.dart';
import '../welcome.dart';

class AdminShell extends StatelessWidget {
  final String currentKey;
  final String title;
  final UserProfile profile;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const AdminShell({
    Key? key,
    required this.currentKey,
    required this.title,
    required this.profile,
    required this.body,
    this.floatingActionButton,
    this.actions,
  }) : super(key: key);



  Route _logoutRoute() {
    if (!kIsWeb && Platform.isIOS) {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      );
    }
    return MaterialPageRoute(builder: (context) => const WelcomeScreen());
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Clear the stack and go to WelcomeScreen using the custom route.
      Navigator.of(context).pushAndRemoveUntil(_logoutRoute(), (r) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
    } catch (_) {
      // Optionally handle/log error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _AdminDrawer(
        currentKey: currentKey,
        onSelect: (k) => navigateAdmin(context, k, profile),
        onLogout: () => _logout(context),
      ),
      appBar: AppBar(
        elevation: 4,
        backgroundColor: Colors.purple.shade500,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Notifications clicked'))),
          ),
          TextButton(
            onPressed: () => _logout(context),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
          ...?actions,
        ],
      ),
      body: Column(
        children: [
          ADNavigation(
            currentKey: currentKey,
            onNavigationChanged: (k) => navigateAdmin(context, k, profile),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final String currentKey;
  final void Function(String) onSelect;
  final VoidCallback onLogout;

  const _AdminDrawer({
    Key? key,
    required this.currentKey,
    required this.onSelect,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget tile(String title, String key, IconData icon) => ListTile(
          leading: Icon(icon, color: currentKey == key ? Colors.purple : null),
          title: Text(
            title,
            style: TextStyle(
              color: currentKey == key ? Colors.purple : null,
              fontWeight:
                  currentKey == key ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            if (currentKey != key) onSelect(key);
          },
        );

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            tile('Dashboard',        'adminDashboard',      Icons.dashboard_outlined),
            tile('Profile',          'adminProfile',        Icons.person_outline),
            tile('Reports',          'adminReports',        Icons.assessment_outlined),
            tile('Feedback',         'adminFeedback',       Icons.chat_bubble_outline),
            tile('Roles',            'adminRoles',          Icons.admin_panel_settings_outlined),
            tile('Safety Measures',  'adminSafetyMeasures', Icons.health_and_safety_outlined),
            tile('Announcement',     'adminAnnouncement',   Icons.campaign_outlined),
            tile('Manage',           'adminManage',         Icons.tune),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: onLogout, // uses the custom route via _logout above
            ),
          ],
        ),
      ),
    );
  }
}
