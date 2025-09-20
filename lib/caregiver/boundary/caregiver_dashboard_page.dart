import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

// Import your 5 tab pages (boundary widgets)
import 'caregiver_home_page.dart';
import 'create_events_page.dart';
import 'cg_ai_assistant_page.dart';
import 'report_page.dart';
import 'caregiver_account_page.dart';

class CaregiverDashboardPage extends StatefulWidget {
  final UserProfile userProfile;
  const CaregiverDashboardPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<CaregiverDashboardPage> createState() => _CaregiverDashboardPageState();
}

class _CaregiverDashboardPageState extends State<CaregiverDashboardPage> {
  final _bucket = PageStorageBucket();
  int _index = 0;

  late final List<_TabSpec> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _TabSpec(
        title: 'Home',
        icon: Icons.dashboard_outlined,
        // If your page expects the profile, pass it in:
        content: CaregiverHomeTab(userProfile: widget.userProfile),
      ),
      _TabSpec(
        title: 'Create Events',
        icon: Icons.event_available_outlined,
        content: CreateEventsPage(userProfile: widget.userProfile),
      ),
      _TabSpec(
        title: 'AI Assistant',
        icon: Icons.smart_toy_outlined,
        content: CgAIAssistant(userProfile: widget.userProfile),
      ),
      _TabSpec(
        title: 'Reports',
        icon: Icons.insert_chart_outlined,
        content: ReportPage(userProfile: widget.userProfile),
      ),
      _TabSpec(
        title: 'Account',
        icon: Icons.person_outline,
        content: CaregiverAccountPage(userProfile: widget.userProfile),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final current = _tabs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        centerTitle: true,
        actions: [
          if (_index == 0) // example: quick action on Home
            IconButton(
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Alerts',
              onPressed: () {
                // open alerts screen, if any
              },
            ),
        ],
      ),

      // Keep each tab's state with IndexedStack + PageStorage
      body: PageStorage(
        bucket: _bucket,
        child: IndexedStack(
          index: _index,
          children: _tabs.map((t) => _ensureContent(t.content)).toList(),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: _tabs
            .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.title))
            .toList(),
      ),

      // Optional FAB shown only on “Create Events”
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                // trigger create-event flow inside CreateEventsPage (e.g., using a controller or callback)
              },
              icon: const Icon(Icons.add),
              label: const Text('New Event'),
            )
          : null,
    );
  }

  /// Ensures each tab is content-only. If a tab widget already returns a Scaffold,
  /// we wrap it so we don’t end up with nested AppBars/Scaffolds.
  Widget _ensureContent(Widget w) {
    // If your tab pages are pure content (no Scaffold), just return w.
    // If some of them currently use Scaffold, you can wrap them like this:
    return _TabBody(child: w);
  }
}

class _TabSpec {
  final String title;
  final IconData icon;
  final Widget content;
  _TabSpec({required this.title, required this.icon, required this.content});
}

/// A thin wrapper that avoids double-Scaffold problems by stripping AppBars
/// in nested pages. If your tab pages are content-only, this simply returns them.
class _TabBody extends StatelessWidget {
  final Widget child;
  const _TabBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // If child already handles its own scroll, just return it.
    // Otherwise, give a default SafeArea.
    return SafeArea(
      top: false, // we already have an AppBar on the shell
      child: child,
    );
  }
}
