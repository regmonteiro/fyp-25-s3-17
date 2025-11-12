import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'admin_routes.dart';

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

  bool _isLoading = false;
  String _searchQuery = '';
  List<ServiceItem> _allServices = [];
  List<ServiceItem> _filteredServices = [];
  final TextEditingController _searchController = TextEditingController();

  static const String _COLLECTION_SERVICES = "Services";

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  void _navigateToDashboard() {
    // Use your existing navigation function
    navigateAdmin(context, 'adminDashboard', widget.userProfile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Services'),
        backgroundColor: Colors.purple.shade500,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _navigateToDashboard, // Use the navigation function
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.dashboard),
            onPressed: _navigateToDashboard, // Use the navigation function
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createService,
        backgroundColor: Colors.purple.shade500,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ... rest of your existing methods (_buildBody, _loadServices, etc.) remain the same
  Widget _buildBody() {
    return Column(
      children: [
        // Header Section
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Create, edit, and manage AllCare Platform services",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search services...",
                  border: OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _filterServices();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _filterServices();
                  });
                },
              ),
            ],
          ),
        ),

        // Content
        if (_isLoading)
          Expanded(child: _buildLoadingState())
        else
          Expanded(
            child: _filteredServices.isEmpty
                ? _buildEmptyState()
                : _buildServicesList(),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Loading services..."),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? "No services found. Create your first service!"
                  : 'No services found matching "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (_searchQuery.isEmpty) ...[
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade500,
                  foregroundColor: Colors.white,
                ),
                child: Text("Create First Service"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServicesList() {
    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: _filteredServices.length,
      itemBuilder: (context, index) =>
          _buildServiceItem(_filteredServices[index]),
    );
  }

  Widget _buildServiceItem(ServiceItem service) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              service.description,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (service.details.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                service.details,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editService(service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade500,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Edit"),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteService(service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Delete"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Data methods
  void _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final querySnapshot = await _db.collection(_COLLECTION_SERVICES).get();
      List<ServiceItem> services = [];

      for (final doc in querySnapshot.docs) {
        services.add(ServiceItem.fromDocument(doc));
      }

      if (services.isEmpty) {
        await _createDefaultServices();
        _loadServices();
        return;
      }

      setState(() {
        _allServices = services;
        _filterServices();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _createDefaultServices() async {
    try {
      final servicesData = {
        "service1": {
          "title": "Personal AI Assistant",
          "description": "Guidance, habit reminders, and smart suggestions.",
          "details": "AI assistance for older adults.",
          "category": "AI Assistance",
          "price": 0.0,
          "duration": "24/7",
          "isActive": true,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
          "createdBy": _auth.currentUser?.email ?? 'admin',
        },
      };

      final batch = _db.batch();
      servicesData.forEach((id, data) {
        batch.set(_db.collection(_COLLECTION_SERVICES).doc(id), data);
      });
      await batch.commit();
    } catch (e) {
      print('Error creating services: $e');
      rethrow;
    }
  }

  void _filterServices() {
    final q = _searchQuery.toLowerCase().trim();
    _filteredServices = q.isEmpty
        ? List.of(_allServices)
        : _allServices
              .where(
                (s) =>
                    s.title.toLowerCase().contains(q) ||
                    s.description.toLowerCase().contains(q),
              )
              .toList();
    setState(() {});
  }

  void _createService() {
    _showServiceForm(null);
  }

  void _editService(ServiceItem service) {
    _showServiceForm(service);
  }

  void _showServiceForm(ServiceItem? service) {
    showDialog(
      context: context,
      builder: (_) => ServiceFormDialog(
        service: service,
        onSubmit: (title, description, details) async {
          if (title.isEmpty || description.isEmpty) return;

          setState(() => _isLoading = true);
          final data = {
            'title': title,
            'description': description,
            'details': details,
            'category': 'General',
            'price': 0.0,
            'duration': 'Flexible',
            'updatedAt': FieldValue.serverTimestamp(),
            'createdBy': _auth.currentUser?.email ?? 'admin',
            'isActive': true,
          };

          try {
            if (service != null) {
              await _db
                  .collection(_COLLECTION_SERVICES)
                  .doc(service.id)
                  .update(data);
            } else {
              data['createdAt'] = FieldValue.serverTimestamp();
              await _db.collection(_COLLECTION_SERVICES).add(data);
            }
            _loadServices();
          } catch (e) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed: $e')));
          }
        },
      ),
    );
  }

  void _deleteService(ServiceItem service) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Service'),
        content: Text('Delete "${service.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteService(service.id);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteService(String id) async {
    setState(() => _isLoading = true);
    try {
      await _db.collection(_COLLECTION_SERVICES).doc(id).delete();
      _loadServices();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class ServiceItem {
  final String id;
  final String title;
  final String description;
  final String details;
  final String category;
  final double price;
  final String duration;
  final bool isActive;

  ServiceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.details,
    this.category = 'General',
    this.price = 0.0,
    this.duration = 'Flexible',
    this.isActive = true,
  });

  factory ServiceItem.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceItem(
      id: doc.id,
      title: data['title']?.toString() ?? 'Untitled',
      description: data['description']?.toString() ?? '',
      details: data['details']?.toString() ?? '',
      category: data['category']?.toString() ?? 'General',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      duration: data['duration']?.toString() ?? 'Flexible',
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}

class ServiceFormDialog extends StatefulWidget {
  final ServiceItem? service;
  final Function(String, String, String) onSubmit;

  const ServiceFormDialog({Key? key, this.service, required this.onSubmit})
    : super(key: key);

  @override
  _ServiceFormDialogState createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<ServiceFormDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _titleController.text = widget.service!.title;
      _descriptionController.text = widget.service!.description;
      _detailsController.text = widget.service!.details;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.service != null ? "Edit Service" : "Create Service",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Title *",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: "Description *",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              decoration: InputDecoration(
                labelText: "Details",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel"),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text(widget.service != null ? "Update" : "Create"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title and description are required')),
      );
      return;
    }
    widget.onSubmit(
      _titleController.text.trim(),
      _descriptionController.text.trim(),
      _detailsController.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _detailsController.dispose();
    super.dispose();
  }
}
