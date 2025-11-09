import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../assistant_chat.dart';
/// ───────────────────────── Models & Service ─────────────────────────

class Reminder {
  final String id;
  final String title;
  final String startTimeIso; // "yyyy-MM-ddTHH:mm"
  final int duration;
  final String createdAt;

  Reminder({
    required this.id,
    required this.title,
    required this.startTimeIso,
    required this.duration,
    required this.createdAt,
  });

  DateTime? get start =>
      startTimeIso.isEmpty ? null : DateTime.tryParse(startTimeIso);

  Map<String, dynamic> toMap() => {
        'title': title,
        'startTime': startTimeIso,
        'duration': duration,
        'createdAt': createdAt,
      };

  static Reminder fromMap(String id, Map<String, dynamic> m) {
    return Reminder(
      id: id,
      title: (m['title'] ?? '').toString(),
      startTimeIso: (m['startTime'] ?? '').toString(),
      duration: int.tryParse((m['duration'] ?? 0).toString()) ?? 0,
      createdAt: (m['createdAt'] ?? '').toString(),
    );
  }
}

class ReminderService {
  final _fs = FirebaseFirestore.instance;

String _emailToKey(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain'; // keeps '@'
}



  Future<String?> _emailKeyForCurrent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final mail = user.email;
    if (mail == null || mail.isEmpty) return null;
    return _emailToKey(mail);
  }

  Stream<List<Reminder>> subscribeMine() async* {
    final key = await _emailKeyForCurrent();
    if (key == null) {
      yield const <Reminder>[];
      return;
    }
    yield* _fs.collection('reminders').doc(key).snapshots().map((doc) {
      if (!doc.exists) return <Reminder>[];
      final data = Map<String, dynamic>.from(doc.data() ?? {});
      final items = <Reminder>[];
      for (final e in data.entries) {
        if (e.value is Map) {
          items.add(Reminder.fromMap(
              e.key, Map<String, dynamic>.from(e.value as Map)));
        }
      }
      items.sort((a, b) {
        final sentinel = DateTime.fromMillisecondsSinceEpoch(1 << 62);
       final as = a.start ?? sentinel;
        final bs = b.start ?? sentinel;
        return as.compareTo(bs);
      });
      return items;
    });
  }

  /// Creates a child map entry with a generated id under reminders/{emailKey}
  Future<void> create({
    required String title,
    required DateTime start,
    required int durationMinutes,
  }) async {
    final key = await _emailKeyForCurrent();
    if (key == null) throw Exception('Missing email key');

    final doc = _fs.collection('reminders').doc(key);
    final id = _fs.collection('_').doc().id; // random id helper

    await doc.set({
      'ownerEmailKey': key,
    if (FirebaseAuth.instance.currentUser?.uid != null)
       'ownerUid': FirebaseAuth.instance.currentUser!.uid,
      id: {
        'title': title,
        'startTime': DateFormat("yyyy-MM-ddTHH:mm").format(start),
        'duration': durationMinutes,
        'createdAt': DateTime.now().toIso8601String(),
      }
    }, SetOptions(merge: true));
  }

  /// Updates an existing child map at reminders/{emailKey}/{id}
  Future<void> update({
    required String id,
    required Reminder updated,
  }) async {
    final key = await _emailKeyForCurrent();
    if (key == null) throw Exception('Missing email key');

    await _fs.collection('reminders').doc(key).set({
      id: updated.toMap(),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    final key = await _emailKeyForCurrent();
    if (key == null) throw Exception('Missing email key');

    final ref = _fs.collection('reminders').doc(key);
    final snap = await ref.get();
    if (!snap.exists) return;
    await ref.update({ id: FieldValue.delete() });
  }
}

/// ───────────────────────── UI Page ─────────────────────────

class CreateEventRemindersPage extends StatefulWidget {
  const CreateEventRemindersPage({super.key});

  @override
  State<CreateEventRemindersPage> createState() =>
      _CreateEventRemindersPageState();
}

class _CreateEventRemindersPageState extends State<CreateEventRemindersPage> {
  final _svc = ReminderService();

  final _titleCtl = TextEditingController();
  final _durationCtl = TextEditingController();
  DateTime? _start;
  bool _loading = false;
  String? _msg; // error or success (styled below)
  bool _isError = false;

  // editing state
  String? _editingId;
  DateTime? _editStart;

  @override
  void dispose() {
    _titleCtl.dispose();
    _durationCtl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start ?? now),
    );
    if (t == null) return;
    setState(() {
      _start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _pickEditStart(DateTime? initial) async {
    final base = initial ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 5),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;
    setState(() {
      _editStart = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _create() async {
    final title = _titleCtl.text.trim();
    final dur = int.tryParse(_durationCtl.text.trim());
    if (title.isEmpty || _start == null || dur == null || dur <= 0) {
      setState(() {
        _isError = true;
        _msg = 'Please fill all fields.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      await _svc.create(title: title, start: _start!, durationMinutes: dur);
      setState(() {
        _isError = false;
        _msg = 'Reminder created successfully!';
        _titleCtl.clear();
        _durationCtl.clear();
        _start = null;
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _msg = 'Failed to create reminder: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      await _svc.delete(id);
      setState(() {
        _isError = false;
        _msg = 'Reminder deleted!';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _msg = 'Failed to delete reminder: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveEdit(Reminder r) async {
    if (_editStart == null) {
      setState(() {
        _isError = true;
        _msg = 'Start time cannot be empty.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final updated = Reminder(
        id: r.id,
        title: r.title,
        startTimeIso: DateFormat("yyyy-MM-ddTHH:mm").format(_editStart!),
        duration: r.duration,
        createdAt: DateTime.now().toIso8601String(),
      );
      await _svc.update(id: r.id, updated: updated);
      setState(() {
        _isError = false;
        _msg = 'Reminder updated!';
        _editingId = null;
        _editStart = null;
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _msg = 'Failed to update reminder: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _fmtDateTime(DateTime dt) =>
      DateFormat('yyyy-MM-dd • h:mm a').format(dt);

  @override
  Widget build(BuildContext context) {
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

      body: Container(
        // you can set a background image with a DecorationImage if you want to match React
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Create Reminder',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 22),

                      // form
                      LayoutBuilder(
                        builder: (context, c) {
                          final twoCols = c.maxWidth > 640;
                          return Column(
                            children: [
                              // title
                              TextField(
                                controller: _titleCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Reminder Title',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Start Time'),
                                        const SizedBox(height: 6),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.calendar_today),
                                          label: Text(
                                            _start == null
                                                ? 'Pick date & time'
                                                : _fmtDateTime(_start!),
                                          ),
                                          onPressed: _pickStart,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: _durationCtl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Duration (minutes)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_msg != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isError ? const Color(0xFFFCE4E4) : const Color(0xFFE7F0FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _msg!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isError ? const Color(0xFFC62828) : const Color(0xFF1565C0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _create,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: Text(_loading ? 'Creating…' : 'Confirm',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Row(
                        children: const [
                          Text('Your Reminders',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // list
                      StreamBuilder<List<Reminder>>(
                        stream: _svc.subscribeMine(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final reminders = snap.data ?? const <Reminder>[];
                          if (reminders.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('No reminders yet.',
                                  style: TextStyle(color: Colors.grey)),
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, c) {
                              final w = c.maxWidth;
                              final crossAxisCount = w >= 960 ? 3 : (w >= 640 ? 2 : 1);
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.2,
                                ),
                                itemCount: reminders.length,
                                itemBuilder: (context, i) {
                                  final r = reminders[i];
                                  final isEditing = _editingId == r.id;
                                  final startLabel =
                                      r.start == null ? '—' : DateFormat('y-MM-dd h:mm a').format(r.start!);

                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 18, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 8),

                                          if (isEditing) ...[
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.schedule),
                                              label: Text(_editStart == null
                                                  ? 'Pick new start'
                                                  : _fmtDateTime(_editStart!)),
                                              onPressed: () => _pickEditStart(r.start),
                                            ),
                                            const SizedBox(height: 6),
                                            Text('Duration: ${r.duration} minute${r.duration == 1 ? '' : 's'}',
                                                style: const TextStyle(color: Colors.black54)),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                ElevatedButton(
                                                  onPressed: _loading ? null : () => _saveEdit(r),
                                                  child: const Text('Save'),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  onPressed: _loading
                                                      ? null
                                                      : () {
                                                          setState(() {
                                                            _editingId = null;
                                                            _editStart = null;
                                                          });
                                                        },
                                                  child: const Text('Cancel'),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            Text('Start: $startLabel',
                                                style: const TextStyle(color: Colors.black54)),
                                            Text('Duration: ${r.duration} minute${r.duration == 1 ? '' : 's'}',
                                                style: const TextStyle(color: Colors.black54)),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                OutlinedButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _editingId = r.id;
                                                      _editStart = r.start;
                                                    });
                                                  },
                                                  child: const Text('Update'),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFEF5350),
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  onPressed: _loading ? null : () => _delete(r.id),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}