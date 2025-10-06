import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
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
  String? _selectedElderId;
  late final List<_TabSpec> _tabs;

  void _onElderSelected(String elderId) {
    setState(() {
      _selectedElderId = elderId;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize the tabs only once here in initState
    _tabs = [
      _TabSpec(
        title: 'Home',
        icon: Icons.dashboard_outlined,
        content: CaregiverHomeTab(
          userProfile: widget.userProfile,
          onElderSelected: _onElderSelected,
        ),
      ),
      _TabSpec(
        title: 'Create Events',
        icon: Icons.event_available_outlined,
        content: CreateEventsPage(
          userProfile: widget.userProfile,
          elderlyId: null,
        ),
      ),
      _TabSpec(
        title: 'AI Assistant',
        icon: Icons.smart_toy_outlined,
        content: CgAIAssistant(userProfile: widget.userProfile),
      ),
      _TabSpec(
        title: 'Reports',
        icon: Icons.insert_chart_outlined,
        content: ViewReportsCaregiverPage(userProfile: widget.userProfile),
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
          if (_index == 0)
            IconButton(
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Alerts',
              onPressed: () {
                // open alerts screen, if any
              },
            ),
        ],
      ),
      body: PageStorage(
        bucket: _bucket,
        child: IndexedStack(
          index: _index,
          children: _tabs.map((t) {
            // Conditionally re-create the page for the current tab only
            if (_selectedElderId != null && t.title == 'Create Events') {
              return _ensureContent(
                CreateEventsPage(
                  userProfile: widget.userProfile,
                  elderlyId: _selectedElderId,
                ),
              );
            }
            return _ensureContent(t.content);
          }).toList(),
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
      floatingActionButton: _index == 1 && _selectedElderId != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateEventsPage(
                      userProfile: widget.userProfile,
                      elderlyId: _selectedElderId!,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New Event'),
            )
          : null,
    );
  }

  Widget _ensureContent(Widget w) {
    // A simplified version that just returns the child
    return _TabBody(child: w);
  }
}

class _TabSpec {
  final String title;
  final IconData icon;
  final Widget content;
  _TabSpec({required this.title, required this.icon, required this.content});
}

class _TabBody extends StatelessWidget {
  final Widget child;
  const _TabBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: child,
    );
  }
}
