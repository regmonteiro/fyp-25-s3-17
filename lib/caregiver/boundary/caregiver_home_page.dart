import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../models/user_profile.dart';
import '../../ui/widgets/kpi_card.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controller/caregiver_home_controller.dart';
import 'create_events_page.dart';

class CaregiverHomeTab extends StatefulWidget {
  final UserProfile userProfile;
  final Function(String)? onElderSelected; // This is the callback from the parent

  const CaregiverHomeTab({Key? key, required this.userProfile, this.onElderSelected}) : super(key: key);

  @override
  State<CaregiverHomeTab> createState() => _CaregiverHomeTabState();
}

class _CaregiverHomeTabState extends State<CaregiverHomeTab> {
  String? _selectedElderId;
  late final CaregiverHomeController _controller;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _caregiverStream;

  @override
  void initState() {
    super.initState();
    _controller = CaregiverHomeController();
    _caregiverStream = _controller.getCaregiverStream();
    _selectedElderId = widget.userProfile.uidOfElder;

    // The Fix: Delay the state update until the end of the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedElderId != null) {
        widget.onElderSelected?.call(_selectedElderId!);
      }
    });
  }

  void _onElderSelected(String elderId) {
    setState(() {
      _selectedElderId = elderId;
    });
    // Call the parent's callback to update the dashboard
    widget.onElderSelected?.call(elderId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _caregiverStream,
      builder: (context, caregiverSnap) {
        final caregiverData = caregiverSnap.data?.data();
        final List<dynamic> linkedElders = caregiverData?['linkedElders'] ?? [];
        _selectedElderId = _selectedElderId ?? linkedElders.firstOrNull;

        if (linkedElders.isEmpty) {
          return const _LinkElderCard();
        }

        if (_selectedElderId == null) {
          return _ElderSelector(linkedElders: linkedElders, onSelected: _onElderSelected);
        }

        return _buildCaregiverView(context, _selectedElderId!, linkedElders);
      },
    );
  }

  Widget _buildCaregiverView(BuildContext context, String elderId, List<dynamic> linkedElders) {
    return RefreshIndicator(
      onRefresh: () async => Future.delayed(const Duration(milliseconds: 250)),
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeader(context, elderId, linkedElders),
              _buildMetricsSection(context, elderId),
              _buildScheduleSection(context, elderId),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                if (_selectedElderId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateEventsPage(
                        userProfile: widget.userProfile,
                        elderlyId: _selectedElderId!,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an elder first.')),
                  );
                }
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildHeader(BuildContext context, String elderId, List<dynamic> linkedElders) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _controller.getElderStream(elderId),
          builder: (context, snap) {
            final elderName = (snap.hasData && snap.data!.exists)
                ? (snap.data!.data()?['displayName'] ?? 'Elder')
                : 'Elder';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('Welcome, ${widget.userProfile.displayName}'),
                subtitle: Text('Viewing: $elderName'),
                trailing: linkedElders.length > 1
                    ? IconButton(
                        tooltip: 'Change Elder',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () => _showElderSelectionDialog(context, linkedElders),
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showElderSelectionDialog(BuildContext context, List<dynamic> linkedElders) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select an Elder'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: linkedElders.length,
            itemBuilder: (context, index) {
              final elderId = linkedElders[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(elderId).get(),
                builder: (context, snap) {
                  final elderName = snap.data?.get('displayName') ?? 'Elder';
                  return ListTile(
                    title: Text(elderName),
                    onTap: () {
                      _onElderSelected(elderId);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildMetricsSection(BuildContext context, String elderId) {
    final now = DateTime.now();
    final dayKey = DateFormat('yyyy-MM-dd').format(now);
    return SliverToBoxAdapter(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _controller.getMetricsStream(elderId, dayKey),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Step 2: Handle no data or error state
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: Text('No metrics available for this elder.'));
        }
          final metrics = snap.data?.data();
          final tasksSummary = metrics?['tasksSummary'] ?? '—';
          final medAdherence = '${metrics?['medAdherence7dPct'] ?? 0}%';
          final steps = metrics?['steps'] ?? '—';
          final sleepMinutes = metrics?['sleepMinutes'] ?? 0;
          final sleep = sleepMinutes > 0 ? '${sleepMinutes ~/ 60}h ${sleepMinutes % 60}m' : '—';
          final nextAppointmentTs = metrics?['nextAppointmentAt'] as Timestamp?;
          final nextAppointment = nextAppointmentTs != null ? DateFormat.jm().format(nextAppointmentTs.toDate()) : '—';
          final location = metrics?['location'] ?? '—';

          return Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                KpiCard(title: 'Tasks Due', value: tasksSummary.toString(), icon: Icons.check_circle_outline),
                KpiCard(title: 'Med Adherence', value: medAdherence, icon: Icons.medication_liquid),
                KpiCard(title: 'Activity', value: '$steps steps', icon: Icons.directions_run),
                KpiCard(title: 'Sleep', value: sleep, icon: Icons.nightlight_round),
                KpiCard(title: 'Next Appointment', value: nextAppointment, icon: Icons.calendar_today),
                KpiCard(title: 'Location', value: location.toString(), icon: Icons.location_on),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildScheduleSection(BuildContext context, String elderId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _controller.getTasksStream(elderId, startOfDay, endOfDay),
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
                    title: Text('${DateFormat.jm().format(dueAt)} — ${data['title'] ?? 'Untitled'}'),
                    trailing: IconButton(
                      icon: Icon(done ? Icons.done_all : Icons.check_box_outline_blank,
                          color: done ? Colors.green : null),
                      onPressed: () => _controller.toggleTaskDone(d.reference, done),
                    ),
                    onTap: () => _openTask(context, d.id, data),
                  );
                }).toList(),
              ),
            );
          },
        ),
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
            Text('Due: ${DateFormat.jm().format(dueAt)}'),
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

class _LinkElderCard extends StatefulWidget {
  const _LinkElderCard({Key? key}) : super(key: key);

  @override
  State<_LinkElderCard> createState() => _LinkElderCardState();
}

class _LinkElderCardState extends State<_LinkElderCard> {
  final _controller = TextEditingController();
  bool _saving = false;
  final CaregiverHomeController _homeController = CaregiverHomeController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveLink() async {
    final entered = _controller.text.trim();
    if (entered.isEmpty) return;

    setState(() => _saving = true);
    try {
      await _homeController.linkElder(entered);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elder linked successfully')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            hintText: 'Paste the elder’s UID',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _saveLink,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: const Text('Save Link'),
        ),
      ],
    );
  }
}

class _ElderSelector extends StatelessWidget {
  final List<dynamic> linkedElders;
  final Function(String) onSelected;

  const _ElderSelector({
    required this.linkedElders,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Select an Elder to view their profile:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...linkedElders.map((elderId) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(elderId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final elderName = snapshot.data?.get('displayName') ?? 'Elder';
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(elderName),
                  onTap: () => onSelected(elderId),
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }
}