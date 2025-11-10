import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageMembership extends StatefulWidget {
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final int? userCreatedAt;

  const AdminManageMembership({
    Key? key,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userCreatedAt,
  }) : super(key: key);

  @override
  _AdminManageMembershipState createState() => _AdminManageMembershipState();
}

class _AdminManageMembershipState extends State<AdminManageMembership> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = false;
  bool _showError = false;
  String _errorMessage = '';
  List<MembershipPlan> _plans = [];
  MembershipPlan? _editingPlan;

  // Colors
  final Color _whiteColor = Colors.white;
  final Color _blackColor = Colors.black;
  final Color _darkerGrayColor = Colors.grey.shade700;
  final Color _blueColor = Color(0xFF2196F3);
  final Color _errorBackgroundColor = Color(0xFFEBEE);
  final Color _errorTextColor = Color(0xFFD32F2F);
  final Color _orangeColor = Color(0xFFFF9800);
  final Color _redColor = Color(0xFFF44336);
  final Color _greenColor = Color(0xFF4CAF50);
  final Color _purpleColor = Color(0xFF9C27B0);
  final Color _pinkColor = Color(0xFFE91E63);
  final Color _cyanColor = Color(0xFF00BCD4);
  final Color _skyColor = Color(0xFF03A9F4);

  static const String _TAG = "AdminManageMembership";
  static const String _COLLECTION_MEMBERSHIPS = "membershipPlans";

  @override
  void initState() {
    super.initState();
    _loadPlansFromFirebase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _whiteColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.purple.shade500,
      elevation: 4,
      title: Text(
        "Membership Management",
        style: TextStyle(
          color: _whiteColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: _whiteColor),
        onPressed: () {
          Navigator.pop(context);
        },
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

          // Plans List or Empty State
          Expanded(
            child: _plans.isEmpty && !_isLoading
                ? _buildEmptyState()
                : _buildPlansList(),
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
          "Manage Membership Plans",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _blackColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Create, edit, and manage AllCare Platform membership plans",
          style: TextStyle(
            fontSize: 16,
            color: _darkerGrayColor,
          ),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _showPlanForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blueColor,
            foregroundColor: _whiteColor,
            padding: EdgeInsets.all(12),
          ),
          child: Text("+ Add New Plan"),
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
            "No membership plans found.\nTap 'Add New Plan' to create your first plan.",
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

  Widget _buildPlansList() {
    return ListView.builder(
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        return _buildPlanCard(_plans[index]);
      },
    );
  }

  Widget _buildPlanCard(MembershipPlan plan) {
    Color cardColor = _getColorForScheme(plan.colorScheme);

    return Card(
      elevation: 8,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.all(30),
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _blackColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        plan.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badges Container
                Row(
                  children: [
                    if (plan.popular) _buildBadge("Popular", _orangeColor),
                    if (plan.trial) _buildBadge("Trial", _greenColor),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),

            // Pricing Section
            Row(
              children: [
                Text(
                  "\$${plan.price}",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _blackColor,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  "per ${plan.period}",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Features Label
            Text(
              "Features:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _blackColor,
              ),
            ),
            SizedBox(height: 8),

            // Features List
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.features.map((feature) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    "• $feature",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16),

            // Last Updated
            Text(
              "Last updated: ${_formatDate(plan.lastUpdatedAt)}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editPlan(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orangeColor,
                      foregroundColor: _whiteColor,
                    ),
                    child: Text("Edit"),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deletePlan(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redColor,
                      foregroundColor: _whiteColor,
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: EdgeInsets.only(left: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _whiteColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_services),
          label: 'Services',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.card_membership),
          label: 'Member',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Home clicked")),
            );
            break;
          case 1:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Services clicked")),
            );
            break;
          case 2:
          // Current page
            break;
          case 3:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Profile clicked")),
            );
            break;
        }
      },
      currentIndex: 2, // Select the Member tab
    );
  }

  // Plan Management Methods
  void _loadPlansFromFirebase() {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    print("$_TAG: Starting Firebase Query");
    print("$_TAG: Collection: $_COLLECTION_MEMBERSHIPS");

    if (_auth.currentUser == null) {
      print("$_TAG: User is not authenticated!");
      _displayError("User not authenticated. Please log in again.");
      _setLoading(false);
      return;
    }

    _db.collection(_COLLECTION_MEMBERSHIPS)
        .get()
        .then((querySnapshot) {
      _setLoading(false);

      print("$_TAG: Firebase Query Result");
      print("$_TAG: Number of documents: ${querySnapshot.docs.length}");

      setState(() {
        _plans.clear();

        for (var document in querySnapshot.docs) {
          try {
            MembershipPlan plan = MembershipPlan.fromDocument(document);
            _plans.add(plan);
            print("$_TAG: Successfully parsed plan: ${plan.title}");
          } catch (e) {
            print("$_TAG: Error parsing document ${document.id}: $e");
          }
        }
      });

      _updateEmptyState();
    })
        .catchError((error) {
      _setLoading(false);
      print("$_TAG: Query failed completely: $error");
      _displayError("Network error: $error");
    });
  }

  void _showPlanForm([MembershipPlan? plan]) {
    _editingPlan = plan;
    showDialog(
      context: context,
      builder: (context) => _buildPlanForm(plan),
    );
  }

  Widget _buildPlanForm(MembershipPlan? plan) {
    final TextEditingController titleController = TextEditingController(text: plan?.title ?? '');
    final TextEditingController subtitleController = TextEditingController(text: plan?.subtitle ?? '');
    final TextEditingController priceController = TextEditingController(text: plan?.price ?? '');

    String selectedPeriod = plan?.period ?? "Select period";
    String selectedColorScheme = plan?.colorScheme ?? "Blue";
    bool popularChecked = plan?.popular ?? false;
    bool trialChecked = plan?.trial ?? false;

    List<TextEditingController> featureControllers = [];
    if (plan?.features != null) {
      for (String feature in plan!.features) {
        featureControllers.add(TextEditingController(text: feature));
      }
    } else {
      featureControllers.add(TextEditingController());
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(plan != null ? "Edit Membership Plan" : "Create New Membership Plan"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text("Plan Title *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: "e.g., Monthly Care",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),

                // Subtitle
                Text("Subtitle *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextField(
                  controller: subtitleController,
                  decoration: InputDecoration(
                    hintText: "e.g., Perfect for getting started",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),

                // Price and Period row
                Row(
                  children: [
                    // Price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Price *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          TextField(
                            controller: priceController,
                            decoration: InputDecoration(
                              hintText: "e.g., 90",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    // Period
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Period *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedPeriod,
                            items: ["Select period", "15 days", "month", "year", "3 years"].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedPeriod = newValue!;
                              });
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Color Scheme and Checkboxes row
                Row(
                  children: [
                    // Color Scheme
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Color Scheme", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedColorScheme,
                            items: ["Blue", "Sky", "Cyan", "Green", "Purple", "Pink"].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedColorScheme = newValue!;
                              });
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    // Checkboxes
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            title: Text("Mark as Popular"),
                            value: popularChecked,
                            onChanged: (bool? value) {
                              setState(() {
                                popularChecked = value!;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            title: Text("Is Trial Plan"),
                            value: trialChecked,
                            onChanged: (bool? value) {
                              setState(() {
                                trialChecked = value!;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Features
                Text("Features *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...featureControllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  TextEditingController controller = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: "Enter feature description",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        if (featureControllers.length > 1)
                          IconButton(
                            icon: Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                featureControllers.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }).toList(),

                // Add Feature Button
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      featureControllers.add(TextEditingController());
                    });
                  },
                  child: Text("+ Add Feature"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _submitPlanForm(
                  titleController.text.trim(),
                  subtitleController.text.trim(),
                  priceController.text.trim(),
                  selectedPeriod,
                  selectedColorScheme,
                  popularChecked,
                  trialChecked,
                  featureControllers,
                );
                Navigator.pop(context);
              },
              child: Text(plan != null ? "Update Plan" : "Create Plan"),
            ),
          ],
        );
      },
    );
  }

  void _submitPlanForm(
      String title,
      String subtitle,
      String price,
      String period,
      String colorScheme,
      bool popular,
      bool trial,
      List<TextEditingController> featureControllers,
      ) {
    // Validate form
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a plan title")),
      );
      return;
    }

    if (subtitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a plan subtitle")),
      );
      return;
    }

    if (price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a plan price")),
      );
      return;
    }

    if (period == "Select period") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a billing period")),
      );
      return;
    }

    // Collect features
    List<String> features = [];
    for (var controller in featureControllers) {
      String feature = controller.text.trim();
      if (feature.isNotEmpty) {
        features.add(feature);
      }
    }

    if (features.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please add at least one feature")),
      );
      return;
    }

    // Get current timestamp
    String currentTime = DateTime.now().toIso8601String();

    // Create plan object
    MembershipPlan plan = MembershipPlan(
      id: _editingPlan?.id,
      title: title,
      subtitle: subtitle,
      price: price,
      period: period,
      popular: popular,
      trial: trial,
      features: features,
      colorScheme: colorScheme.toLowerCase(),
      createdAt: _editingPlan?.createdAt ?? currentTime,
      lastUpdatedAt: currentTime,
    );

    _savePlanToFirebase(plan);
  }

  void _savePlanToFirebase(MembershipPlan plan) {
    _setLoading(true);
    print("$_TAG: Saving plan to Firebase: ${plan.title}");

    if (_editingPlan != null) {
      // Update existing plan
      _db.collection(_COLLECTION_MEMBERSHIPS)
          .doc(plan.id)
          .set(plan.toMap())
          .then((_) {
        _setLoading(false);
        _loadPlansFromFirebase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Plan updated successfully")),
        );
      })
          .catchError((error) {
        _setLoading(false);
        print("$_TAG: Failed to update plan: $error");
        _displayError("Failed to update plan: $error");
      });
    } else {
      // Create new plan
      _db.collection(_COLLECTION_MEMBERSHIPS)
          .add(plan.toMap())
          .then((documentReference) {
        _setLoading(false);
        _loadPlansFromFirebase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Plan created successfully")),
        );
      })
          .catchError((error) {
        _setLoading(false);
        print("$_TAG: Failed to create plan: $error");
        _displayError("Failed to create plan: $error");
      });
    }
  }

  void _editPlan(MembershipPlan plan) {
    _showPlanForm(plan);
  }

  void _deletePlan(MembershipPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Plan"),
        content: Text("Are you sure you want to delete this membership plan? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeletePlan(plan.id!); // Added null assertion operator
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

  void _performDeletePlan(String planId) { // Changed parameter type to non-nullable String
    _setLoading(true);

    _db.collection(_COLLECTION_MEMBERSHIPS)
        .doc(planId)
        .delete()
        .then((_) {
      _setLoading(false);
      _loadPlansFromFirebase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Plan deleted successfully")),
      );
    })
        .catchError((error) {
      _setLoading(false);
      print("$_TAG: Failed to delete plan: $error");
      _displayError("Failed to delete plan: $error");
    });
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
    if (loading) {
      _hideError();
    }
  }

  void _displayError(String error) {
    setState(() {
      _errorMessage = error;
      _showError = true;
    });
  }

  void _hideError() {
    setState(() {
      _showError = false;
    });
  }

  void _updateEmptyState() {
    setState(() {});
  }

  Color _getColorForScheme(String scheme) {
    switch (scheme.toLowerCase()) {
      case "blue": return _blueColor;
      case "sky": return _skyColor;
      case "cyan": return _cyanColor;
      case "green": return _greenColor;
      case "purple": return _purpleColor;
      case "pink": return _pinkColor;
      default: return _blueColor;
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

  String _formatTime(int hour, int minute) {
    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    return "$displayHour:${minute.toString().padLeft(2, '0')} $period";
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

// MembershipPlan Model Class
class MembershipPlan {
  String? id;
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
    this.id,
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

    // Handle trial field - some documents might not have it
    dynamic trialObj = document.get('trial');
    bool trial;
    if (trialObj is bool) {
      trial = trialObj;
    } else {
      trial = false;
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
      title: document.get('title') ?? '',
      subtitle: document.get('subtitle') ?? '',
      price: price,
      period: document.get('period') ?? '',
      popular: document.get('popular') ?? false,
      trial: trial,
      features: features,
      colorScheme: document.get('colorScheme') ?? 'blue',
      createdAt: document.get('createdAt') ?? '',
      lastUpdatedAt: document.get('lastUpdatedAt') ?? '',
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