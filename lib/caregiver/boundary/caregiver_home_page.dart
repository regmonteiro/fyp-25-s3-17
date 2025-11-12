import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:async/async.dart' show StreamZip;
import '../../models/user_profile.dart';
import '../../ui/widgets/kpi_card.dart';
import '../controller/caregiver_home_controller.dart'
    show CaregiverHomeController, CaregiverHomeViewModel;
import 'medicine_reminders_page.dart';
import '../../financial/wallet_page.dart';
import '../../medical/gp_consultation_page.dart';
import '../../medical/consultation_booking_page.dart';
import 'package:provider/provider.dart';
import '../../medical/shop_page.dart' as shop;
import 'package:url_launcher/url_launcher.dart';
import '../../features/share_experience_page.dart';
import '../../features/communicate_page.dart';
import 'accounts_pages/elderly_access_page.dart';
import '../../medical/caregiver_health_upload_page.dart';
import '../../medical/controller/health_records_controller.dart';
import '../../services/care_routine_template_service.dart';
import 'care_routine_template_page.dart';
import '../../announcement/announcements_widget.dart';
import '../../announcement/all_announcement_page.dart';
import '../../announcement/announcement_controller.dart';
import '../../models/announcement.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../assistant_chat.dart';
import 'accounts_pages/cg_account_page.dart';
import 'view_reports_caregiver_page.dart';



Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _streamElderlyId(
  List<String> uids,
) {
  if (uids.isEmpty) {
    return Stream.value(const []);
  }
  // Split into chunks of 10
  final chunks = <List<String>>[];
  for (var i = 0; i < uids.length; i += 10) {
    chunks.add(uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10));
  }

  final streams = chunks.map((chunk) {
    return FirebaseFirestore.instance
        .collection('Account')
        .where(FieldPath.documentId, whereIn: chunk)
        .snapshots()
        .map((qs) => qs.docs);
  }).toList();

  return StreamZip(streams).map((lists) => lists.expand((x) => x).toList());
}

class CaregiverHomePage extends StatefulWidget {
  final UserProfile userProfile;
  final ValueChanged<String>? onElderlySelected;

  const CaregiverHomePage({
    Key? key,
    required this.userProfile,
    this.onElderlySelected,
  }) : super(key: key);

  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  late final CaregiverHomeController _c;
  String? _selectedElderlyId;
  bool _initializedOnce = false;

  @override
  void initState() {
    super.initState();
    _c = CaregiverHomeController(userProfile: widget.userProfile);
    _selectedElderlyId = widget.userProfile.elderlyId; // default if present
    _c.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedElderlyId != null) {
        _c.setActiveElder(_selectedElderlyId!);
        widget.onElderlySelected?.call(_selectedElderlyId!);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

Future<void> _sendStatusPing(String toUid, String kind, {String? message}) async {
  await FirebaseFirestore.instance.collection('notifications').add({
    'toUid': toUid,
    'fromUid': widget.userProfile.uid,
    'type': 'ok_ping',             // unified type for both directions
    'kind': kind,                  // 'are_you_ok' | 'im_ok' | 'need_help'
    'title': kind == 'are_you_ok' ? 'Are you OK?' :
             kind == 'im_ok'      ? 'I am OK' : 'I need help',
    'message': message ?? '',
    'timestamp': FieldValue.serverTimestamp(),
    'read': false,
    'priority': kind == 'need_help' ? 'high' : 'low',
  });
}

Future<void> migrateCaregiverDocToElderlyIds(String caregiverId) async {
  final doc = await FirebaseFirestore.instance.collection('Account').doc(caregiverId).get();
  if (!doc.exists) return;
  final data = doc.data()!;
  final merged = <String>{};

  void addList(dynamic v) {
    if (v is List) {
      for (final e in v) {
        final s = e?.toString().trim();
        if (s != null && s.isNotEmpty) merged.add(s);
      }
    }
  }

  addList(data['elderlyIds']);        // keep existing
  addList(data['linkedElderUids']);   // legacy
  addList(data['linkedElders']);      // legacy
  final single = (data['uidOfElder'] as String?)?.trim(); // legacy single
  if (single != null && single.isNotEmpty) merged.add(single);

  await FirebaseFirestore.instance.collection('Account').doc(caregiverId).set({
    'elderlyIds': merged.toList(),
    // Optional: remove legacy keys
    'linkedElderUids': FieldValue.delete(),
    'linkedElders': FieldValue.delete(),
    'uidOfElder': FieldValue.delete(),
  }, SetOptions(merge: true));
}

Future<void> _showStatusSheet() async {
  final toUid = _selectedElderlyId;
  if (toUid == null) {
    _snack('Select an elder first.');
    return;
  }
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text('Quick Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ask: Are you OK?'),
            onTap: () => Navigator.pop(context, 'are_you_ok'),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Send: I am OK'),
            onTap: () => Navigator.pop(context, 'im_ok'),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            title: const Text('Send: I need help'),
            onTap: () => Navigator.pop(context, 'need_help'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null) return;
  try {
    await _sendStatusPing(toUid, choice);
    _snack('Status sent.');
  } catch (e) {
    _snack('Failed to send status: $e');
  }
}


/// Reusable row with 2 large buttons (Open Chat/Call + Quick Status)
Widget _buildCommunicateRow(BuildContext context) {
  final disabled = _selectedElderlyId == null;
  return Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: disabled
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunicatePage(
                        userProfile: widget.userProfile,
                        partnerUid: _selectedElderlyId,
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.chat_bubble, size: 24),
          label: const Text("Chat / Call Elder", style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.indigo.shade500,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: disabled ? null : _showStatusSheet,
          icon: const Icon(Icons.favorite_outline, size: 24),
          label: const Text("Quick Status", style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.pink.shade600,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ],
  );
}



  Future<void> _onRefresh() => _c.init();

  void _selectElderly(String elderlyId) {
    if (_selectedElderlyId == elderlyId) return;
    setState(() => _selectedElderlyId = elderlyId);
    _c.setActiveElder(elderlyId);
    widget.onElderlySelected?.call(elderlyId);
  }

  Future<String?> _chooseElder(List<String> elderlyIds, Map<String, String> elderNames) async {
    if (elderlyIds.isEmpty) return null;
    if (elderlyIds.length == 1) return elderlyIds.first;

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('Choose Elder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...elderlyIds.map((id) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(_c.latestVm?.elderNames[id] ?? 'Elder'),
                  onTap: () => Navigator.pop(context, id),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Fetch phone from users/{elderUid}.phone (string), then dial.
  Future<void> _callElderFlow(List<String> elderlyIds) async {
    final chosen = await _chooseElder(elderlyIds, _c.latestVm?.elderNames ?? const {});
    if (chosen == null) return;

    try {
      final snap = await FirebaseFirestore.instance.collection('Account').doc(chosen).get();
      final rawPhone = snap.data()?['phoneNum'] ?? snap.data()?['elderPhone'];
      final phone = rawPhone == null ? null : rawPhone.toString().trim();

      if (phone == null || phone.isEmpty) {
        _snack('No phone number found for this elder.');
        return;
      }
      final uri = Uri(scheme: 'tel', path: phone);
      if (!await canLaunchUrl(uri)) {
        _snack('This device cannot place calls.');
        return;
      }
      await launchUrl(uri);
    } catch (e) {
      _snack('Call failed: $e');
    }
  }

  /// Navigate to your video-call screen/route with the selected elder.
  Future<void> _videoCallFlow(List<String> elderlyIds) async {
    final chosen = await _chooseElder(elderlyIds, _c.latestVm?.elderNames ?? const {});
    if (chosen == null) return;
    Navigator.pushNamed(context, '/videoCall', arguments: {'elderlyId': chosen});
  }

  void _openTask(BuildContext context, String id, Map<String, dynamic> data) {
    final ts = data['dueAt'] as Timestamp?;
    final dueAt = ts?.toDate();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (data['title'] ?? 'Task').toString(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (dueAt != null) Text('Due: ${DateFormat.jm().format(dueAt)}'),
              const SizedBox(height: 12),
              Text((data['notes'] ?? 'No notes').toString()),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CaregiverHomeViewModel>(
      stream: _c.view$,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final vm = snap.data!;

        // First-time selection: when data first arrives and no elder chosen yet.
        if (!_initializedOnce) {
          _initializedOnce = true;
          if (_selectedElderlyId == null && vm.linkedElderlyIds.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _selectElderly(vm.linkedElderlyIds.first);
            });
          }
        }

        final unread = vm.unreadNotifications;

        return Scaffold(

          appBar: AppBar(
            title: Text('Welcome back, ${widget.userProfile.safeDisplayName}!'),
            centerTitle: true,
            actions: [
              IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
  final email = FirebaseAuth.instance.currentUser?.email ?? 'guest@allcare.ai';
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AssistantChat(userEmail: email),
    ),
  );
},
            ),
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications),
                      Positioned(
                        right: 0,
                        top: 10,
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.red,
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Linked Elder Card / Selector
                _LinkedElderInfoCard(
                    caregiverName: widget.userProfile.safeDisplayName,
                    caregiverUid: widget.userProfile.uid,
                    linkedIds: vm.linkedElderlyIds,
                    selected: _selectedElderlyId,
                    elderNameFor: (uid) => vm.elderNames[uid] ?? 'Elder',
                    onPick: _selectElderly,
                    onLink: (uid) async {
                      try {
                        await _c.linkElderly(uid);
                        _snack('Linked elder successfully');
                      } catch (e) {
                        _snack('Failed to link elder: $e');
                      }
                    },
                  ),

                const SizedBox(height: 12),

                if (_selectedElderlyId != null) ...[
                  _ElderDetailsCard(elderUid: _selectedElderlyId!),
                  const SizedBox(height: 12),
                ],

                // (Optional) Show a collapsible “all elders” details block
                _AllLinkedEldersDetails(linkedIds: vm.linkedElderlyIds),
                const SizedBox(height: 12),

                if (_selectedElderlyId != null) ...[
                  _HealthSection(
                    metricsDoc: vm.metricsByElder[_selectedElderlyId!],
                  ),
                  const SizedBox(height: 12),

                  _ElderDetailsCard(elderUid: _selectedElderlyId!),
                  const SizedBox(height: 12),

                  _DailyCareRoutineSection(
                    elderlyId: _selectedElderlyId!,
                    onManage: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CareRoutineTemplatePage()),
                      );
                    },
                  ),
                  _AnnouncementsSection(),
                  const AnnouncementsWidget(),
                    const SizedBox(height: 8),
                    // “View all” shortcut
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.campaign_outlined),
                        title: const Text('View all announcements'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AllAnnouncementsPage()),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                  const SizedBox(height: 12),

                  _buildCommunicateRow(context),
                  const SizedBox(height: 12),

                  CaregiverUpcomingRemindersSection(
                    elderlyIds: vm.linkedElderlyIds,
                    elderlyNameByUid: vm.elderNames, // optional map of uid -> display name
                  ),
                  const SizedBox(height: 12),

                  _CommunityFeedPreview(),
                  const SizedBox(height: 12),


                  _CaregiverMedicalQuickActions(
                    userProfile: widget.userProfile,
                    elderlyId: _selectedElderlyId,
                  ),

                  _ScheduleTodaySection(
                    items: vm.todayScheduleByElder[_selectedElderlyId!] ?? const [],
                    onToggleDone: _c.toggleTaskDone,
                    onOpen: (ref, data) => _openTask(context, ref.path, data),
                  ),
                  const SizedBox(height: 12),

                  MedicationTracker(
                    reminders: vm.todayMedsByElder[_selectedElderlyId!] ?? const [],
                    elderlyLookup: vm.elderNames,
                    onMarkDone: _c.markMedDoneByIds,
                  ),
                  const SizedBox(height: 12),

                  _NotificationsSection(
                    notifications: vm.notifications,
                    
                    onMarkRead: _c.markNotificationRead,
                    onMarkAll: () => _c.markAllNotificationsRead(
                      vm.notifications
                          .where((n) => !(n['read'] as bool? ?? false))
                          .map((n) => (n['id'] as String))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _QuickActions(
                    userProfile: widget.userProfile,
                    onCreateEvent: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateMedicationReminderPage(
                            userProfile: widget.userProfile,
                            elderlyId: _selectedElderlyId,
                          ),
                        ),
                      );
                    },
                    onAddMedication: () => _snack('Open Medication screen'),
                    onScheduleAppt: () => _snack('Open Appointment screen'),
                    onViewReports: () => _snack('Open Reports'),
                    onGenerateReport: () => _snack('Generate Custom Report'),
                    onNotifications: () => _snack('Open Notifications'),
                    onSettings: () => _snack('Open Settings'),
                  ),
                ] else
                  const _EmptyHint(text: 'Link or select an Elder to begin.'),
                const SizedBox(height: 40),
              ],
            ),
          ),
          floatingActionButton: (_selectedElderlyId != null)
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateMedicationReminderPage(
                          userProfile: widget.userProfile,
                          elderlyId: _selectedElderlyId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Event'),
                )
              : null,
        );
      },
    );
  }
}

/// ───────────────────────── UI PARTIALS ─────────────────────────

class _LinkedElderInfoCard extends StatefulWidget {
  final String caregiverName;
  final String caregiverUid;
  final List<String> linkedIds;
  final String? selected;
  final String Function(String) elderNameFor;
  final ValueChanged<String> onPick;
  final Future<void> Function(String elderlyId) onLink;

  const _LinkedElderInfoCard({
    required this.caregiverName,
    required this.caregiverUid,
    required this.linkedIds,
    required this.selected,
    required this.elderNameFor,
    required this.onPick,
    required this.onLink,
  });

  @override
  State<_LinkedElderInfoCard> createState() => _LinkedElderInfoCardState();
}

class _LinkedElderInfoCardState extends State<_LinkedElderInfoCard> {
  late final TextEditingController _idCtl;

  @override
  void initState() {
    super.initState();
    _idCtl = TextEditingController();
  }

  @override
  void dispose() {
    _idCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLinked = widget.linkedIds.isNotEmpty;
    final first8 = widget.caregiverUid.length >= 8
        ? widget.caregiverUid.substring(0, 8)
        : widget.caregiverUid;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ElderlyAccessPage()));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: $first8…', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(widget.caregiverName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              isLinked
                  ? 'Linked Elderly (${widget.linkedIds.length})'
                  : 'No Elder Linked',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (isLinked)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: widget.linkedIds.map((id) {
                  final isSel = id == widget.selected;
                  return ChoiceChip(
                    label: Text(widget.elderNameFor(id)),
                    selected: isSel,
                    onSelected: (_) => widget.onPick(id),
                    labelStyle: const TextStyle(color: Colors.black),
                    selectedColor: Colors.white70,
                    backgroundColor: Colors.white12,
                    side: const BorderSide(color: Colors.white30),
                  );
                }).toList(),
              ),
            if (!isLinked) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _idCtl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Elder UID',
                  labelStyle: const TextStyle(color: Colors.white),
                  prefixIcon: const Icon(Icons.link, color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white38),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSubmitted: (_) async {
                  final id = _idCtl.text.trim();
                  if (id.isEmpty) return;
                  await widget.onLink(id);
                  if (mounted) _idCtl.clear();
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final id = _idCtl.text.trim();
                  if (id.isEmpty) return;
                  await widget.onLink(id);
                  if (mounted) _idCtl.clear();
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Link Elder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: const [
                Spacer(),
                Icon(Icons.arrow_forward_ios, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ───────────────────────── Elder Details UI ─────────────────────────

int? _ageFromDob(Object? dob) {
  DateTime? birth;
  if (dob is Timestamp) birth = dob.toDate();
  if (dob is String && dob.isNotEmpty) {
    try { birth = DateTime.parse(dob); } catch (_) {}
  }
  if (birth == null) return null;
  final now = DateTime.now();
  var age = now.year - birth.year;
  if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
  return age;
}

Widget _fieldRow(String label, String value, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) Padding(
          padding: const EdgeInsets.only(right: 8, top: 2),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );
}

class _ElderDetailsCard extends StatelessWidget {
  final String elderUid;
  const _ElderDetailsCard({required this.elderUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('Account').doc(elderUid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(child: ListTile(title: Text('Loading elder details…')));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Card(child: ListTile(title: Text('Elder profile not found.')));
        }
        final d = snap.data!.data() ?? {};
        final displayName = (d['safeDisplayName'] ?? d['displayName'])?.toString().trim();
        final fn = (d['firstName'] ?? d['firstname'])?.toString().trim() ?? '';
        final ln = (d['lastName'] ?? d['lastname'])?.toString().trim() ?? '';
        final name = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();

        final age = _ageFromDob(d['dob']);
        final phone = (d['phoneNum'] ?? d['elderPhone'] ?? '').toString();

        final conditions = (d['conditions'] ?? d['medicalConditions'] ?? const []) as List?;
        final allergies  = (d['allergies'] ?? const []) as List?;
        final meds       = (d['activeMedications'] ?? const []) as List?; // List<Map> or List<String>

        final lastActive = (d['lastActiveAt'] is Timestamp) ? (d['lastActiveAt'] as Timestamp).toDate() : null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.badge_outlined),
                  const SizedBox(width: 8),
                  Text('Elder Details', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (phone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.call),
                      tooltip: 'Call',
                      onPressed: () async {
                        final uri = Uri(scheme: 'tel', path: phone);
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                    ),
                ]),
                const SizedBox(height: 12),
                _fieldRow('Name', name, icon: Icons.person_outline),
                _fieldRow('Age', age == null ? '—' : '$age'),
                _fieldRow('Phone', phone, icon: Icons.phone_outlined),

                const SizedBox(height: 8),
                if (conditions != null && conditions.isNotEmpty) ...[
                  const Text('Conditions', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: conditions.map((c) => Chip(label: Text(c.toString()))).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                if (allergies != null && allergies.isNotEmpty) ...[
                  const Text('Allergies', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: allergies.map((a) => Chip(label: Text(a.toString()))).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                if (meds != null && meds.isNotEmpty) ...[
                  const Text('Active Medications', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ...meds.take(8).map((m) {
                    if (m is Map) {
                      final mm = Map<String, dynamic>.from(m);
                      final n = (mm['name'] ?? mm['medicationName'] ?? 'Medication').toString();
                      final dose = (mm['dosage'] ?? '').toString();
                      final freq = (mm['frequency'] ?? '').toString();
                      final extra = [dose, freq].where((s) => s.isNotEmpty).join(' • ');
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(n),
                        subtitle: extra.isEmpty ? null : Text(extra),
                      );
                    } else {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(m.toString()),
                      );
                    }
                  }),
                  const SizedBox(height: 8),
                ],


                if (lastActive != null)
                  Text('Last active: ${DateFormat('y-MM-dd h:mm a').format(lastActive)}',
                      style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AllLinkedEldersDetails extends StatelessWidget {
  final List<String> linkedIds;
  const _AllLinkedEldersDetails({required this.linkedIds});

  @override
  Widget build(BuildContext context) {
    if (linkedIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      stream: _streamElderlyId(linkedIds),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Card(child: ListTile(title: Text('Loading linked elders…')));
        }
        final docs = snap.data!;
        return Card(
          child: ExpansionTile(
            title: const Text('All Linked Elders (details)'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: docs.map((ds) {
              final d = ds.data() ?? {};
              final uid = ds.id;
              final name = (d['safeDisplayName'] ?? d['displayName'])?.toString().trim() ??
                  '${(d['firstName'] ?? d['firstname'] ?? '').toString()} ${(d['lastName'] ?? d['lastname'] ?? '').toString()}'.trim();
              final age = _ageFromDob(d['dob']);
              final phone = (d['phoneNum'] ?? d['elderPhone'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? uid : name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _fieldRow('UID', uid),
                    _fieldRow('Age', age == null ? '—' : '$age'),
                    _fieldRow('Phone', phone),
                    const Divider(),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _DailyCareRoutineSection extends StatelessWidget {
  final String elderlyId;
  final VoidCallback onManage;

  const _DailyCareRoutineSection({
    required this.elderlyId,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final svc = CareRoutineTemplateService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: svc.subscribeAssignedRoutines(elderlyId),
      builder: (context, snap) {
        final isLoading = snap.connectionState == ConnectionState.waiting;
        final assigned = snap.data ?? const <Map<String, dynamic>>[];

        if (isLoading) {
          return const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Loading care routine…'),
            ),
          );
        }

        // Nothing assigned yet
        if (assigned.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Care Routine', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onManage,
                      icon: const Icon(Icons.settings),
                      label: const Text('Manage'),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  const ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('No routine assigned yet'),
                    subtitle: Text('Create or assign a routine to see daily items here.'),
                  ),
                ],
              ),
            ),
          );
        }

        // Flatten all items across assigned templates
        final rows = <_RoutineRow>[];
        for (final a in assigned) {
          final tpl = Map<String, dynamic>.from(a['templateData'] as Map);
          final name = (tpl['name'] ?? 'Routine').toString();
          final items = List<Map<String, dynamic>>.from(tpl['items'] as List);
          for (final it in items) {
            rows.add(_RoutineRow(
              templateName: name,
              type: (it['type'] ?? '').toString(),
              time: (it['time'] ?? '').toString(),
              title: (it['title'] ?? '').toString(),
              description: (it['description'] ?? '').toString(),
            ));
          }
        }

        // Sort by time (HH:mm); unknown times go last
        rows.sort((a, b) => _timeKey(a.time).compareTo(_timeKey(b.time)));

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Care Routine (Today)', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.settings),
                    label: const Text('Manage'),
                  ),
                ]),
                const SizedBox(height: 6),

                if (rows.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('No activities in your routine'),
                    subtitle: Text('Add activities to the template to see them here.'),
                  )
                else
                  ...rows.map((r) => ListTile(
                        leading: _typeIcon(r.type),
                        title: Text('${r.time.isEmpty ? '' : '${r.time} — '}${r.title}'),
                        subtitle: r.description.isEmpty
                            ? Text(r.templateName, style: const TextStyle(color: Colors.grey))
                            : Text('${r.templateName} • ${r.description}'),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  // Convert "HH:mm" into sortable integer (e.g., "08:30" -> 830)
  static int _timeKey(String t) {
    if (t.isEmpty) return 99999;
    final parts = t.split(':');
    if (parts.length != 2) return 99999;
    final h = int.tryParse(parts[0]) ?? 99;
    final m = int.tryParse(parts[1]) ?? 99;
    return (h * 100) + m;
  }

  static Widget _typeIcon(String type) {
    IconData data;
    Color color;
    switch (type) {
      case 'medication':
        data = Icons.medication;
        color = Colors.red;
        break;
      case 'meal':
        data = Icons.restaurant;
        color = Colors.orange;
        break;
      case 'rest':
        data = Icons.nightlight_round;
        color = Colors.blueGrey;
        break;
      case 'entertainment':
        data = Icons.favorite;
        color = Colors.purple;
        break;
      default:
        data = Icons.access_time;
        color = Colors.teal;
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.12),
      child: Icon(data, color: color, size: 18),
    );
  }
}

class _RoutineRow {
  final String templateName;
  final String type;
  final String time;
  final String title;
  final String description;
  _RoutineRow({
    required this.templateName,
    required this.type,
    required this.time,
    required this.title,
    required this.description,
  });
}

class _HealthSection extends StatelessWidget {
  final Map<String, dynamic>? metricsDoc;

  const _HealthSection({required this.metricsDoc});

  @override
  Widget build(BuildContext context) {
    if (metricsDoc == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.insights_outlined),
          title: Text('No health metrics available for today'),
        ),
      );
    }

    final m = metricsDoc!;
    final medAdh = '${m['medAdherence7dPct'] ?? 0}%';
    final steps = (m['steps'] != null) ? '${m['steps']} steps' : '—';
    final sleepMin = (m['sleepMinutes'] ?? 0) as int;
    final sleep = sleepMin > 0 ? '${sleepMin ~/ 60}h ${sleepMin % 60}m' : '—';
    final nextAt = (m['nextAppointmentAt'] as Timestamp?)?.toDate();
    final nextStr = nextAt != null ? DateFormat.jm().format(nextAt) : '—';
    final tasksDue = '${m['tasksSummary'] ?? '—'}';
    final location = (m['location'] ?? '—').toString();

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        KpiCard(title: 'Tasks Due', value: tasksDue, icon: Icons.check_circle_outline),
        KpiCard(title: 'Med Adherence', value: medAdh, icon: Icons.medication_liquid),
        KpiCard(title: 'Activity', value: steps, icon: Icons.directions_run),
        KpiCard(title: 'Sleep', value: sleep, icon: Icons.nightlight_round),
        KpiCard(title: 'Next Appt', value: nextStr, icon: Icons.calendar_today),
        KpiCard(title: 'Location', value: location, icon: Icons.location_on),
      ],
    );
  }
}

class _AnnouncementsSection extends StatelessWidget {
  final _ctrl = AnnouncementController();
  _AnnouncementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: _ctrl.streamForUserType('caregiver'), // or compute userType dynamically
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Loading announcements…'),
            ),
          );
        }
        final anns = snap.data!;
        if (anns.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.campaign_outlined),
              title: Text('No new announcements.'),
            ),
          );
        }
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.campaign_outlined, color: Colors.blue),
                title: const Text('Announcements'),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AllAnnouncementsPage()),
                    );
                  },
                  child: const Text('View all'),
                ),
              ),
              const Divider(height: 0),
              ...anns.take(3).map((a) => ListTile(
                    title: Text(a.title),
                    subtitle: Text(
                      a.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class EventReminder {
  final String id;        // field name under reminders/{userKey}
  final String title;
  final String startTime; // ISO-8601 string
  final int duration;     // minutes
  final String createdAt; // ISO-8601 string

  EventReminder({
    required this.id,
    required this.title,
    required this.startTime,
    required this.duration,
    required this.createdAt,
  });

  factory EventReminder.fromMap(String id, Map<String, dynamic> m) {
    int _toInt(Object? v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return EventReminder(
      id: id,
      title: (m['title'] ?? '').toString(),
      startTime: (m['startTime'] ?? '').toString(),
      duration: _toInt(m['duration']),
      createdAt: (m['createdAt'] ?? '').toString(),
    );
  }
}

/// View-model with owner context for listing
class _OwnedReminder {
  final String elderlyUid;
  final String elderlyLabel; // name or fallback to uid
  final EventReminder r;

  _OwnedReminder({
    required this.elderlyUid,
    required this.elderlyLabel,
    required this.r,
  });

  DateTime? get start => DateTime.tryParse(r.startTime);
}

/// ─────────────────────────────────────────────────────────────────
/// Caregiver section: shows upcoming reminders for all linked elderly
/// Pass in the caregiver's list of elderly UIDs and (optionally) a
/// lookup map for display names.
/// ─────────────────────────────────────────────────────────────────
class CaregiverUpcomingRemindersSection extends StatefulWidget {
  /// All elderly UIDs linked to this caregiver (from caregiver profile).
  final List<String> elderlyIds;

  /// Optional display names for each elderly UID.
  /// If absent or missing, the UI will show the UID.
  final Map<String, String> elderlyNameByUid;

  const CaregiverUpcomingRemindersSection({
    super.key,
    required this.elderlyIds,
    this.elderlyNameByUid = const {},
  });

  @override
  State<CaregiverUpcomingRemindersSection> createState() =>
      _CaregiverUpcomingRemindersSectionState();
}

class _CaregiverUpcomingRemindersSectionState
    extends State<CaregiverUpcomingRemindersSection> {
  final _db = FirebaseFirestore.instance;

  /// uid -> emailKey (for /reminders/{emailKey})
  final Map<String, String> _emailKeyByUid = {};

  /// Active Firestore subscriptions (one per elderly reminders doc)
  final List<StreamSubscription> _subs = [];

  /// In-memory store: uid -> reminderId -> EventReminder
  final Map<String, Map<String, EventReminder>> _byOwner = {};

  /// UI filter: '__ALL__' or a specific elderlyUid
  String _selected = '__ALL__';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initAndSubscribe();
  }

  @override
  void didUpdateWidget(covariant CaregiverUpcomingRemindersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.elderlyIds.toSet() != widget.elderlyIds.toSet()) {
      _teardownSubs();
      _emailKeyByUid.clear();
      _byOwner.clear();
      _selected = '__ALL__';
      _initAndSubscribe();
    }
  }

  @override
  void dispose() {
    _teardownSubs();
    super.dispose();
  }

  void _teardownSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  /// Resolve AccountByUid/{uid}.emailKey, then subscribe to /reminders/{emailKey}
  Future<void> _initAndSubscribe() async {
    final ids = widget.elderlyIds.where((e) => e.trim().isNotEmpty).toList();
    if (ids.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    for (final uid in ids) {
      try {
        final byUid = await _db.collection('AccountByUid').doc(uid).get();
        final emailKey = (byUid.data()?['emailKey'] as String?)?.trim();
        if (emailKey == null || emailKey.isEmpty) {
          // Skip if no emailKey recorded; still mark structure to avoid NPE
          _emailKeyByUid[uid] = '';
          _byOwner[uid] = {};
          continue;
        }

        _emailKeyByUid[uid] = emailKey;
        _byOwner[uid] = {};

        // subscribe to /reminders/{emailKey}
        final sub = _db.collection('reminders').doc(emailKey).snapshots().listen(
          (snap) {
            final next = <String, EventReminder>{};
            if (snap.exists) {
              final data = snap.data() ?? {};
              data.forEach((k, v) {
                if (v is Map<String, dynamic>) {
                  next[k] = EventReminder.fromMap(k, v);
                } else if (v is Map) {
                  next[k] = EventReminder.fromMap(k, Map<String, dynamic>.from(v));
                }
              });
            }
            setState(() {
              _byOwner[uid] = next;
              _loading = false;
            });
          },
          onError: (_) {
            // keep UI responsive even if one stream errors
            setState(() => _loading = false);
          },
        );

        _subs.add(sub);
      } catch (_) {
        // ignore this uid on error; continue with others
        setState(() => _loading = false);
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  List<_OwnedReminder> get _allOwned {
    final out = <_OwnedReminder>[];
    _byOwner.forEach((uid, map) {
      final label = widget.elderlyNameByUid[uid] ?? uid;
      map.forEach((_, r) {
        out.add(_OwnedReminder(elderlyUid: uid, elderlyLabel: label, r: r));
      });
    });
    // sort by start time ascending (nulls last)
    out.sort((a, b) {
      final ax = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bx = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ax.compareTo(bx);
    });
    return out;
  }

  List<_OwnedReminder> get _filtered {
    final all = _allOwned;
    if (_selected == '__ALL__') return all;
    return all.where((e) => e.elderlyUid == _selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.elderlyIds;
    final list = _filtered;

    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: LinearProgressIndicator()),
        ),
      );
    }

    if (ids.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.people_outline),
          title: Text('No linked elderly found.'),
          subtitle: Text('Link an elderly profile to view their reminders here.'),
        ),
      );
    }

    if (list.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_available_outlined),
                title: Text('No upcoming event reminders for the selection.'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 8),
            ...list.map((o) {
              final start = o.start;
              final startStr = start != null
                  ? DateFormat('EEE, MMM d, h:mm a').format(start)
                  : '—';
              final endStr = _fmtEnd(start, o.r.duration);

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event, color: Colors.orange),
                title: Text(o.r.title.isEmpty ? 'Reminder' : o.r.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  endStr.isNotEmpty ? '$startStr – $endStr' : startStr,
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.blueGrey.withOpacity(0.1),
                  ),
                  child: Text(
                    o.elderlyLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                onTap: () {
                  // Optionally navigate to detail page or edit dialog
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '__ALL__',
        child: Text('All elderly'),
      ),
      ...widget.elderlyIds.map((uid) {
        final label = widget.elderlyNameByUid[uid] ?? uid;
        return DropdownMenuItem(value: uid, child: Text(label));
      }),
    ];

    return Row(
      children: [
        Text('Upcoming Event Reminders', style: theme.titleMedium),
        const Spacer(),
        DropdownButton<String>(
          value: _selected,
          onChanged: (v) => setState(() => _selected = v ?? '__ALL__'),
          items: items,
        ),
      ],
    );
  }

  String _fmtEnd(DateTime? start, int minutes) {
    if (start == null || minutes <= 0) return '';
    final end = start.add(Duration(minutes: minutes));
    return DateFormat('h:mm a').format(end);
  }
}

class _CaregiverMedicalQuickActions extends StatelessWidget {
  final UserProfile userProfile;
  final String? elderlyId;

  const _CaregiverMedicalQuickActions({
    required this.userProfile,
    required this.elderlyId,
  });

  @override
  Widget build(BuildContext context) {
    if (elderlyId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medical Access & Shopping', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _medicalButton(
              context,
              title: 'See GP Now',
              icon: Icons.local_hospital,
              color: Colors.red.shade100,
              iconColor: Colors.red.shade800,
              page: GPConsultationPage(userProfile: userProfile),
            ),
            _medicalButton(
              context,
              title: 'Book Appt',
              icon: Icons.calendar_month,
              color: Colors.blue.shade100,
              iconColor: Colors.blue.shade800,
              page: ConsultationBookingPage(userProfile: userProfile),
            ),
            _medicalButton(
                context,
                title: 'Shop Meds',
                icon: Icons.shopping_bag,
                color: Colors.orange.shade100,
                iconColor: Colors.orange.shade800,
                page: const shop.ShopPage(),
              ),
              _medicalButton(
  context,
  title: 'Upload Health',
  icon: Icons.upload_file,
  color: Colors.teal.shade100,
  iconColor: Colors.teal.shade800,
  page: CaregiverHealthUploadPage(caregiver: userProfile),
)
          ],
        ),
      ],
    );
  }

  Widget _medicalButton(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required Color iconColor,
      required Widget page}) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Icon(icon, size: 32, color: iconColor),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTodaySection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(DocumentReference ref, bool done) onToggleDone;
  final void Function(DocumentReference ref, Map<String, dynamic> data) onOpen;

  const _ScheduleTodaySection({
    required this.items,
    required this.onToggleDone,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.inbox_outlined),
          title: Text('No upcoming items for today'),
        ),
      );
    }
    return Card(
      child: Column(
        children: items.map((m) {
          final dueAt = (m['dueAt'] as Timestamp?)?.toDate();
          final kind = (m['kind'] as String?) ?? 'task';
          final done = (m['done'] as bool?) ?? false;
          final docRef = m['ref'] as DocumentReference;

          return ListTile(
            leading: Icon(
              kind == 'med' ? Icons.medical_services : Icons.event,
              color: kind == 'med' ? Colors.blue : Colors.teal,
            ),
            title: Text(
              '${dueAt != null ? '${DateFormat.jm().format(dueAt)} — ' : ''}${m['title'] ?? 'Untitled'}',
            ),
            subtitle: Text(m['location']?.toString() ?? 'No location'),
            trailing: IconButton(
              icon: Icon(
                done ? Icons.done_all : Icons.check_box_outline_blank,
                color: done ? Colors.green : null,
              ),
              onPressed: () => onToggleDone(docRef, done),
            ),
            onTap: () => onOpen(docRef, m),
          );
        }).toList(),
      ),
    );
  }
}


class MedicationTracker extends StatefulWidget {
  
  final List<dynamic> reminders;

  final Map<String, String> elderlyLookup;

  final Future<void> Function(String elderlyId, String reminderId) onMarkDone;

    final String? initialSelectedElderlyId;
      final ValueChanged<String /* '__ALL__' or elderlyId */ >? onFilterChanged;



  const MedicationTracker({
    super.key,
    required this.reminders,
    required this.onMarkDone,
    this.elderlyLookup = const {},
    this.initialSelectedElderlyId,
    this.onFilterChanged,
  });

  @override
  State<MedicationTracker> createState() => _MedicationTrackerState();
}

class MedicationReminderLike {
  final String id;
  final String elderlyId;
  final String name;
  final String dosage;
  final String time;
  final bool isCompleted;

  MedicationReminderLike({
    required this.id,
    required this.elderlyId,
    required this.name,
    required this.dosage,
    required this.time,
    required this.isCompleted,
  });

  /// Convert from Map or strongly-typed model.
  factory MedicationReminderLike.fromAny(dynamic v) {
    if (v is MedicationReminderLike) return v;

    // Assume Map-like
    final Map<String, dynamic> m = (v as Map).map(
      (k, val) => MapEntry(k.toString(), val),
    );

    final status = (m['status'] ?? '').toString().trim().toLowerCase();
    final completed = (m['isCompleted'] is bool)
        ? (m['isCompleted'] as bool)
        : (status == 'completed' || status == 'done' || status == 'taken');

    return MedicationReminderLike(
      id: (m['id'] ?? '').toString(),
      elderlyId: (m['elderlyId'] ?? '').toString(),
      name: (m['medicationName'] ?? 'Medication').toString(),
      dosage: (m['dosage'] ?? '').toString(),
      time: (m['reminderTime'] ?? 'Anytime').toString(),
      isCompleted: completed,
    );
  }
}

class _MedicationTrackerState extends State<MedicationTracker> {
  String _selectedElderly = '__ALL__';

  @override
  void initState() {
    super.initState();
    // if parent passed an initial filter AND it's valid, use it; else '__ALL__'
    final ids = _elderlyIds; // computed from current reminders
    final pref = widget.initialSelectedElderlyId?.trim();
    if (pref != null && pref.isNotEmpty && ids.contains(pref)) {
      _selectedElderly = pref;
    } else {
      _selectedElderly = '__ALL__';
    }
  }

  List<MedicationReminderLike> get _all =>
      widget.reminders.map(MedicationReminderLike.fromAny).toList();

  List<String> get _elderlyIds {
    final ids = _all.map((e) => e.elderlyId).where((e) => e.isNotEmpty).toSet().toList();
    ids.sort();
    return ids;
  }

  String _elderlyLabel(String id) =>
      id == '__ALL__' ? 'All elderly' : (widget.elderlyLookup[id] ?? id);

  List<MedicationReminderLike> get _filtered =>
      _selectedElderly == '__ALL__'
          ? _all
          : _all.where((r) => r.elderlyId == _selectedElderly).toList();

  Future<void> _nudgeToTakeMedicine(MedicationReminderLike item) async {
    final db = FirebaseFirestore.instance;
    final fromUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final toUid = item.elderlyId;
    final title = 'Time to take your medication';
    final msg = [
      if (item.name.isNotEmpty) item.name,
      if (item.dosage.isNotEmpty) item.dosage,
      if (item.time.isNotEmpty) 'at ${item.time}',
    ].join(' • ');

    await db.collection('notifications').add({
      'toUid': toUid,
      'fromUid': fromUid,
      'type': 'medication_prompt',     // NEW type for your rules/handlers
      'title': title,
      'message': msg,
      'reminderId': item.id,
      'elderlyId': toUid,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'priority': 'medium',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder sent to take medicine')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meds = _filtered;

    if (meds.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.medication_outlined),
                title: Text('No medications scheduled for the selected elderly'),
              ),
            ],
          ),
        ),
      );
    }

    final total = meds.length;
    final done = meds.where((m) => m.isCompleted).length;
    final pct = total == 0 ? 0.0 : (done / total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('$done of $total taken today'),
                const Spacer(),
                Text('${(pct * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: pct.clamp(0.0, 1.0)),
            const SizedBox(height: 8),

            // Items
            ...meds.map((m) {
              final elderlyName = _elderlyLabel(m.elderlyId);
              final subtitleParts = <String>[
                if (elderlyName.isNotEmpty) 'For: $elderlyName',
                if (m.dosage.isNotEmpty) m.dosage,
                m.time,
              ];
              final subtitle = subtitleParts.join(' • ');

              final trailing = m.isCompleted
                  ? const Chip(label: Text('Done'))
                  : Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => widget.onMarkDone(m.elderlyId, m.id),
                          child: const Text('Mark done'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _nudgeToTakeMedicine(m),
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('Nudge'),
                        ),
                      ],
                    );

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  m.isCompleted ? Icons.check_circle : Icons.medication,
                  color: m.isCompleted ? Colors.green : null,
                ),
                title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(subtitle),
                trailing: trailing,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ids = _elderlyIds;

    return Row(
      children: [
        Text('Medication Tracker', style: theme.titleMedium),
        const Spacer(),
        DropdownButton<String>(
          value: _selectedElderly,
          onChanged: (v) => setState(() => _selectedElderly = v ?? '__ALL__'),
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem(
              value: '__ALL__',
              child: Text('All elderly'),
            ),
            ...ids.map((id) => DropdownMenuItem(
                  value: id,
                  child: Text(_elderlyLabel(id)),
                )),
          ],
        ),
      ],
    );
  }
}


class _NotificationsSection extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(String id) onMarkRead;
  final Future<void> Function() onMarkAll;


  const _NotificationsSection({
    required this.notifications,
    required this.onMarkRead,
    required this.onMarkAll,
  });

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !(n['read'] as bool? ?? false)).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Recent Notifications', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (unread > 0)
                  FilledButton.tonal(
                    onPressed: onMarkAll,
                    child: Text('Mark all ($unread) read'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (notifications.isEmpty)
              const ListTile(
                leading: Icon(Icons.notifications_none),
                title: Text('No notifications'),
              )
            else
              ...notifications.take(5).map((n) {
                final title = (n['title'] ?? 'Notification').toString();
                final msg = (n['message'] ?? '').toString();
                final read = (n['read'] ?? false) as bool;
                final priority = (n['priority'] ?? 'low') as String;
                final type = (n['type'] ?? '').toString();
                final kind = (n['kind'] ?? '').toString();
                Color dot;
                switch (priority) {
                  case 'critical':
                    dot = const Color(0xFFdc3545);
                    break;
                  case 'high':
                    dot = const Color(0xFFfd7e14);
                    break;
                  case 'medium':
                    dot = const Color(0xFFffc107);
                    break;
                  case 'low':
                  default:
                    dot = const Color(0xFF28a745);
                }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg),
                      if (type == 'payment_required')
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.payment),
                            label: const Text('Pay Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Navigate to Payment Page')),
                              );
                            },
                          ),
                        ),
                      if (type == 'gp_invite')
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.video_call),
                            label: const Text('Join Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Join Consultation Video Call')),
                              );
                            },
                          ),
                        ),
                        if (type == 'ok_ping') ...[
  const SizedBox(height: 6),
  if (kind == 'are_you_ok')
    Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text("I'm OK"),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('notifications').add({
              'toUid': n['fromUid'],
              'fromUid': n['toUid'],
              'type': 'ok_ping',
              'kind': 'im_ok',
              'title': 'I am OK',
              'message': '',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'priority': 'low',
            });
            await onMarkRead(n['id'] as String);
          },
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text('Need Help'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('notifications').add({
              'toUid': n['fromUid'],
              'fromUid': n['toUid'],
              'type': 'ok_ping',
              'kind': 'need_help',
              'title': 'I need help',
              'message': '',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'priority': 'high',
            });
            await onMarkRead(n['id'] as String);
          },
        ),
      ],
    ),
  if (kind == 'im_ok')
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Chip(
        label: const Text("Elder replied: I'm OK"),
        avatar: const Icon(Icons.check_circle, color: Colors.green),
      ),
    ),
  if (kind == 'need_help')
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Chip(
        label: const Text("Elder needs help!"),
        avatar: const Icon(Icons.warning_amber_rounded, color: Colors.red),
      ),
    ),
],
                    ],
                  ),
                  trailing: read
                      ? const Icon(Icons.check, color: Colors.green, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.mark_email_read),
                          onPressed: () => onMarkRead(n['id'] as String),
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedPreview extends StatelessWidget {
  final int limit;
  const _CommunityFeedPreview({this.limit = 3});

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('SharedExperiences')            // same as ElderlyHomePage
        .orderBy('sharedAt', descending: true)
        .limit(limit);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: ListTile(title: Text('Loading community…')));
        }
        if (snapshot.hasError) {
          return const Card(child: ListTile(title: Text('Error loading community feed.')));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: const Text('Be the first to share in the community!'),
              trailing: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ShareExperiencePage()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Share now'),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Community Feed', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ShareExperiencePage()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Share'),
                  ),
                ]),
                const SizedBox(height: 6),
                ...docs.map((d) {
                  final m = d.data();
                  final title = (m['title'] ?? '').toString().trim();
                  final description = (m['description'] ?? '').toString().trim();
                  final content = description.isEmpty
                      ? (title.isEmpty ? 'Untitled' : title)
                      : (description.length > 100 ? '${description.substring(0, 100)}…' : description);

                  return ListTile(
                    leading: const Icon(Icons.forum_outlined),
                    title: Text(content),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ShareExperiencePage()),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}



class _QuickActions extends StatelessWidget {
  final UserProfile userProfile;
  final VoidCallback onCreateEvent;
  final VoidCallback onAddMedication;
  final VoidCallback onScheduleAppt;
  final VoidCallback onViewReports;
  final VoidCallback onGenerateReport;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  const _QuickActions({
    required this.userProfile,
    required this.onCreateEvent,
    required this.onAddMedication,
    required this.onScheduleAppt,
    required this.onViewReports,
    required this.onGenerateReport,
    required this.onNotifications,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_QA>[
      _QA(Icons.medical_services, 'Add Medication', (){
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreateMedicationReminderPage(userProfile: userProfile)),
        );
      }),
      _QA(Icons.bar_chart, 'View Reports', (){
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ViewReportsCaregiverPage(caregiverEmail: userProfile.email!)),
        );
      }),
      _QA(Icons.insights, 'Upload Health Records', (){
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CaregiverHealthUploadPage(caregiver: userProfile)),
        );
      }),
      _QA(Icons.groups, 'Share Experiences', () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShareExperiencePage()));
      }),
      _QA(Icons.access_time, 'Care Routine', () {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const CareRoutineTemplatePage()));
}),
      _QA(Icons.notifications, 'Notifications', onNotifications),
      _QA(Icons.settings, 'Settings', (){
        Navigator.push(context, MaterialPageRoute(builder: (_) => CgAccountPage(userProfile: userProfile)));
      }),

      _QA(Icons.call, 'Call Elderly', () async {
  final state = context.findAncestorStateOfType<_CaregiverHomePageState>();
  if (state == null) return;
  final vm = state._c.latestVm;

  // Only accept canonical keys
  final ids = <String>{
    ...((vm?.linkedElderlyIds ?? const <String>[]).map((e) => e.trim())),
  }.where((e) => e.isNotEmpty).toList();

  if (ids.isEmpty) {
    state._snack('No elderly linked. Add an elderlyId first.');
    return;
  }

  await state._callElderFlow(ids);
}),

_QA(Icons.video_call, 'Video Call', () async {
  final state = context.findAncestorStateOfType<_CaregiverHomePageState>();
  if (state == null) return;
  final vm = state._c.latestVm;

  final ids = <String>{
    ...((vm?.linkedElderlyIds ?? const <String>[]).map((e) => e.trim())),
  }.where((e) => e.isNotEmpty).toList();

  if (ids.isEmpty) {
    state._snack('No elderly linked. Add an elderlyId first.');
    return;
  }

  await state._videoCallFlow(ids);
}),

      _QA(Icons.account_balance_wallet, 'Wallet', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WalletPage(userProfile: userProfile)),
        );
      }),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items
                  .map((qa) => OutlinedButton.icon(
                        onPressed: qa.onTap,
                        icon: Icon(qa.icon),
                        label: Text(qa.label),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QA {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _QA(this.icon, this.label, this.onTap);
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text)),
      );
}
