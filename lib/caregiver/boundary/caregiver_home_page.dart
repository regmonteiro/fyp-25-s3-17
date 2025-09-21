import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class CaregiverHomeTab extends StatefulWidget {
  final UserProfile userProfile;
  const CaregiverHomeTab({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<CaregiverHomeTab> createState() => _CaregiverHomeTabState();
}

class _CaregiverHomeTabState extends State<CaregiverHomeTab> {
  late String? _elderId;
  final _elderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _elderId = widget.userProfile.uidOfElder; // expects you added this field to UserProfile
  }

  @override
  void dispose() {
    _elderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If caregiver not yet linked to an elder → show quick link card
    if (_elderId == null || _elderId!.isEmpty) {
      return _LinkElderCard(
        onSave: (entered) async {
          final uid = widget.userProfile.uid; // caregiver’s uid
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'uidOfElder': entered.trim(),
          });
          setState(() => _elderId = entered.trim());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Elder linked successfully')),
            );
          }
        },
      );
    }

    final elderId = _elderId!;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day + 1);
    final dayKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return RefreshIndicator(
      onRefresh: () async => Future.delayed(const Duration(milliseconds: 250)),
      child: CustomScrollView(
        slivers: [
          // Welcome + elder name
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(elderId).snapshots(),
                builder: (context, snap) {
                  final elderName = (snap.hasData && snap.data!.exists)
                      ? (snap.data!.data()?['displayName'] ?? 'Elder')
                      : 'Elder';
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Welcome, ${widget.userProfile.displayName}'),
                      subtitle: Text('Elder: $elderName'),
                      trailing: IconButton(
                        tooltip: 'Relink Elder',
                        icon: const Icon(Icons.link_off),
                        onPressed: () => _showRelinkDialog(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Alerts rail (open alerts)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('alerts')
                    .where('elderId', isEqualTo: elderId)
                    .where('status', isEqualTo: 'open')
                    .orderBy('createdAt', descending: true)
                    .limit(12)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
                    );
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Chip(
                            label: Text('No active alerts'),
                            backgroundColor: Colors.grey,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: docs.map((d) {
                      final data = d.data();
                      final type = (data['type'] as String?) ?? 'alert';
                      final label = (data['message'] as String?) ?? _labelForAlertType(type);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          avatar: Icon(_iconForAlertType(type), color: Colors.white),
                          label: Text(label, style: const TextStyle(color: Colors.white)),
                          backgroundColor: _colorForAlertType(type),
                          onPressed: () => _ackAlert(context, d.reference),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),

          // KPI grid (metricsDaily/{elderId}_YYYY-MM-DD)
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _metricDocBuilder(elderId, dayKey, (m) => _kpiCard(
                      title: 'Tasks Due',
                      value: (m?['tasksSummary'] ?? '—').toString(),
                      icon: Icons.check_circle_outline,
                    )),
                _metricDocBuilder(elderId, dayKey, (m) => _kpiCard(
                      title: 'Med Adherence',
                      value: '${m?['medAdherence7dPct'] ?? 0}% (7-day)',
                      icon: Icons.medication_liquid,
                    )),
                _metricDocBuilder(elderId, dayKey, (m) => _kpiCard(
                      title: 'Activity',
                      value: '${m?['steps'] ?? '—'} steps',
                      icon: Icons.directions_run,
                    )),
                _metricDocBuilder(elderId, dayKey, (m) {
                  final mins = (m?['sleepMinutes'] ?? 0) as int;
                  final h = mins ~/ 60;
                  final mm = (mins % 60).toString().padLeft(2, '0');
                  return _kpiCard(
                    title: 'Sleep',
                    value: mins == 0 ? '—' : '${h}h ${mm}m',
                    icon: Icons.nightlight_round,
                  );
                }),
                _metricDocBuilder(elderId, dayKey, (m) {
                  final ts = m?['nextAppointmentAt'] as Timestamp?;
                  final t = ts?.toDate();
                  return _kpiCard(
                    title: 'Next Appointment',
                    value: t == null ? '—' : _hhmm(t),
                    icon: Icons.calendar_today,
                  );
                }),
                _metricDocBuilder(elderId, dayKey, (m) => _kpiCard(
                      title: 'Location',
                      value: (m?['location'] ?? '—').toString(),
                      icon: Icons.location_on,
                    )),
              ],
            ),
          ),

          // Today header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Today\'s Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          // Today’s tasks/meds
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('tasks')
                    .where('elderId', isEqualTo: elderId)
                    .where('dueAt', isGreaterThanOrEqualTo: startOfDay)
                    .where('dueAt', isLessThan: endOfDay)
                    .orderBy('dueAt')
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final items = snap.data!.docs;
                  if (items.isEmpty) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.inbox_outlined),
                        title: Text('No items for today'),
                      ),
                    );
                  }
                  return Card(
                    child: Column(
                      children: items.map((d) {
                        final data = d.data();
                        final dueAt = (data['dueAt'] as Timestamp).toDate();
                        final done = (data['done'] as bool?) ?? false;
                        final kind = (data['kind'] as String?) ?? 'task';
                        return ListTile(
                          leading: Icon(
                            kind == 'med' ? Icons.medical_services : Icons.task_alt_outlined,
                            color: kind == 'med' ? Colors.blue : Colors.teal,
                          ),
                          title: Text('${_hhmm(dueAt)} — ${data['title'] ?? 'Untitled'}'),
                          trailing: IconButton(
                            icon: Icon(done ? Icons.done_all : Icons.check_box_outline_blank,
                                color: done ? Colors.green : null),
                            onPressed: () => _toggleDone(d.reference, done),
                          ),
                          onTap: () => _openTask(context, d.id, data),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _metricDocBuilder(
    String elderId,
    String dayKey,
    Widget Function(Map<String, dynamic>? m) builder,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('metricsDaily')
          .doc('${elderId}_$dayKey')
          .snapshots(),
      builder: (context, snap) => builder(snap.data?.data()),
    );
  }

  static String _labelForAlertType(String t) {
    switch (t) {
      case 'fall':
        return 'Fall Detected';
      case 'med_missed':
        return 'Missed Medication';
      case 'device_offline':
        return 'Device Offline';
      default:
        return 'Alert';
    }
  }

  Widget _kpiCard({
  required String title,
  required String value,
  required IconData icon,
}) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

  static Color _colorForAlertType(String t) {
    switch (t) {
      case 'fall':
        return Colors.red;
      case 'med_missed':
        return Colors.orange;
      case 'device_offline':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  static IconData _iconForAlertType(String t) {
    switch (t) {
      case 'fall':
        return Icons.warning;
      case 'med_missed':
        return Icons.medical_services;
      case 'device_offline':
        return Icons.signal_cellular_off;
      default:
        return Icons.notifications;
    }
  }

  static String _hhmm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _toggleDone(DocumentReference ref, bool wasDone) async {
    final now = DateTime.now();
    await ref.update({'done': !wasDone, 'completedAt': !wasDone ? now : null});
  }

  Future<void> _ackAlert(BuildContext context, DocumentReference ref) async {
    await ref.update({'status': 'ack'});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert acknowledged')),
      );
    }
  }

  void _showRelinkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Relink Elder'),
        content: TextField(
          controller: _elderController,
          decoration: const InputDecoration(
            labelText: 'Elder User UID',
            hintText: 'paste Elder UID here',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final entered = _elderController.text.trim();
              if (entered.isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userProfile.uid) // caregiver doc
                  .update({'uidOfElder': entered});
              if (mounted) {
                setState(() => _elderId = entered);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Elder linked successfully')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openTask(BuildContext context, String id, Map<String, dynamic> data) {
    final dueAt = (data['dueAt'] as Timestamp).toDate();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['title'] ?? 'Task', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Due: ${_hhmm(dueAt)}'),
            const SizedBox(height: 12),
            Text(data['notes'] ?? 'No notes'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small helper widget to link an elder when none is set
class _LinkElderCard extends StatefulWidget {
  final Future<void> Function(String elderUid) onSave;
  const _LinkElderCard({Key? key, required this.onSave}) : super(key: key);

  @override
  State<_LinkElderCard> createState() => _LinkElderCardState();
}

class _LinkElderCardState extends State<_LinkElderCard> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Link Elder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Elder User UID',
            hintText: 'Paste the elder’s Firebase UID',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving
              ? null
              : () async {
                  final v = _controller.text.trim();
                  if (v.isEmpty) return;
                  setState(() => _saving = true);
                  try {
                    await widget.onSave(v);
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: const Text('Save Link'),
        ),
      ],
    );
  }
}
