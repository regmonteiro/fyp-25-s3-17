import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFeedback extends StatefulWidget {
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final int? userCreatedAt;

  const AdminFeedback({
    Key? key,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userCreatedAt,
  }) : super(key: key);

  @override
  _AdminFeedbackState createState() => _AdminFeedbackState();
}

class _AdminFeedbackState extends State<AdminFeedback> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = true;
  bool _showAll = false;
  List<Feedback> _allFeedbacks = [];
  List<Feedback> _displayedFeedbacks = [];

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;
  final Color _redColor = Colors.red;
  final Color _blackColor = Colors.black;

  static const String _TAG = "AdminFeedback";

  @override
  void initState() {
    super.initState();
    _loadFeedbackData();
  }

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

          // Main Content
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
      title: Text(
        "Feedback",
        style: TextStyle(
          color: _whiteColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.menu, color: _whiteColor),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Menu clicked")),
            );
          },
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
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            "User Feedback",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _blackColor,
            ),
          ),
          SizedBox(height: 16),

          // Loading State
          if (_isLoading) _buildLoadingState(),

          // Empty State
          if (!_isLoading && _allFeedbacks.isEmpty) _buildEmptyState(),

          // Feedback List
          if (!_isLoading && _allFeedbacks.isNotEmpty) _buildFeedbackList(),

          // Toggle Button
          if (!_isLoading && _allFeedbacks.length > 5) _buildToggleButton(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Loading feedback...",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Text(
          "No feedback available",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildFeedbackList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _displayedFeedbacks.length,
        itemBuilder: (context, index) {
          return FeedbackItem(feedback: _displayedFeedbacks[index]);
        },
      ),
    );
  }

  Widget _buildToggleButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _toggleShowMore,
        style: ElevatedButton.styleFrom(
          backgroundColor: _purpleColor,
        ),
        child: Text(
          _showAll ? "Show Less" : "Show More",
          style: TextStyle(color: _whiteColor),
        ),
      ),
    );
  }

  // Navigation Handler
  void _handleNavigationChanged(String activityKey) {
    print("$_TAG: Navigation changed to: $activityKey");
  }

  // Data Loading Methods
  void _loadFeedbackData() {
    _setLoading(true);

    // Check if user is authenticated first
    if (_auth.currentUser == null) {
      print("$_TAG: User not authenticated");
      _setLoading(false);
      return;
    }

    // Load from Firestore
    _db.collection("feedback")
        .get()
        .then((querySnapshot) {
      _processFeedbackData(querySnapshot);
    })
        .catchError((error) {
      print("$_TAG: Firestore access failed: $error");
      _setLoading(false);
    });
  }

  void _processFeedbackData(QuerySnapshot querySnapshot) {
    _allFeedbacks.clear();

    if (querySnapshot.docs.isNotEmpty) {
      for (var document in querySnapshot.docs) {
        try {
          Feedback? feedback = _parseFeedbackDocument(document);
          if (feedback != null) {
            feedback.id = document.id;
            _allFeedbacks.add(feedback);
          }
        } catch (e) {
          print("$_TAG: Error parsing feedback document: $e");
        }
      }

      // Sort by date descending
      _allFeedbacks.sort((a, b) => b.date.compareTo(a.date));
      _updateDisplayedFeedbacks();

      _setLoading(false);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Feedback data loaded successfully")),
      );
    } else {
      // If no data in Firestore, show empty state
      print("$_TAG: No data in Firestore");
      _setLoading(false);
    }
  }

  Feedback? _parseFeedbackDocument(DocumentSnapshot document) {
    try {
      String comment = document.get("comment") ?? "";
      String dateString = document.get("date") ?? "";
      int rating = document.get("rating") ?? 0;
      String userEmail = document.get("userEmail") ?? "";
      String userId = document.get("userId") ?? "";

      // Validate required fields
      if (comment.isEmpty || dateString.isEmpty || userEmail.isEmpty) {
        print("$_TAG: Missing required fields in feedback document: ${document.id}");
        return null;
      }

      // Parse the date from ISO format
      DateTime date = _parseISODate(dateString);
      if (date == DateTime(1970)) { // Default fallback
        print("$_TAG: Invalid date format in feedback document: $dateString");
        date = DateTime.now(); // Fallback to current date
      }

      return Feedback(
        id: document.id,
        userId: userId,
        userEmail: userEmail,
        comment: comment,
        rating: rating,
        date: date,
      );

    } catch (e) {
      print("$_TAG: Error parsing feedback document: $e");
      return null;
    }
  }

  DateTime _parseISODate(String dateString) {
    try {
      // Try parsing directly
      return DateTime.parse(dateString);
    } catch (e) {
      print("$_TAG: Failed to parse date: $dateString");
      return DateTime(1970); // Return epoch as fallback
    }
  }

  void _updateDisplayedFeedbacks() {
    setState(() {
      if (_showAll) {
        _displayedFeedbacks = List.from(_allFeedbacks);
      } else {
        _displayedFeedbacks = _pickRandomFeedbacks(_allFeedbacks, 5);
      }
    });
  }

  List<Feedback> _pickRandomFeedbacks(List<Feedback> feedbacks, int count) {
    if (feedbacks.length <= count) {
      return List.from(feedbacks);
    }

    List<Feedback> randomFeedbacks = [];
    List<int> takenIndices = [];

    while (randomFeedbacks.length < count && takenIndices.length < feedbacks.length) {
      int index = DateTime.now().millisecondsSinceEpoch % feedbacks.length; // Simple pseudo-random
      if (!takenIndices.contains(index)) {
        takenIndices.add(index);
        randomFeedbacks.add(feedbacks[index]);
      }
    }

    return randomFeedbacks;
  }

  void _toggleShowMore() {
    setState(() {
      _showAll = !_showAll;
      _updateDisplayedFeedbacks();
    });

    // Scroll to top when showing all
    if (_showAll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // This would scroll the list to top, but we don't have a ScrollController in this simple implementation
        // In a real app, you might want to add a ScrollController to the ListView
      });
    }
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
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

  @override
  void dispose() {
    super.dispose();
  }
}

// Feedback Item Widget
class FeedbackItem extends StatelessWidget {
  final Feedback feedback;

  const FeedbackItem({Key? key, required this.feedback}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                _buildAvatar(),
                SizedBox(width: 20),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              feedback.userEmail,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(feedback.date),
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),

                      // Comment
                      Text(
                        feedback.comment,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF555555),
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 12),

                      // Rating
                      Text(
                        "⭐ ${feedback.rating} / 5",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2691f5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.circular(27.5),
      ),
      child: Center(
        child: Text(
          _getInitials(feedback.userEmail),
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getInitials(String email) {
    if (email.isEmpty) return "?";

    String namePart = email.split("@")[0];
    List<String> parts = namePart.split(RegExp(r'[.\-_]'));

    if (parts.isEmpty) {
      return email[0].toUpperCase();
    } else if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// Feedback Entity Class
class Feedback {
  String id;
  String userId;
  String userEmail;
  String comment;
  int rating;
  DateTime date;

  Feedback({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.comment,
    required this.rating,
    required this.date,
  });

  // Helper method to check if feedback is positive (rating >= 4)
  bool isPositive() {
    return rating >= 4;
  }

  @override
  String toString() {
    return 'Feedback{id: $id, userEmail: $userEmail, rating: $rating, date: $date}';
  }
}

// ADNavigation Widget (included in same file)
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

  String _currentActivity = "adminFeedback";

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