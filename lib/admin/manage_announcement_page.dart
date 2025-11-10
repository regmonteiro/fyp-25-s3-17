import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAnnouncement extends StatefulWidget {
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final int? userCreatedAt;

  const AdminAnnouncement({
    Key? key,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userCreatedAt,
  }) : super(key: key);

  @override
  _AdminAnnouncementState createState() => _AdminAnnouncementState();
}

class _AdminAnnouncementState extends State<AdminAnnouncement> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Checkbox states
  bool _elderlyChecked = false;
  bool _caregiverChecked = false;
  bool _adminChecked = false;

  // State variables
  bool _isLoading = false;
  bool _isFormVisible = false;
  String _successMessage = '';
  String _errorMessage = '';

  // Announcements list
  List<Announcement> _announcementsList = [];

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;
  final Color _redColor = Colors.red;
  final Color _greenColor = Colors.green;
  final Color _blueColor = Color(0xFF003366);
  final Color _lightBlueColor = Color(0xFFe6f0fa);
  final Color _buttonBlueColor = Color(0xFF4a90e2);
  final Color _darkBlueColor = Color(0xFF004080);

  static const String _TAG = "AdminAnnouncement";

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBlueColor,
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
              "System Announcements",
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _whiteColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Title
            _buildTitle(),
            SizedBox(height: 24),

            // New Announcement Button
            _buildToggleFormButton(),
            SizedBox(height: 20),

            // Form Section
            if (_isFormVisible) _buildFormSection(),

            // Loading Progress
            if (_isLoading) _buildLoadingIndicator(),

            // Success Message
            if (_successMessage.isNotEmpty) _buildSuccessMessage(),

            // Error Message
            if (_errorMessage.isNotEmpty) _buildErrorMessage(),

            // Previous Announcements Section
            _buildPreviousAnnouncementsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      "System Announcements",
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: _blueColor,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildToggleFormButton() {
    return ElevatedButton(
      onPressed: _toggleFormVisibility,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFormVisible ? _redColor : _buttonBlueColor,
        foregroundColor: _whiteColor,
        elevation: 4,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(_isFormVisible ? "Cancel" : "New Announcement"),
    );
  }

  Widget _buildFormSection() {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // Title Input
          _buildTitleInput(),
          SizedBox(height: 16),

          // Description Input
          _buildDescriptionInput(),
          SizedBox(height: 16),

          // User Groups Section
          _buildUserGroupsSection(),
          SizedBox(height: 16),

          // Submit Button
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return TextField(
      controller: _titleController,
      decoration: InputDecoration(
        hintText: "Title",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _blueColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _blueColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _blueColor),
        ),
        hintStyle: TextStyle(color: _blueColor),
        contentPadding: EdgeInsets.all(16),
      ),
      style: TextStyle(fontSize: 16),
    );
  }

  Widget _buildDescriptionInput() {
    return Container(
      height: 120,
      child: TextField(
        controller: _descriptionController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: "Description",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _blueColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _blueColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _blueColor),
          ),
          hintStyle: TextStyle(color: _blueColor),
          contentPadding: EdgeInsets.all(16),
        ),
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildUserGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Send To User Groups",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _darkBlueColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFf7faff),
          ),
          child: Column(
            children: [
              _buildCheckbox(
                value: _elderlyChecked,
                onChanged: (value) => setState(() => _elderlyChecked = value!),
                label: "Elderly",
              ),
              SizedBox(height: 8),
              _buildCheckbox(
                value: _caregiverChecked,
                onChanged: (value) => setState(() => _caregiverChecked = value!),
                label: "Caregiver",
              ),
              SizedBox(height: 8),
              _buildCheckbox(
                value: _adminChecked,
                onChanged: (value) => setState(() => _adminChecked = value!),
                label: "Admin",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: _blueColor,
        ),
        Text(
          label,
          style: TextStyle(
            color: _blueColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSubmitAnnouncement,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF007acc),
        foregroundColor: _whiteColor,
        elevation: 4,
        minimumSize: Size(double.infinity, 50),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(_isLoading ? "Sending..." : "Send Announcement"),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildSuccessMessage() {
    return Text(
      _successMessage,
      style: TextStyle(
        color: _greenColor,
        fontSize: 16,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildErrorMessage() {
    return Text(
      _errorMessage,
      style: TextStyle(
        color: _redColor,
        fontSize: 16,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPreviousAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _announcementsList.isEmpty
              ? "Previous Announcements"
              : "Previous Announcements (${_announcementsList.length})",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _darkBlueColor,
          ),
        ),
        SizedBox(height: 16),

        // No Data Message
        if (_announcementsList.isEmpty)
          Text(
            "No announcements found. Create your first announcement above.",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

        // Announcements List
        if (_announcementsList.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _announcementsList.length,
            itemBuilder: (context, index) {
              return _buildAnnouncementItem(_announcementsList[index]);
            },
          ),
      ],
    );
  }

  Widget _buildAnnouncementItem(Announcement announcement) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFdbe9ff),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and time
          Row(
            children: [
              Expanded(
                flex: 7,
                child: Text(
                  announcement.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkBlueColor,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _formatDate(announcement.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF336699),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Description
          Text(
            announcement.description,
            style: TextStyle(
              fontSize: 16,
              color: _blueColor,
            ),
          ),
          SizedBox(height: 10),

          // Footer with user groups and created by
          Text(
            _buildFooterText(announcement),
            style: TextStyle(
              fontSize: 14,
              color: _blueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _buildFooterText(Announcement announcement) {
    StringBuffer footer = StringBuffer();

    // Add user groups
    if (announcement.userGroups.isNotEmpty) {
      footer.write("To: ");
      for (int i = 0; i < announcement.userGroups.length; i++) {
        if (i > 0) footer.write(", ");
        footer.write(_capitalizeFirstLetter(announcement.userGroups[i]));
      }
    }

    // Add created by
    if (announcement.createdBy.isNotEmpty) {
      if (footer.isNotEmpty) footer.write(" | ");
      footer.write("By: ${announcement.createdBy.replaceAll('_', '.')}");
    }

    // Add read count
    if (footer.isNotEmpty) footer.write(" | ");
    footer.write("Read by: ${announcement.readBy.length}");

    return footer.toString();
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatDate(DateTime date) {
    return "${_padZero(date.day)} ${_getMonthName(date.month)} ${date.year}, ${_padZero(date.hour)}:${_padZero(date.minute)}";
  }

  String _padZero(int number) {
    return number.toString().padLeft(2, '0');
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  // Navigation Handler
  void _handleNavigationChanged(String activityKey) {
    print("$_TAG: Navigation changed to: $activityKey");
  }

  // Form Visibility Toggle
  void _toggleFormVisibility() {
    setState(() {
      _isFormVisible = !_isFormVisible;
      if (!_isFormVisible) {
        _clearForm();
        _hideMessages();
      }
    });
  }

  // Form Submission
  void _handleSubmitAnnouncement() {
    String title = _titleController.text.trim();
    String description = _descriptionController.text.trim();

    // Clear previous messages
    _hideMessages();

    // Validation
    if (title.isEmpty) {
      _showError("Please fill in the title.");
      return;
    }

    if (description.isEmpty) {
      _showError("Please fill in the description.");
      return;
    }

    // Get selected user groups
    List<String> userGroups = _getSelectedUserGroups();
    if (userGroups.isEmpty) {
      _showError("Please select at least one user group.");
      return;
    }

    // Create announcement
    _createAnnouncement(title, description, userGroups);
  }

  List<String> _getSelectedUserGroups() {
    List<String> selectedGroups = [];
    if (_elderlyChecked) selectedGroups.add("elderly");
    if (_caregiverChecked) selectedGroups.add("caregiver");
    if (_adminChecked) selectedGroups.add("admin");
    return selectedGroups;
  }

  void _createAnnouncement(String title, String description, List<String> userGroups) {
    _setLoading(true);

    // Get current user email for createdBy field
    String currentUserEmail = "admin";
    if (_auth.currentUser != null && _auth.currentUser!.email != null) {
      currentUserEmail = _auth.currentUser!.email!.replaceAll(".", "_");
    }

    // Get current timestamp
    DateTime currentTime = DateTime.now();

    // Create empty readBy map
    Map<String, bool> readBy = {};

    // Create announcement data
    Map<String, dynamic> announcement = {
      "title": title,
      "description": description,
      "userGroups": userGroups,
      "createdBy": currentUserEmail,
      "createdAt": currentTime.toIso8601String(),
      "readBy": readBy,
    };

    // Save to Firestore
    _db.collection("Announcements")
        .add(announcement)
        .then((documentReference) {
      _setLoading(false);
      _showSuccess("Announcement sent successfully!");
      _clearForm();
      _toggleFormVisibility();
      _loadAnnouncements(); // Reload the list
      print("$_TAG: Announcement created with ID: ${documentReference.id}");
    })
        .catchError((error) {
      _setLoading(false);
      _showError("Failed to send announcement: $error");
      print("$_TAG: Error creating announcement: $error");
    });
  }

  void _loadAnnouncements() {
    _setLoading(true);

    _db.collection("Announcements")
        .orderBy("createdAt", descending: true)
        .get()
        .then((querySnapshot) {
      _setLoading(false);
      List<Announcement> loadedAnnouncements = [];

      if (querySnapshot.docs.isNotEmpty) {
        for (var document in querySnapshot.docs) {
          try {
            Announcement? announcement = _parseAnnouncementDocument(document);
            if (announcement != null) {
              announcement.id = document.id;
              loadedAnnouncements.add(announcement);
              print("$_TAG: Successfully loaded announcement: ${announcement.title}");
            }
          } catch (e) {
            print("$_TAG: Error parsing announcement document: $e");
          }
        }
      }

      setState(() {
        _announcementsList = loadedAnnouncements;
      });

      print("$_TAG: Loaded ${loadedAnnouncements.length} announcements");
    })
        .catchError((error) {
      _setLoading(false);
      _showError("Failed to load announcements: $error");
      print("$_TAG: Error loading announcements: $error");

      // Even if there's an error, update UI to show empty state
      setState(() {
        _announcementsList = [];
      });
    });
  }

  Announcement? _parseAnnouncementDocument(DocumentSnapshot document) {
    try {
      final data = document.data() as Map<String, dynamic>?;
      if (data == null) return null;

      String title = data["title"] ?? "";
      String description = data["description"] ?? "";
      String createdBy = data["createdBy"] ?? "admin";
      String createdAt = data["createdAt"] ?? "";

      // Get userGroups array
      List<String> userGroups = (data["userGroups"] as List<dynamic>?)?.cast<String>() ?? [];
      // Get readBy map
      Map<String, bool> readBy = (data["readBy"] as Map<String, dynamic>?)?.map((key, value) => MapEntry(key, value as bool)) ?? {};

      // Validate required fields
      if (title.isEmpty || description.isEmpty) {
        print("$_TAG: Missing required fields in announcement document: ${document.id}");
        return null;
      }

      // Parse date
      DateTime createdAtDate;
      try {
        createdAtDate = DateTime.parse(createdAt);
      } catch (e) {
        print("$_TAG: Failed to parse date: $createdAt, using current date");
        createdAtDate = DateTime.now();
      }

      return Announcement(
        title: title,
        description: description,
        createdBy: createdBy,
        createdAt: createdAtDate,
        userGroups: userGroups,
        readBy: readBy,
      );

    } catch (e) {
      print("$_TAG: Error parsing announcement document: $e");
      return null;
    }
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  void _showSuccess(String message) {
    setState(() {
      _successMessage = message;
      _errorMessage = '';
    });
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = '';
    });
  }

  void _hideMessages() {
    setState(() {
      _successMessage = '';
      _errorMessage = '';
    });
  }

  void _clearForm() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _elderlyChecked = false;
      _caregiverChecked = false;
      _adminChecked = false;
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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Announcement Model Class
class Announcement {
  String id;
  String title;
  String description;
  String createdBy;
  DateTime createdAt;
  List<String> userGroups;
  Map<String, bool> readBy;

  Announcement({
    this.id = '',
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.userGroups,
    required this.readBy,
  });
}

// ADNavigation Widget (same as previous implementation)
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

  String _currentActivity = "adminAnnouncement";

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