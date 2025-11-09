import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // NEW: prevents double taps & helps avoid re-entrancy
  bool _busy = false;

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

  @override
  void initState() {
    super.initState();
    _ctrl = GpAppointmentController(mirrorToCaregivers: true);
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _time = const TimeOfDay(hour: 9, minute: 0);
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

    setState(() => _busy = true);
    try {
      // 1) Confirm (use dialog's ctx to pop the dialog, not the page)
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm booking'),
          content: Text(
            'Book GP consultation on '
            '${DateFormat('EEE, MMM d, h:mm a').format(start)}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
          ],
        ),
      );

      if (ok != true) return; // cancelled
      if (!mounted) return;    // page might have been closed while dialog open

      // 2) Do the booking
      final res = await _ctrl.bookFutureGpCall(
        elderlyId: widget.userProfile.uid,
        elderlyName: widget.userProfile.safeDisplayName,
        start: start,
        duration: _duration,
        reason: _reasonCtrl.text.trim(),
        invitePrimaryCaregiver: _invitePrimaryCaregiver,
      );

      if (!mounted) return;

      // 3) Feedback
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.ok ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );

      // 4) Leave page on success (schedule on microtask to avoid using context in same frame)
      if (res.ok) {
        Future.microtask(() {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userProfile.safeDisplayName;

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
                  Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick a time and tell us the main reason. We’ll set up a video GP call and remind you and your caregiver.',
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

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
              future: _ctrl.fetchPrimaryCaregiver(widget.userProfile.uid),
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
                label: const Text('Confirm Booking'),
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
          ]),
        ),
      ),
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
