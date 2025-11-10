import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  _AdminManageServiceState createState() => _AdminManageServiceState();
}

class _AdminManageServiceState extends State<AdminManageService> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = false;
  bool _showError = false;
  String _errorMessage = '';
  List<ServiceItem> _services = [];

  // Colors
  final Color _whiteColor = Colors.white;
  final Color _blackColor = Colors.black;
  final Color _darkerGrayColor = Colors.grey.shade700;
  final Color _blueColor = Color(0xFF2196F3);
  final Color _errorBackgroundColor = Color(0xFFEBEE);
  final Color _errorTextColor = Color(0xFFD32F2F);
  final Color _purpleColor = Colors.purple.shade500;
  final Color _redColor = Colors.red;
  final Color _cardBackgroundColor = Color(0xFFFFFFFF);
  final Color _titleTextColor = Color(0xFF333333);
  final Color _descriptionTextColor = Color(0xFF666666);
  final Color _detailsTextColor = Color(0xFF444444);
  final Color _idTextColor = Color(0xFF888888);
  final Color _detailsBackgroundColor = Color(0xFFf8f9fa);

  static const String _TAG = "AdminManageService";
  static const String _COLLECTION_SERVICES = "Services";

  @override
  void initState() {
    super.initState();
    _loadServicesFromFirebase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _whiteColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.purple.shade500,
      elevation: 4,
      title: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: _whiteColor),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Text(
              "Manage Services",
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
              backgroundColor: Colors.red,
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

  Widget _buildBody() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildHeaderSection(),
          SizedBox(height: 24),

          // Error Message
          if (_showError) _buildErrorMessage(),
          if (_showError) SizedBox(height: 16),

          // Loading Indicator
          if (_isLoading) _buildLoadingIndicator(),

          // Services List or Empty State
          Expanded(
            child: _services.isEmpty && !_isLoading
                ? _buildEmptyState()
                : _buildServicesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Manage Services",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _blackColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Create, edit, and manage AllCare Platform services",
          style: TextStyle(
            fontSize: 16,
            color: _darkerGrayColor,
          ),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _showServiceForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blueColor,
            foregroundColor: _whiteColor,
            padding: EdgeInsets.all(12),
          ),
          child: Text("+ Add New Service"),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorBackgroundColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: _errorTextColor,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 24),
            onPressed: () {
              setState(() {
                _showError = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_problem,
            size: 64,
            color: _darkerGrayColor,
          ),
          SizedBox(height: 16),
          Text(
            "No services found. Create your first service to get started.",
            style: TextStyle(
              fontSize: 16,
              color: _darkerGrayColor,
            ),
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

  // Service Management Methods
  void _loadServicesFromFirebase() {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    _db.collection(_COLLECTION_SERVICES)
        .get()
        .then((querySnapshot) {
      setState(() {
        _isLoading = false;
        _services.clear();

        for (var document in querySnapshot.docs) {
          ServiceItem service = ServiceItem.fromDocument(document);
          _services.add(service);
          print("$_TAG: Loaded service: ${service.title}");
        }
      });
    })
        .catchError((error) {
      setState(() {
        _isLoading = false;
      });
      print("$_TAG: Error loading services: $error");
      _displayError("Failed to load services: $error");
    });
  }

  void _showServiceForm([ServiceItem? service]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildServiceForm(service);
      },
    );
  }

  Widget _buildServiceForm(ServiceItem? service) {
    final TextEditingController titleController = TextEditingController(text: service?.title ?? '');
    final TextEditingController descController = TextEditingController(text: service?.description ?? '');
    final TextEditingController detailsController = TextEditingController(text: service?.details ?? '');

    return Padding(
      padding: EdgeInsets.all(50),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service != null ? "Edit Service" : "Add New Service",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),

          // Title Input
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              hintText: "Service Title",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),

          // Description Input
          TextField(
            controller: descController,
            decoration: InputDecoration(
              hintText: "Description",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),

          // Details Input
          TextField(
            controller: detailsController,
            decoration: InputDecoration(
              hintText: "Details",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          SizedBox(height: 20),

          // Save Button
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
              backgroundColor: _blueColor,
              foregroundColor: _whiteColor,
              minimumSize: Size(double.infinity, 50),
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
        SnackBar(content: Text("Please enter a service title")),
      );
      return;
    }

    if (service == null) {
      // Create new service
      ServiceItem newService = ServiceItem(
        id: '',
        title: title,
        description: description,
        details: details,
      );

      _db.collection(_COLLECTION_SERVICES)
          .add(newService.toMap())
          .then((documentReference) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Service created successfully")),
        );
        _loadServicesFromFirebase();
      })
          .catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating service")),
        );
        print("$_TAG: Error creating service: $error");
      });
    } else {
      // Update existing service
      service.title = title;
      service.description = description;
      service.details = details;

      _db.collection(_COLLECTION_SERVICES)
          .doc(service.id)
          .set(service.toMap())
          .then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Service updated successfully")),
        );
        _loadServicesFromFirebase();
      })
          .catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating service")),
        );
        print("$_TAG: Error updating service: $error");
      });
    }
  }

  void _editService(ServiceItem service) {
    _showServiceForm(service);
  }

  void _deleteService(ServiceItem service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Service"),
        content: Text('Are you sure you want to delete "${service.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteService(service);
            },
            child: Text(
              "Delete",
              style: TextStyle(color: _redColor),
            ),
          ),
        ],
      ),
    );
  }

  void _performDeleteService(ServiceItem service) {
    _db.collection(_COLLECTION_SERVICES)
        .doc(service.id)
        .delete()
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Service deleted successfully")),
      );
      _loadServicesFromFirebase();
    })
        .catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting service")),
      );
      print("$_TAG: Error deleting service: $error");
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

// ServiceItem Model Class
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
    return ServiceItem(
      id: document.id,
      title: document.get('title') ?? '',
      description: document.get('description') ?? '',
      details: document.get('details') ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'details': details,
    };
  }
}

// Service Card Widget (Accessory File)
class ServiceCard extends StatelessWidget {
  final ServiceItem service;
  final Function(ServiceItem) onEdit;
  final Function(ServiceItem) onDelete;

  const ServiceCard({
    Key? key,
    required this.service,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Colors
    final Color _purpleColor = Colors.purple.shade500;
    final Color _redColor = Colors.red;
    final Color _whiteColor = Colors.white;
    final Color _titleTextColor = Color(0xFF333333);
    final Color _descriptionTextColor = Color(0xFF666666);
    final Color _detailsTextColor = Color(0xFF444444);
    final Color _idTextColor = Color(0xFF888888);
    final Color _detailsBackgroundColor = Color(0xFFf8f9fa);

    return Card(
      elevation: 2,
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Title and Actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _titleTextColor,
                    ),
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => onEdit(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purpleColor,
                        foregroundColor: _whiteColor,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        textStyle: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                      child: Text("Edit"),
                    ),
                    SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: () => onDelete(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _redColor,
                        foregroundColor: _whiteColor,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        textStyle: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                      child: Text("Delete"),
                    ),
                  ],
                ),
              ],
            ),

            // Short Description
            Container(
              margin: EdgeInsets.only(top: 12),
              child: Text(
                service.description,
                style: TextStyle(
                  fontSize: 16,
                  color: _descriptionTextColor,
                ),
              ),
            ),

            // Full Details Section (only if details exist)
            if (service.details.isNotEmpty) ...[
              Container(
                margin: EdgeInsets.only(top: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _detailsBackgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Full Details:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _titleTextColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      service.details,
                      style: TextStyle(
                        fontSize: 14,
                        color: _detailsTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Service ID
            Container(
              margin: EdgeInsets.only(top: 16),
              child: Text(
                "ID: ${service.id}",
                style: TextStyle(
                  fontSize: 12,
                  color: _idTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}