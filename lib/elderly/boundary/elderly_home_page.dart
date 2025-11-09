import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../controller/elderly_home_controller.dart' as ehc;
import '../../models/user_profile.dart';
import '../../features/communicate_page.dart';
import '../../medical/gp_consultation_page.dart';
import '../../medical/consultation_booking_page.dart';
import '../../medical/consultation_history_page.dart' as ch;
import '../../medical/health_records_page.dart' as hr;
import '../../medical/shop_page.dart' as shop;
import '../../financial/wallet_page.dart';
import 'account/caregiver_access_page.dart';
import '../../services/cart_services.dart';
import 'package:provider/provider.dart';
import '../../features/share_experience_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../announcement/announcements_widget.dart';
import '../../announcement/all_announcement_page.dart';
import '../../models/announcement.dart';
import 'create_event_reminders_page.dart';
import 'view_activties_page.dart';
import '../../widgets/feedback_section.dart';
import '../../assistant_chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/learning_reco_service.dart';
import 'learning_page.dart';

/// -------- Caregiver lookup for an elder (UID == elderlyId)
Stream<List<Map<String, dynamic>>> caregiversForElder$(String elderlyId) {
  final q = FirebaseFirestore.instance
      .collection('Account')
      .where('elderlyIds', arrayContains: elderlyId);

  return q.snapshots().map((qs) => qs.docs.map((d) {
        final m = d.data();
        final first = (m['firstName'] ?? m['firstname'] ?? '').toString().trim();
        final last  = (m['lastName']  ?? m['lastname']  ?? '').toString().trim();
        final safe  = (m['safeDisplayName'] ?? m['displayName'] ?? '').toString().trim();
        final name  = safe.isNotEmpty ? safe : [first, last].where((x) => x.isNotEmpty).join(' ').trim();

        return {
          'uid': d.id,
          'name': name.isEmpty ? 'caregiver' : name,
          'email': (m['email'] ?? '').toString(),
          'phone': (m['phoneNum'] ?? m['caregiverPhone'] ?? '').toString(),
          'photoUrl': (m['photoURL'] ?? m['photoUrl'] ?? '').toString(),
          'userType': (m['userType'] ?? '').toString(),
        };
      }).toList());
}

/// Allowed kinds of "OK" pings.
const _okPingKinds = {'are_you_ok', 'im_ok', 'need_help'};

/// Create a status ping in /notifications and return the new doc ID.
Future<String> _sendStatusPing({
  required String fromUid,
  required String toUid,
  required String kind, // 'are_you_ok' | 'im_ok' | 'need_help'
  String? message,
  String? elderlyId,
  String? caregiverId,
  String? fromName,
  String? toName,
}) async {
  if (!_okPingKinds.contains(kind)) {
    throw ArgumentError.value(kind, 'kind', 'Unsupported status kind');
  }

  final now = FieldValue.serverTimestamp();

  final docRef = await FirebaseFirestore.instance.collection('notifications').add({
    'toUid': toUid,
    'fromUid': fromUid,
    'participants': [fromUid, toUid],
    'type': 'ok_ping',
    'kind': kind,
    'schema': 1,
    'title': kind == 'are_you_ok' ? 'Are you OK?' : (kind == 'im_ok' ? 'I am OK' : 'I need help'),
    'message': (message ?? '').trim(),
    'priority': kind == 'need_help' ? 'high' : 'low',
    if (elderlyId != null) 'elderlyId': elderlyId,
    if (caregiverId != null) 'caregiverId': caregiverId,
    if (fromName != null && fromName.isNotEmpty) 'fromName': fromName,
    if (toName != null && toName.isNotEmpty) 'toName': toName,
    'createdAt': now,
    'timestamp': now,
    'read': false,
    'readAt': null,
  });

  return docRef.id;
}

class ElderlyHomePage extends StatefulWidget {
  final UserProfile userProfile;

  const ElderlyHomePage({Key? key, required this.userProfile}) : super(key: key);

  @override
  _ElderlyHomePageState createState() => _ElderlyHomePageState();
}

class _ElderlyHomePageState extends State<ElderlyHomePage> {
  late ehc.ElderlyHomeController _homeController;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _announcementsKey = GlobalKey();
  final GlobalKey _eventRemindersKey = GlobalKey();
  final GlobalKey _recommendationsKey = GlobalKey();
  final GlobalKey _shareExperienceKey = GlobalKey();
  final GlobalKey _activitiesKey = GlobalKey();
  final GlobalKey _feedbackKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    _homeController = ehc.ElderlyHomeController(uid: widget.userProfile.uid);

    final elderlyId = widget.userProfile.uid;
    FirebaseFirestore.instance
        .collection('Account')
        .where('elderlyIds', arrayContains: elderlyId)
        .get()
        .then((qs) {
          debugPrint('DEBUG: caregivers found for $elderlyId = ${qs.docs.length}');
          for (final d in qs.docs) {
            debugPrint('CG: ${d.id} → ${d.data()}');
          }
        })
        .catchError((e) {
          debugPrint('DEBUG: error fetching caregivers: $e');
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeController.debugLogCaregiversForCurrentUser();
    });
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

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

      body: Row(
        children: [
          _buildQuickNavigation(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildCaregiverContactRow(context),
                  const SizedBox(height: 24),
                  _buildCaregiverInfoCard(context),
                  const SizedBox(height: 16),
                  _buildSectionTitle(context, "My Caregivers", GlobalKey(), showSeeAll: false),
                  _buildCaregiverContactList(context),
                  const SizedBox(height: 24),

                  _buildQuickActions(context),
                  const SizedBox(height: 24),

                  _buildSectionTitle(context, "Announcements", _announcementsKey, showSeeAll: false),
                  _buildAnnouncementsSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle(context, "Event Reminders", _eventRemindersKey, showSeeAll: true),
                    _buildEventRemindersSection(),
                    const SizedBox(height: 24),


                  _buildSectionTitle(context, "Learning Recommendations", _recommendationsKey, showSeeAll: true),
                  _buildLearningRecommendationsSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle(context, "Activities", _activitiesKey, showSeeAll: true),
                      _buildActivitiesPreviewSection(),
                      const SizedBox(height: 24),

                  _buildCommunityButton(context),
                  const SizedBox(height: 32),

                  _buildSectionTitle(context, "Community Feed", _shareExperienceKey, showSeeAll: true),
                  _buildCommunityFeedSection(context),
                  const SizedBox(height: 32),

                  _buildSectionTitle(context, "Shared Feedback on Platform", GlobalKey(), showSeeAll: false),
                  _buildFeedbackSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------- Top identity card (Elder + caregivers summary)
  Widget _buildCaregiverInfoCard(BuildContext context) {
    final elderlyId = widget.userProfile.uid;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: caregiversForElder$(elderlyId),
      builder: (context, snap) {
        final caregivers = snap.data ?? const [];
        final isLinked = caregivers.isNotEmpty;

        final label = isLinked
            ? caregivers.map((c) => c['name'] as String).join(', ')
            : 'No Caregiver Linked';

        return _elderSummaryCard(
          context,
          name: widget.userProfile.safeDisplayName,
          id: elderlyId,
          caregiverSummary: label,
          isLinked: isLinked,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CaregiverAccessPage()));
          },
        );
      },
    );
  }

  Widget _elderSummaryCard(
    BuildContext context, {
    required String name,
    required String id,
    required String caregiverSummary,
    required bool isLinked,
    VoidCallback? onTap,
  }) {
    final shortId = id.isNotEmpty
        ? (id.length > 8 ? '${id.substring(0, 8)}…' : id)
        : '—';

    return GestureDetector(
      onTap: onTap,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ID: $shortId', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text('Caregiver: $caregiverSummary', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ]),
            ),
            isLinked
                ? const Icon(Icons.favorite, color: Colors.white, size: 40)
                : const Icon(Icons.people_outline, color: Colors.white, size: 40),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }

  /// ---------------- “My Caregivers” list
  Widget _buildCaregiverContactList(BuildContext context) {
    final elderlyId = widget.userProfile.uid;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: caregiversForElder$(elderlyId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }
        final caregivers = snap.data ?? const [];
        if (caregivers.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('No caregivers linked yet.'),
              subtitle: Text('Ask your caregiver to link you from their app.'),
            ),
          );
        }

        return Column(
          children: caregivers.map((cg) {
            final uid = cg['uid'] as String;
            final name = cg['name'] as String;
            final email = (cg['email'] as String?) ?? '';
            final phone = (cg['phone'] as String?) ?? '';

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: Text([email, phone].where((s) => s.isNotEmpty).join(' · ')),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Chat / Call',
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunicatePage(userProfile: widget.userProfile, partnerUid: uid),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Call',
                      icon: const Icon(Icons.call),
                      onPressed: () async {
                        final tel = phone.trim();
                        if (tel.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No phone on file.')),
                          );
                          return;
                        }
                        final uri = Uri(scheme: 'tel', path: tel);
                        final ok = await canLaunchUrl(uri);
                        if (!ok) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('This device cannot place calls.')),
                          );
                          return;
                        }
                        await launchUrl(uri);
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// ---------------- Left rail
  Widget _buildQuickNavigation() {
    return Container(
      width: 60,
      color: Colors.deepPurple.shade200,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          _buildNavLink(Icons.campaign, 'Announce', () => _scrollToSection(_announcementsKey)),
          _buildNavLink(Icons.calendar_today, 'Event Reminders', () => _scrollToSection(_eventRemindersKey)),
          _buildNavLink(Icons.lightbulb_outline, 'Learn', () => _scrollToSection(_recommendationsKey)),
          _buildNavLink(Icons.local_activity_outlined, 'Activities', () => _scrollToSection(_activitiesKey)),
          _buildNavLink(Icons.people_outline, 'Share Experience', () => _scrollToSection(_shareExperienceKey)),
          _buildNavLink(Icons.feedback_outlined, 'Feedback', () => _scrollToSection(_feedbackKey)),
        ],
      ),
    );
  }

  Widget _buildNavLink(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  /// ---------------- Header + quick actions
  Widget _buildCaregiverContactRow(BuildContext context) {
    Future<String?> _showElderlyStatusSheet() async {
      return showModalBottomSheet<String>(
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
                leading: const Icon(Icons.check_circle_outline),
                title: const Text("Send: I'm OK"),
                onTap: () => Navigator.pop(context, 'im_ok'),
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: const Text('Send: I need help'),
                onTap: () => Navigator.pop(context, 'need_help'),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Ask caregiver: Are you OK?'),
                onTap: () => Navigator.pop(context, 'are_you_ok'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CommunicatePage(userProfile: widget.userProfile)),
              );
            },
            icon: const Icon(Icons.call, size: 24),
            label: const Text("Call Caregiver", style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.pink.shade400,
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final choice = await _showElderlyStatusSheet();
              if (choice == null) return;

              try {
                final qs = await FirebaseFirestore.instance
                    .collection('Account')
                    .where('elderlyIds', arrayContains: widget.userProfile.uid)
                    .get();

                final caregiverUids = qs.docs.map((d) => d.id).toList();
                if (caregiverUids.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('No linked caregivers.')));
                  return;
                }

                await Future.wait(caregiverUids.map((cg) => _sendStatusPing(
                      fromUid: widget.userProfile.uid,
                      toUid: cg,
                      kind: choice,
                      elderlyId: widget.userProfile.uid,
                      caregiverId: cg,
                    )));

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Status sent to ${caregiverUids.length} caregiver(s).')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Failed to send status: $e')));
              }
            },
            icon: const Icon(Icons.favorite_outline, size: 24),
            label: const Text("I am OK / Help", style: TextStyle(fontSize: 16)),
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

  Future<void> markNotificationRead(String id) async {
    final ref = FirebaseFirestore.instance.collection('notifications').doc(id);
    await ref.update({'read': true, 'readAt': FieldValue.serverTimestamp()});
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "Immediate Medical Access", GlobalKey(), showSeeAll: false),
        const SizedBox(height: 10),
        _buildActionGrid([
          _buildActionButton(
            context,
            'See GP now',
            Icons.local_hospital,
            Colors.red.shade100,
            Colors.red.shade800,
            GPConsultationPage(userProfile: widget.userProfile),
          ),
          _buildActionButton(
            context,
            'Book GP Consultation',
            Icons.calendar_month,
            Colors.blue.shade100,
            Colors.blue.shade800,
            ConsultationBookingPage(userProfile: widget.userProfile),
          ),
          _buildActionButton(
            context,
            'Consultation History',
            Icons.history,
            Colors.purple.shade100,
            Colors.purple.shade800,
            ch.ConsultationHistoryPage(),
          ),
        ]),
        const SizedBox(height: 24),
        _buildSectionTitle(context, "Health Records & Shop Medicine", GlobalKey(), showSeeAll: false),
        const SizedBox(height: 10),
        _buildActionGrid([
          _buildActionButton(
            context,
            'My Health records',
            Icons.folder_open,
            Colors.green.shade100,
            Colors.green.shade800,
            hr.HealthRecordsPage(userProfile: widget.userProfile),
          ),
          _buildActionButton(
            context,
            'Shop Meds & wellness',
            Icons.shopping_bag,
            Colors.orange.shade100,
            Colors.orange.shade800,
            const shop.ShopPage(),
          ),
          _buildActionButton(
            context,
            'Wellness Tips',
            Icons.self_improvement,
            Colors.cyan.shade100,
            Colors.cyan.shade800,
            ShareExperiencePage(),
          ),
        ]),
      ],
    );
  }

  Widget _buildActionGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: children,
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color bgColor,
    Color iconColor,
    Widget targetPage,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => targetPage)),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, size: 36, color: iconColor),
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

  Widget _activitiesSection() {
    return Container(
      height: 100,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: const Text('Activites'),
    );
  }

  Widget _buildFeedbackSection() {
    return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          'Shared Feedback on Platform',
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 12),
      const FeedbackSection(),
    ],
  );
}
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome back, ${widget.userProfile.safeDisplayName}!'),
        ]),
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WalletPage(userProfile: widget.userProfile)),
          ),
          icon: const Icon(Icons.account_balance_wallet, color: Color(0xFF6A1B9A)),
          label: const Text('My Wallet', style: TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, GlobalKey key, {bool showSeeAll = true}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (showSeeAll)
            TextButton(
              onPressed: () {
                if (title == "Upcoming Events Reminder") {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventRemindersPage()));
                } else if (title == "Community Feed") {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ShareExperiencePage()));
                } else {
                  debugPrint("See all $title");
                }
              },
              child: const Text("See all", style: TextStyle(color: Colors.blue)),
            ),
        ],
      ),
    );
  }

  /// -------- Event Reminder
  Widget _buildEventRemindersSection() {
  String _fmtShort(DateTime dt) => DateFormat('EEE, MMM d • h:mm a').format(dt);

  Future<void> _createReminder() async {
    final titleCtrl = TextEditingController();
    DateTime? start;
    int duration = 30;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 12,
        ),
        child: StatefulBuilder(
          builder: (context, setS) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create Reminder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          start == null ? 'Pick date & time' : _fmtShort(start!),
                        ),
                        onPressed: () async {
                          final now = DateTime.now();
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 3),
                            initialDate: now,
                          );
                          if (d == null) return;
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              now.add(const Duration(minutes: 5)),
                            ),
                          );
                          if (t == null) return;
                          setS(() {
                            start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => duration = int.tryParse(v.trim()) ?? 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Create'),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty || start == null || duration <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields.')),
                        );
                        return;
                      }
                      try {
                        await _homeController.createReminder(
                          title: title,
                          start: start!,
                          durationMinutes: duration,
                        );
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editReminder(ehc.EventReminder r) async {
    final titleCtrl = TextEditingController(text: r.title);
    DateTime start = DateTime.tryParse(r.startTime) ?? DateTime.now();
    int duration = r.duration;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 12,
        ),
        child: StatefulBuilder(
          builder: (context, setS) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Update Reminder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text(_fmtShort(start)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(start.year - 1),
                            lastDate: DateTime(start.year + 3),
                            initialDate: start,
                          );
                          if (d == null) return;
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(start),
                          );
                          if (t == null) return;
                          setS(() {
                            start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller:
                            TextEditingController(text: r.duration.toString()),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) =>
                            duration = int.tryParse(v.trim()) ?? r.duration,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty || duration <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all fields.')),
                            );
                            return;
                          }
                          try {
                            await _homeController.updateReminder(
                              reminderId: r.id,
                              title: title,
                              start: start,
                              durationMinutes: duration,
                            );
                            if (mounted) Navigator.pop(context);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('Failed: $e')));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        try {
                          await _homeController.deleteReminder(r.id);
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('My Reminders',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_alarm),
            label: const Text('Create'),
            onPressed: _createReminder,
          ),
        ],
      ),
      const SizedBox(height: 8),
      StreamBuilder<List<ehc.EventReminder>>(
        stream: _homeController.reminders$(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: LinearProgressIndicator());
          }
          if (snap.hasError) {
            return Card(
              color: const Color(0xFFFFEDEE),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading reminders: ${snap.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          final list = snap.data ?? const <ehc.EventReminder>[];
          if (list.isEmpty) {
            return const Card(
              child: ListTile(
                leading: Icon(Icons.alarm_off),
                title: Text('No reminders yet.'),
                subtitle: Text('Tap “Create” to add one.'),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final r = list[i];
              final dt = DateTime.tryParse(r.startTime);
              final when = dt == null ? '—' : _fmtShort(dt);
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.alarm, color: Colors.deepPurple),
                  title: Text(r.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$when • ${r.duration} min'),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _editReminder(r),
                ),
              );
            },
          );
        },
      ),
    ],
  );
}

  /// -------- Announcements
  Widget _buildAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AnnouncementsWidget(),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined, color: Colors.blue),
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
      ],
    );
  }

  /// -------- Learning
  Widget _buildLearningRecommendationsSection() {
  final svc = LearningRecommendationsService();
  return StreamBuilder<List<LearningReco>>(
    stream: svc.subscribeTop(3),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: LinearProgressIndicator());
      }
      if (snap.hasError) {
        return Card(
          color: const Color(0xFFFFEDEE),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading learning recommendations: ${snap.error}',
                style: const TextStyle(color: Colors.red)),
          ),
        );
      }
      final list = snap.data ?? const <LearningReco>[];
      if (list.isEmpty) {
        return const Card(
          child: ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('No learning recommendations yet.'),
            subtitle: Text('Check back soon!'),
          ),
        );
      }

      return Column(
        children: list.map((r) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.lightbulb, color: Colors.deepPurple),
              title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                r.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // open the link if present; otherwise go to See All page
                if (r.url != null && r.url!.trim().isNotEmpty) {
                  final uri = Uri.tryParse(r.url!) ?? Uri.parse('https://${r.url!}');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningResourcesPageRT()));
                }
              },
            ),
          );
        }).toList(),
      );
    },
  );
}

    /// -------- Activities (preview)
Widget _buildActivitiesPreviewSection() {
  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('Activities').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: LinearProgressIndicator());
      }
      if (snapshot.hasError) {
        return Card(
          color: const Color(0xFFFFEDEE),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading activities: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          ),
        );
      }

      final docs = snapshot.data?.docs ?? const [];
      if (docs.isEmpty) {
        return const Card(
          child: ListTile(
            leading: Icon(Icons.local_activity_outlined),
            title: Text('No activities available yet.'),
            subtitle: Text('Check back later for new recommendations.'),
          ),
        );
      }

      // show top 3
      return Column(
        children: docs.take(3).map((d) {
          final m = d.data();
          final title = (m['title'] ?? '').toString();
          final difficulty = (m['difficulty'] ?? '').toString();
          final duration = (m['duration'] ?? '').toString(); // if present
          final subtitleBits = [
            if (difficulty.isNotEmpty) 'Difficulty: $difficulty',
            if (duration.isNotEmpty) 'Duration: $duration'
          ];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.fitness_center, color: Colors.deepPurple),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(subtitleBits.join(' • ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewActivitiesPage()),
                );
              },
            ),
          );
        }).toList(),
      );
    },
  );
}

  /// -------- Community CTA
  Widget _buildCommunityButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShareExperiencePage())),
        icon: const Icon(Icons.people, size: 24),
        label: const Text("Connect with the Community", style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.amber.shade600,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  /// -------- Community Feed (Preview of last 3 stories)
  Widget _buildCommunityFeedSection(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('SharedExperiences')
        .orderBy('sharedAt', descending: true)
        .limit(3);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Community Feed Error: ${snapshot.error}");
          return const Center(child: Text("Error loading feed."));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text("Be the first to share in the community!")),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final title = (data['title'] as String? ?? '').trim();
            final description = (data['description'] as String? ?? '').trim();
            final uidOrKey = (data['user'] as String? ?? '').trim();
            final tsIso = (data['sharedAt'] as String?)?.trim();

            final content = description.isEmpty
                ? (title.isEmpty ? 'No Content' : title)
                : (description.length > 100 ? '${description.substring(0, 100)}…' : description);

            String formattedTime = '';
            if (tsIso != null && tsIso.isNotEmpty) {
              try {
                final dt = DateTime.parse(tsIso);
                formattedTime = DateFormat('MMM d, h:mm a').format(dt);
              } catch (_) {}
            }

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: (() async {
                if (uidOrKey.contains('@')) {
                  return FirebaseFirestore.instance.collection('Account').doc(uidOrKey).get();
                } else {
                  final qs = await FirebaseFirestore.instance
                      .collection('Account')
                      .where('uid', isEqualTo: uidOrKey)
                      .limit(1)
                      .get();
                  return qs.docs.isNotEmpty ? qs.docs.first : null;
                }
              })(),
              builder: (context, accSnap) {
                String author = 'Anonymous';
                final snap = accSnap.data; // may be null

                if (snap != null && snap.exists) {
                  final acc = snap.data()!;
                  final first = (acc['firstname'] as String?)?.trim() ?? '';
                  final last  = (acc['lastname']  as String?)?.trim() ?? '';
                  final full  = '$first $last'.trim();
                  author = full.isEmpty ? (acc['email'] as String? ?? 'Anonymous') : full;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16.0),
                    title: Text(
                      content,
                      style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('by $author',
                              style: TextStyle(
                                  fontSize: 12, fontStyle: FontStyle.italic, color: Colors.deepPurple.shade700)),
                          Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShareExperiencePage())),

                  ),
                );
              }
            );
          },
        );
      },
    );
  }
}

