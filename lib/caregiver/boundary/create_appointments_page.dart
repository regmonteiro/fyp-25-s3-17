import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../controller/create_appointments_controller.dart';
import '../../assistant_chat.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateAppointmentsPage extends StatefulWidget {
  final UserProfile userProfile;
  final String? elderlyId;

  const CreateAppointmentsPage({Key? key, required this.userProfile, this.elderlyId})
      : super(key: key);

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

  final List<String> _appointmentTypes = const ['appointment', 'task', 'reminder'];
  final List<Duration> _durations = const [
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  @override
  void initState() {
    super.initState();
    _selectedElderId = widget.elderlyId;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _createAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    final caregiverUid = widget.userProfile.uid;
    if (_selectedElderId == null || _selectedElderId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an elder.')));
      return;
    }

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _isAllDay ? 0 : _selectedTime.hour,
        _isAllDay ? 0 : _selectedTime.minute,
      );

      await _controller.createAppointment(
        elderlyId: _selectedElderId!,
        caregiverId: caregiverUid,
        title: _titleController.text,
        description: _descController.text,
        dateTime: dateTime,
        type: _appointmentType,
        isAllDay: _isAllDay,
        duration: _selectedDuration,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment created successfully!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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


      appBar: AppBar(title: const Text('Create Appointment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Account')
                    .doc(caregiverUid)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final data = snap.data!.data() ?? {};
                  final elderlyIds = (data['elderlyIds'] as List?)?.cast<String>() ?? [];
                  if (elderlyIds.isEmpty) {
                    return const Text('No linked elders found.',
                        style: TextStyle(color: Colors.red));
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedElderId ?? elderlyIds.first,
                    decoration: const InputDecoration(
                        labelText: 'Select Elder', border: OutlineInputBorder()),
                    items: elderlyIds
                        .map((id) =>
                            DropdownMenuItem(value: id, child: Text(id)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedElderId = val),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                    labelText: 'Notes', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _appointmentType,
                items: _appointmentTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _appointmentType = v ?? 'appointment'),
                decoration: const InputDecoration(
                    labelText: 'Type', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                    'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),
              SwitchListTile(
                title: const Text('All Day'),
                value: _isAllDay,
                onChanged: (v) => setState(() => _isAllDay = v),
              ),
              if (!_isAllDay) ...[
                ListTile(
                  title: Text('Time: ${_selectedTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: _selectTime,
                ),
                DropdownButtonFormField<Duration>(
                  value: _selectedDuration,
                  decoration: const InputDecoration(
                      labelText: 'Duration', border: OutlineInputBorder()),
                  items: _durations
                      .map((d) => DropdownMenuItem(
                          value: d, child: Text('${d.inMinutes} min')))
                      .toList(),
                  onChanged: (d) => setState(
                      () => _selectedDuration = d ?? const Duration(minutes: 30)),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createAppointment,
                child: const Text('Create Appointment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
