import 'package:flutter/material.dart';
import 'elderly_home_page.dart';
import '../controller/elderly_dashboard_controller.dart';
import 'ai_assistant_page.dart';
import 'events_page.dart';
import 'learning_page.dart';
import 'account/account_page.dart';
import '../../models/user_profile.dart';

class ElderlyDashboardPage extends StatefulWidget {
  final UserProfile userProfile;
  const ElderlyDashboardPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<ElderlyDashboardPage> createState() => _ElderlyDashboardPageState();
}

class _ElderlyDashboardPageState extends State<ElderlyDashboardPage> {
  final ElderlyDashboardController _controller = ElderlyDashboardController();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ElderlyHomePage(userProfile: widget.userProfile),
      const EventsPage(),
      const AIAssistantPage(),
      const LearningResourcesPageRT(),
      const AccountPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _controller.onItemTapped(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_controller.selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _controller.selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'AI Assistant',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: 'Learning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
        type: BottomNavigationBarType.fixed, // Use this for more than 3 items
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.white54,
        backgroundColor: const Color(0xFF16213E),
      ),
    );
  }
}