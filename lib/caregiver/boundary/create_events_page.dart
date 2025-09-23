import 'package:flutter/material.dart';
import '../controller/create_events_controller.dart';
import '../../models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateEventsPage extends StatefulWidget {
  final UserProfile userProfile;
  final String? elderlyId;

  const CreateEventsPage({Key? key, required this.userProfile, this.elderlyId}) : super(key: key);

  @override
  _CreateEventsPageState createState() => _CreateEventsPageState();
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

  final List<String> _eventTypes = ['appointment', 'task', 'reminder'];
  final List<Duration> _durations = [
    const Duration(minutes: 30),
    const Duration(hours: 1),
    const Duration(hours: 2),
    const Duration(hours: 3),
    const Duration(hours: 4),
  ];

  @override
  void initState() {
    super.initState();
    _selectedElderId = widget.elderlyId;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _createEvent() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedElderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an elder.')),
        );
        return;
      }

      DateTime finalDateTime = _selectedDate;
      if (!_isAllDay) {
        finalDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      }

      await _controller.createAppointment(
        elderlyId: _selectedElderId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dateTime: finalDateTime,
        type: _eventType,
        isAllDay: _isAllDay,
        caregiverId: widget.userProfile.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Event'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // New: Elder Selection Dropdown
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userProfile.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data?.data()?['linkedElders'] == null) {
                    return const CircularProgressIndicator();
                  }

                  final linkedElders = snapshot.data!.data()?['linkedElders'] as List<dynamic>;

                  if (linkedElders.isEmpty) {
                    return const Text('No elders linked to your account.', style: TextStyle(color: Colors.red));
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedElderId,
                    decoration: InputDecoration(
                      labelText: 'Select Elder',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: linkedElders.map<DropdownMenuItem<String>>((elderId) {
                      return DropdownMenuItem<String>(
                        value: elderId,
                        child: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(elderId).get(),
                          builder: (context, elderSnapshot) {
                            if (!elderSnapshot.hasData) {
                              return const Text('Loading...');
                            }
                            final elderName = elderSnapshot.data?.get('displayName') ?? 'Elder';
                            return Text(elderName);
                          },
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedElderId = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Please select an elder' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _eventType,
                decoration: InputDecoration(
                  labelText: 'Event Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _eventTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _eventType = newValue!;
                  });
                },
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
                    onChanged: (bool value) {
                      setState(() {
                        _isAllDay = value;
                      });
                    },
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _durations.map((Duration duration) {
                    return DropdownMenuItem<Duration>(
                      value: duration,
                      child: Text('${duration.inMinutes} minutes'),
                    );
                  }).toList(),
                  onChanged: (Duration? newValue) {
                    setState(() {
                      _selectedDuration = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _createEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create Event',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}