import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageActivities extends StatefulWidget {
  final String? userEmail;
  final String? userFirstName;
  final String? userLastName;
  final int? userCreatedAt;

  const AdminManageActivities({
    Key? key,
    this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userCreatedAt,
  }) : super(key: key);

  @override
  _AdminManageActivitiesState createState() => _AdminManageActivitiesState();
}

class _AdminManageActivitiesState extends State<AdminManageActivities> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = false;
  String _searchQuery = '';
  List<Activity> _allActivities = [];
  List<Activity> _filteredActivities = [];
  Activity? _editingActivity;

  // Form data
  final TextEditingController _searchController = TextEditingController();

  // Constants
  final List<String> _categories = ["Exercise", "Social", "Educational", "Creative", "Wellness", "Entertainment"];
  final List<String> _difficulties = ["Easy", "Beginner", "Intermediate", "Advanced"];
  final List<String> _durations = ["15 mins", "30 mins", "45 mins", "1 hour", "1.5 hours", "2 hours", "2+ hours"];

  // Colors
  final Color _backgroundColor = Color(0xFFf5f5f5);
  final Color _whiteColor = Colors.white;
  final Color _blackColor = Colors.black;
  final Color _darkGrayColor = Color(0xFF666666);
  final Color _purpleColor = Colors.purple.shade500;
  final Color _redColor = Colors.red;
  final Color _blueColor = Colors.blue;
  final Color _greenColor = Colors.green;
  final Color _orangeColor = Colors.orange;
  final Color _lightGrayColor = Color(0xFFE0E0E0);

  static const String _TAG = "AdminManageActivities";
  static const String _COLLECTION_ACTIVITIES = "Activities";

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildAddButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _purpleColor,
      elevation: 4,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: _whiteColor),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          Text(
            "Activities",
            style: TextStyle(
              color: _whiteColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: _whiteColor),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Notifications clicked")),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.menu, color: _whiteColor),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Menu clicked")),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Header Section
        _buildHeaderSection(),

        // Loading State
        if (_isLoading) _buildLoadingState(),

        // Empty State or Activities Grid
        Expanded(
          child: _filteredActivities.isEmpty && !_isLoading
              ? _buildEmptyState()
              : _buildActivitiesGrid(),
        ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      color: _whiteColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Create, edit, and manage activities for elderly users",
            style: TextStyle(
              color: _darkGrayColor,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          // Search and Add Button Container
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search activities...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterActivities();
                      });
                    },
                  ),
                ),
              ),
              SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Loading activities...",
              style: TextStyle(
                fontSize: 16,
                color: _darkGrayColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          _searchQuery.isEmpty
              ? "No activities found. Create your first activity to get started."
              : 'No activities found matching "$_searchQuery"',
          style: TextStyle(
            fontSize: 16,
            color: _darkGrayColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActivitiesGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _filteredActivities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(_filteredActivities[index]);
      },
    );
  }

  Widget _buildActivityCard(Activity activity) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Title
            Text(
              activity.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),

            // Activity Summary
            Text(
              activity.summary,
              style: TextStyle(
                fontSize: 16,
                color: _darkGrayColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16),

            // Primary Tags (Category, Difficulty, Duration)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (activity.category != null && activity.category!.isNotEmpty)
                  _buildTag(activity.category!, _blueColor),
                if (activity.difficulty != null && activity.difficulty!.isNotEmpty)
                  _buildTag(activity.difficulty!, _greenColor),
                if (activity.duration != null && activity.duration!.isNotEmpty)
                  _buildTag(activity.duration!, _orangeColor),
              ],
            ),

            // Custom Tags
            if (activity.tags.isNotEmpty) ...[
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activity.tags.map((tag) => _buildTag(tag, _purpleColor)).toList(),
              ),
            ],

            // Divider
            Container(
              height: 1,
              color: _lightGrayColor,
              margin: EdgeInsets.symmetric(vertical: 16),
            ),

            // Full Description
            if (activity.description != null && activity.description!.isNotEmpty) ...[
              Text(
                activity.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF444444),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 16),
            ],

            // Action Buttons
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _editActivity(activity),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purpleColor,
                        foregroundColor: _whiteColor,
                      ),
                      child: Text("Edit"),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _deleteActivity(activity),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _redColor,
                        foregroundColor: _whiteColor,
                      ),
                      child: Text("Delete"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _whiteColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton(
      onPressed: _createActivity,
      backgroundColor: _purpleColor,
      foregroundColor: _whiteColor,
      child: Icon(Icons.add),
    );
  }

  // Activity Management Methods
  void _loadActivities() {
    setState(() {
      _isLoading = true;
    });

    print("$_TAG: Loading activities from Firebase...");

    _db.collection(_COLLECTION_ACTIVITIES)
        .get()
        .then((querySnapshot) {
      setState(() {
        _isLoading = false;
        _allActivities.clear();

        for (var document in querySnapshot.docs) {
          try {
            Activity activity = Activity.fromDocument(document);
            _allActivities.add(activity);
            print("$_TAG: Loaded activity: ${activity.title}");
          } catch (e) {
            print("$_TAG: Error parsing activity document: $e");
          }
        }

        _filterActivities();
      });
    })
        .catchError((error) {
      setState(() {
        _isLoading = false;
      });
      print("$_TAG: Error loading activities: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load activities: $error")),
      );
    });
  }

  void _filterActivities() {
    if (_searchQuery.isEmpty) {
      _filteredActivities = List.from(_allActivities);
    } else {
      String query = _searchQuery.toLowerCase();
      _filteredActivities = _allActivities.where((activity) {
        return activity.title.toLowerCase().contains(query) ||
            (activity.summary.toLowerCase().contains(query)) ||
            (activity.category != null && activity.category!.toLowerCase().contains(query)) ||
            (activity.description != null && activity.description!.toLowerCase().contains(query)) ||
            activity.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // Sort by title
    _filteredActivities.sort((a, b) => a.title.compareTo(b.title));
  }

  void _createActivity() {
    _editingActivity = null;
    _showActivityForm();
  }

  void _editActivity(Activity activity) {
    _editingActivity = activity;
    _showActivityForm();
  }

  void _showActivityForm() {
    showDialog(
      context: context,
      builder: (context) => ActivityFormDialog(
        activity: _editingActivity,
        categories: _categories,
        difficulties: _difficulties,
        durations: _durations,
        onSubmit: _submitActivityForm,
      ),
    );
  }

  void _submitActivityForm(
      String title,
      String summary,
      String category,
      String difficulty,
      String duration,
      String image,
      String description,
      bool requiresAuth,
      List<String> tags,
      ) {
    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> activityData = {
      'title': title,
      'summary': summary,
      'category': category,
      'difficulty': difficulty,
      'duration': duration,
      'image': image,
      'description': description,
      'requiresAuth': requiresAuth,
      'tags': tags,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': _auth.currentUser?.email ?? 'admin',
    };

    if (_editingActivity != null) {
      // Update existing activity
      _db.collection(_COLLECTION_ACTIVITIES)
          .doc(_editingActivity!.id)
          .set(activityData)
          .then((_) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Activity updated successfully")),
        );
        _loadActivities();
      })
          .catchError((error) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update activity: $error")),
        );
      });
    } else {
      // Create new activity
      _db.collection(_COLLECTION_ACTIVITIES)
          .add(activityData)
          .then((_) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Activity created successfully")),
        );
        _loadActivities();
      })
          .catchError((error) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create activity: $error")),
        );
      });
    }
  }

  void _deleteActivity(Activity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Activity"),
        content: Text("Are you sure you want to delete this activity? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteActivity(activity.id);
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

  void _performDeleteActivity(String activityId) {
    setState(() {
      _isLoading = true;
    });

    _db.collection(_COLLECTION_ACTIVITIES)
        .doc(activityId)
        .delete()
        .then((_) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Activity deleted successfully")),
      );
      _loadActivities();
    })
        .catchError((error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete activity: $error")),
      );
    });
  }
}

// Activity Model Class
class Activity {
  String id;
  String title;
  String summary;
  String? category;
  String? difficulty;
  String? duration;
  String? image;
  String? description;
  bool requiresAuth;
  List<String> tags;

  Activity({
    required this.id,
    required this.title,
    required this.summary,
    this.category,
    this.difficulty,
    this.duration,
    this.image,
    this.description,
    required this.requiresAuth,
    required this.tags,
  });

  factory Activity.fromDocument(DocumentSnapshot document) {
    // Handle tags array
    List<String> tags = [];
    dynamic tagsObj = document.get('tags');
    if (tagsObj is List) {
      for (var tag in tagsObj) {
        if (tag is String && tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    return Activity(
      id: document.id,
      title: document.get('title') ?? 'No Title',
      summary: document.get('summary') ?? 'No Summary',
      category: document.get('category'),
      difficulty: document.get('difficulty'),
      duration: document.get('duration'),
      image: document.get('image'),
      description: document.get('description'),
      requiresAuth: document.get('requiresAuth') ?? false,
      tags: tags,
    );
  }
}

// Activity Form Dialog
class ActivityFormDialog extends StatefulWidget {
  final Activity? activity;
  final List<String> categories;
  final List<String> difficulties;
  final List<String> durations;
  final Function(
      String title,
      String summary,
      String category,
      String difficulty,
      String duration,
      String image,
      String description,
      bool requiresAuth,
      List<String> tags,
      ) onSubmit;

  const ActivityFormDialog({
    Key? key,
    this.activity,
    required this.categories,
    required this.difficulties,
    required this.durations,
    required this.onSubmit,
  }) : super(key: key);

  @override
  _ActivityFormDialogState createState() => _ActivityFormDialogState();
}

class _ActivityFormDialogState extends State<ActivityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedCategory;
  String? _selectedDifficulty;
  String? _selectedDuration;
  bool _requiresAuth = false;
  List<TextEditingController> _tagControllers = [];

  @override
  void initState() {
    super.initState();

    // Populate form if editing
    if (widget.activity != null) {
      _titleController.text = widget.activity!.title;
      _summaryController.text = widget.activity!.summary;
      _imageController.text = widget.activity!.image ?? '';
      _descriptionController.text = widget.activity!.description ?? '';
      _selectedCategory = widget.activity!.category;
      _selectedDifficulty = widget.activity!.difficulty;
      _selectedDuration = widget.activity!.duration;
      _requiresAuth = widget.activity!.requiresAuth;

      // Populate tags
      for (String tag in widget.activity!.tags) {
        _tagControllers.add(TextEditingController(text: tag));
      }
    }

    // Add one empty tag by default if no tags exist
    if (_tagControllers.isEmpty) {
      _tagControllers.add(TextEditingController());
    }

    // Set default values for dropdowns
    _selectedCategory ??= widget.categories.first;
    _selectedDifficulty ??= widget.difficulties.first;
    _selectedDuration ??= widget.durations.first;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Form(
        key: _formKey,
        child: Container(
          padding: EdgeInsets.all(20),
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.activity != null ? "Edit Activity" : "Create New Activity",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),

                // Title
                Text("Title *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: "Activity Title *",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Activity title is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Summary
                Text("Summary *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _summaryController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Summary *",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Summary is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Spinners Row
                Row(
                  children: [
                    // Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Category", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            items: widget.categories.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedCategory = newValue;
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
                    // Difficulty
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Difficulty", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedDifficulty,
                            items: widget.difficulties.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDifficulty = newValue;
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
                    // Duration
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Duration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedDuration,
                            items: widget.durations.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDuration = newValue;
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

                // Image URL
                Text("Image URL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _imageController,
                  decoration: InputDecoration(
                    hintText: "Image URL",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),

                // Description
                Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Full Description",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),

                // Requires Auth Checkbox
                CheckboxListTile(
                  title: Text("Requires User Authentication"),
                  value: _requiresAuth,
                  onChanged: (bool? value) {
                    setState(() {
                      _requiresAuth = value ?? false;
                    });
                  },
                ),
                SizedBox(height: 16),

                // Tags
                Text("Additional Tags", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ..._tagControllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  TextEditingController controller = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: "Enter tag",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              if (_tagControllers.length > 1) {
                                _tagControllers.removeAt(index);
                              } else {
                                controller.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),

                // Add Tag Button
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _tagControllers.add(TextEditingController());
                    });
                  },
                  child: Text("+ Add Tag"),
                ),
                SizedBox(height: 20),

                // Buttons
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
                        onPressed: _submitForm,
                        child: Text(widget.activity != null ? "Update Activity" : "Create Activity"),
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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Collect tags
      List<String> tags = [];
      for (var controller in _tagControllers) {
        String tag = controller.text.trim();
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      }

      widget.onSubmit(
        _titleController.text.trim(),
        _summaryController.text.trim(),
        _selectedCategory!,
        _selectedDifficulty!,
        _selectedDuration!,
        _imageController.text.trim(),
        _descriptionController.text.trim(),
        _requiresAuth,
        tags,
      );

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _imageController.dispose();
    _descriptionController.dispose();
    for (var controller in _tagControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}