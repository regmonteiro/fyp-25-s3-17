import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminManage extends StatefulWidget {
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final int? userCreatedAt;

  const AdminManage({
    Key? key,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userCreatedAt,
  }) : super(key: key);

  @override
  _AdminManageState createState() => _AdminManageState();
}

class _AdminManageState extends State<AdminManage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;
  final Color _redColor = Colors.red;
  final Color _blueColor = Colors.blue;

  static const String _TAG = "AdminManage";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _whiteColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // AD Navigation Toolbar
          ADNavigation(
            onNavigationChanged: _handleNavigationChanged,
          ),

          // Main Content - Vertical Buttons
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _purpleColor,
      elevation: 4,
      title: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: _whiteColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Menu clicked")),
              );
            },
          ),
          Expanded(
            child: Text(
              "Manage",
              style: TextStyle(
                color: _whiteColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: _whiteColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Notifications clicked")),
              );
            },
          ),
          ElevatedButton(
            onPressed: _logoutUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: _redColor,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: Text(
              "Logout",
              style: TextStyle(color: _whiteColor),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: EdgeInsets.all(50),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Services Button
            _buildManagementButton(
              text: "Services",
              onPressed: _openServicesManagement,
            ),
            SizedBox(height: 16),

            // Membership Button
            _buildManagementButton(
              text: "Membership",
              onPressed: _openMembershipManagement,
            ),
            SizedBox(height: 16),

            // Activities Button
            _buildManagementButton(
              text: "Activities",
              onPressed: _openActivitiesManagement,
            ),
            SizedBox(height: 16),

            // Medical Products Button
            _buildManagementButton(
              text: "Medical Products",
              onPressed: _openMedicalProductsManagement,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 150, // Fixed height for consistency
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _blueColor,
          foregroundColor: _whiteColor,
          elevation: 4,
          textStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: _whiteColor,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  // Navigation Handler
  void _handleNavigationChanged(String activityKey) {
    print("$_TAG: Navigation changed to: $activityKey");
  }

  // Management Screen Navigation Methods
  void _openServicesManagement() {
    try {
      print("$_TAG: Opening Services Management");
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(builder: (context) => AdminManageService()),
      // );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opening Services Management")),
      );
    } catch (e) {
      print("$_TAG: Error opening Services Management: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening Services Management")),
      );
    }
  }

  void _openMembershipManagement() {
    try {
      print("$_TAG: Opening Membership Management");
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(builder: (context) => AdminManageMembership()),
      // );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opening Membership Management")),
      );
    } catch (e) {
      print("$_TAG: Error opening Membership Management: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening Membership Management")),
      );
    }
  }

  void _openActivitiesManagement() {
    try {
      print("$_TAG: Opening Activities Management");
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(builder: (context) => AdminManageActivities()),
      // );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opening Activities Management")),
      );
    } catch (e) {
      print("$_TAG: Error opening Activities Management: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening Activities Management")),
      );
    }
  }

  void _openMedicalProductsManagement() {
    try {
      print("$_TAG: Opening Medical Products Management");
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(builder: (context) => AdminManageMedical()),
      // );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opening Medical Products Management")),
      );
    } catch (e) {
      print("$_TAG: Error opening Medical Products Management: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening Medical Products Management")),
      );
    }
  }

  void _logoutUser() {
    _auth.signOut();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Logged out successfully")),
    );
    _redirectToLogin();
  }

  void _redirectToLogin() {
    print("$_TAG: Redirecting to login page");
    // Navigator.pushAndRemoveUntil(
    //   context,
    //   MaterialPageRoute(builder: (context) => LoginPage()),
    //   (route) => false,
    // );
  }
}

// ADNavigation Widget (same as previous implementations)
class ADNavigation extends StatefulWidget {
  final Function(String) onNavigationChanged;

  const ADNavigation({Key? key, required this.onNavigationChanged}) : super(key: key);

  @override
  _ADNavigationState createState() => _ADNavigationState();
}

class _ADNavigationState extends State<ADNavigation> {
  static const String _TAG = "ADNavigation";

  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;

  String _currentActivity = "adminManage";

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _whiteColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildNavItem("ad_dashboardNav", "Dashboard", "adminDashboard"),
            _buildNavItem("ad_profileNav", "Profile", "adminProfile"),
            _buildNavItem("ad_reportsNav", "Reports", "adminReports"),
            _buildNavItem("ad_feedbackNav", "Feedback", "adminFeedback"),
            _buildNavItem("ad_rolesNav", "Roles", "adminRoles"),
            _buildNavItem("ad_safetyMeasuresNav", "Safety Measures", "adminSafetyMeasures"),
            _buildNavItem("ad_announcementNav", "Announcement", "adminAnnouncement"),
            _buildNavItem("ad_manageNav", "Manage", "adminManage", isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(String id, String text, String activityKey, {bool isLast = false}) {
    bool isSelected = _currentActivity == activityKey;

    return Container(
      margin: EdgeInsets.only(right: isLast ? 16 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNavigation(activityKey),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: isSelected
                ? BoxDecoration(
              color: _purpleColor,
              borderRadius: BorderRadius.circular(20),
            )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? _whiteColor : _purpleColor,
                    shape: BoxShape.rectangle,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? _whiteColor : _purpleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(String activityKey) {
    print("$_TAG: Navigating to $activityKey");

    try {
      if (_currentActivity != activityKey) {
        setState(() {
          _currentActivity = activityKey;
        });

        widget.onNavigationChanged(activityKey);
      } else {
        print("$_TAG: Already on $activityKey");
        _highlightCurrentItem(activityKey);
      }
    } catch (e) {
      print("$_TAG: Error navigating to $activityKey: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot open ${_getScreenName(activityKey)}")),
      );
    }
  }

  String _getScreenName(String activityKey) {
    String screenName = activityKey.replaceAll('admin', '');
    if (screenName.isEmpty) return "Screen";

    String result = screenName[0].toUpperCase() + screenName.substring(1);
    result = result.replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}');

    return result.trim();
  }

  void _highlightCurrentItem(String currentActivity) {
    print("$_TAG: AD Highlighting: $currentActivity");

    try {
      setState(() {
        _currentActivity = currentActivity;
      });
    } catch (e) {
      print("$_TAG: Error highlighting current item: $currentActivity, $e");
    }
  }

  // Public methods to mimic the Java class functionality
  void highlightCurrentItem(String currentActivity) {
    _highlightCurrentItem(currentActivity);
  }

  void refreshNavigation() {
    print("$_TAG: Refreshing navigation...");
    setState(() {});
  }

  bool isNavigationInitialized() {
    return true;
  }
}