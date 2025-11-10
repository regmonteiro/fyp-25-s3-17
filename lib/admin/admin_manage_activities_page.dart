// lib/admin/admin_manage_activities_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_shell.dart';
import '../models/user_profile.dart';

class AdminManageActivitiesPage extends StatefulWidget {
  final UserProfile userProfile;
  const AdminManageActivitiesPage({Key? key, required this.userProfile}) : super(key: key);

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
  final List<String> _categories = ["Exercise", "Social", "Educational", "Creative", "Wellness", "Entertainment"];
  final List<String> _difficulties = ["Easy", "Beginner", "Intermediate", "Advanced"];
  final List<String> _durations = ["15 mins", "30 mins", "45 mins", "1 hour", "1.5 hours", "2 hours", "2+ hours"];

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
          // Empty or Activities Grid
          Expanded(
            child: _filteredActivities.isEmpty
                ? _buildEmptyState()
                : _buildActivitiesGrid(),
          ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
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
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Loading activities..."),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          _searchQuery.isEmpty
              ? "No activities found. Create your first activity to get started."
              : 'No activities found matching "$_searchQuery"',
          style: TextStyle(fontSize: 16, color: _darkGrayColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActivitiesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              activity.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Summary
            Text(
              activity.summary,
              style: TextStyle(fontSize: 16, color: _darkGrayColor),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            // Primary tags
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                if ((activity.category ?? '').isNotEmpty) _chip(activity.category!, _blueColor),
                if ((activity.difficulty ?? '').isNotEmpty) _chip(activity.difficulty!, _greenColor),
                if ((activity.duration ?? '').isNotEmpty) _chip(activity.duration!, _orangeColor),
              ],
            ),
            if (activity.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: activity.tags.map((t) => _chip(t, _purpleColor)).toList(),
              ),
            ],
            Container(height: 1, color: _lightGrayColor, margin: const EdgeInsets.symmetric(vertical: 16)),
            if ((activity.description ?? '').isNotEmpty) ...[
              Text(
                activity.description!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF444444), height: 1.4),
                maxLines: 3, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _editActivity(activity),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purpleColor, foregroundColor: _whiteColor,
                      ),
                      child: const Text("Edit"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _deleteActivity(activity),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _redColor, foregroundColor: _whiteColor,
                      ),
                      child: const Text("Delete"),
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

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Text(text,
            style: TextStyle(color: _whiteColor, fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _buildAddButton() => FloatingActionButton(
        onPressed: _createActivity,
        backgroundColor: _purpleColor,
        foregroundColor: _whiteColor,
        child: const Icon(Icons.add),
      );

  // ───────── Data methods ─────────
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load activities: $e')),
      );
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
        await _db.collection(_COLLECTION_ACTIVITIES).doc(_editingActivity!.id).set(data);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save activity: $e')),
      );
    }
  }

  void _deleteActivity(Activity a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete activity: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ───────── Activity model & form dialog (unchanged from your version) ─────────

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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.activity != null ? "Edit Activity" : "Create New Activity",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Title
                const Text("Title *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(hintText: "Activity Title *", border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Activity title is required' : null,
                ),
                const SizedBox(height: 16),

                // Summary
                const Text("Summary *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _summaryController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: "Summary *", border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Summary is required' : null,
                ),
                const SizedBox(height: 16),

                // Category / Difficulty / Duration
                Row(
                  children: [
                    Expanded(child: _dropdown("Category", widget.categories, _selectedCategory, (v) => setState(() => _selectedCategory = v))),
                    const SizedBox(width: 16),
                    Expanded(child: _dropdown("Difficulty", widget.difficulties, _selectedDifficulty, (v) => setState(() => _selectedDifficulty = v))),
                    const SizedBox(width: 16),
                    Expanded(child: _dropdown("Duration", widget.durations, _selectedDuration, (v) => setState(() => _selectedDuration = v))),
                  ],
                ),
                const SizedBox(height: 16),

                // Image URL
                const Text("Image URL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _imageController,
                  decoration: const InputDecoration(hintText: "Image URL", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),

                // Description
                const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: "Full Description", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),

                // Requires Auth Checkbox
                CheckboxListTile(
                  title: const Text("Requires User Authentication"),
                  value: _requiresAuth,
                  onChanged: (v) => setState(() => _requiresAuth = v ?? false),
                ),
                const SizedBox(height: 16),

                // Tags
                const Text("Additional Tags", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            decoration: const InputDecoration(hintText: "Enter tag", border: OutlineInputBorder()),
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
                  onPressed: () => setState(() => _tagControllers.add(TextEditingController())),
                  child: const Text("+ Add Tag"),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel"))),
                    const SizedBox(width: 16),
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

  Widget _dropdown(String label, List<String> options, String? value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value ?? options.first,
          items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
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
