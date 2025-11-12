import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import 'admin_shell.dart';
import '../models/user_profile.dart';

class AdminReportsPage extends StatefulWidget {
  final UserProfile userProfile;
  const AdminReportsPage({Key? key, required this.userProfile})
    : super(key: key);
  @override
  _AdminReportsState createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReportsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Text Editing Controllers
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _showReportData = false;
  bool _showFilters = false;
  String _selectedUserType = "all";
  String _searchTerm = "";
  String _errorMessage = "";

  // Data
  List<Map<String, dynamic>> _reportData = [];
  List<Map<String, dynamic>> _filteredReportData = [];

  // Chart data
  int _adminCount = 0;
  int _caregiverCount = 0;
  int _elderlyCount = 0;
  int _unknownCount = 0;
  int _activeUsers = 0;
  int _inactiveUsers = 0;

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;
  final Color _blackColor = Colors.black;
  final Color _redColor = Colors.red;
  final Color _greenColor = Colors.green;
  final Color _grayColor = Colors.grey;

  // Chart colors
  final List<Color> _chartColors = [
    Color(0xFF4CAF50), // Green - Admin
    Color(0xFF2196F3), // Blue - Caregiver
    Color(0xFFFF9800), // Orange - Elderly
    Color(0xFF9C27B0), // Purple - Unknown
    Color(0xFFFF6B6B), // Red - Inactive
    Color(0xFF4ECDC4), // Green - Active
    Color(0xFF45B7D1), // Blue - Pending
  ];

  static const String _TAG = "AdminReports";

  @override
  void initState() {
    super.initState();
    _autoGenerateOverview();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentKey: 'adminReports',
      title: 'Admin Usage Report',
      profile: widget.userProfile,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      color: Color(0xFFf9fafa),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            SizedBox(height: 25),

            // Date Selection Form
            _buildDateSelectionForm(),
            SizedBox(height: 20),

            // Action Buttons
            _buildActionButtons(),
            SizedBox(height: 20),

            // Error Message
            _buildErrorMessage(),
            SizedBox(height: 16),

            // Report Data Section
            _buildReportDataSection(),

            // Loading Progress Bar
            if (_isLoading) _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      "Admin Usage Report",
      style: TextStyle(
        fontSize: 28,
        color: Color(0xFF333333),
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDateSelectionForm() {
    return Row(
      children: [
        // Start Date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Start Date:",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              TextField(
                controller: _startDateController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  filled: true,
                  fillColor: _whiteColor,
                ),
                readOnly: true,
                onTap: () => _showDatePicker(_startDateController),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),

        // End Date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "End Date:",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              TextField(
                controller: _endDateController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  filled: true,
                  fillColor: _whiteColor,
                ),
                readOnly: true,
                onTap: () => _showDatePicker(_endDateController),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _generateReportWithDates,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purpleColor,
              minimumSize: Size(double.infinity, 45),
            ),
            child: Text(
              "Generate Report",
              style: TextStyle(
                color: _whiteColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: _downloadPdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: _greenColor,
              minimumSize: Size(double.infinity, 45),
            ),
            child: Text(
              "Download PDF",
              style: TextStyle(
                color: _whiteColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage.isEmpty) return SizedBox.shrink();

    return Text(
      _errorMessage,
      style: TextStyle(
        color: _redColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildReportDataSection() {
    if (!_showReportData) return SizedBox.shrink();

    return Column(
      children: [
        // User Type Filter Buttons
        if (_showFilters) _buildFilterButtons(),
        if (_showFilters) SizedBox(height: 16),

        // Search Bar
        if (_showFilters) _buildSearchBar(),
        if (_showFilters) SizedBox(height: 16),

        // Report Summary
        _buildReportSummary(),
        SizedBox(height: 16),

        // User Type Cards Container
        _buildUserTypeCards(),
        SizedBox(height: 30),

        // User Type Distribution Chart
        _buildBarChart(),
        SizedBox(height: 20),

        // Subscriber Status Chart
        _buildPieChart(),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFilterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFilterButton("Show All", "all"),
        SizedBox(width: 4),
        _buildFilterButton("Admin", "admin"),
        SizedBox(width: 4),
        _buildFilterButton("Elderly", "elderly"),
        SizedBox(width: 4),
        _buildFilterButton("Caregiver", "caregiver"),
      ],
    );
  }

  Widget _buildFilterButton(String text, String userType) {
    bool isSelected = _selectedUserType == userType;
    return ElevatedButton(
      onPressed: () => _setUserTypeFilter(userType),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Color(0xFF7B68EE) : Color(0xFF666666),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: Size(0, 35),
      ),
      child: Text(text, style: TextStyle(color: _whiteColor, fontSize: 12)),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search by email...",
              contentPadding: EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              filled: true,
              fillColor: _whiteColor,
            ),
            onChanged: (value) {
              setState(() {
                _searchTerm = value.toLowerCase().trim();
                _filterAndDisplayReportData();
              });
            },
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: _clearSearch,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF666666),
            minimumSize: Size(45, 45),
          ),
          child: Text(
            "X",
            style: TextStyle(
              color: _whiteColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportSummary() {
    int totalUsers = _reportData.length;
    int totalLogins = _reportData.fold(
      0,
      (sum, user) => sum + (user['loginCount'] as int),
    );

    return Text(
      "Total Users: $totalUsers\nTotal Logins: $totalLogins",
      style: TextStyle(
        fontSize: 18,
        color: Color(0xFF333333),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildUserTypeCards() {
    return Column(
      children: [
        _buildUserTypeCard("Admin", "admin"),
        SizedBox(height: 16),
        _buildUserTypeCard("Elderly", "elderly"),
        SizedBox(height: 16),
        _buildUserTypeCard("Caregiver", "caregiver"),
        SizedBox(height: 16),
        _buildUserTypeCard("Unknown", "unknown"),
      ],
    );
  }

  Widget _buildUserTypeCard(String displayName, String userType) {
    List<Map<String, dynamic>> users = _filteredReportData
        .where((user) => user['userType'] == userType)
        .toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$displayName Users",
              style: TextStyle(
                fontSize: 18,
                color: _getUserTypeColor(userType),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildUserTable(users),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTable(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24),
        color: _whiteColor,
        child: Center(
          child: Text(
            "No users found",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
            label: Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              "Login Count",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              "Last Active",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: users.map((user) {
          return DataRow(
            cells: [
              DataCell(Text(user['email'] ?? "N/A")),
              DataCell(Text(user['loginCount'].toString())),
              DataCell(Text(user['lastActiveDate'] ?? "N/A")),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "User Type Distribution",
          style: TextStyle(
            fontSize: 22,
            color: Color(0xFF2d3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 300,
          padding: EdgeInsets.all(16),
          color: _whiteColor,
          child: Row(
            children: [
              // Y-axis labels
              Container(
                width: 30,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "20",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      "15",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      "10",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      "5",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      "0",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),

              // Chart bars
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar("admin", _adminCount, _chartColors[0]),
                    _buildBar("caregiver", _caregiverCount, _chartColors[1]),
                    _buildBar("elderly", _elderlyCount, _chartColors[2]),
                    _buildBar("unknown", _unknownCount, _chartColors[3]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(String label, int count, Color color) {
    int maxCount = [
      _adminCount,
      _caregiverCount,
      _elderlyCount,
      _unknownCount,
    ].reduce((a, b) => a > b ? a : b);
    double heightFactor = maxCount > 0 ? count / maxCount : 0;
    double barHeight = 200 * heightFactor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(width: 30, height: barHeight, color: color),
        SizedBox(height: 4),
        Text(
          "$label\n$count",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    int totalUsers = _activeUsers + _inactiveUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Subscriber Status",
          style: TextStyle(
            fontSize: 22,
            color: Color(0xFF2d3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 300,
          padding: EdgeInsets.all(16),
          child: totalUsers > 0
              ? _buildPieChartContent()
              : _buildPieChartPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildPieChartContent() {
    int totalUsers = _activeUsers + _inactiveUsers;
    double activePercentage = (_activeUsers / totalUsers) * 100;
    double inactivePercentage = (_inactiveUsers / totalUsers) * 100;

    return Row(
      children: [
        // Pie Chart Visualization
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(200, 200),
                painter: PieChartPainter(
                  activePercentage: activePercentage,
                  inactivePercentage: inactivePercentage,
                  activeColor: _chartColors[5],
                  inactiveColor: _chartColors[4],
                ),
              ),
              Text(
                "Total\n$totalUsers",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _whiteColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Legend
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                "Active Users",
                _activeUsers,
                activePercentage.round(),
                _chartColors[5],
              ),
              SizedBox(height: 8),
              _buildLegendItem(
                "Inactive Users",
                _inactiveUsers,
                inactivePercentage.round(),
                _chartColors[4],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartPlaceholder() {
    return Center(
      child: Text(
        "Loading pie chart...",
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    int count,
    int percentage,
    Color color,
  ) {
    return Row(
      children: [
        Container(width: 20, height: 20, color: color),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label: $count ($percentage%)",
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(child: CircularProgressIndicator());
  }

  Color _getUserTypeColor(String userType) {
    switch (userType.toLowerCase()) {
      case "admin":
        return _chartColors[0];
      case "caregiver":
        return _chartColors[1];
      case "elderly":
        return _chartColors[2];
      default:
        return _chartColors[3];
    }
  }

  // Date Picker
  void _showDatePicker(TextEditingController controller) {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    ).then((selectedDate) {
      if (selectedDate != null) {
        controller.text =
            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
      }
    });
  }

  // Report Generation
  void _autoGenerateOverview() {
    _startDateController.clear();
    _endDateController.clear();
    _generateOverview();
  }

  void _generateOverview() {
    _hideError();
    _setLoading(true);
    _fetchAllUserDataForOverview();
  }

  void _generateReportWithDates() {
    String startDate = _startDateController.text.trim();
    String endDate = _endDateController.text.trim();

    // Validation for date-based report
    if (startDate.isEmpty || endDate.isEmpty) {
      _showError("Please select both start and end date for detailed report.");
      return;
    }

    DateTime start = DateTime.parse(startDate);
    DateTime end = DateTime.parse(endDate);
    DateTime today = DateTime.now();

    if (start.isAfter(end)) {
      _showError("Start date cannot be later than end date.");
      return;
    }

    if (start.isAfter(today) || end.isAfter(today)) {
      _showError("Dates cannot be in the future.");
      return;
    }

    _hideError();
    _setLoading(true);
    _fetchReportDataWithDates(startDate, endDate);
  }

  void _fetchAllUserDataForOverview() {
    _reportData.clear();

    _db
        .collection("Account")
        .get()
        .then((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            _processUserDataForOverview(querySnapshot);
          } else {
            _showError("No user data found.");
            _setLoading(false);
          }
        })
        .catchError((error) {
          _showError("Failed to fetch user data: $error");
          _setLoading(false);
        });
  }

  void _fetchReportDataWithDates(String startDate, String endDate) {
    _reportData.clear();

    _db
        .collection("Account")
        .get()
        .then((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            _processUserDataWithDates(querySnapshot, startDate, endDate);
          } else {
            _showError("No user data found.");
            _setLoading(false);
          }
        })
        .catchError((error) {
          _showError("Failed to fetch user data: $error");
          _setLoading(false);
        });
  }

  void _processUserDataForOverview(QuerySnapshot querySnapshot) {
    _processUserData(querySnapshot, null, null, false);
  }

  void _processUserDataWithDates(
    QuerySnapshot querySnapshot,
    String startDate,
    String endDate,
  ) {
    _processUserData(querySnapshot, startDate, endDate, true);
  }

  void _processUserData(
    QuerySnapshot querySnapshot,
    String? startDate,
    String? endDate,
    bool showFilters,
  ) {
    _reportData.clear();

    for (var document in querySnapshot.docs) {
      try {
        String userId = document.id;
        String email = document.get("email") ?? "N/A";
        String userType = document.get("userType") ?? "unknown";

        // Get login logs from the document
        Map<String, dynamic> loginLogs = document.get("loginLogs") ?? {};

        int loginCount = 0;
        String lastActiveDate = "N/A";

        if (loginLogs.isNotEmpty) {
          if (startDate != null && endDate != null) {
            // Filter logs by date range for detailed report
            List<Map<String, dynamic>> filteredLogs =
                _filterLoginLogsByDateRange(loginLogs, startDate, endDate);
            loginCount = filteredLogs.length;

            // Get last active date from filtered logs
            if (filteredLogs.isNotEmpty) {
              // Sort by date to get the most recent
              filteredLogs.sort((a, b) {
                DateTime? dateA = _parseDateFromLog(a);
                DateTime? dateB = _parseDateFromLog(b);
                return dateB?.compareTo(dateA ?? DateTime.now()) ?? 0;
              });
              Map<String, dynamic> lastLog = filteredLogs.first;
              DateTime? lastActive = _parseDateFromLog(lastLog);
              if (lastActive != null) {
                lastActiveDate =
                    "${lastActive.year}-${lastActive.month.toString().padLeft(2, '0')}-${lastActive.day.toString().padLeft(2, '0')} ${lastActive.hour.toString().padLeft(2, '0')}:${lastActive.minute.toString().padLeft(2, '0')}";
              }
            } else {
              // Use last login from all logs if no logs in range
              DateTime? lastLogin = _getLastLoginFromAllLogs(loginLogs);
              if (lastLogin != null) {
                lastActiveDate =
                    "${lastLogin.year}-${lastLogin.month.toString().padLeft(2, '0')}-${lastLogin.day.toString().padLeft(2, '0')} ${lastLogin.hour.toString().padLeft(2, '0')}:${lastLogin.minute.toString().padLeft(2, '0')}";
              }
            }
          } else {
            // For overview - count ALL logins (no date filtering)
            loginCount = _getTotalLoginCount(loginLogs);

            // Get last active date from ALL logs
            DateTime? lastLogin = _getLastLoginFromAllLogs(loginLogs);
            if (lastLogin != null) {
              lastActiveDate =
                  "${lastLogin.year}-${lastLogin.month.toString().padLeft(2, '0')}-${lastLogin.day.toString().padLeft(2, '0')} ${lastLogin.hour.toString().padLeft(2, '0')}:${lastLogin.minute.toString().padLeft(2, '0')}";
            }
          }
        } else {
          // No login logs, check if there's a lastLoginDate field as fallback
          Timestamp? lastLogin = document.get("lastLoginDate");
          if (lastLogin != null) {
            DateTime lastLoginDate = lastLogin.toDate();
            lastActiveDate =
                "${lastLoginDate.year}-${lastLoginDate.month.toString().padLeft(2, '0')}-${lastLoginDate.day.toString().padLeft(2, '0')} ${lastLoginDate.hour.toString().padLeft(2, '0')}:${lastLoginDate.minute.toString().padLeft(2, '0')}";
          }
        }

        // Create report item
        Map<String, dynamic> reportItem = {
          "id": userId,
          "email": email,
          "userType": userType,
          "loginCount": loginCount,
          "lastActiveDate": lastActiveDate,
        };

        _reportData.add(reportItem);
        print(
          "$_TAG: Processed user: $email, Logins: $loginCount, Last Active: $lastActiveDate",
        );
      } catch (e) {
        print("$_TAG: Error processing user document: $e");
      }
    }

    _setLoading(false);
    if (_reportData.isEmpty) {
      _showError("No data found.");
    } else {
      if (showFilters) {
        _displayReportDataWithFilters();
      } else {
        _displayOverviewData();
      }
    }
  }

  List<Map<String, dynamic>> _filterLoginLogsByDateRange(
    Map<String, dynamic> loginLogs,
    String startDate,
    String endDate,
  ) {
    List<Map<String, dynamic>> filteredLogs = [];

    try {
      DateTime start = DateTime.parse(startDate);
      DateTime end = DateTime.parse(
        endDate,
      ).add(Duration(days: 1)); // Include end date

      // Iterate through all login logs
      for (var entry in loginLogs.entries) {
        dynamic logEntry = entry.value;
        if (logEntry is Map<String, dynamic>) {
          DateTime? logDate = _parseDateFromLog(logEntry);

          if (logDate != null &&
              !logDate.isBefore(start) &&
              logDate.isBefore(end)) {
            filteredLogs.add(logEntry);
          }
        }
      }
    } catch (e) {
      print("$_TAG: Error filtering login logs by date range: $e");
    }

    return filteredLogs;
  }

  DateTime? _parseDateFromLog(Map<String, dynamic> log) {
    try {
      dynamic dateObj = log["date"];
      if (dateObj is Timestamp) {
        return dateObj.toDate();
      } else if (dateObj is String) {
        return DateTime.parse(dateObj);
      }
    } catch (e) {
      print("$_TAG: Error parsing date from log: $e");
    }
    return null;
  }

  DateTime? _getLastLoginFromAllLogs(Map<String, dynamic> loginLogs) {
    DateTime? lastLogin;

    for (var entry in loginLogs.entries) {
      dynamic logEntry = entry.value;
      if (logEntry is Map<String, dynamic>) {
        DateTime? logDate = _parseDateFromLog(logEntry);

        if (logDate != null &&
            (lastLogin == null || logDate.isAfter(lastLogin))) {
          lastLogin = logDate;
        }
      }
    }

    return lastLogin;
  }

  int _getTotalLoginCount(Map<String, dynamic> loginLogs) {
    return loginLogs.length;
  }

  void _displayOverviewData() {
    setState(() {
      _showReportData = true;
      _showFilters = false;
      _updateChartsWithData();
      _filteredReportData = List.from(_reportData);
    });
  }

  void _displayReportDataWithFilters() {
    setState(() {
      _showReportData = true;
      _showFilters = true;
      _updateChartsWithData();
      _filterAndDisplayReportData();
    });
  }

  void _updateChartsWithData() {
    _updateBarChartWithData();
    _updatePieChartWithData();
  }

  void _updateBarChartWithData() {
    // Calculate user type distribution
    Map<String, int> userTypeCounts = {};
    for (var user in _reportData) {
      String userType = user["userType"];
      userTypeCounts[userType] = (userTypeCounts[userType] ?? 0) + 1;
    }

    setState(() {
      _adminCount = userTypeCounts["admin"] ?? 0;
      _caregiverCount = userTypeCounts["caregiver"] ?? 0;
      _elderlyCount = userTypeCounts["elderly"] ?? 0;
      _unknownCount = userTypeCounts["unknown"] ?? 0;
    });
  }

  void _updatePieChartWithData() {
    int activeUsers = 0;
    int inactiveUsers = 0;

    for (var user in _reportData) {
      int loginCount = user["loginCount"];
      if (loginCount > 0) {
        activeUsers++;
      } else {
        inactiveUsers++;
      }
    }

    setState(() {
      _activeUsers = activeUsers;
      _inactiveUsers = inactiveUsers;
    });
  }

  void _filterAndDisplayReportData() {
    _filteredReportData.clear();

    // Apply filters
    for (var user in _reportData) {
      String userType = user["userType"];
      String email = user["email"];

      // Apply user type filter
      bool typeMatches =
          _selectedUserType == "all" || _selectedUserType == userType;

      // Apply search filter
      bool searchMatches =
          _searchTerm.isEmpty || email.toLowerCase().contains(_searchTerm);

      if (typeMatches && searchMatches) {
        _filteredReportData.add(user);
      }
    }

    setState(() {});
  }

  void _setUserTypeFilter(String userType) {
    setState(() {
      _selectedUserType = userType;
    });
    _filterAndDisplayReportData();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchTerm = "";
      _filterAndDisplayReportData();
    });
  }

  // PDF Download Implementation - Fixed Version
  void _downloadPdf() async {
    if (_filteredReportData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No data to export")));
      return;
    }

    _setLoading(true);

    try {
      // Generate PDF document
      final pdf = await _generatePdfDocument();

      // Save and share the PDF
      await _saveAndSharePdf(pdf);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("PDF exported successfully")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to export PDF: $e")));
      print("$_TAG: PDF export error: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<pw.Document> _generatePdfDocument() async {
    final pdf = pw.Document();

    // Get report metadata
    String reportTitle = "Admin Usage Report";
    String generatedDate = DateTime.now().toString().split('.').first;
    String dateRange =
        _startDateController.text.isNotEmpty &&
            _endDateController.text.isNotEmpty
        ? "${_startDateController.text} to ${_endDateController.text}"
        : "All Time Overview";

    // Use simple page format to avoid font issues
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                "Generated on: $generatedDate",
                style: pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                "Date Range: $dateRange",
                style: pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Summary Statistics
              _buildPdfSummarySection(),
              pw.SizedBox(height: 20),

              // User Type Distribution
              _buildPdfUserTypeSection(),
              pw.SizedBox(height: 20),

              // Subscriber Status
              _buildPdfSubscriberSection(),
              pw.SizedBox(height: 20),

              // User Data Table
              _buildPdfUserTableSection(),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfSummarySection() {
    int totalUsers = _reportData.length;
    int totalLogins = _reportData.fold(
      0,
      (sum, user) => sum + (user['loginCount'] as int),
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Report Summary",
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildPdfSummaryRow("Total Users:", totalUsers.toString()),
          _buildPdfSummaryRow("Total Logins:", totalLogins.toString()),
          _buildPdfSummaryRow("Active Users:", _activeUsers.toString()),
          _buildPdfSummaryRow("Inactive Users:", _inactiveUsers.toString()),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 12)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfUserTypeSection() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "User Type Distribution",
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfTypeItem("Admin", _adminCount),
              _buildPdfTypeItem("Caregiver", _caregiverCount),
              _buildPdfTypeItem("Elderly", _elderlyCount),
              _buildPdfTypeItem("Unknown", _unknownCount),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTypeItem(String type, int count) {
    return pw.Column(
      children: [
        pw.Container(
          width: 30,
          height: 30,
          decoration: pw.BoxDecoration(
            color: _getPdfColor(_getUserTypeColor(type.toLowerCase())),
            borderRadius: pw.BorderRadius.circular(15),
          ),
          child: pw.Center(
            child: pw.Text(
              count.toString(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(type, style: pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildPdfSubscriberSection() {
    int totalUsers = _activeUsers + _inactiveUsers;
    double activePercentage = totalUsers > 0
        ? (_activeUsers / totalUsers) * 100
        : 0;
    double inactivePercentage = totalUsers > 0
        ? (_inactiveUsers / totalUsers) * 100
        : 0;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Subscriber Status",
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildPdfStatusItem(
            "Active Users",
            _activeUsers,
            activePercentage,
            PdfColors.green,
          ),
          pw.SizedBox(height: 4),
          _buildPdfStatusItem(
            "Inactive Users",
            _inactiveUsers,
            inactivePercentage,
            PdfColors.red,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStatusItem(
    String label,
    int count,
    double percentage,
    PdfColor color,
  ) {
    return pw.Row(
      children: [
        pw.Container(width: 10, height: 10, color: color),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            "$label: $count (${percentage.toStringAsFixed(1)}%)",
            style: pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfUserTableSection() {
    if (_filteredReportData.isEmpty) {
      return pw.Text(
        "No user data available",
        style: pw.TextStyle(fontSize: 12),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "User Details (${_filteredReportData.length} users)",
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        // Simple table without complex formatting
        pw.Column(
          children: [
            // Table header
            pw.Container(
              color: PdfColors.grey200,
              padding: pw.EdgeInsets.all(4),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      "Email",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      "Type",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      "Logins",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      "Last Active",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Table rows
            ..._filteredReportData
                .map(
                  (user) => pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300),
                      ),
                    ),
                    padding: pw.EdgeInsets.all(4),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            user['email'] ?? "N/A",
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            _capitalize(user['userType']),
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            user['loginCount'].toString(),
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            user['lastActiveDate'] ?? "N/A",
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ],
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  PdfColor _getPdfColor(Color color) {
    return PdfColor.fromInt(color.value);
  }

  Future<void> _saveAndSharePdf(pw.Document pdf) async {
    try {
      final bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'admin_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      print("Error sharing PDF: $e");
      // Fallback: Save to temporary directory
      final output = await getTemporaryDirectory();
      final file = File(
        "${output.path}/admin_report_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("PDF saved to device storage")));
    }
  }

  void _logoutUser() {
    _auth.signOut();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Logged out successfully")));
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

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  void _hideError() {
    setState(() {
      _errorMessage = "";
    });
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// Pie Chart Painter
class PieChartPainter extends CustomPainter {
  final double activePercentage;
  final double inactivePercentage;
  final Color activeColor;
  final Color inactiveColor;

  PieChartPainter({
    required this.activePercentage,
    required this.inactivePercentage,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw active slice
    paint.color = activeColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180), // Start from top
      (activePercentage / 100) * 2 * 3.14159,
      true,
      paint,
    );

    // Draw inactive slice
    paint.color = inactiveColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180) + (activePercentage / 100) * 2 * 3.14159,
      (inactivePercentage / 100) * 2 * 3.14159,
      true,
      paint,
    );

    // Draw border
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
