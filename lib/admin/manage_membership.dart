// lib/admin/admin_manage_membership_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_shell.dart';
import '../models/user_profile.dart';
import 'admin_routes.dart' show navigateAdmin;

class AdminManageMembershipPage extends StatefulWidget {
  final UserProfile userProfile;
  const AdminManageMembershipPage({Key? key, required this.userProfile})
    : super(key: key);

  @override
  _AdminManageMembershipPageState createState() =>
      _AdminManageMembershipPageState();
}

class _AdminManageMembershipPageState extends State<AdminManageMembershipPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = false;
  String _searchQuery = '';
  List<MembershipPlan> _allPlans = [];
  List<MembershipPlan> _filteredPlans = [];
  MembershipPlan? _editingPlan;

  // Form data
  final TextEditingController _searchController = TextEditingController();

  // Colors
  final Color _backgroundColor = const Color(0xFFf5f5f5);
  final Color _whiteColor = Colors.white;
  final Color _darkGrayColor = const Color(0xFF666666);
  final Color _purpleColor = Colors.purple.shade500;
  final Color _redColor = Colors.red;
  final Color _blueColor = Colors.blue;
  final Color _greenColor = Colors.green;
  final Color _orangeColor = Colors.orange;
  final Color _lightGrayColor = const Color(0xFFE0E0E0);
  final Color _cyanColor = const Color(0xFF00BCD4);
  final Color _pinkColor = const Color(0xFFE91E63);
  final Color _skyColor = const Color(0xFF03A9F4);

  static const String _TAG = "AdminManageMembership";
  static const String _COLLECTION_MEMBERSHIPS = "membershipPlans";

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      profile: widget.userProfile,
      currentKey: 'adminManageMembership',
      title: 'Membership Plans',
      body: _buildBody(),
      floatingActionButton: _buildAddButton(),
      showBackButton: true,
      onBackPressed: () =>
          navigateAdmin(context, 'adminDashboard', widget.userProfile),
      showDashboardButton: true,
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Header Section (search)
        _buildHeaderSection(),

        // Loading State
        if (_isLoading)
          Expanded(child: _buildLoadingState())
        else
          // Empty or Plans Grid/List
          Expanded(
            child: _filteredPlans.isEmpty
                ? _buildEmptyState()
                : _buildPlansLayout(),
          ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        _getResponsiveValue(mobile: 16, tablet: 20, desktop: 24),
      ),
      color: _whiteColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Create, edit, and manage membership plans for AllCare Platform",
            style: TextStyle(
              color: _darkGrayColor,
              fontSize: _getResponsiveValue(
                mobile: 12,
                tablet: 14,
                desktop: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: _getResponsiveValue(
                    mobile: 44,
                    tablet: 48,
                    desktop: 52,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search membership plans...",
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _getResponsiveValue(
                          mobile: 12,
                          tablet: 16,
                          desktop: 20,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterPlans();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            "Loading membership plans...",
            style: TextStyle(
              fontSize: _getResponsiveValue(
                mobile: 14,
                tablet: 16,
                desktop: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          _getResponsiveValue(mobile: 24, tablet: 32, desktop: 40),
        ),
        child: Text(
          _searchQuery.isEmpty
              ? "No membership plans found. Create your first plan to get started."
              : 'No plans found matching "$_searchQuery"',
          style: TextStyle(
            fontSize: _getResponsiveValue(mobile: 14, tablet: 16, desktop: 18),
            color: _darkGrayColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPlansLayout() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      // Mobile - List view
      return _buildPlansList();
    } else if (screenWidth < 1200) {
      // Tablet - Grid with 2 columns
      return _buildPlansGrid(crossAxisCount: 2);
    } else {
      // Desktop - Grid with 3 columns
      return _buildPlansGrid(crossAxisCount: 3);
    }
  }

  Widget _buildPlansList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredPlans.length,
      itemBuilder: (context, index) =>
          _buildPlanListItem(_filteredPlans[index]),
    );
  }

  Widget _buildPlanListItem(MembershipPlan plan) {
    Color cardColor = _getColorForScheme(plan.colorScheme);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            _getResponsiveValue(mobile: 16, tablet: 20, desktop: 24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: TextStyle(
                            fontSize: _getResponsiveValue(
                              mobile: 18,
                              tablet: 20,
                              desktop: 22,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          plan.subtitle,
                          style: TextStyle(
                            fontSize: _getResponsiveValue(
                              mobile: 12,
                              tablet: 14,
                              desktop: 16,
                            ),
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badges
                  Row(
                    children: [
                      if (plan.popular) _buildBadge("Popular", _orangeColor),
                      if (plan.trial) _buildBadge("Trial", _greenColor),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Pricing
              Row(
                children: [
                  Text(
                    "\$${plan.price}",
                    style: TextStyle(
                      fontSize: _getResponsiveValue(
                        mobile: 24,
                        tablet: 28,
                        desktop: 32,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "per ${plan.period}",
                    style: TextStyle(
                      fontSize: _getResponsiveValue(
                        mobile: 12,
                        tablet: 14,
                        desktop: 16,
                      ),
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Features
              Text(
                "Features:",
                style: TextStyle(
                  fontSize: _getResponsiveValue(
                    mobile: 14,
                    tablet: 16,
                    desktop: 18,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: plan.features.take(3).map((feature) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      "• $feature",
                      style: TextStyle(
                        fontSize: _getResponsiveValue(
                          mobile: 12,
                          tablet: 14,
                          desktop: 16,
                        ),
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
              if (plan.features.length > 3)
                Text(
                  "+ ${plan.features.length - 3} more features",
                  style: TextStyle(
                    fontSize: _getResponsiveValue(
                      mobile: 10,
                      tablet: 12,
                      desktop: 14,
                    ),
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),

              SizedBox(height: 16),
              Container(
                height: 1,
                color: _lightGrayColor,
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),

              // Last Updated
              Text(
                "Last updated: ${_formatDate(plan.lastUpdatedAt)}",
                style: TextStyle(
                  fontSize: _getResponsiveValue(
                    mobile: 10,
                    tablet: 11,
                    desktop: 12,
                  ),
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _editPlan(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purpleColor,
                        foregroundColor: _whiteColor,
                        padding: EdgeInsets.symmetric(
                          vertical: _getResponsiveValue(
                            mobile: 8,
                            tablet: 12,
                            desktop: 16,
                          ),
                        ),
                      ),
                      child: Text(
                        "Edit",
                        style: TextStyle(
                          fontSize: _getResponsiveValue(
                            mobile: 12,
                            tablet: 14,
                            desktop: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _deletePlan(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _redColor,
                        foregroundColor: _whiteColor,
                        padding: EdgeInsets.symmetric(
                          vertical: _getResponsiveValue(
                            mobile: 8,
                            tablet: 12,
                            desktop: 16,
                          ),
                        ),
                      ),
                      child: Text(
                        "Delete",
                        style: TextStyle(
                          fontSize: _getResponsiveValue(
                            mobile: 12,
                            tablet: 14,
                            desktop: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlansGrid({required int crossAxisCount}) {
    return GridView.builder(
      padding: EdgeInsets.all(
        _getResponsiveValue(mobile: 8, tablet: 12, desktop: 16),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: _getResponsiveValue(
          mobile: 8,
          tablet: 12,
          desktop: 16,
        ),
        mainAxisSpacing: _getResponsiveValue(
          mobile: 8,
          tablet: 12,
          desktop: 16,
        ),
        childAspectRatio: _getResponsiveValue(
          mobile: 0.8,
          tablet: 0.85,
          desktop: 0.9,
        ),
      ),
      itemCount: _filteredPlans.length,
      itemBuilder: (_, i) => _buildPlanCard(_filteredPlans[i]),
    );
  }

  Widget _buildPlanCard(MembershipPlan plan) {
    Color cardColor = _getColorForScheme(plan.colorScheme);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            _getResponsiveValue(mobile: 12, tablet: 16, desktop: 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: TextStyle(
                            fontSize: _getResponsiveValue(
                              mobile: 16,
                              tablet: 18,
                              desktop: 20,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          plan.subtitle,
                          style: TextStyle(
                            fontSize: _getResponsiveValue(
                              mobile: 10,
                              tablet: 12,
                              desktop: 14,
                            ),
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Badges
                  Column(
                    children: [
                      if (plan.popular)
                        _buildSmallBadge("Popular", _orangeColor),
                      if (plan.trial) _buildSmallBadge("Trial", _greenColor),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Pricing
              Row(
                children: [
                  Text(
                    "\$${plan.price}",
                    style: TextStyle(
                      fontSize: _getResponsiveValue(
                        mobile: 20,
                        tablet: 24,
                        desktop: 28,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    "/${plan.period}",
                    style: TextStyle(
                      fontSize: _getResponsiveValue(
                        mobile: 10,
                        tablet: 12,
                        desktop: 14,
                      ),
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Features
              Text(
                "Features:",
                style: TextStyle(
                  fontSize: _getResponsiveValue(
                    mobile: 12,
                    tablet: 14,
                    desktop: 16,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: plan.features.take(2).map((feature) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        "• $feature",
                        style: TextStyle(
                          fontSize: _getResponsiveValue(
                            mobile: 10,
                            tablet: 11,
                            desktop: 12,
                          ),
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (plan.features.length > 2)
                Text(
                  "+ ${plan.features.length - 2} more",
                  style: TextStyle(
                    fontSize: _getResponsiveValue(
                      mobile: 9,
                      tablet: 10,
                      desktop: 11,
                    ),
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),

              SizedBox(height: 12),
              Container(
                height: 1,
                color: _lightGrayColor,
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),

              // Last Updated
              Text(
                "Updated: ${_formatDateShort(plan.lastUpdatedAt)}",
                style: TextStyle(
                  fontSize: _getResponsiveValue(
                    mobile: 8,
                    tablet: 9,
                    desktop: 10,
                  ),
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 12),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _editPlan(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purpleColor,
                        foregroundColor: _whiteColor,
                        padding: EdgeInsets.symmetric(
                          vertical: _getResponsiveValue(
                            mobile: 6,
                            tablet: 8,
                            desktop: 10,
                          ),
                        ),
                      ),
                      child: Text(
                        "Edit",
                        style: TextStyle(
                          fontSize: _getResponsiveValue(
                            mobile: 10,
                            tablet: 12,
                            desktop: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _getResponsiveValue(
                      mobile: 4,
                      tablet: 6,
                      desktop: 8,
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _deletePlan(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _redColor,
                        foregroundColor: _whiteColor,
                        padding: EdgeInsets.symmetric(
                          vertical: _getResponsiveValue(
                            mobile: 6,
                            tablet: 8,
                            desktop: 10,
                          ),
                        ),
                      ),
                      child: Text(
                        "Delete",
                        style: TextStyle(
                          fontSize: _getResponsiveValue(
                            mobile: 10,
                            tablet: 12,
                            desktop: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: EdgeInsets.only(left: 8),
      padding: EdgeInsets.symmetric(
        horizontal: _getResponsiveValue(mobile: 8, tablet: 12, desktop: 16),
        vertical: _getResponsiveValue(mobile: 4, tablet: 6, desktop: 8),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _whiteColor,
          fontSize: _getResponsiveValue(mobile: 10, tablet: 11, desktop: 12),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(
        horizontal: _getResponsiveValue(mobile: 6, tablet: 8, desktop: 10),
        vertical: _getResponsiveValue(mobile: 2, tablet: 3, desktop: 4),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _whiteColor,
          fontSize: _getResponsiveValue(mobile: 8, tablet: 9, desktop: 10),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAddButton() => FloatingActionButton(
    onPressed: _createPlan,
    backgroundColor: _purpleColor,
    foregroundColor: _whiteColor,
    child: const Icon(Icons.add),
  );

  // Helper method to get responsive values
  double _getResponsiveValue({
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return mobile;
    } else if (screenWidth < 1200) {
      return tablet;
    } else {
      return desktop;
    }
  }

  // Data methods
  void _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _db.collection(_COLLECTION_MEMBERSHIPS).get();
      final list = <MembershipPlan>[];
      for (final d in snap.docs) {
        try {
          list.add(MembershipPlan.fromDocument(d));
        } catch (e) {
          print("$_TAG: Error parsing document ${d.id}: $e");
        }
      }
      setState(() {
        _allPlans = list;
        _filterPlans();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load membership plans: $e')),
      );
    }
  }

  void _filterPlans() {
    final q = _searchQuery.toLowerCase().trim();
    _filteredPlans = q.isEmpty
        ? List.of(_allPlans)
        : _allPlans.where((p) {
            bool contains(String? s) => (s ?? '').toLowerCase().contains(q);
            return contains(p.title) ||
                contains(p.subtitle) ||
                contains(p.period) ||
                p.features.any((f) => f.toLowerCase().contains(q));
          }).toList();
    _filteredPlans.sort((a, b) => a.title.compareTo(b.title));
    setState(() {});
  }

  void _createPlan() {
    _editingPlan = null;
    _showPlanForm();
  }

  void _editPlan(MembershipPlan p) {
    _editingPlan = p;
    _showPlanForm();
  }

  void _showPlanForm() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MembershipPlanFormDialog(
        plan: _editingPlan,
        onSubmit: _submitPlanForm,
      ),
    ).then((_) {
      // Reset editing plan when dialog is closed
      _editingPlan = null;
    });
  }

  void _submitPlanForm(
    String title,
    String subtitle,
    String price,
    String period,
    String colorScheme,
    bool popular,
    bool trial,
    List<String> features,
  ) async {
    setState(() => _isLoading = true);

    final data = {
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'period': period,
      'popular': popular,
      'trial': trial,
      'features': features,
      'colorScheme': colorScheme,
      'lastUpdatedAt': DateTime.now().toIso8601String(),
      'createdBy': _auth.currentUser?.email ?? 'admin',
    };

    try {
      if (_editingPlan != null) {
        // Update existing plan
        await _db
            .collection(_COLLECTION_MEMBERSHIPS)
            .doc(_editingPlan!.id)
            .update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership plan updated successfully')),
        );
      } else {
        // Create new plan
        data['createdAt'] = DateTime.now().toIso8601String();
        await _db.collection(_COLLECTION_MEMBERSHIPS).add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership plan created successfully')),
        );
      }
      _loadPlans();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save membership plan: $e')),
      );
    }
  }

  void _deletePlan(MembershipPlan p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Membership Plan'),
        content: const Text(
          'Are you sure you want to delete this membership plan? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeletePlan(p.id);
            },
            child: Text('Delete', style: TextStyle(color: _redColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeletePlan(String planId) async {
    setState(() => _isLoading = true);
    try {
      await _db.collection(_COLLECTION_MEMBERSHIPS).doc(planId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership plan deleted successfully')),
      );
      _loadPlans();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete membership plan: $e')),
      );
    }
  }

  Color _getColorForScheme(String scheme) {
    switch (scheme.toLowerCase()) {
      case "blue":
        return _blueColor;
      case "sky":
        return _skyColor;
      case "cyan":
        return _cyanColor;
      case "green":
        return _greenColor;
      case "purple":
        return _purpleColor;
      case "pink":
        return _pinkColor;
      case "orange":
        return _orangeColor;
      case "teal":
        return Colors.teal;
      default:
        return _blueColor;
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${_getMonthName(date.month)} ${date.day}, ${date.year} at ${_formatTime(date.hour, date.minute)}";
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateShort(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${_getMonthName(date.month)} ${date.day}, ${date.year}";
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(int hour, int minute) {
    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    return "$displayHour:${minute.toString().padLeft(2, '0')} $period";
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// MembershipPlan Model
class MembershipPlan {
  String id;
  String title;
  String subtitle;
  String price;
  String period;
  bool popular;
  bool trial;
  List<String> features;
  String colorScheme;
  String createdAt;
  String lastUpdatedAt;

  MembershipPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.period,
    required this.popular,
    required this.trial,
    required this.features,
    required this.colorScheme,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory MembershipPlan.fromDocument(DocumentSnapshot document) {
    // Handle price field - it can be string or number
    dynamic priceObj = document.get('price');
    String price;
    if (priceObj is String) {
      price = priceObj;
    } else if (priceObj is num) {
      price = priceObj.toString();
    } else {
      price = "0";
    }

    // Handle features array
    dynamic featuresObj = document.get('features');
    List<String> features;
    if (featuresObj is List) {
      features = List<String>.from(featuresObj);
    } else {
      features = [];
    }

    return MembershipPlan(
      id: document.id,
      title: document.get('title') ?? 'No Title',
      subtitle: document.get('subtitle') ?? 'No Subtitle',
      price: price,
      period: document.get('period') ?? 'month',
      popular: document.get('popular') ?? false,
      trial: document.get('trial') ?? false,
      features: features,
      colorScheme: document.get('colorScheme') ?? 'blue',
      createdAt: document.get('createdAt') ?? DateTime.now().toIso8601String(),
      lastUpdatedAt:
          document.get('lastUpdatedAt') ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'period': period,
      'popular': popular,
      'trial': trial,
      'features': features,
      'colorScheme': colorScheme,
      'createdAt': createdAt,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }
}

// Membership Plan Form Dialog
class MembershipPlanFormDialog extends StatefulWidget {
  final MembershipPlan? plan;
  final Function(
    String title,
    String subtitle,
    String price,
    String period,
    String colorScheme,
    bool popular,
    bool trial,
    List<String> features,
  )
  onSubmit;

  const MembershipPlanFormDialog({Key? key, this.plan, required this.onSubmit})
    : super(key: key);

  @override
  _MembershipPlanFormDialogState createState() =>
      _MembershipPlanFormDialogState();
}

class _MembershipPlanFormDialogState extends State<MembershipPlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedPeriod = "month";
  String _selectedColorScheme = "Blue";
  bool _popularChecked = false;
  bool _trialChecked = false;
  List<TextEditingController> _featureControllers = [];

  final List<String> _periods = ["15 days", "month", "year", "3 years"];

  // FIXED: Ensure all color scheme values are unique
  final List<String> _colorSchemes = [
    "Blue",
    "Sky",
    "Cyan",
    "Green",
    "Purple",
    "Pink",
    "Orange",
    "Teal",
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final p = widget.plan;
    if (p != null) {
      _titleController.text = p.title;
      _subtitleController.text = p.subtitle;
      _priceController.text = p.price;
      _selectedPeriod = p.period;

      // FIXED: Handle case where saved color scheme might not be in the list
      if (_colorSchemes.contains(p.colorScheme)) {
        _selectedColorScheme = p.colorScheme;
      } else {
        _selectedColorScheme = "Blue"; // Default fallback
      }

      _popularChecked = p.popular;
      _trialChecked = p.trial;

      // Clear any existing controllers
      for (final controller in _featureControllers) {
        controller.dispose();
      }
      _featureControllers.clear();

      // Add controllers for existing features
      for (final feature in p.features) {
        _featureControllers.add(TextEditingController(text: feature));
      }
    }

    // Ensure at least one feature field exists
    if (_featureControllers.isEmpty) {
      _featureControllers.add(TextEditingController());
    }
  }

  double _getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return screenWidth * 0.95;
    } else if (screenWidth < 1200) {
      return 600;
    } else {
      return 700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Form(
        key: _formKey,
        child: Container(
          padding: EdgeInsets.all(_getResponsivePadding()),
          width: _getDialogWidth(context),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.plan != null
                      ? "Edit Membership Plan"
                      : "Create New Membership Plan",
                  style: TextStyle(
                    fontSize: _getResponsiveValue(
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                _buildFormField(
                  label: "Plan Title *",
                  controller: _titleController,
                  hintText: "e.g., Monthly Care Plan",
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Plan title is required'
                      : null,
                  maxLines: 1,
                ),

                // Subtitle
                _buildFormField(
                  label: "Subtitle *",
                  controller: _subtitleController,
                  hintText: "e.g., Perfect for getting started",
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Subtitle is required' : null,
                  maxLines: 2,
                ),

                // Price and Period row
                _buildPricePeriodRow(),

                // Color Scheme
                _buildDropdown(
                  "Color Scheme",
                  _colorSchemes,
                  _selectedColorScheme,
                  (v) => setState(() => _selectedColorScheme = v!),
                ),

                // Checkboxes
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: Text("Mark as Popular"),
                        value: _popularChecked,
                        onChanged: (v) =>
                            setState(() => _popularChecked = v ?? false),
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: Text("Is Trial Plan"),
                        value: _trialChecked,
                        onChanged: (v) =>
                            setState(() => _trialChecked = v ?? false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Features
                const Text(
                  "Features *",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._featureControllers.asMap().entries.map((e) {
                  final i = e.key;
                  final c = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: c,
                            decoration: const InputDecoration(
                              hintText: "Enter feature description",
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (_featureControllers.length == 1 &&
                                  (value == null || value.isEmpty)) {
                                return 'At least one feature is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              if (_featureControllers.length > 1) {
                                _featureControllers.removeAt(i);
                              } else {
                                c.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
                ElevatedButton.icon(
                  onPressed: () => setState(
                    () => _featureControllers.add(TextEditingController()),
                  ),
                  icon: Icon(Icons.add),
                  label: Text("Add Feature"),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        child: Text(
                          widget.plan != null ? "Update Plan" : "Create Plan",
                          style: TextStyle(
                            fontSize: _getResponsiveValue(
                              mobile: 14,
                              tablet: 16,
                              desktop: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _getResponsiveValue(mobile: 14, tablet: 16, desktop: 16),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPricePeriodRow() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      // Mobile - vertical layout
      return Column(
        children: [
          _buildFormField(
            label: "Price *",
            controller: _priceController,
            hintText: "e.g., 90",
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Price is required';
              }
              if (double.tryParse(v) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
            maxLines: 1,
          ),
          _buildDropdown(
            "Billing Period *",
            _periods,
            _selectedPeriod,
            (v) => setState(() => _selectedPeriod = v!),
          ),
        ],
      );
    } else {
      // Tablet/Desktop - horizontal layout
      return Row(
        children: [
          Expanded(
            child: _buildFormField(
              label: "Price *",
              controller: _priceController,
              hintText: "e.g., 90",
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Price is required';
                }
                if (double.tryParse(v) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDropdown(
              "Billing Period *",
              _periods,
              _selectedPeriod,
              (v) => setState(() => _selectedPeriod = v!),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildDropdown(
    String label,
    List<String> options,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    // FIXED: Add validation to ensure the current value exists in options
    String currentValue = value;
    if (!options.contains(value)) {
      currentValue = options.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _getResponsiveValue(mobile: 14, tablet: 16, desktop: 16),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: currentValue, // Use the validated current value
          items: options
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          validator: (value) => value == null ? 'Please select a period' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  double _getResponsiveValue({
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return mobile;
    } else if (screenWidth < 1200) {
      return tablet;
    } else {
      return desktop;
    }
  }

  double _getResponsivePadding() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return 16;
    } else if (screenWidth < 1200) {
      return 20;
    } else {
      return 24;
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final features = <String>[];
      for (final c in _featureControllers) {
        final f = c.text.trim();
        if (f.isNotEmpty) features.add(f);
      }

      if (features.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one feature')),
        );
        return;
      }

      widget.onSubmit(
        _titleController.text.trim(),
        _subtitleController.text.trim(),
        _priceController.text.trim(),
        _selectedPeriod,
        _selectedColorScheme,
        _popularChecked,
        _trialChecked,
        features,
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _priceController.dispose();
    for (final c in _featureControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
