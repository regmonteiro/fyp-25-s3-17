import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'controller/gp_appointment_controller.dart';

class ConsultationBookingPage extends StatefulWidget {
  final UserProfile userProfile;

  const ConsultationBookingPage({super.key, required this.userProfile});

  @override
  State<ConsultationBookingPage> createState() => _ConsultationBookingPageState();
}

class _ConsultationBookingPageState extends State<ConsultationBookingPage> {
  final _formKey = GlobalKey<FormState>();
  late final GpAppointmentController _ctrl;

  DateTime? _date;
  TimeOfDay? _time;
  Duration _duration = const Duration(minutes: 20);
  final _reasonCtrl = TextEditingController();
  bool _invitePrimaryCaregiver = false;

  // anti-double-tap
  bool _busy = false;

  // quick-reasons
  final Set<String> _selectedReasons = {};
  final _fallbackReasons = const [
    'Fever / Flu-like',
    'Cough / Sore throat',
    'Headache / Dizziness',
    'Medication refill',
    'Skin rash / irritation',
    'Stomach pain',
    'Follow-up consultation',
  ];

  // caregiver-aware state
  String? _userType;                       // 'elderly' | 'caregiver' | 'admin' | null
  List<String> _linkedElderlyIds = <String>[];
  String? _effectiveElderUid;              // which elder we’re booking for

  // editing existing appointment
  String? _editingApptId;                  // null = create mode, non-null = editing

  @override
  void initState() {
    super.initState();
    _ctrl = GpAppointmentController(mirrorToCaregivers: true);

    // default date/time (tomorrow 9am)
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _time = const TimeOfDay(hour: 9, minute: 0);

    // detect userType & prepare caregiver flow
    _ctrl.userTypeOf(widget.userProfile.uid).then((type) async {
      if (!mounted) return;
      setState(() => _userType = type);

      if (type == 'caregiver') {
        final ids = await _ctrl.fetchEldersForCaregiver(widget.userProfile.uid);
        if (!mounted) return;
        ids.sort();
        setState(() {
          _linkedElderlyIds = ids;
          _effectiveElderUid = ids.isNotEmpty ? ids.first : null;
        });
      } else {
        // elderly/self by default
        setState(() => _effectiveElderUid = widget.userProfile.uid);
      }
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  DateTime? _composeStart() {
    if (_date == null || _time == null) return null;
    return DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final start = _composeStart();
    if (start == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose date and time.')),
      );
      return;
    }

    // caregiver must pick a target elder
    final targetElderUid = _effectiveElderUid ?? widget.userProfile.uid;
    if (_userType == 'caregiver' &&
        (targetElderUid.isEmpty || !_linkedElderlyIds.contains(targetElderUid))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a linked elderly profile to book for.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final isEditing = _editingApptId != null;

      // confirm
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(isEditing ? 'Confirm changes' : 'Confirm booking'),
          content: Text(
            '${isEditing ? 'Update' : 'Book'} GP consultation on '
            '${DateFormat('EEE, MMM d, h:mm a').format(start)}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      BookingResult res;
      if (isEditing) {
        // UPDATE existing appointment
        res = await _ctrl.updateGpCall(
          elderlyId: targetElderUid,
          appointmentId: _editingApptId!,
          start: start,
          duration: _duration,
          reason: _reasonCtrl.text.trim(),
        );
      } else {
        // CREATE new appointment
        res = await _ctrl.bookFutureGpCall(
          elderlyId: targetElderUid,
          elderlyName: widget.userProfile.safeDisplayName,
          start: start,
          duration: _duration,
          reason: _reasonCtrl.text.trim(),
          invitePrimaryCaregiver: _invitePrimaryCaregiver,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.ok ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );

      if (res.ok) {
        setState(() {
          _editingApptId = null; // back to create mode
        });
        // For creates, you might want to pop. For editing, stay here.
        if (!isEditing) {
          Future.microtask(() {
            if (mounted) Navigator.of(context).maybePop();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // wait for userType detection once
    if (_userType == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final headerName = (_userType == 'caregiver' && _effectiveElderUid != null)
        ? 'Booking for linked elder: ${_effectiveElderUid!.substring(0, (_effectiveElderUid!.length >= 8 ? 8 : _effectiveElderUid!.length))}…'
        : widget.userProfile.safeDisplayName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book GP Consultation (Advance)'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(
              elevation: 3,
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Booking for:', style: TextStyle(color: Colors.black54)),
                  Text(
                    headerName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                  ),
                  const SizedBox(height: 8),
                  const Text('Pick a time and tell us the main reason. '
                      'We’ll set up a video GP call and remind you and your caregiver.'),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // caregiver-only: pick linked elder
            if (_userType == 'caregiver') ...[
              Text('Choose linked elderly', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (_linkedElderlyIds.isEmpty)
                Card(
                  color: Colors.orange.shade100,
                  child: const ListTile(
                    leading: Icon(Icons.person_off),
                    title: Text('No linked elderly profiles'),
                    subtitle: Text('Link an elderly profile before booking on their behalf.'),
                  ),
                )
              else if (_linkedElderlyIds.length == 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ChoiceChip(
                    selected: true,
                    onSelected: (_) {},
                    label: Text(_linkedElderlyIds.first),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _effectiveElderUid,
                  items: _linkedElderlyIds
                      .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _effectiveElderUid = v;
                      _editingApptId = null; // reset editing when switching elder
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Linked elderly',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            Row(children: [
              Expanded(
                child: _pickTile(
                  label: 'Date',
                  value: _date == null ? 'Choose date' : DateFormat('EEE, MMM d').format(_date!),
                  icon: Icons.calendar_today,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pickTile(
                  label: 'Time',
                  value: _time == null ? 'Choose time' : _time!.format(context),
                  icon: Icons.access_time,
                  onTap: _pickTime,
                ),
              ),
            ]),
            const SizedBox(height: 10),

            Row(
              children: [
                const Text('Duration:'),
                const SizedBox(width: 8),
                DropdownButton<Duration>(
                  value: _duration,
                  items: const [
                    DropdownMenuItem(value: Duration(minutes: 15), child: Text('15 min')),
                    DropdownMenuItem(value: Duration(minutes: 20), child: Text('20 min')),
                    DropdownMenuItem(value: Duration(minutes: 30), child: Text('30 min')),
                  ],
                  onChanged: (d) => setState(() => _duration = d ?? const Duration(minutes: 20)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Reasons for appointment', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            StreamBuilder<List<String>>(
              stream: _ctrl.quickReasonsStream(),
              builder: (_, snap) {
                final list = (snap.data == null || snap.data!.isEmpty) ? _fallbackReasons : snap.data!;
                return Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: list.map((reason) {
                    final isSelected = _selectedReasons.contains(reason);
                    return FilterChip(
                      label: Text(reason),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedReasons.add(reason);
                          } else {
                            _selectedReasons.remove(reason);
                          }
                          _reasonCtrl.text = _selectedReasons.join(', ');
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. “Persistent cough since yesterday”, “Medication refill”, …',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please select or enter a reason' : null,
            ),
            const SizedBox(height: 16),

            FutureBuilder<Map<String, String>?>(
              future: _ctrl.fetchPrimaryCaregiver(_effectiveElderUid ?? widget.userProfile.uid),
              builder: (_, careSnap) {
                final cg = careSnap.data;
                if (cg == null) {
                  return Card(
                    color: Colors.orange.shade100,
                    child: const ListTile(
                      leading: Icon(Icons.person_off),
                      title: Text('No caregiver linked'),
                      subtitle: Text('Link a caregiver to include them in reminders and the call invite.'),
                    ),
                  );
                }
                return CheckboxListTile(
                  value: _invitePrimaryCaregiver,
                  onChanged: (v) => setState(() => _invitePrimaryCaregiver = v ?? false),
                  title: Text('Invite caregiver (${cg['name']})'),
                  subtitle: const Text('They will receive the event/reminder and be invited to join the call.'),
                );
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(_editingApptId == null ? 'Confirm Booking' : 'Save Changes'),
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),

            if (_editingApptId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Editing existing appointment. Tap "Save Changes" or cancel editing below.',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _editingApptId = null;
                      _reasonCtrl.clear();
                      _selectedReasons.clear();
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
              'Upcoming & past appointments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _appointmentsList(),
          ]),
        ),
      ),
    );
  }

  Widget _appointmentsList() {
    final elderUid = _effectiveElderUid ?? widget.userProfile.uid;
    if (elderUid.isEmpty) {
      return const Text('No profile selected.');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ctrl.appointmentsStreamFor(elderUid),
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

        final docs = snap.data?.docs ?? const [];
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
            final ts = data['dateTime'] as Timestamp?;
            final start = ts?.toDate();
            final status = (data['status'] ?? 'scheduled').toString();
            final desc = (data['description'] ?? '').toString();
            final isCancelled = status.toLowerCase() == 'cancelled';

            final whenStr = (start == null)
                ? '(no time)'
                : DateFormat('EEE, MMM d, h:mm a').format(start);

            return Card(
              color: isCancelled ? Colors.grey.shade200 : Colors.white,
              child: ListTile(
                leading: Icon(
                  isCancelled ? Icons.event_busy : Icons.event_available,
                  color: isCancelled ? Colors.grey : Colors.teal,
                ),
                title: Text(
                  whenStr,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCancelled ? Colors.grey : Colors.black,
                  ),
                ),
                subtitle: Text(
                  '$status • $desc',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit),
                      color: isCancelled ? Colors.grey : Colors.blueGrey,
                      onPressed: isCancelled
                          ? null
                          : () {
                              final endTs = data['endDateTime'] as Timestamp?;
                              final startTime = start;
                              if (startTime != null) {
                                setState(() {
                                  _editingApptId = doc.id;

                                  _date = DateTime(
                                    startTime.year,
                                    startTime.month,
                                    startTime.day,
                                  );
                                  _time = TimeOfDay(
                                    hour: startTime.hour,
                                    minute: startTime.minute,
                                  );

                                  if (endTs != null) {
                                    final end = endTs.toDate();
                                    _duration = end.isAfter(startTime)
                                        ? end.difference(startTime)
                                        : const Duration(minutes: 20);
                                  } else {
                                    _duration = const Duration(minutes: 20);
                                  }

                                  _reasonCtrl.text = desc;
                                  _selectedReasons.clear();
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Editing selected appointment.'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                    ),
                    IconButton(
                      tooltip: 'Cancel appointment',
                      icon: const Icon(Icons.delete),
                      color: Colors.red.shade400,
                      onPressed: isCancelled
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Cancel appointment'),
                                  content: const Text(
                                      'Are you sure you want to cancel this appointment?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('No'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Yes, cancel'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              final res = await _ctrl.cancelGpCall(
                                elderlyId: elderUid,
                                appointmentId: doc.id,
                              );
                              if (!mounted) return;

                              if (_editingApptId == doc.id) {
                                setState(() => _editingApptId = null);
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.ok ? Colors.green : Colors.red,
                                  duration: const Duration(seconds: 2),
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

  Widget _pickTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Row(children: [
            Icon(icon, color: Colors.teal),
            const SizedBox(width: 10),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
          ]),
        ),
      ),
    ]);
  }
}
