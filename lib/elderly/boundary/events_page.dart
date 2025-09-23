import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../controller/events_controller.dart';
import 'package:table_calendar/table_calendar.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({Key? key}) : super(key: key);

  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final EventsController _controller = EventsController();
  final _auth = FirebaseAuth.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('User not authenticated.'));
    }

    final String userId = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Calendar'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCalendar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextFormField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search events',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildSearchSuggestions(userId),
            const SizedBox(height: 16),
            const Text(
              'Upcoming Events',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _buildUpcomingEventsList(userId),
            const SizedBox(height: 16),
            _buildAppointmentsList(userId),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, userId),
        icon: const Icon(Icons.add),
        label: const Text('Add Task/Appointment'),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      focusedDay: _focusedDay,
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      selectedDayPredicate: (day) {
        return _selectedDay != null && isSameDay(_selectedDay!, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.lightBlue,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions(String userId) {
    if (_searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _controller.getAppointmentsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading suggestions.'));
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allAppointments = snapshot.data!.docs;
        final suggestions = allAppointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title']?.toLowerCase() ?? '';
          final description = data['description']?.toLowerCase() ?? '';
          final type = data['type']?.toLowerCase() ?? '';
          final searchQueryLower = _searchQuery.toLowerCase();
          return title.contains(searchQueryLower) ||
                 description.contains(searchQueryLower) ||
                 type.contains(searchQueryLower);
        }).toList();

        if (suggestions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('No matching suggestions.'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final appointment = suggestions[index];
            final data = appointment.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['title']),
              subtitle: Text(data['description'] ?? ''),
              onTap: () {
                setState(() {
                  _searchController.text = data['title'];
                  _searchQuery = data['title'];
                  _selectedDay = (data['dateTime'] as Timestamp).toDate();
                  _focusedDay = _selectedDay!;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingEventsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _controller.getUpcomingEventsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No upcoming events.'));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final appointment = snapshot.data!.docs[index];
            final appointmentData = appointment.data() as Map<String, dynamic>;
            final date = DateFormat('MMM d, yyyy').format((appointmentData['dateTime'] as Timestamp).toDate());
            final time = appointmentData['isAllDay'] ? 'All Day' : DateFormat('h:mm a').format((appointmentData['dateTime'] as Timestamp).toDate());
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(appointmentData['title']),
                subtitle: Text('${appointmentData['description']} - $date, $time'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showUpdateDialog(context, userId, appointment.id, appointmentData),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _controller.deleteAppointment(elderlyUserId: userId, appointmentId: appointment.id),
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

  Widget _buildAppointmentsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _controller.getAppointmentsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No appointments on this day.'));
        }

        final allAppointments = snapshot.data!.docs;
        final filteredAppointments = allAppointments.where((doc) {
          final appointmentData = doc.data() as Map<String, dynamic>;
          final docDate = (appointmentData['dateTime'] as Timestamp).toDate();
          final title = appointmentData['title']?.toLowerCase() ?? '';
          final description = appointmentData['description']?.toLowerCase() ?? '';
          final type = appointmentData['type']?.toLowerCase() ?? '';
          final searchQueryLower = _searchQuery.toLowerCase();

          final matchesSearch = title.contains(searchQueryLower) ||
              description.contains(searchQueryLower) ||
              type.contains(searchQueryLower);
          
          final matchesSelectedDay = _selectedDay != null && isSameDay(docDate, _selectedDay!);
          
          return matchesSearch && matchesSelectedDay;
        }).toList();

        if (filteredAppointments.isEmpty) {
          return const Center(child: Text('No matching appointments found.'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredAppointments.length,
          itemBuilder: (context, index) {
            final appointment = filteredAppointments[index];
            final appointmentData = appointment.data() as Map<String, dynamic>;
            final time = appointmentData['isAllDay'] ? 'All Day' : DateFormat('h:mm a').format((appointmentData['dateTime'] as Timestamp).toDate());
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(appointmentData['title']),
                subtitle: Text('${appointmentData['description']} - $time'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showUpdateDialog(context, userId, appointment.id, appointmentData),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _controller.deleteAppointment(elderlyUserId: userId, appointmentId: appointment.id),
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

  void _showCreateDialog(BuildContext context, String userId) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? selectedDate = _selectedDay;
    TimeOfDay? selectedTime = TimeOfDay.now();
    int durationMinutes = 30; // Default duration
    String selectedType = 'Appointment';
    bool isAllDay = false;
    final List<String> quickDescriptions = ['Doctor Appointment', 'Medication', 'Walk the dog', 'Grocery shopping', 'Family call'];
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Item', textAlign: TextAlign.center),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Quick Descriptions', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Wrap(
                      spacing: 8.0,
                      children: quickDescriptions.map((desc) {
                        return ActionChip(
                          label: Text(desc),
                          onPressed: () {
                            descriptionController.text = desc;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField(
                      value: selectedType,
                      items: ['Appointment', 'Task', 'Event'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value.toString();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    CheckboxListTile(
                      title: const Text("All Day Event"),
                      value: isAllDay,
                      onChanged: (bool? value) {
                        setState(() {
                          isAllDay = value ?? false;
                          if (isAllDay) {
                            selectedTime = TimeOfDay(hour: 0, minute: 0);
                            durationMinutes = 1440; // 24 hours
                          }
                        });
                      },
                    ),
                    ListTile(
                      title: Text(selectedDate == null ? 'Select Date' : DateFormat('MMM d, yyyy').format(selectedDate!)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                    if (!isAllDay)
                      ListTile(
                        title: Text(selectedTime == null ? 'Select Time' : selectedTime!.format(context)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              selectedTime = pickedTime;
                            });
                          }
                        },
                      ),
                    if (!isAllDay)
                      Row(
                        children: [
                          const Text('Duration:'),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: durationMinutes,
                            items: const [15, 30, 45, 60, 90, 120].map((minutes) {
                              return DropdownMenuItem<int>(
                                value: minutes,
                                child: Text('$minutes min'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                if (value != null) {
                                  durationMinutes = value;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty && selectedDate != null && selectedTime != null) {
                      final finalDateTime = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      await _controller.createAppointment(
                        elderlyUserId: userId,
                        title: titleController.text,
                        description: descriptionController.text,
                        dateTime: finalDateTime,
                        type: selectedType,
                        isAllDay: isAllDay,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _showUpdateDialog(BuildContext context, String userId, String appointmentId, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title']);
    final descriptionController = TextEditingController(text: data['description']);
    DateTime? selectedDate = (data['dateTime'] as Timestamp).toDate();
    TimeOfDay? selectedTime = TimeOfDay.fromDateTime(selectedDate);
    String selectedType = data['type'];
    bool isAllDay = data['isAllDay'] ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField(
                      value: selectedType,
                      items: ['Appointment', 'Task', 'Event'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value.toString();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    CheckboxListTile(
                      title: const Text("All Day Event"),
                      value: isAllDay,
                      onChanged: (bool? value) {
                        setState(() {
                          isAllDay = value ?? false;
                          if (isAllDay) {
                            selectedTime = TimeOfDay(hour: 0, minute: 0);
                          }
                        });
                      },
                    ),
                    ListTile(
                      title: Text(selectedDate == null ? 'Select Date' : DateFormat('MMM d, yyyy').format(selectedDate!)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                    if (!isAllDay)
                      ListTile(
                        title: Text(selectedTime == null ? 'Select Time' : selectedTime!.format(context)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              selectedTime = pickedTime;
                            });
                          }
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty && selectedDate != null && selectedTime != null) {
                      final finalDateTime = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      await _controller.updateAppointment(
                        elderlyUserId: userId,
                        appointmentId: appointmentId,
                        title: titleController.text,
                        description: descriptionController.text,
                        dateTime: finalDateTime,
                        type: selectedType,
                        isAllDay: isAllDay,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}