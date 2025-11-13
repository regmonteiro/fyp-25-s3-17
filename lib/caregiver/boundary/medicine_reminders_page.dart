import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/medicine_reminder_service.dart';
import '../../models/user_profile.dart';
import '../../assistant_chat.dart';


class CreateMedicationReminderPage extends StatefulWidget {
  final UserProfile userProfile;
  final String? elderlyId;
  const CreateMedicationReminderPage({super.key, required this.userProfile, this.elderlyId});

  @override
  State<CreateMedicationReminderPage> createState() => _CreateMedicationReminderPageState();
}

class _CreateMedicationReminderPageState extends State<CreateMedicationReminderPage> {
  final _svc = MedicineRemindersService();

  // form state
  String? _selectedElderlyUid;                 // elderly uid (self for elderly users)
  List<Map<String, String>> _elderlyChoices = []; // [{uid, firstname, lastname, email}]
  String _medicationName = '';
  String _date = _today();
  String _time = '';
  int _repeatCount = 1;
  String _dosage = '';
  int _quantity = 1;

  bool _loading = true;
  String? _error;
  String? _success;

  // Stream + identity to avoid "already listened" errors
  Stream<List<MedicationReminder>>? _stream;
  Object _streamIdentity = Object();

  final _notesCtrl = TextEditingController();

  static String _today() => DateTime.now().toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Please log in to access this feature.';
        });
        return;
      }

      // Fetch caregiver’s linked elderly IDs
      final ids = await _svc.caregiverElderlyIds();

      // If an elderlyId is explicitly provided (e.g. from a card tap),
      // prefer it and make sure it appears in the choices.
      final preferred = (widget.elderlyId ?? '').trim();
      if (ids.isNotEmpty) {
        // Caregiver flow
        final info = await _svc.elderlyBasicInfo(ids); // [{uid, firstname, lastname, email}]
        // If deep-linked elderlyId not in list, append a fallback row so it’s selectable
        if (preferred.isNotEmpty && !info.any((e) => e['uid'] == preferred)) {
          info.insert(0, {
            'uid': preferred,
            'firstname': 'Elder',
            'lastname': '',
            'email': '',
          });
        }
        _elderlyChoices = info;
        // Preselect preferred, else the first choice
        _selectedElderlyUid = preferred.isNotEmpty ? preferred : (info.isNotEmpty ? info.first['uid'] : null);
      } else {
        // Elderly (self) flow — still allow preselection if passed
        final selfUid = preferred.isNotEmpty ? preferred : user.uid;
        _selectedElderlyUid = selfUid;
        _elderlyChoices = [
          {'uid': selfUid, 'firstname': 'You', 'lastname': '', 'email': user.email ?? ''}
        ];
      }

      _attachStream();
    } catch (e) {
      _error = 'Failed to load: $e';
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _attachStream() {
    if (_selectedElderlyUid == null) {
      _stream = const Stream<List<MedicationReminder>>.empty();
    } else {
      _stream = _svc
          .subscribe(elderlyId: _selectedElderlyUid!)
          .asBroadcastStream(); // allow multiple listeners safely
    }
    _streamIdentity = Object(); // force StreamBuilder to dispose old subscription
    setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final init = DateTime.tryParse(_date) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _date = d.toIso8601String().split('T').first);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      setState(() => _time = '$hh:$mm');
    }
  }

  Future<void> _create() async {
    setState(() { _error = null; _success = null; });
    if (_selectedElderlyUid == null) { setState(() => _error = 'No elderly selected'); return; }
    if (_medicationName.trim().isEmpty || _date.isEmpty || _time.isEmpty || _repeatCount < 1 || _quantity < 1) {
      setState(() => _error = 'Please fill in all required fields');
      return;
    }
    try {
      await _svc.create(
        elderlyId: _selectedElderlyUid!,
        medicationName: _medicationName.trim(),
        date: _date,
        reminderTime: _time,
        repeatCount: _repeatCount,
        dosage: _dosage.trim().isEmpty ? null : _dosage.trim(),
        quantity: _quantity,
      );
      setState(() {
        _success = 'Medication reminder created successfully!';
        _medicationName = '';
        _date = _today();
        _time = '';
        _repeatCount = 1;
        _dosage = '';
        _quantity = 1;
      });
    } catch (e) {
      setState(() => _error = 'Failed to create: $e');
    }
  }

  Future<void> _delete(String reminderId) async {
    if (_selectedElderlyUid == null) return;
    try {
      await _svc.delete(elderlyId: _selectedElderlyUid!, reminderId: reminderId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _toggleComplete(MedicationReminder r) async {
    if (_selectedElderlyUid == null) return;
    if (!r.isCompleted) {
      // Ask for optional notes
      _notesCtrl.text = '';
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Mark as taken'),
          content: TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _svc.toggleCompletion(
                  elderlyId: _selectedElderlyUid!,
                  reminderId: r.id,
                  markComplete: true,
                  notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else {
      await _svc.toggleCompletion(
        elderlyId: _selectedElderlyUid!,
        reminderId: r.id,
        markComplete: false,
      );
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && FirebaseAuth.instance.currentUser == null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    final isCaregiver =
      (widget.userProfile.userType ?? '').toLowerCase() == 'caregiver';

return Scaffold(
    appBar: AppBar(title: const Text('Create Medication Reminder')),

    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: FloatingActionButton(
      heroTag: 'assistant_medrem_fab',
      backgroundColor: Colors.deepPurple,
      onPressed: () {
        final email =
            FirebaseAuth.instance.currentUser?.email ?? 'guest@allcare.ai';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssistantChat(userEmail: email),
          ),
        );
      },
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
    ),
  body: Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // 🔹 Elderly selector: show for *any* caregiver with choices
          if (isCaregiver && _elderlyChoices.isNotEmpty) ...[
            const Text(
              'Select Elderly',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedElderlyUid,
              items: _elderlyChoices.map((e) {
                final name =
                    '${e['firstname'] ?? ''} ${e['lastname'] ?? ''}'.trim();
                return DropdownMenuItem(
                  value: e['uid'],
                  child: Text(
                    name.isEmpty ? (e['email'] ?? e['uid']!) : name,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _selectedElderlyUid = v);
                _attachStream();
              },
              decoration:
                  const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
          ],

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _medicationName,
                      onChanged: (v) => _medicationName = v,
                      decoration: const InputDecoration(
                        labelText: 'Medication Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            controller: TextEditingController(text: _date),
                            decoration: const InputDecoration(
                              labelText: 'Date * (yyyy-MM-dd)',
                              border: OutlineInputBorder(),
                            ),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            controller: TextEditingController(text: _time),
                            decoration: const InputDecoration(
                              labelText: 'Time * (HH:mm)',
                              border: OutlineInputBorder(),
                            ),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _dosage,
                            onChanged: (v) => _dosage = v,
                            decoration: const InputDecoration(
                              labelText: 'Dosage (optional)',
                              hintText: 'e.g., 500mg, 1 tablet',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: '$_quantity',
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _quantity = int.tryParse(v) ?? 1,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: '$_repeatCount',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _repeatCount = int.tryParse(v) ?? 1,
                      decoration: const InputDecoration(
                        labelText: 'Repeat Count *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFB00020))),
                      ),
                    if (_success != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F6EA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_success!, style: const TextStyle(color: Color(0xFF0B6B3A))),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedElderlyUid == null ? null : _create,
                        child: const Text('Create Reminder'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Reminders list + simple filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Medication Reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),

            StreamBuilder<List<MedicationReminder>>(
              key: ValueKey(_streamIdentity), // ensure fresh subscription after _attachStream()
              stream: _stream,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data ?? const <MedicationReminder>[];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No medication reminders found')),
                  );
                }

                final completed = items.where((e) => e.isCompleted).length;
                final total = items.length;
                final pct = total == 0 ? 0 : ((completed / total) * 100).round();

                return Column(
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 12,
                        color: const Color(0xFFE2E8F0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: total == 0 ? 0 : completed / total,
                            child: Container(color: const Color(0xFF10B981)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(label: Text('$completed of $total completed')),
                        const SizedBox(width: 8),
                        Chip(label: Text('$pct% Complete')),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (_, i) {
                        final r = items[i];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: IconButton(
                              tooltip: r.isCompleted ? 'Mark as not taken' : 'Mark as taken',
                              icon: Icon(r.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked),
                              onPressed: () => _toggleComplete(r),
                            ),
                            title: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              children: [
                                Text(r.medicationName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: r.isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                    border: Border.all(color: r.isCompleted ? const Color(0xFF34D399) : const Color(0xFFFCA5A5)),
                                  ),
                                  child: Text(
                                    r.isCompleted ? 'Taken' : 'Pending',
                                    style: TextStyle(
                                      color: r.isCompleted ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${r.date}  •  Time: ${r.reminderTime}  •  Repeat: ${r.repeatCount}'),
                                if ((r.dosage ?? '').isNotEmpty) Text('Dosage: ${r.dosage}'),
                                if (r.quantity > 1) Text('Qty: ${r.quantity}'),
                                if (r.isCompleted && (r.completedAt ?? '').isNotEmpty)
                                  Text('Taken at: ${r.completedAt}'),
                                if (r.isCompleted && (r.notes ?? '').isNotEmpty)
                                  Text('Notes: ${r.notes}'),
                              ],
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete, color: Color(0xFFB00020)),
                              onPressed: () => _delete(r.id),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: items.length,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
