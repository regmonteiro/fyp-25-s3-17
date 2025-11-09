// lib/pages/view_activities_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/activities_service.dart';
import '../../assistant_chat.dart';

class ViewActivitiesPage extends StatefulWidget {
  const ViewActivitiesPage({
    super.key,
    this.isElderlyOverride,
  });

  /// If your app already knows the role, pass it here.
  /// Otherwise the page will default to `false` for non-null users.
  final bool? isElderlyOverride;

  @override
  State<ViewActivitiesPage> createState() => _ViewActivitiesPageState();
}

class _ViewActivitiesPageState extends State<ViewActivitiesPage> {
  final _svc = ActivitiesService();

  // ui state
  String _activeTab = 'activities'; // 'activities' | 'registrations'
  String _query = '';
  String _sortBy = 'title'; // title | category | difficulty
  bool _loading = true;

  // data
  List<Activity> _activities = [];
  List<ActivityRegistration> _registrations = [];

  // register panel state
  String? _registeringId;
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;

  // modal
  Activity? _selectedActivity;

  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _email => _user?.email;

  bool get _isAuthenticated => _user != null;

  bool get _isElderly {
    // Use override if provided; else you can wire your own lookup.
    return widget.isElderlyOverride ?? false;
  }

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchAllActivities();
      setState(() => _activities = list);
    } catch (e) {
      debugPrint('Error loading activities: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load activities: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRegistrations() async {
    if (_email == null) return;
    setState(() => _loading = true);
    try {
      final regs = await _svc.getUserRegistrations(_email!);
      setState(() => _registrations = regs);
    } catch (e) {
      debugPrint('Error loading registrations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load registrations: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Activity> get _filteredSortedActivities {
  final q = _query.trim().toLowerCase();

  final f = _activities
      .where((a) => a.title.toLowerCase().contains(q))
      .toList();

  int cmp(String lhs, String rhs) =>
      lhs.toLowerCase().compareTo(rhs.toLowerCase());

  switch (_sortBy) {
    case 'category':
      f.sort((a, b) {
        final c = cmp(a.category, b.category);
        return c != 0 ? c : cmp(a.title, b.title); // tie-breaker
      });
      break;

    case 'difficulty':
      f.sort((a, b) {
        final c = cmp(a.difficulty, b.difficulty);
        return c != 0 ? c : cmp(a.title, b.title);
      });
      break;

    default:
      f.sort((a, b) => cmp(a.title, b.title));
  }
  return f;
}

  bool _isPastSelection(DateTime? d, TimeOfDay? t) {
    if (d == null || t == null) return false;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    return dt.isBefore(DateTime.now());
  }


  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _pickedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pickedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _pickedTime = picked);
  }

  Future<void> _toggleRegisterPanel(Activity a) async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to register for activities.')),
      );
      return;
    }
    if (!_isElderly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only elderly users can register for activities.')),
      );
      return;
    }
    setState(() {
      _registeringId = (_registeringId == a.id) ? null : a.id;
      _pickedDate = null;
      _pickedTime = null;
    });
  }

  Future<void> _confirmRegister(Activity a) async {
    if (_email == null) return;
    if (_pickedDate == null || _pickedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time.')),
      );
      return;
    }
    if (_isPastSelection(_pickedDate, _pickedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot register for past dates/times.')),
      );
      return;
    }

    final date = '${_pickedDate!.year.toString().padLeft(4, '0')}-'
        '${_pickedDate!.month.toString().padLeft(2, '0')}-'
        '${_pickedDate!.day.toString().padLeft(2, '0')}';

    final time = '${_pickedTime!.hour.toString().padLeft(2, '0')}:'
        '${_pickedTime!.minute.toString().padLeft(2, '0')}';

    try {
      final msg = await _svc.registerForActivity(
        activityId: a.id,
        userEmail: _email!,
        date: date,
        time: time,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        setState(() {
          _registeringId = null;
          _pickedDate = null;
          _pickedTime = null;
        });
        if (_activeTab == 'registrations') {
          _loadRegistrations();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _cancelRegistration(ActivityRegistration r) async {
    if (r.isPast) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot cancel a past event.')),
      );
      return;
    }
    await _svc.cancelRegistration(activityId: r.activityId, registrationId: r.registrationId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration cancelled.')),
      );
      _loadRegistrations();
    }
  }

  // UI bits
  Widget _hero() {
    // You can replace this with an AssetImage for your hero
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        'https://images.unsplash.com/photo-1518611012118-696072aa579a?q=80&w=1600',
        height: MediaQuery.of(context).size.height * 0.35,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  void _openDetails(Activity a) {
    setState(() => _selectedActivity = a);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (a.image.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(a.image, height: 250, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(a.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  a.description.isNotEmpty ? a.description : (a.summary.isNotEmpty ? a.summary : 'No description available.'),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (a.category.isNotEmpty) _chip(a.category),
                    if (a.difficulty.isNotEmpty) _chip(a.difficulty),
                    if (a.duration.isNotEmpty) _chip(a.duration),
                  ],
                ),
              ),
              if (a.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: a.tags.map((t) => _tag('#$t')).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 12),
                    if (_isAuthenticated && _isElderly)
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _toggleRegisterPanel(a);
                        },
                        child: const Text('Register Now'),
                      ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    ).then((_) => setState(() => _selectedActivity = null));
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xfff0f4ff),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xff2d6cdf), fontWeight: FontWeight.w600)),
      );

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xfff8f9fa),
          border: Border.all(color: const Color(0xffe9ecef)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xff495057))),
      );

  // Tabs
  Widget _activitiesTab() {
    final list = _filteredSortedActivities;
    return Column(
      children: [
        const SizedBox(height: 12),
        // toolbar
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 250, maxWidth: 420),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search activities…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffdddddd)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'title', child: Text('Title')),
                    DropdownMenuItem(value: 'category', child: Text('Category')),
                    DropdownMenuItem(value: 'difficulty', child: Text('Difficulty')),
                  ],
                  onChanged: (v) => setState(() => _sortBy = v ?? 'title'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // grid
        GridView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: list.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1, // change to 2/3 for wide screens if you like
            childAspectRatio: 3 / 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemBuilder: (_, i) {
            final a = list[i];
            return InkWell(
              onTap: () => _openDetails(a),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black12, offset: Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (a.image.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(a.image, height: 140, fit: BoxFit.cover),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(a.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (a.category.isNotEmpty) _chip(a.category),
                                if (a.difficulty.isNotEmpty) _chip(a.difficulty),
                                if (a.duration.isNotEmpty) _chip(a.duration),
                              ],
                            ),
                            const Spacer(),
                            if (_isAuthenticated && _isElderly)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: FilledButton(
                                  onPressed: () => _toggleRegisterPanel(a),
                                  child: Text(_registeringId == a.id ? 'Cancel' : 'Register'),
                                ),
                              ),
                            if (_registeringId == a.id && _isAuthenticated && _isElderly)
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xfff9f9f9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _pickDate,
                                          icon: const Icon(Icons.calendar_today),
                                          label: Text(_pickedDate == null
                                              ? 'Select Date'
                                              : '${_pickedDate!.year}-${_pickedDate!.month.toString().padLeft(2, '0')}-${_pickedDate!.day.toString().padLeft(2, '0')}'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: _pickTime,
                                          icon: const Icon(Icons.schedule),
                                          label: Text(_pickedTime == null
                                              ? 'Select Time'
                                              : '${_pickedTime!.hour.toString().padLeft(2, '0')}:${_pickedTime!.minute.toString().padLeft(2, '0')}'),
                                        ),
                                      ],
                                    ),
                                    if (_isPastSelection(_pickedDate, _pickedTime))
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Text('⚠️ Cannot register for past dates and times',
                                            style: TextStyle(color: Colors.red, fontSize: 12)),
                                      ),
                                    const SizedBox(height: 8),
                                    FilledButton(
                                      onPressed: (_pickedDate != null &&
                                              _pickedTime != null &&
                                              !_isPastSelection(_pickedDate, _pickedTime))
                                          ? () => _confirmRegister(a)
                                          : null,
                                      child: const Text('Confirm Registration'),
                                    )
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _registrationsTab() {
    if (!_isAuthenticated) {
      return _emptyState(
        title: 'Please log in to view your registrations',
        action: null,
      );
    }
    if (!_isElderly) {
      return _emptyState(title: 'Only elderly users can register for activities');
    }
    if (_loading) {
      return _emptyState(title: 'Loading your registrations…', subtitle: 'Please wait.');
    }
    if (_registrations.isEmpty) {
      return _emptyState(
        title: 'No registrations found',
        subtitle: 'You haven’t registered for any activities yet.',
        action: ElevatedButton(
          onPressed: () => setState(() => _activeTab = 'activities'),
          child: const Text('Browse Activities'),
        ),
      );
    }

    return Column(
      children: _registrations.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.activityImage.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(r.activityImage, width: 80, height: 80, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 80)),
                )
              else
                const SizedBox(width: 80, height: 80),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(r.activityTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (r.isPast)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xff6c757d),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PAST EVENT',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Date: ${r.date}  |  Time: ${r.time}', style: const TextStyle(color: Colors.black87)),
                    if (r.createdAt != null)
                      Text('Registered on: ${r.createdAt!.toLocal().toString().split(' ').first}',
                          style: const TextStyle(color: Colors.black54)),
                    Text('Status: ${r.status}', style: const TextStyle(color: Colors.black54)),
                    if (r.isPast)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('This activity has already occurred and cannot be cancelled.',
                            style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: r.isPast ? null : () => _cancelRegistration(r),
                style: ElevatedButton.styleFrom(backgroundColor: r.isPast ? Colors.grey : Colors.red),
                child: Text(r.isPast ? 'Event Passed' : 'Cancel'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyState({required String title, String? subtitle, Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, color: Colors.black87)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            action,
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTabs = _isAuthenticated && _isElderly;

    return Scaffold(
      backgroundColor: const Color(0xfffafafa),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _hero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  const Text('Activities on AllCare Platform',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text(
                    'Explore activities designed to engage, educate, and empower elderly users.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  if (showTabs)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Browse Activities'),
                          selected: _activeTab == 'activities',
                          onSelected: (_) => setState(() => _activeTab = 'activities'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('My Registrations'),
                          selected: _activeTab == 'registrations',
                          onSelected: (_) {
                            setState(() => _activeTab = 'registrations');
                            _loadRegistrations();
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (_activeTab == 'activities' || !showTabs)
                    _loading ? _emptyState(title: 'Loading activities…') : _activitiesTab(),
                  if (showTabs && _activeTab == 'registrations') _registrationsTab(),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    floatingActionButton: FloatingActionButton(
    backgroundColor: Colors.deepPurple,
    onPressed: () {
      final email = FirebaseAuth.instance.currentUser?.email ?? 'guest@allcare.ai';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssistantChat(userEmail: email),
        ),
      );
    },
    child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
  ),
);
  }
}
