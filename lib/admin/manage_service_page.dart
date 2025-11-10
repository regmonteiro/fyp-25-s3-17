import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


import '../models/user_profile.dart';
import '../admin/admin_shell.dart';
import '../admin/admin_routes.dart' show navigateAdmin;

class AdminManageService extends StatefulWidget {
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final int? userCreatedAt;

  const AdminManageService({
    Key? key,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userCreatedAt,
  }) : super(key: key);

  @override
  State<AdminManageService> createState() => _AdminManageServiceState();
}

class _AdminManageServiceState extends State<AdminManageService> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // UI + state
  bool _isLoading = false;
  bool _showError = false;
  String _errorMessage = '';
  List<ServiceItem> _services = [];

  // Colors
  final Color _whiteColor = Colors.white;
  final Color _blackColor = Colors.black;
  final Color _darkerGrayColor = Colors.grey.shade700;
  final Color _blueColor = const Color(0xFF2196F3);
  final Color _errorBackgroundColor = const Color(0xFFFFEBEE);
  final Color _errorTextColor = const Color(0xFFD32F2F);

  static const String _COLLECTION_SERVICES = "Services";

  // Build a UserProfile for AdminShell
  UserProfile get _profile => UserProfile(
        uid: '',
        email: widget.userEmail ?? '',
        firstname: widget.userFirstName ?? '',
        lastname: widget.userLastName ?? '',
      );

  @override
  void initState() {
    super.initState();
    _loadServicesFromFirebase();
  }

  @override
  Widget build(BuildContext context) {
    // AdminShell renders the admin header + navigation
    return AdminShell(
      title: 'Manage Services',
      currentKey: 'adminManageService', // ensure this key exists in kAdminPages if you navigate to it
      profile: _profile,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications clicked')),
          ),
        ),
        TextButton(
          onPressed: _logoutUser,
          child: const Text('Logout', style: TextStyle(color: Colors.white)),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Text(
              "Manage Services",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _blackColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create, edit, and manage AllCare Platform services",
              style: TextStyle(
                fontSize: 16,
                color: _darkerGrayColor,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showServiceForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blueColor,
                foregroundColor: _whiteColor,
                padding: const EdgeInsets.all(12),
              ),
              child: const Text("+ Add New Service"),
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_showError) _buildErrorMessage(),
            if (_showError) const SizedBox(height: 16),

            // Loading Indicator
            if (_isLoading) const Center(child: CircularProgressIndicator()),

            // Services List or Empty State
            Expanded(
              child: _services.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : _buildServicesList(),
            ),
          ],
        ),
      ),
    );
  }

  // ——— UI helpers ———

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _errorBackgroundColor),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(color: _errorTextColor, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () => setState(() => _showError = false),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final darker = _darkerGrayColor;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.report_problem, size: 64, color: darker),
          const SizedBox(height: 16),
          Text(
            "No services found. Create your first service to get started.",
            style: TextStyle(fontSize: 16, color: darker),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    return ListView.builder(
      itemCount: _services.length,
      itemBuilder: (context, index) {
        return ServiceCard(
          service: _services[index],
          onEdit: _editService,
          onDelete: _deleteService,
        );
      },
    );
  }

  // ——— CRUD ———

  void _loadServicesFromFirebase() {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _showError = false;
    });

    _db.collection(_COLLECTION_SERVICES).get().then((querySnapshot) {
      setState(() {
        _isLoading = false;
        _services = querySnapshot.docs.map((d) => ServiceItem.fromDocument(d)).toList();
      });
    }).catchError((error) {
      setState(() => _isLoading = false);
      _displayError("Failed to load services: $error");
    });
  }

  void _showServiceForm([ServiceItem? service]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildServiceForm(service),
    );
  }

  Widget _buildServiceForm(ServiceItem? service) {
    final titleController = TextEditingController(text: service?.title ?? '');
    final descController = TextEditingController(text: service?.description ?? '');
    final detailsController = TextEditingController(text: service?.details ?? '');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(service != null ? "Edit Service" : "Add New Service",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          TextField(
            controller: titleController,
            decoration: const InputDecoration(hintText: "Service Title", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: descController,
            decoration: const InputDecoration(hintText: "Description", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: detailsController,
            decoration: const InputDecoration(hintText: "Details", border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              _saveService(
                service,
                titleController.text.trim(),
                descController.text.trim(),
                detailsController.text.trim(),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(service != null ? "Update Service" : "Create Service"),
          ),
        ],
      ),
    );
  }

  void _saveService(ServiceItem? service, String title, String description, String details) {
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a service title")),
      );
      return;
    }

    if (service == null) {
      final newService = ServiceItem(id: '', title: title, description: description, details: details);
      _db.collection(_COLLECTION_SERVICES).add(newService.toMap()).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Service created successfully")));
        _loadServicesFromFirebase();
      }).catchError((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error creating service")));
      });
    } else {
      service
        ..title = title
        ..description = description
        ..details = details;

      _db.collection(_COLLECTION_SERVICES).doc(service.id).set(service.toMap()).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Service updated successfully")));
        _loadServicesFromFirebase();
      }).catchError((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating service")));
      });
    }
  }

  void _editService(ServiceItem service) => _showServiceForm(service);

  void _deleteService(ServiceItem service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Service"),
        content: Text('Are you sure you want to delete "${service.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteService(service);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _performDeleteService(ServiceItem service) {
    _db.collection(_COLLECTION_SERVICES).doc(service.id).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Service deleted successfully")));
      _loadServicesFromFirebase();
    }).catchError((_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting service")));
    });
  }

  void _displayError(String error) {
    setState(() {
      _errorMessage = error;
      _showError = true;
    });
  }

  void _logoutUser() {
    _auth.signOut();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out successfully")));
    // Navigate somewhere safe after logout (adjust destination as needed)
    navigateAdmin(context, 'adminDashboard', _profile);
  }
}

// ——— Model ———
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

// ——— UI: Service Card ———
class ServiceCard extends StatelessWidget {
  final ServiceItem service;
  final void Function(ServiceItem) onEdit;
  final void Function(ServiceItem) onDelete;

  const ServiceCard({
    Key? key,
    required this.service,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color titleTextColor = Color(0xFF333333);
    const Color descriptionTextColor = Color(0xFF666666);
    const Color detailsTextColor = Color(0xFF444444);
    const Color idTextColor = Color(0xFF888888);
    const Color detailsBackgroundColor = Color(0xFFF8F9FA);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: titleTextColor,
                    ),
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => onEdit(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text("Edit"),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: () => onDelete(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              ],
            ),

            // Description
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                service.description,
                style: const TextStyle(fontSize: 16, color: descriptionTextColor),
              ),
            ),

            // Details
            if (service.details.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: detailsBackgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Full Details:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.details,
                      style: const TextStyle(fontSize: 14, color: detailsTextColor, height: 1.4),
                    ),
                  ],
                ),
              ),

            // ID
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                "ID: ${service.id}",
                style: const TextStyle(fontSize: 12, color: idTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
