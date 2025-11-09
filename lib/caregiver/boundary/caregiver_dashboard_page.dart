import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import 'caregiver_home_page.dart';
import 'create_appointments_page.dart';
import 'report_page.dart';
import '../boundary/accounts_pages/cg_account_page.dart';
import '../controller/caregiver_dashboard_controller.dart';

class CaregiverDashboardPage extends StatefulWidget {
  final UserProfile userProfile;
  const CaregiverDashboardPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<CaregiverDashboardPage> createState() => _CaregiverDashboardPageState();
}

class _CaregiverDashboardPageState extends State<CaregiverDashboardPage> {

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CaregiverDashboardController(),
      child: _DashboardScaffold(userProfile: widget.userProfile),
    );
  }
}

class _DashboardScaffold extends StatelessWidget {
  final UserProfile userProfile;
  const _DashboardScaffold({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<CaregiverDashboardController>();

    final tabs = <_TabSpec>[
      _TabSpec(
        title: 'Home',
        icon: Icons.dashboard_outlined,
        content: CaregiverHomePage(
          userProfile: userProfile,
          onElderlySelected: d.selectElder, // optional
        ),
      ),
      _TabSpec(
          title: 'Create Events',
          icon: Icons.event_available_outlined,
          content: Builder(
            builder: (ctx) {
              final dashboard = ctx.watch<CaregiverDashboardController>();
              final page = ctx.findAncestorWidgetOfExactType<CaregiverDashboardPage>()!;
              final userProfile = page.userProfile;

              return CreateAppointmentsPage(
                userProfile: userProfile,
                elderlyId: dashboard.selectedElderId,
              );
            },
          ),
        ),

          _TabSpec(
            title: 'Reports',
            icon: Icons.insert_chart_outlined,
            content: Builder(
              builder: (ctx) {
                final page = ctx.findAncestorWidgetOfExactType<CaregiverDashboardPage>()!;
                final userProfile = page.userProfile;

                return ViewReportsCaregiverPage(userProfile: userProfile);
              },
            ),
          ),

          _TabSpec(
            title: 'Account',
            icon: Icons.person_outline,
            content: Builder(
              builder: (ctx) {
                final page = ctx.findAncestorWidgetOfExactType<CaregiverDashboardPage>()!;
                final userProfile = page.userProfile;

                return CgAccountPage(userProfile: userProfile);
              },
            ),
          ),
        ];

    final current = tabs[d.index];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        centerTitle: true,
        actions: [
          if (d.index == 0)
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {},
            ),
        ],
      ),
      body: PageStorage(
        bucket: PageStorageBucket(),
        child: IndexedStack(
          index: d.index,
          children: tabs.map((t) => _TabBody(child: t.content)).toList(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: d.index,
        type: BottomNavigationBarType.fixed,
        onTap: d.setIndex,
        items: tabs
            .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.title))
            .toList(),
      ),
      floatingActionButton: d.index == 1 && d.selectedElderId != null
          ? FloatingActionButton.extended(
              onPressed: () {
                final page = context.findAncestorWidgetOfExactType<CaregiverDashboardPage>()!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateAppointmentsPage(
                      userProfile: page.userProfile,
                      elderlyId: d.selectedElderId!,
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
  Widget build(BuildContext context) => SafeArea(top: false, child: child);
}
