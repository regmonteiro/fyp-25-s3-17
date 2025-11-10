import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final int? userCreatedAt;

  const AdminDashboard({
    Key? key,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userCreatedAt,
  }) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  List<User> _userList = [];
  List<User> _filteredUserList = [];
  Map<String, bool> _actionLoadingMap = {};
  Map<String, String> _userDobMap = {};

  static const String _TAG = "AdminDashboard";

  @override
  void initState() {
    super.initState();
    _getUserDataFromConstructor();
    _initializeFirebase();
    _fetchUsersFromFirebase();
  }

  void _getUserDataFromConstructor() {
    print("$_TAG: User data from constructor:");
    print("$_TAG: Email: ${widget.userEmail}");
    print("$_TAG: First Name: ${widget.userFirstName}");
    print("$_TAG: Last Name: ${widget.userLastName}");
    print("$_TAG: Created At: ${widget.userCreatedAt}");
  }

  void _initializeFirebase() {
    print("$_TAG: Firebase initialized");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // App Bar
          _buildAppBar(),

          // AD Navigation Toolbar
          ADNavigation(
            onNavigationChanged: _handleNavigationChanged,
          ),

          // Dashboard Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildDashboardContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.purple.shade500,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            // Menu Icon
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Menu clicked")),
                );
              },
            ),

            Expanded(
              child: Text(
                "Dashboard",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Notifications Icon
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Notifications clicked")),
                );
              },
            ),

            // Logout Button
            ElevatedButton(
              onPressed: _logoutUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Text(
                "Logout",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildHeaderSection(),

          SizedBox(height: 16),

          // Search Section
          _buildSearchSection(),

          SizedBox(height: 16),

          // Users Table
          _buildUsersTable(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Registered Users",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search users...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade500),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade500),
              ),
              hintStyle: TextStyle(color: Colors.purple.shade200),
            ),
            onChanged: (value) {
              _performSearch(value);
            },
          ),
        ),

        SizedBox(width: 8),

        ElevatedButton(
          onPressed: () {
            _performSearch(_searchController.text);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade500,
            padding: EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(
            "Search",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2.0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header
            _buildTableHeader(),

            // Table Rows
            _buildTableRows(),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.purple.shade200,
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          _buildHeaderCell("First Name", 120),
          _buildHeaderCell("Last Name", 120),
          _buildHeaderCell("Email", 200),
          _buildHeaderCell("User Type", 120),
          _buildHeaderCell("Phone", 150),
          _buildHeaderCell("Date of Birth", 120),
          _buildHeaderCell("Created At", 150),
          _buildHeaderCell("Last Login", 180),
          _buildHeaderCell("Status", 100),
          _buildHeaderCell("Actions", 120),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.purple.shade500,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTableRows() {
    if (_filteredUserList.isEmpty) {
      return Container(
        padding: EdgeInsets.all(50),
        child: Text(
          "No registered users found.",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      children: _filteredUserList.map((user) => _buildUserTableRow(user)).toList(),
    );
  }

  Widget _buildUserTableRow(User user) {
    bool isActive = user.status?.toLowerCase() == "active";

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
      ),
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          _buildTableCell(user.firstName ?? "Not provided", 120),
          _buildTableCell(user.lastName ?? "Not provided", 120),
          _buildEmailCell(user.email ?? "Not provided", 200),
          _buildUserTypeBadge(user.userType ?? "Not specified", 120),
          _buildTableCell(user.phone ?? "Not provided", 150),
          _buildTableCell(_getDobForUser(user.userId ?? ""), 120),
          _buildDateCell(_getCreatedAtFormatted(user), 150),
          _buildDateCell(_getLastLoginFormatted(user), 180),
          _buildStatusCell(user.status ?? "Active", 100),
          _buildActionCell(user, isActive, 120),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildEmailCell(String email, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      child: Text(
        email,
        style: TextStyle(
          color: Color(0xFF005f73),
          fontSize: 12,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildUserTypeBadge(String userType, double width) {
    Color backgroundColor;
    Color textColor;

    switch (userType.toLowerCase()) {
      case "admin":
        backgroundColor = Color(0xFFf28482);
        textColor = Color(0xFF4a2c2a);
        break;
      case "caregiver":
        backgroundColor = Color(0xFF82c0cc);
        textColor = Color(0xFF1e3d47);
        break;
      case "elderly":
        backgroundColor = Color(0xFFf7ede2);
        textColor = Color(0xFF5f4b3e);
        break;
      default:
        backgroundColor = Color(0xFFccc5b9);
        textColor = Color(0xFF6e6b5a);
        break;
    }

    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _capitalizeFirstLetter(userType),
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDateCell(String dateString, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      child: Text(
        dateString,
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusCell(String status, double width) {
    Color textColor = (status.toLowerCase() == "inactive" || status.toLowerCase() == "deactivated")
        ? Color(0xFFd9534f)
        : Color(0xFF3c763d);

    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionCell(User user, bool isActive, double width) {
    bool isLoading = _actionLoadingMap[user.userId ?? ""] == true;

    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _toggleUserStatus(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Color(0xFFd9534f) : Color(0xFF5cb85c),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size(0, 0),
        ),
        child: isLoading
            ? Text("Processing...", style: TextStyle(fontSize: 10, color: Colors.white))
            : Text(
          isActive ? "Deactivate" : "Activate",
          style: TextStyle(fontSize: 10, color: Colors.white),
        ),
      ),
    );
  }

  // Navigation Handler
  void _handleNavigationChanged(String activityKey) {
    print("$_TAG: Navigation changed to: $activityKey");
    // Navigation logic would be handled by parent widget or Navigator
  }

  // Firebase Methods
  void _fetchUsersFromFirebase() {
    print("$_TAG: Fetching users from Firebase with real-time listener...");

    _db.collection("Account").snapshots().listen((querySnapshot) {
      try {
        _userList.clear();
        _userDobMap.clear();

        if (querySnapshot.docs.isNotEmpty) {
          for (var document in querySnapshot.docs) {
            try {
              User user = _createUserFromDocument(document);
              if (user.userType?.toLowerCase() != "unknown") {
                _userList.add(user);
              }
            } catch (e) {
              print("$_TAG: Error parsing user document: $e");
            }
          }
          print("$_TAG: Successfully fetched ${_userList.length} users");
        } else {
          print("$_TAG: No users found in database");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No users found in database")),
          );
        }

        _performSearch(_searchController.text);

      } catch (e) {
        print("$_TAG: Exception in fetchUsersFromFirebase: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading users from database")),
        );
      }
    }, onError: (error) {
      print("$_TAG: Error fetching users: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load users: $error")),
      );
    });
  }

  User _createUserFromDocument(DocumentSnapshot document) {
    User user = User();
    user.userId = document.id;

    print("$_TAG: === Document ID: ${document.id} ===");
    print("$_TAG: Full document data: ${document.data()}");

    Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};

    user.firstName = data["firstname"] ?? "Not provided";
    user.lastName = data["lastname"] ?? "Not provided";
    user.email = data["email"] ?? "Not provided";
    user.userType = data["userType"] ?? "Not specified";
    user.phone = data["phoneNum"] ?? "Not provided";
    user.status = data["status"] ?? "Active";

    String dateOfBirth = data["dob"] ?? "";
    if (dateOfBirth.isNotEmpty) {
      _userDobMap[document.id] = dateOfBirth;
      print("$_TAG: Stored DOB in map for user ${document.id}: $dateOfBirth");
    }

    // Handle timestamps
    String createdAtString = data["createdAt"] ?? "";
    String lastLoginString = data["lastLoginDate"] ?? "";

    user.createdAt = _parseDateString(createdAtString) ?? DateTime.now();
    user.lastLogin = _parseDateString(lastLoginString) ?? user.createdAt;

    if (user.userType!.isEmpty) {
      user.userType = "unknown";
    }

    print("$_TAG: Created user: ${user.firstName} ${user.lastName} | Type: ${user.userType} | Status: ${user.status}");

    return user;
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

  String _getDobForUser(String userId) {
    if (userId.isNotEmpty && _userDobMap.containsKey(userId)) {
      String dob = _userDobMap[userId]!;
      print("$_TAG: Retrieved DOB for user $userId: $dob");
      return dob;
    }
    print("$_TAG: No DOB found for user $userId");
    return "Not provided";
  }

  String _getLastLoginFormatted(User user) {
    try {
      DateTime? lastLogin = user.lastLogin;
      print("$_TAG: getLastLoginFormatted - Input lastLogin: $lastLogin");

      if (lastLogin != null) {
        String formatted = "${lastLogin.day} ${_getMonthName(lastLogin.month)} ${lastLogin.year}, ${lastLogin.hour.toString().padLeft(2, '0')}:${lastLogin.minute.toString().padLeft(2, '0')}";
        print("$_TAG: Formatted lastLogin: $formatted");
        return formatted;
      } else {
        print("$_TAG: lastLogin is null");
      }
    } catch (e) {
      print("$_TAG: Error getting last login: $e");
    }
    return "Never logged in";
  }

  String _getCreatedAtFormatted(User user) {
    try {
      DateTime? createdAt = user.createdAt;
      print("$_TAG: getCreatedAtFormatted - Input createdAt: $createdAt");

      if (createdAt != null) {
        String formatted = "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";
        print("$_TAG: Formatted createdAt: $formatted");
        return formatted;
      } else {
        print("$_TAG: createdAt is null");
      }
    } catch (e) {
      print("$_TAG: Error getting created at: $e");
    }
    return "N/A";
  }

  String _getMonthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }

  void _performSearch(String searchTerm) {
    if (searchTerm.isEmpty) {
      setState(() {
        _filteredUserList = List.from(_userList);
      });
    } else {
      String lowercasedTerm = searchTerm.toLowerCase().trim();
      setState(() {
        _filteredUserList = _userList.where((user) {
          return (user.firstName?.toLowerCase().contains(lowercasedTerm) == true) ||
              (user.lastName?.toLowerCase().contains(lowercasedTerm) == true) ||
              (user.email?.toLowerCase().contains(lowercasedTerm) == true) ||
              (user.userType?.toLowerCase().contains(lowercasedTerm) == true) ||
              (user.phone?.toLowerCase().contains(lowercasedTerm) == true) ||
              (user.status?.toLowerCase().contains(lowercasedTerm) == true) ||
              (_getDobForUser(user.userId ?? "").toLowerCase().contains(lowercasedTerm));
        }).toList();
      });
    }
  }

  void _toggleUserStatus(User user) {
    String currentStatus = user.status ?? "Active";
    String action = currentStatus.toLowerCase() == "active" ? "deactivate" : "activate";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm"),
          content: Text("Are you sure you want to $action the account for ${user.email}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processUserStatusChange(user, currentStatus, action);
              },
              child: Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  void _processUserStatusChange(User user, String currentStatus, String action) {
    setState(() {
      _actionLoadingMap[user.userId ?? ""] = true;
    });

    String newStatus = currentStatus.toLowerCase() == "active" ? "Inactive" : "Active";

    _db.collection("Account").doc(user.userId).update({"status": newStatus}).then((_) {
      setState(() {
        _actionLoadingMap[user.userId ?? ""] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account for ${user.email} has been ${newStatus.toLowerCase()}.")),
      );
    }).catchError((error) {
      setState(() {
        _actionLoadingMap[user.userId ?? ""] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to $action the account. Please try again.")),
      );
    });
  }

  void _logoutUser() {
    try {
      _auth.signOut();
      // Navigation would be handled by parent
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logged out successfully")),
      );
    } catch (e) {
      print("$_TAG: Error during logout: $e");
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  String _currentActivity = "adminDashboard";

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

// User class with same methods as Java version
class User {
  String? userId;
  String? firstName;
  String? lastName;
  String? email;
  String? userType;
  String? phone;
  DateTime? createdAt;
  DateTime? lastLogin;
  String? status;

  // Getters and setters to match Java class methods
  String? getUserId() => userId;
  void setUserId(String value) => userId = value;

  String? getFirstName() => firstName;
  void setFirstName(String value) => firstName = value;

  String? getLastName() => lastName;
  void setLastName(String value) => lastName = value;

  String? getEmail() => email;
  void setEmail(String value) => email = value;

  String? getUserType() => userType;
  void setUserType(String value) => userType = value;

  String? getPhone() => phone;
  void setPhone(String value) => phone = value;

  DateTime? getCreatedAt() => createdAt;
  void setCreatedAt(DateTime value) => createdAt = value;

  DateTime? getLastLogin() => lastLogin;
  void setLastLogin(DateTime value) => lastLogin = value;

  String? getStatus() => status;
  void setStatus(String value) => status = value;
}