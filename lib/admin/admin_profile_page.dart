import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProfile extends StatefulWidget {
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final int? userCreatedAt;

  const AdminProfile({
    Key? key,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userCreatedAt,
  }) : super(key: key);

  @override
  _AdminProfileState createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _currentUser;

  // Text Editing Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // State variables
  bool _isEditMode = false;
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalBirthDate = '';
  String _originalPhoneNumber = '';

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;
  final Color _purpleLightColor = Colors.purple.shade200;
  final Color _blackColor = Colors.black;
  final Color _grayColor = Colors.grey;
  final Color _redColor = Colors.red;

  static const String _TAG = "AdminProfile";

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _initializeFirebase();
    _loadUserData();
    _recordLogin();
  }

  void _initializeFirebase() {
    print("$_TAG: Firebase initialized");
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
        "Profile",
        style: TextStyle(
          color: _whiteColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _logoutUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: _redColor,
            padding: EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(
            "Logout",
            style: TextStyle(color: _whiteColor, fontSize: 14),
          ),
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          _buildHeader(),
          SizedBox(height: 20),

          // Profile Details Card
          _buildProfileDetailsCard(),
          SizedBox(height: 30),

          // Action Buttons Card
          _buildActionButtonsCard(),
          SizedBox(height: 30),

          // Danger Zone Card
          _buildDangerZoneCard(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      "Profile Details",
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _blackColor,
      ),
    );
  }

  Widget _buildProfileDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First Name
            _buildLabel("First Name"),
            _buildEditableField(_firstNameController, "First Name"),
            SizedBox(height: 16),

            // Last Name
            _buildLabel("Last Name"),
            _buildEditableField(_lastNameController, "Last Name"),
            SizedBox(height: 16),

            // Email (Non-editable)
            _buildLabel("Email Address"),
            _buildNonEditableField(_currentUser?.email ?? "Loading..."),
            SizedBox(height: 16),

            // Birth Date
            _buildLabel("Birth Date"),
            _buildEditableField(_birthDateController, "Birth Date"),
            SizedBox(height: 16),

            // Phone Number
            _buildLabel("Phone Number"),
            _buildEditableField(_phoneController, "Phone Number", isPhone: true),
            SizedBox(height: 16),

            // User Type (Non-editable)
            _buildLabel("User Type"),
            _buildNonEditableField("Admin"),
            SizedBox(height: 16),

            // Account Created Time (Non-editable)
            _buildLabel("Account Created"),
            _buildNonEditableField("Loading...", isSmall: true),
            SizedBox(height: 16),

            // Last Login Time (Non-editable)
            _buildLabel("Last Login"),
            _buildNonEditableField("Loading...", isSmall: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _blackColor,
      ),
    );
  }

  Widget _buildEditableField(TextEditingController controller, String hint, {bool isPhone = false}) {
    return TextField(
      controller: controller,
      enabled: _isEditMode,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.all(12),
        border: OutlineInputBorder(),
        hintText: hint,
      ),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
    );
  }

  Widget _buildNonEditableField(String text, {bool isSmall = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmall ? 14 : 18,
          color: _blackColor,
        ),
      ),
    );
  }

  Widget _buildActionButtonsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Edit/Save Changes Button
            ElevatedButton(
              onPressed: _isEditMode ? _saveChanges : _enterEditMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditMode ? Colors.green : _purpleColor,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                _isEditMode ? "Save Changes" : "Edit Profile",
                style: TextStyle(color: _whiteColor, fontSize: 16),
              ),
            ),
            SizedBox(height: 12),

            // Cancel Edit Button
            if (_isEditMode)
              ElevatedButton(
                onPressed: _cancelEditMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _grayColor,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text(
                  "Cancel",
                  style: TextStyle(color: _whiteColor, fontSize: 16),
                ),
              ),
            if (_isEditMode) SizedBox(height: 12),

            // View Login History Button
            ElevatedButton(
              onPressed: _viewLoginHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purpleColor,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                "View Login History",
                style: TextStyle(color: _whiteColor, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Danger Zone",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _redColor,
              ),
            ),
            SizedBox(height: 12),

            // Delete Account Button
            ElevatedButton(
              onPressed: _showDeleteAccountConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _redColor,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                "Delete Account",
                style: TextStyle(color: _whiteColor, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation Handler
  void _handleNavigationChanged(String activityKey) {
    print("$_TAG: Navigation changed to: $activityKey");
  }

  // Edit Mode Methods
  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      // Store original values for cancel functionality
      _originalFirstName = _firstNameController.text;
      _originalLastName = _lastNameController.text;
      _originalBirthDate = _birthDateController.text;
      _originalPhoneNumber = _phoneController.text;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("You can now edit your profile information")),
    );
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
    });
  }

  void _cancelEditMode() {
    setState(() {
      // Restore original values
      _firstNameController.text = _originalFirstName;
      _lastNameController.text = _originalLastName;
      _birthDateController.text = _originalBirthDate;
      _phoneController.text = _originalPhoneNumber;
      _isEditMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Changes cancelled")),
    );
  }

  void _saveChanges() {
    String newFirstName = _firstNameController.text.trim();
    String newLastName = _lastNameController.text.trim();
    String newBirthDate = _birthDateController.text.trim();
    String newPhoneNumber = _phoneController.text.trim();

    if (_validateInputs(newFirstName, newLastName, newBirthDate, newPhoneNumber)) {
      _updateUserProfileInFirebase(newFirstName, newLastName, newBirthDate, newPhoneNumber);
    }
  }

  bool _validateInputs(String firstName, String lastName, String birthDate, String phoneNumber) {
    if (firstName.isEmpty) {
      _showError("First name cannot be empty");
      return false;
    }

    if (lastName.isEmpty) {
      _showError("Last name cannot be empty");
      return false;
    }

    if (birthDate.isEmpty) {
      _showError("Birth date cannot be empty");
      return false;
    }

    if (phoneNumber.isEmpty) {
      _showError("Phone number cannot be empty");
      return false;
    }

    // Enhanced phone number validation for 8 digits starting with 6, 8, or 9
    if (!_isValidPhoneNumber(phoneNumber)) {
      _showError("Phone number must be 8 digits starting with 6, 8, or 9");
      return false;
    }

    return true;
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    // Check if it's exactly 8 digits
    if (phoneNumber.length != 8) {
      return false;
    }

    // Check if it contains only digits using RegExp
    if (!RegExp(r'^\d+$').hasMatch(phoneNumber)) {
      return false;
    }

    // Check if it starts with 6, 8, or 9
    String firstDigit = phoneNumber[0];
    return firstDigit == '6' || firstDigit == '8' || firstDigit == '9';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _updateUserProfileInFirebase(String firstName, String lastName, String birthDate, String phoneNumber) {
    if (_currentUser != null) {
      Map<String, Object> updates = {
        "firstname": firstName,
        "lastname": lastName,
        "dob": birthDate,
        "phoneNum": phoneNumber,
      };

      _db.collection("Account").doc(_currentUser!.uid)
          .update(updates)
          .then((_) {
        print("$_TAG: Profile updated successfully for user: ${_currentUser!.uid}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile updated successfully!")),
        );

        _exitEditMode();
        _loadUserData(); // Reload data to ensure consistency
      }).catchError((error) {
        print("$_TAG: Failed to update profile: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $error")),
        );
      });
    }
  }

  // Firebase Methods
  void _loadUserData() {
    if (_currentUser != null) {
      print("$_TAG: Loading user data for: ${_currentUser!.uid}");

      // Fetch additional user data from Firestore
      DocumentReference userRef = _db.collection("Account").doc(_currentUser!.uid);
      userRef.get().then((DocumentSnapshot document) {
        if (document.exists) {
          print("$_TAG: User document found, loading data...");

          Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};

          // Retrieve all user data from Firestore with correct field names
          String firstName = data["firstname"] ?? "Not provided";
          String lastName = data["lastname"] ?? "Not provided";
          String birthDate = data["dob"] ?? "Not provided";
          String phoneNumber = data["phoneNum"] ?? "Not provided";
          String userType = data["userType"] ?? "Admin";

          // Handle timestamps
          DateTime? createdAt = _getDateFromDocument(data, "createdAt");
          DateTime? lastLogin = _getDateFromDocument(data, "lastLoginDate");

          setState(() {
            _firstNameController.text = firstName;
            _lastNameController.text = lastName;
            _birthDateController.text = birthDate.isNotEmpty ? birthDate : "Not provided";
            _phoneController.text = phoneNumber.isNotEmpty ? phoneNumber : "Not provided";
          });

          // Update timestamps display
          _setTimestampsFromFirestore(createdAt, lastLogin);

        } else {
          // Document doesn't exist in Firestore
          print("$_TAG: User document not found in Firestore");
          _setDefaultValues();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("User profile not found in database")),
          );
        }
      }).catchError((error) {
        // Firestore query failed
        print("$_TAG: Error loading user data: $error");
        _setDefaultValues();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load user data: $error")),
        );
      });
    } else {
      // No user is logged in
      print("$_TAG: No user logged in");
      _setDefaultValues();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No user logged in")),
      );
      _redirectToLogin();
    }
  }

  DateTime? _getDateFromDocument(Map<String, dynamic> data, String fieldName) {
    try {
      // Try to get as Timestamp (Firestore native type)
      if (data[fieldName] is Timestamp) {
        Timestamp timestamp = data[fieldName] as Timestamp;
        print("$_TAG: Got $fieldName as Timestamp: ${timestamp.toDate()}");
        return timestamp.toDate();
      }

      // If not found as Timestamp, try as String
      if (data[fieldName] is String) {
        String dateString = data[fieldName] as String;
        if (dateString.isNotEmpty) {
          print("$_TAG: Got $fieldName as String: $dateString");
          return _parseDateString(dateString);
        }
      }

      print("$_TAG: $fieldName not found or null in document");
      return null;

    } catch (e) {
      print("$_TAG: Error getting $fieldName from document: $e");
      return null;
    }
  }

  void _setTimestampsFromFirestore(DateTime? createdAt, DateTime? lastLogin) {
    try {
      // These would be displayed in the UI if we had the text widgets for them
      print("$_TAG: Created At: $createdAt");
      print("$_TAG: Last Login: $lastLogin");

      // In a real implementation, you would update Text widgets here
      String formattedCreatedAt = createdAt != null ? _formatDate(createdAt) : "Unknown";
      String formattedLastLogin = lastLogin != null ? _formatDate(lastLogin) : "Never logged in";

      print("$_TAG: Formatted Created At: $formattedCreatedAt");
      print("$_TAG: Formatted Last Login: $formattedLastLogin");

    } catch (e) {
      print("$_TAG: Error setting timestamps: $e");
    }
  }

  DateTime? _parseDateString(String dateString) {
    if (dateString.isEmpty) return null;

    try {
      // Try parsing ISO format
      return DateTime.parse(dateString);
    } catch (e) {
      print("$_TAG: Error parsing date string: $dateString, $e");
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day} ${_getMonthName(date.month)} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _getMonthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }

  void _setDefaultValues() {
    setState(() {
      _firstNameController.text = "Name not available";
      _lastNameController.text = "";
      _birthDateController.text = "Not provided";
      _phoneController.text = "Not provided";
    });
  }

  void _recordLogin() {
    if (_currentUser != null) {
      Map<String, Object> loginRecord = {
        "date": DateTime.now(),
        "device": "Flutter App",
        "action": "login",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };

      Map<String, Object> updates = {
        "lastLoginDate": DateTime.now(),
        "loginHistory": FieldValue.arrayUnion([loginRecord]),
      };

      _db.collection("Account").doc(_currentUser!.uid)
          .update(updates)
          .then((_) {
        print("$_TAG: Login recorded successfully in main document");
      }).catchError((error) {
        print("$_TAG: Failed to record login: $error");
      });
    }
  }

  void _viewLoginHistory() {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please log in to view login history")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Loading Login History"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Please wait while we retrieve your login history..."),
          ],
        ),
      ),
    );

    // Get login history from main document
    _db.collection("Account").doc(_currentUser!.uid)
        .get()
        .then((DocumentSnapshot document) {
      Navigator.of(context).pop(); // Close loading dialog

      if (document.exists) {
        Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};
        List<dynamic> loginHistory = data["loginHistory"] ?? [];

        if (loginHistory.isNotEmpty) {
          _showEnhancedLoginHistoryDialog(loginHistory.cast<Map<String, dynamic>>());
        } else {
          _showNoLoginHistoryDialog();
        }
      } else {
        _showNoLoginHistoryDialog();
      }
    }).catchError((error) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load login history: $error")),
      );
      print("$_TAG: Error loading login history: $error");
    });
  }

  void _showEnhancedLoginHistoryDialog(List<Map<String, dynamic>> loginHistory) {
    // Sort by timestamp descending (newest first)
    loginHistory.sort((a, b) {
      int timestampA = a["timestamp"] ?? 0;
      int timestampB = b["timestamp"] ?? 0;
      return timestampB.compareTo(timestampA);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Login History (${loginHistory.length} records)"),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: loginHistory.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> loginRecord = loginHistory[index];
              DateTime? timestamp = _getTimestampFromRecord(loginRecord);
              String deviceInfo = loginRecord["device"] ?? "Unknown device";
              String action = loginRecord["action"] ?? "login";

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) Divider(),
                  Text(
                    "${index + 1}. ${timestamp != null ? _formatDate(timestamp) : 'Unknown date'}",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text("Device: $deviceInfo | Action: $action"),
                  SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _viewLoginHistory(); // Refresh
            },
            child: Text("Refresh"),
          ),
        ],
      ),
    );
  }

  DateTime? _getTimestampFromRecord(Map<String, dynamic> loginRecord) {
    // Handle timestamp
    if (loginRecord["timestamp"] is int) {
      return DateTime.fromMillisecondsSinceEpoch(loginRecord["timestamp"]);
    }

    // Try to get date object directly
    if (loginRecord["date"] is Timestamp) {
      return (loginRecord["date"] as Timestamp).toDate();
    }

    return null;
  }

  void _showNoLoginHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Login History"),
        content: Text("No login history found.\n\nYour login activities will be recorded here when you:\n• Log into the app\n• Access your profile\n• Perform authentication-related activities"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Account"),
        content: Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteUserAccount();
            },
            child: Text("Delete", style: TextStyle(color: _redColor)),
          ),
        ],
      ),
    );
  }

  void _deleteUserAccount() {
    if (_currentUser != null) {
      _db.collection("Account").doc(_currentUser!.uid)
          .delete()
          .then((_) {
        _currentUser!.delete().then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Account deleted successfully")),
          );
          _redirectToLogin();
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete account: $error")),
          );
        });
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete user data: $error")),
        );
      });
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
    // This would navigate to your login page (Main.dart)
    // For now, we'll just print a message
    print("$_TAG: Redirecting to login page");
    // Navigator.pushAndRemoveUntil(
    //   context,
    //   MaterialPageRoute(builder: (context) => Main()),
    //   (route) => false,
    // );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    super.dispose();
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

  String _currentActivity = "adminProfile";

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