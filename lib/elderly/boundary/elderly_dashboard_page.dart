import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import 'elderly_home_page.dart';
import 'learning_page.dart';
import 'account/account_page.dart';
import '../controller/elderly_dashboard_controller.dart';
import 'create_event_reminders_page.dart';
import 'view_activties_page.dart';

class ElderlyDashboardPage extends StatefulWidget {
  final UserProfile userProfile;
  const ElderlyDashboardPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<ElderlyDashboardPage> createState() => _ElderlyDashboardPageState();
}

class _ElderlyDashboardPageState extends State<ElderlyDashboardPage> {
  final ElderlyDashboardController _controller = ElderlyDashboardController();


late final List<Widget> _rootPages;
late final List<GlobalKey<NavigatorState>> _navigatorKeys;

@override
void initState() {
  super.initState();

  _rootPages = [
    ElderlyHomePage(userProfile: widget.userProfile),
    const CreateEventRemindersPage(),
    const ViewActivitiesPage(),
    const LearningResourcesPageRT(),
    const AccountPage(),
  ];
  _navigatorKeys =
      List.generate(_rootPages.length, (_) => GlobalKey<NavigatorState>());
}

  Widget _buildTabNavigator({
    required GlobalKey<NavigatorState> key,
    required Widget child,
  }) {
    return Navigator(
      key: key,
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => child, settings: settings),
    );
  }

  // Bottom bar tap
  void _onItemTapped(int index) {
    if (index == _controller.selectedIndex) {
      // Tapping the active tab pops to its root
      final nav = _navigatorKeys[index].currentState;
      nav?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _controller.onItemTapped(index));
    }
  }

  // Android back button: pop inner stack first
  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_controller.selectedIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    if (_controller.selectedIndex != 0) {
      setState(() => _controller.onItemTapped(0));
      return false;
    }
    return true; // exiting app (or previous route)
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _controller.selectedIndex,
          children: List.generate(
            _rootPages.length,
            (i) => _buildTabNavigator(
              key: _navigatorKeys[i],
              child: _rootPages[i],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _controller.selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Create Event Reminders'),
            BottomNavigationBarItem(icon: Icon(Icons.volunteer_activism_outlined), label: 'Activities'),
            BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'AI Assistant'),
            BottomNavigationBarItem(icon: Icon(Icons.book_outlined), label: 'Learning'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
          ],
          selectedItemColor: Colors.purpleAccent,
          unselectedItemColor: Colors.white54,
          backgroundColor: const Color(0xFF16213E),
        ),
      ),
    );
  }
}
