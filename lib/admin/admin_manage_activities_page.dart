import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_shell.dart';
import '../models/user_profile.dart';
import 'admin_routes.dart';

class AdminManageActivitiesPage extends StatefulWidget {
  final UserProfile userProfile;
  const AdminManageActivitiesPage({Key? key, required this.userProfile})
    : super(key: key);

  @override
  _AdminManageActivitiesState createState() => _AdminManageActivitiesState();
}

class _AdminManageActivitiesState extends State<AdminManageActivitiesPage> {
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
  final List<String> _categories = [
    "Exercise",
    "Social",
    "Educational",
    "Creative",
    "Wellness",
    "Entertainment",
  ];
  final List<String> _difficulties = [
    "Easy",
    "Beginner",
    "Intermediate",
    "Advanced",
  ];
  final List<String> _durations = [
    "15 mins",
    "30 mins",
    "45 mins",
    "1 hour",
    "1.5 hours",
    "2 hours",
    "2+ hours",
  ];

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

  static const String _TAG = "AdminManageActivities";
  static const String _COLLECTION_ACTIVITIES = "Activities";

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      profile: widget.userProfile,
      currentKey: 'adminManage',
      title: 'Activities',
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
          // Empty or Activities Grid/List
          Expanded(
            child: _filteredActivities.isEmpty
                ? _buildEmptyState()
                : _buildActivitiesLayout(),
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
            "Create, edit, and manage activities for elderly users",
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
                      hintText: "Search activities...",
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
                        _filterActivities();
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
            "Loading activities...",
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
              ? "No activities found. Create your first activity to get started."
              : 'No activities found matching "$_searchQuery"',
          style: TextStyle(
            fontSize: _getResponsiveValue(mobile: 14, tablet: 16, desktop: 18),
            color: _darkGrayColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActivitiesLayout() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      // Mobile - List view
      return _buildActivitiesList();
    } else if (screenWidth < 1200) {
      // Tablet - Grid with 2 columns
      return _buildActivitiesGrid(crossAxisCount: 2);
    } else {
      // Desktop - Grid with 3 columns
      return _buildActivitiesGrid(crossAxisCount: 3);
    }
  }

  Widget _buildActivitiesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredActivities.length,
      itemBuilder: (context, index) =>
          _buildActivityListItem(_filteredActivities[index]),
    );
  }

  Widget _buildActivityListItem(Activity activity) {
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
              activity.title,
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
            // Summary
            Text(
              activity.summary,
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
            // Primary tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if ((activity.category ?? '').isNotEmpty)
                  _chip(activity.category!, _blueColor),
                if ((activity.difficulty ?? '').isNotEmpty)
                  _chip(activity.difficulty!, _greenColor),
                if ((activity.duration ?? '').isNotEmpty)
                  _chip(activity.duration!, _orangeColor),
              ],
            ),
            if (activity.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: activity.tags
                    .map((t) => _chip(t, _purpleColor))
                    .toList(),
              ),
            ],
            Container(
              height: 1,
              color: _lightGrayColor,
              margin: const EdgeInsets.symmetric(vertical: 12),
            ),
            if ((activity.description ?? '').isNotEmpty) ...[
              Text(
                activity.description!,
                style: TextStyle(
                  fontSize: _getResponsiveValue(
                    mobile: 12,
                    tablet: 14,
                    desktop: 16,
                  ),
                  color: const Color(0xFF444444),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editActivity(activity),
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
                    onPressed: () => _deleteActivity(activity),
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

  Widget _buildActivitiesGrid({required int crossAxisCount}) {
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
      itemCount: _filteredActivities.length,
      itemBuilder: (_, i) => _buildActivityCard(_filteredActivities[i]),
    );
  }

  Widget _buildActivityCard(Activity activity) {
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
              activity.title,
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
            // Summary
            Text(
              activity.summary,
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
            // Primary tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if ((activity.category ?? '').isNotEmpty)
                  _chip(activity.category!, _blueColor),
                if ((activity.difficulty ?? '').isNotEmpty)
                  _chip(activity.difficulty!, _greenColor),
                if ((activity.duration ?? '').isNotEmpty)
                  _chip(activity.duration!, _orangeColor),
              ],
            ),
            if (activity.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: activity.tags
                    .map((t) => _chip(t, _purpleColor))
                    .toList(),
              ),
            ],
            const Spacer(),
            Container(
              height: 1,
              color: _lightGrayColor,
              margin: const EdgeInsets.symmetric(vertical: 12),
            ),
            if ((activity.description ?? '').isNotEmpty) ...[
              Text(
                activity.description!,
                style: TextStyle(
                  fontSize: _getResponsiveValue(
                    mobile: 10,
                    tablet: 12,
                    desktop: 14,
                  ),
                  color: const Color(0xFF444444),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editActivity(activity),
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
                    onPressed: () => _deleteActivity(activity),
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

  Widget _chip(String text, Color color) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: _getResponsiveValue(mobile: 8, tablet: 10, desktop: 12),
      vertical: _getResponsiveValue(mobile: 4, tablet: 5, desktop: 6),
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: _whiteColor,
        fontSize: _getResponsiveValue(mobile: 10, tablet: 11, desktop: 12),
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildAddButton() => FloatingActionButton(
    onPressed: _createActivity,
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

  // ───────── Data methods (unchanged) ─────────
  void _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _db.collection(_COLLECTION_ACTIVITIES).get();
      final list = <Activity>[];
      for (final d in snap.docs) {
        try {
          list.add(Activity.fromDocument(d));
        } catch (e) {
          // ignore malformed docs
        }
      }
      setState(() {
        _allActivities = list;
        _filterActivities();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load activities: $e')));
    }
  }

  void _filterActivities() {
    final q = _searchQuery.toLowerCase().trim();
    _filteredActivities = q.isEmpty
        ? List.of(_allActivities)
        : _allActivities.where((a) {
            bool contains(String? s) => (s ?? '').toLowerCase().contains(q);
            return contains(a.title) ||
                contains(a.summary) ||
                contains(a.category) ||
                contains(a.description) ||
                a.tags.any((t) => t.toLowerCase().contains(q));
          }).toList();
    _filteredActivities.sort((a, b) => a.title.compareTo(b.title));
    setState(() {});
  }

  void _createActivity() {
    _editingActivity = null;
    _showActivityForm();
  }

  void _editActivity(Activity a) {
    _editingActivity = a;
    _showActivityForm();
  }

  void _showActivityForm() {
    showDialog(
      context: context,
      builder: (_) => ActivityFormDialog(
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
  ) async {
    setState(() => _isLoading = true);

    final data = {
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

    try {
      if (_editingActivity != null) {
        await _db
            .collection(_COLLECTION_ACTIVITIES)
            .doc(_editingActivity!.id)
            .set(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity updated successfully')),
        );
      } else {
        await _db.collection(_COLLECTION_ACTIVITIES).add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity created successfully')),
        );
      }
      _loadActivities();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save activity: $e')));
    }
  }

  void _deleteActivity(Activity a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text(
          'Are you sure you want to delete this activity? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteActivity(a.id);
            },
            child: Text('Delete', style: TextStyle(color: _redColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteActivity(String activityId) async {
    setState(() => _isLoading = true);
    try {
      await _db.collection(_COLLECTION_ACTIVITIES).doc(activityId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity deleted successfully')),
      );
      _loadActivities();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete activity: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ───────── Activity model & form dialog (with responsive improvements) ─────────

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
    final tags = <String>[];
    final tagsObj = document.get('tags');
    if (tagsObj is List) {
      for (final t in tagsObj) {
        if (t is String && t.isNotEmpty) tags.add(t);
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
  )
  onSubmit;

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
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _imageController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategory;
  String? _selectedDifficulty;
  String? _selectedDuration;
  bool _requiresAuth = false;
  List<TextEditingController> _tagControllers = [];

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    if (a != null) {
      _titleController.text = a.title;
      _summaryController.text = a.summary;
      _imageController.text = a.image ?? '';
      _descriptionController.text = a.description ?? '';
      _selectedCategory = a.category;
      _selectedDifficulty = a.difficulty;
      _selectedDuration = a.duration;
      _requiresAuth = a.requiresAuth;
      for (final t in a.tags) {
        _tagControllers.add(TextEditingController(text: t));
      }
    }
    if (_tagControllers.isEmpty) _tagControllers.add(TextEditingController());

    _selectedCategory ??= widget.categories.first;
    _selectedDifficulty ??= widget.difficulties.first;
    _selectedDuration ??= widget.durations.first;
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
              children: [
                Text(
                  widget.activity != null
                      ? "Edit Activity"
                      : "Create New Activity",
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
                  hintText: "Activity Title *",
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Activity title is required'
                      : null,
                  maxLines: 1,
                ),

                // Summary
                _buildFormField(
                  label: "Summary *",
                  controller: _summaryController,
                  hintText: "Summary *",
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Summary is required' : null,
                  maxLines: 3,
                ),

                // Category / Difficulty / Duration
                _buildDropdownRow(),

                // Image URL
                _buildFormField(
                  label: "Image URL",
                  controller: _imageController,
                  hintText: "Image URL",
                  maxLines: 1,
                ),

                // Description
                _buildFormField(
                  label: "Description",
                  controller: _descriptionController,
                  hintText: "Full Description",
                  maxLines: 4,
                ),

                // Requires Auth Checkbox
                CheckboxListTile(
                  title: Text(
                    "Requires User Authentication",
                    style: TextStyle(
                      fontSize: _getResponsiveValue(
                        mobile: 14,
                        tablet: 16,
                        desktop: 16,
                      ),
                    ),
                  ),
                  value: _requiresAuth,
                  onChanged: (v) => setState(() => _requiresAuth = v ?? false),
                ),
                const SizedBox(height: 16),

                // Tags
                const Text(
                  "Additional Tags",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._tagControllers.asMap().entries.map((e) {
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
                              hintText: "Enter tag",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              if (_tagControllers.length > 1) {
                                _tagControllers.removeAt(i);
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
                ElevatedButton(
                  onPressed: () => setState(
                    () => _tagControllers.add(TextEditingController()),
                  ),
                  child: const Text("+ Add Tag"),
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
                          widget.activity != null
                              ? "Update Activity"
                              : "Create Activity",
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

  Widget _buildDropdownRow() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      // Mobile - vertical layout
      return Column(
        children: [
          _dropdown(
            "Category",
            widget.categories,
            _selectedCategory,
            (v) => setState(() => _selectedCategory = v),
          ),
          const SizedBox(height: 16),
          _dropdown(
            "Difficulty",
            widget.difficulties,
            _selectedDifficulty,
            (v) => setState(() => _selectedDifficulty = v),
          ),
          const SizedBox(height: 16),
          _dropdown(
            "Duration",
            widget.durations,
            _selectedDuration,
            (v) => setState(() => _selectedDuration = v),
          ),
          const SizedBox(height: 16),
        ],
      );
    } else {
      // Tablet/Desktop - horizontal layout
      return Row(
        children: [
          Expanded(
            child: _dropdown(
              "Category",
              widget.categories,
              _selectedCategory,
              (v) => setState(() => _selectedCategory = v),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _dropdown(
              "Difficulty",
              widget.difficulties,
              _selectedDifficulty,
              (v) => setState(() => _selectedDifficulty = v),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _dropdown(
              "Duration",
              widget.durations,
              _selectedDuration,
              (v) => setState(() => _selectedDuration = v),
            ),
          ),
        ],
      );
    }
  }

  Widget _dropdown(
    String label,
    List<String> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
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
          value: value ?? options.first,
          items: options
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
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
      final tags = <String>[];
      for (final c in _tagControllers) {
        final t = c.text.trim();
        if (t.isNotEmpty) tags.add(t);
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
    for (final c in _tagControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
