// lib/admin/admin_manage_service_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_shell.dart';
import '../models/user_profile.dart';
import 'admin_routes.dart' show navigateAdmin;

class AdminManageServicePage extends StatefulWidget {
  final UserProfile userProfile;
  const AdminManageServicePage({Key? key, required this.userProfile})
    : super(key: key);

  @override
  State<AdminManageServicePage> createState() => _AdminManageServicePageState();
}

class _AdminManageServicePageState extends State<AdminManageServicePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = false;
  String _searchQuery = '';
  List<ServiceItem> _allServices = [];
  List<ServiceItem> _filteredServices = [];
  ServiceItem? _editingService;

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

  static const String _TAG = "AdminManageServices";
  static const String _COLLECTION_SERVICES = "Services";

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      profile: widget.userProfile,
      currentKey: 'adminManageService',
      title: 'Services',
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
          // Empty or Services Grid/List
          Expanded(
            child: _filteredServices.isEmpty
                ? _buildEmptyState()
                : _buildServicesLayout(),
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
            "Create, edit, and manage AllCare Platform services",
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
                      hintText: "Search services...",
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
                        _filterServices();
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
            "Loading services...",
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
              ? "No services found. Create your first service to get started."
              : 'No services found matching "$_searchQuery"',
          style: TextStyle(
            fontSize: _getResponsiveValue(mobile: 14, tablet: 16, desktop: 18),
            color: _darkGrayColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildServicesLayout() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      // Mobile - List view
      return _buildServicesList();
    } else if (screenWidth < 1200) {
      // Tablet - Grid with 2 columns
      return _buildServicesGrid(crossAxisCount: 2);
    } else {
      // Desktop - Grid with 3 columns
      return _buildServicesGrid(crossAxisCount: 3);
    }
  }

  Widget _buildServicesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredServices.length,
      itemBuilder: (context, index) =>
          _buildServiceListItem(_filteredServices[index]),
    );
  }

  Widget _buildServiceListItem(ServiceItem service) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(
          _getResponsiveValue(mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              service.title,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              service.description,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 14,
                  tablet: 16,
                  desktop: 18,
                ),
                color: _darkGrayColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Details
            if (service.details.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Details:",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.details,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF444444),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              height: 1,
              color: _lightGrayColor,
              margin: const EdgeInsets.symmetric(vertical: 12),
            ),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editService(service),
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
                    onPressed: () => _deleteService(service),
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
    );
  }

  Widget _buildServicesGrid({required int crossAxisCount}) {
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
          mobile: 0.75,
          tablet: 0.8,
          desktop: 0.85,
        ),
      ),
      itemCount: _filteredServices.length,
      itemBuilder: (_, i) => _buildServiceCard(_filteredServices[i]),
    );
  }

  Widget _buildServiceCard(ServiceItem service) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(
          _getResponsiveValue(mobile: 12, tablet: 16, desktop: 20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              service.title,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              service.description,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                ),
                color: _darkGrayColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Details
            if (service.details.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Details:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.details,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF444444),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Spacer(),
            Container(
              height: 1,
              color: _lightGrayColor,
              margin: const EdgeInsets.symmetric(vertical: 12),
            ),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editService(service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purpleColor,
                      foregroundColor: _whiteColor,
                      padding: EdgeInsets.symmetric(
                        vertical: _getResponsiveValue(
                          mobile: 8,
                          tablet: 10,
                          desktop: 12,
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
                SizedBox(
                  width: _getResponsiveValue(mobile: 6, tablet: 8, desktop: 12),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteService(service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redColor,
                      foregroundColor: _whiteColor,
                      padding: EdgeInsets.symmetric(
                        vertical: _getResponsiveValue(
                          mobile: 8,
                          tablet: 10,
                          desktop: 12,
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
    );
  }

  Widget _buildAddButton() => FloatingActionButton(
    onPressed: _createService,
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
  void _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _db.collection(_COLLECTION_SERVICES).get();
      final list = <ServiceItem>[];
      for (final d in snap.docs) {
        try {
          list.add(ServiceItem.fromDocument(d));
        } catch (e) {
          // ignore malformed docs
        }
      }
      setState(() {
        _allServices = list;
        _filterServices();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load services: $e')));
    }
  }

  void _filterServices() {
    final q = _searchQuery.toLowerCase().trim();
    _filteredServices = q.isEmpty
        ? List.of(_allServices)
        : _allServices.where((s) {
            bool contains(String? text) =>
                (text ?? '').toLowerCase().contains(q);
            return contains(s.title) ||
                contains(s.description) ||
                contains(s.details);
          }).toList();
    _filteredServices.sort((a, b) => a.title.compareTo(b.title));
    setState(() {});
  }

  void _createService() {
    _editingService = null;
    _showServiceForm();
  }

  void _editService(ServiceItem s) {
    _editingService = s;
    _showServiceForm();
  }

  void _showServiceForm() {
    showDialog(
      context: context,
      builder: (_) => ServiceFormDialog(
        service: _editingService,
        onSubmit: _submitServiceForm,
      ),
    );
  }

  void _submitServiceForm(
    String title,
    String description,
    String details,
  ) async {
    setState(() => _isLoading = true);

    final data = {
      'title': title,
      'description': description,
      'details': details,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': _auth.currentUser?.email ?? 'admin',
    };

    try {
      if (_editingService != null) {
        await _db
            .collection(_COLLECTION_SERVICES)
            .doc(_editingService!.id)
            .set(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service updated successfully')),
        );
      } else {
        await _db.collection(_COLLECTION_SERVICES).add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service created successfully')),
        );
      }
      _loadServices();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save service: $e')));
    }
  }

  void _deleteService(ServiceItem s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Are you sure you want to delete "${s.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteService(s.id);
            },
            child: Text('Delete', style: TextStyle(color: _redColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteService(String serviceId) async {
    setState(() => _isLoading = true);
    try {
      await _db.collection(_COLLECTION_SERVICES).doc(serviceId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service deleted successfully')),
      );
      _loadServices();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete service: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Service model
class ServiceItem {
  String id;
  String title;
  String description;
  String details;

  ServiceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.details,
  });

  factory ServiceItem.fromDocument(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>? ?? {};
    return ServiceItem(
      id: document.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      details: data['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'details': details,
  };
}

// Service Form Dialog
class ServiceFormDialog extends StatefulWidget {
  final ServiceItem? service;
  final Function(String title, String description, String details) onSubmit;

  const ServiceFormDialog({Key? key, this.service, required this.onSubmit})
    : super(key: key);

  @override
  _ServiceFormDialogState createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    if (s != null) {
      _titleController.text = s.title;
      _descriptionController.text = s.description;
      _detailsController.text = s.details;
    }
  }

  double _getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return screenWidth * 0.95;
    } else if (screenWidth < 1200) {
      return 500;
    } else {
      return 600;
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
              children: [
                Text(
                  widget.service != null
                      ? "Edit Service"
                      : "Create New Service",
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
                  label: "Title *",
                  controller: _titleController,
                  hintText: "Service Title *",
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Service title is required'
                      : null,
                  maxLines: 1,
                ),

                // Description
                _buildFormField(
                  label: "Description *",
                  controller: _descriptionController,
                  hintText: "Description *",
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Description is required'
                      : null,
                  maxLines: 2,
                ),

                // Details
                _buildFormField(
                  label: "Details",
                  controller: _detailsController,
                  hintText: "Full Details",
                  maxLines: 4,
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
                          widget.service != null
                              ? "Update Service"
                              : "Create Service",
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
      widget.onSubmit(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _detailsController.text.trim(),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _detailsController.dispose();
    super.dispose();
  }
}
