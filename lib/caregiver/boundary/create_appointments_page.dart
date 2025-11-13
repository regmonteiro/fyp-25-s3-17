import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_profile.dart';
import '../controller/create_appointments_controller.dart';
import '../../assistant_chat.dart';

class CreateAppointmentsPage extends StatefulWidget {
  final UserProfile userProfile;
  final String? elderlyId;

  const CreateAppointmentsPage({
    Key? key,
    required this.userProfile,
    this.elderlyId,
  }) : super(key: key);

  @override
  State<CreateAppointmentsPage> createState() => _CreateAppointmentsPageState();
}

class _CreateAppointmentsPageState extends State<CreateAppointmentsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final CreateAppointmentsController _controller = CreateAppointmentsController();

  String? _selectedElderId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Duration _selectedDuration = const Duration(minutes: 30);
  String _appointmentType = 'appointment';
  bool _isAllDay = false;

  final List<String> _appointmentTypes = const [
    'appointment',
    'task',
    'reminder',
  ];

  final List<Duration> _durations = const [
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  bool _busy = false;            // for create/update
  String? _editingId;            // null = create mode, non-null = edit mode

  @override
  void initState() {
    super.initState();
    _selectedElderId = widget.elderlyId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    final caregiverUid = widget.userProfile.uid;
    if (_selectedElderId == null || _selectedElderId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an elder.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _isAllDay ? 0 : _selectedTime.hour,
        _isAllDay ? 0 : _selectedTime.minute,
      );

      if (_editingId == null) {
        // CREATE
        await _controller.createAppointment(
          appointmentId: null,
          elderlyId: _selectedElderId!,
          caregiverId: caregiverUid,
          title: _titleController.text,
          description: _descController.text,
          dateTime: dateTime,
          type: _appointmentType,
          isAllDay: _isAllDay,
          duration: _isAllDay ? const Duration(hours: 24) : _selectedDuration,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment created for elder & caregiver.')),
        );

        // reset form
        setState(() {
          _titleController.clear();
          _descController.clear();
          _appointmentType = 'appointment';
          _isAllDay = false;
          _selectedDuration = const Duration(minutes: 30);
          _selectedDate = DateTime.now();
          _selectedTime = TimeOfDay.now();
        });
      } else {
        // UPDATE
        await _controller.updateAppointment(
          appointmentId: _editingId!,
          elderlyId: _selectedElderId!,
          caregiverId: caregiverUid,
          title: _titleController.text,
          description: _descController.text,
          dateTime: dateTime,
          type: _appointmentType,
          isAllDay: _isAllDay,
          duration: _isAllDay ? const Duration(hours: 24) : _selectedDuration,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment updated.')),
        );

        setState(() {
          _editingId = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _loadIntoForm(Map<String, dynamic> data, String id) {
    final dateStr = (data['date'] ?? '').toString();
    final timeStr = (data['time'] ?? '').toString();
    final type = (data['type'] ?? 'appointment').toString();
    final isAllDay = data['isAllDay'] == true;
    final durMin = (data['durationMinutes'] as int?) ?? 30;

    DateTime date;
    TimeOfDay time;
    try {
      final parts = dateStr.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      date = DateTime(year, month, day);
    } catch (_) {
      date = DateTime.now();
    }

    if (isAllDay) {
      time = const TimeOfDay(hour: 0, minute: 0);
    } else {
      try {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final min = int.parse(parts[1]);
        time = TimeOfDay(hour: hour, minute: min);
      } catch (_) {
        time = TimeOfDay.now();
      }
    }

    setState(() {
      _editingId = id;
      _titleController.text = (data['title'] ?? '').toString();
      _descController.text = (data['notes'] ?? '').toString();
      _appointmentType = type;
      _isAllDay = isAllDay;
      _selectedDate = date;
      _selectedTime = time;
      _selectedDuration = Duration(minutes: durMin);
      _selectedElderId = (data['elderlyId'] ?? _selectedElderId).toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final caregiverUid = widget.userProfile.uid;

    return Scaffold(
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
      appBar: AppBar(
        title: Text(_editingId == null ? 'Create Appointment' : 'Edit Appointment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ───────────── Linked elders dropdown with NAMES ─────────────
              _elderDropdown(caregiverUid),

              const SizedBox(height: 16),

              // ───────────── Title ─────────────
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title required' : null,
              ),

              const SizedBox(height: 16),

              // ───────────── Notes ─────────────
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // ───────────── Type ─────────────
              DropdownButtonFormField<String>(
                value: _appointmentType,
                items: _appointmentTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _appointmentType = v ?? 'appointment'),
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // ───────────── Date ─────────────
              ListTile(
                title: Text(
                  'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),

              // ───────────── All day ─────────────
              SwitchListTile(
                title: const Text('All Day'),
                value: _isAllDay,
                onChanged: (v) => setState(() => _isAllDay = v),
              ),

              // ───────────── Time & Duration if not all day ─────────────
              if (!_isAllDay) ...[
                ListTile(
                  title: Text('Time: ${_selectedTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: _selectTime,
                ),
                DropdownButtonFormField<Duration>(
                  value: _selectedDuration,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                  ),
                  items: _durations
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text('${d.inMinutes} min'),
                        ),
                      )
                      .toList(),
                  onChanged: (d) => setState(
                    () => _selectedDuration = d ?? const Duration(minutes: 30),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ───────────── Create / Save button ─────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_editingId == null ? 'Create Appointment' : 'Save Changes'),
                ),
              ),

              if (_editingId != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _editingId = null;
                        _titleController.clear();
                        _descController.clear();
                        _appointmentType = 'appointment';
                        _isAllDay = false;
                        _selectedDuration = const Duration(minutes: 30);
                        _selectedDate = DateTime.now();
                        _selectedTime = TimeOfDay.now();
                      });
                    },
                    child: const Text('Cancel editing'),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              Text(
                'Your appointments (caregiver & elders)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              _appointmentsList(caregiverUid),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────── Elder dropdown (with names) ──────────────────────

  Widget _elderDropdown(String caregiverUid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Account')
          .doc(caregiverUid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Text(
            'Caregiver account not found.',
            style: TextStyle(color: Colors.red),
          );
        }

        final data = snap.data!.data() ?? {};
        final elderlyIds =
            (data['elderlyIds'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

        if (elderlyIds.isEmpty) {
          return const Text(
            'No linked elders found.',
            style: TextStyle(color: Colors.red),
          );
        }

        // Fetch elder Account docs to get names
        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('Account')
              .where('uid', whereIn: elderlyIds.length > 10 ? elderlyIds.sublist(0, 10) : elderlyIds)
              .get(),
          builder: (context, accSnap) {
            if (accSnap.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            final docs = accSnap.data?.docs ?? [];

            // Build map uid -> display label
            final labelByUid = <String, String>{};
            for (final d in docs) {
              final m = d.data();
              final uid = (m['uid'] ?? d.id).toString();
              String? display = (m['displayName'] as String?)?.trim();
              final first = (m['firstName'] as String?)?.trim() ??
                  (m['firstname'] as String?)?.trim();
              final last = (m['lastName'] as String?)?.trim() ??
                  (m['lastname'] as String?)?.trim();

              if (display == null || display.isEmpty) {
                display = [first, last].where((e) => (e ?? '').isNotEmpty).join(' ').trim();
              }
              labelByUid[uid] =
                  (display == null || display.isEmpty) ? uid : display;
            }

            // ensure selected value is valid
            String value;
            if (_selectedElderId != null && elderlyIds.contains(_selectedElderId)) {
              value = _selectedElderId!;
            } else {
              value = elderlyIds.first;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _selectedElderId = value);
              });
            }

            return DropdownButtonFormField<String>(
              value: value,
              decoration: const InputDecoration(
                labelText: 'Select Elder',
                border: OutlineInputBorder(),
              ),
              items: elderlyIds
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Text(labelByUid[id] ?? id),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedElderId = val),
            );
          },
        );
      },
    );
  }

  // ────────────────────── Appointments list (bottom) ──────────────────────

  Widget _appointmentsList(String caregiverUid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _controller.appointmentsStreamOrdered(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Failed to load appointments: ${snap.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final allDocs = snap.data?.docs ?? const [];
        // Filter by caregiver and (optionally) by selected elder
        final docs = allDocs.where((d) {
          final data = d.data();
          final cgId = (data['caregiverId'] ?? '').toString();
          if (cgId != caregiverUid) return false;
          if (_selectedElderId == null || _selectedElderId!.isEmpty) return true;
          final eId = (data['elderlyId'] ?? '').toString();
          return eId == _selectedElderId;
        }).toList();

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No appointments yet.'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final title = (data['title'] ?? '').toString();
            final notes = (data['notes'] ?? '').toString();
            final type = (data['type'] ?? 'appointment').toString();
            final date = (data['date'] ?? '').toString();
            final time = (data['time'] ?? '').toString();
            final isAllDay = data['isAllDay'] == true;
            final elderlyId = (data['elderlyId'] ?? '').toString();

            final subtitle = StringBuffer()
              ..write(isAllDay ? 'All day • ' : '')
              ..write(type)
              ..write(' • ')
              ..write('$date')
              ..write(isAllDay ? '' : ' $time');

            if (notes.isNotEmpty) {
              subtitle.write('\n$notes');
            }

            return Card(
              child: ListTile(
                leading: const Icon(Icons.event_note),
                title: Text(
                  title.isEmpty ? '(no title)' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  subtitle.toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _loadIntoForm(data, doc.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Editing appointment…'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete),
                      color: Colors.red.shade400,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete appointment'),
                            content: const Text(
                              'Delete this appointment and its reminders/notifications '
                              'for caregiver and elder?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;

                        await _controller.deleteAppointment(
                          appointmentId: doc.id,
                          elderlyId: elderlyId,
                          caregiverId: caregiverUid,
                        );

                        if (_editingId == doc.id) {
                          setState(() => _editingId = null);
                        }

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Appointment deleted.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
