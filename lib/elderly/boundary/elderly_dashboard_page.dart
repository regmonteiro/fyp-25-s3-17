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
    // Initialize the pages list here to pass the userProfile object.
    _pages = [
      ElderlyHomePage(userProfile: widget.userProfile),
      const EventsPage(), // Assuming other pages don't need the profile for now
      const AIAssistantPage(),
      const LearningPage(),
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
      // The body now correctly displays only the selected page from the list.
      body: _pages[_controller.selectedIndex],
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF16213E),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.home_outlined, "Home", 0),
            _buildNavItem(Icons.calendar_today_outlined, "Events", 1),
            const SizedBox(width: 60),
            _buildNavItem(Icons.book_outlined, "Learning", 3),
            _buildNavItem(Icons.person_outline, "Account", 4),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(2),
        tooltip: 'AI Assistant',
        child: const Icon(Icons.mic, size: 30),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _controller.selectedIndex == index;
    final Color selectedColor =
        Theme.of(context).bottomNavigationBarTheme.selectedItemColor ?? Colors.purpleAccent;
    final Color unselectedColor =
        Theme.of(context).bottomNavigationBarTheme.unselectedItemColor ?? Colors.white54;
    final Color itemColor = isSelected ? selectedColor : unselectedColor;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: itemColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: itemColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}