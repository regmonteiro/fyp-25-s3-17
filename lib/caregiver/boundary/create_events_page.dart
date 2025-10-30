import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../controller/create_events_controller.dart';

class CreateEventsPage extends StatefulWidget {
  final UserProfile userProfile;
  final String? elderlyId;

  const CreateEventsPage({Key? key, required this.userProfile, this.elderlyId}) : super(key: key);

  @override
  State<CreateEventsPage> createState() => _CreateEventsPageState();
}

class _CreateEventsPageState extends State<CreateEventsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CreateEventsController _controller = CreateEventsController();

  String? _selectedElderId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Duration _selectedDuration = const Duration(minutes: 30);
  String _eventType = 'appointment';
  bool _isAllDay = false;

  final List<String> _eventTypes = const ['appointment', 'task', 'reminder'];
  final List<Duration> _durations = const [
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 3),
    Duration(hours: 4),
  ];

  @override
  void initState() {
    super.initState();
    _selectedElderId = widget.elderlyId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<String> _elderName(String elderId) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('Account').doc(elderId).get();
      final data = snap.data() ?? {};
      final dn = (data['safeDisplayName'] ?? data['displayName'])?.toString().trim();
      if (dn != null && dn.isNotEmpty) return dn;
      final fn = (data['firstName'] ?? data['firstname'])?.toString().trim() ?? '';
      final ln = (data['lastName'] ?? data['lastname'])?.toString().trim() ?? '';
      final full = [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();
      if (full.isNotEmpty) return full;
    } catch (_) {}
    return '${elderId.substring(0, 8)}…';
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedElderId == null || _selectedElderId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an elder.')));
      return;
    }

    // Extra guard: ensure elder is actually linked to this caregiver
    final caregiverUid = widget.userProfile.uid;
    final cgSnap = await FirebaseFirestore.instance.collection('Account').doc(caregiverUid).get();
    final cg = cgSnap.data() ?? {};
    final linked = (cg['elderlyIds'] is List)
        ? (cg['elderlyIds'] as List).map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toSet()
        : <String>{};
    if (!linked.contains(_selectedElderId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected elder is not linked to your account.')),
      );
      return;
    }

    final DateTime baseDateTime = _isAllDay
        ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0)
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);

    try {
      await _controller.createAppointment(
        elderlyId: _selectedElderId!,
        caregiverId: widget.userProfile.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dateTime: baseDateTime,
        type: _eventType,
        isAllDay: _isAllDay,
        duration: _isAllDay ? const Duration(hours: 24) : _selectedDuration,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created successfully!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final caregiverUid = widget.userProfile.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Event'), backgroundColor: Colors.blue),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Elder selection from Account/{caregiverUid}.elderlyIds  (canonical field)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('Account').doc(caregiverUid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: LinearProgressIndicator());
                  }

                  final cg = snapshot.data?.data() ?? {};
                  final elderlyIds = (cg['elderlyIds'] is List)
                      ? (cg['elderlyIds'] as List)
                          .map((e) => e.toString().trim())
                          .where((s) => s.isNotEmpty)
                          .toList()
                      : const <String>[];

                  if (elderlyIds.isEmpty) {
                    return const Text('No elders linked to your account.', style: TextStyle(color: Colors.red));
                  }

                  // Default dropdown value if not set yet
                  final initial = _selectedElderId != null && elderlyIds.contains(_selectedElderId)
                      ? _selectedElderId
                      : (widget.elderlyId != null && elderlyIds.contains(widget.elderlyId)
                          ? widget.elderlyId
                          : elderlyIds.first);

                  // keep state in sync
                  if (_selectedElderId != initial) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedElderId = initial);
                    });
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedElderId,
                    decoration: InputDecoration(
                      labelText: 'Select Elder',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: elderlyIds.map<DropdownMenuItem<String>>((elderId) {
                      return DropdownMenuItem<String>(
                        value: elderId,
                        child: FutureBuilder<String>(
                          future: _elderName(elderId),
                          builder: (context, nameSnap) {
                            final label = nameSnap.data ?? '${elderId.substring(0, 8)}…';
                            return Text(label);
                          },
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedElderId = val),
                    validator: (v) => (v == null || v.isEmpty) ? 'Please select an elder' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _eventType,
                decoration: InputDecoration(
                  labelText: 'Event Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _eventTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) => setState(() => _eventType = val ?? 'appointment'),
              ),
              const SizedBox(height: 16),

              ListTile(
                title: const Text('Date'),
                subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Text('All Day Event'),
                  const Spacer(),
                  Switch(
                    value: _isAllDay,
                    onChanged: (val) => setState(() => _isAllDay = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!_isAllDay) ...[
                ListTile(
                  title: const Text('Time'),
                  subtitle: Text(_selectedTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<Duration>(
                  value: _selectedDuration,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _durations
                      .map((d) => DropdownMenuItem(value: d, child: Text('${d.inMinutes} minutes')))
                      .toList(),
                  onChanged: (d) => setState(() => _selectedDuration = d ?? const Duration(minutes: 30)),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: _createEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Event', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
