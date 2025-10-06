import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../controller/elderly_home_controller.dart' as ehc;
import '../../models/user_profile.dart';
import 'community_page.dart';
import 'events_page.dart';
import 'communicate_page.dart';
import '../../medical/gp_consultation_page.dart';
import '../../medical/appointment_booking_page.dart';
import '../../medical/consultation_history_page.dart' as ch;
import '../../medical/health_records_page.dart' as hr;
import '../../medical/medication_shop_page.dart' as shop;
import '../../financial/wallet_page.dart';
import 'link_caregiver_page.dart';
import 'account/caregiver_access_page.dart';
import '../../medical/controller/cart_controller.dart';
import 'package:provider/provider.dart';

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
  final GlobalKey _eventsKey = GlobalKey();
  final GlobalKey _recommendationsKey = GlobalKey();
  final GlobalKey _communityKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _homeController = ehc.ElderlyHomeController(elderlyUid: widget.userProfile.uid);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  void _updateStatus() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Status updated. Notifying Caregiver...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  _buildCaregiverContact(context),
                  const SizedBox(height: 24),
                  _buildCaregiverInfoCard(context),
                  const SizedBox(height: 24),

                  _buildQuickActions(context),
                  const SizedBox(height: 24),

                  _buildSectionTitle(context, "Announcements", _announcementsKey, showSeeAll: false),
                  _buildAnnouncementsSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle(context, "Upcoming Events", _eventsKey),
                  _buildEventsSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle(context, "Learning Recommendations", _recommendationsKey, showSeeAll: false),
                  _buildLearningRecommendationsSection(),
                  const SizedBox(height: 24),

                  _buildCommunityButton(context, _communityKey),
                  const SizedBox(height: 32),

                  _buildSectionTitle(context, "Shared Posts & Memories", GlobalKey(), showSeeAll: false),
                  _buildSharedMemoriesSection(),
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

  Widget _buildCaregiverInfoCard(BuildContext context) {
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userProfile.uid)
        .snapshots(),
    builder: (context, snapshot) {
      // Defaults
      String caregiverName = 'No Caregiver Linked';
      bool isLinked = false;
      VoidCallback? onPressed;
      String? buttonText;

      if (snapshot.hasData && snapshot.data!.exists) {
        final data = snapshot.data!.data();
        final caregivers = (data?['linkedCaregivers'] as List?)?.cast<String>() ?? const <String>[];

        if (caregivers.isNotEmpty) {
          final primaryCaregiverId = caregivers.first;
          // Load caregiver display name
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('users').doc(primaryCaregiverId).get(),
            builder: (context, cgSnap) {
              if (cgSnap.hasData && cgSnap.data!.exists) {
                final cg = cgSnap.data!.data();
                caregiverName = (cg?['displayName'] as String?) ??
                                (cg?['firstName'] as String? ?? 'Caregiver');
                isLinked = true;
              }
              return _buildElderlyInfoCard(
                context,
                name: widget.userProfile.displayName,
                id: widget.userProfile.uid,
                caregiver: caregiverName,
                isLinked: isLinked,
              );
            },
          );
        } else {
          // No caregivers linked yet
          onPressed = () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => LinkCaregiverPage()));
          };
          buttonText = 'Link First Caregiver';
        }
      }

      // Fallback (no data or still loading caregiver)
      return _buildElderlyInfoCard(
        context,
        name: widget.userProfile.displayName,
        id: widget.userProfile.uid,
        caregiver: caregiverName,
        isLinked: isLinked,
        onPressed: onPressed,
        buttonText: buttonText ?? 'Link First Caregiver',
      );
    },
  );
}

// Pretty card showing Elder info + caregiver status.
Widget _buildElderlyInfoCard(
  BuildContext context, {
  required String name,
  required String id,
  required String caregiver,
  required bool isLinked,
  VoidCallback? onPressed,
  String? buttonText,
}) {
  return GestureDetector(
    onTap: () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CaregiverAccessPage()));
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ID: ${id.substring(0, 8)}...', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Caregiver: $caregiver', style: const TextStyle(color: Colors.white, fontSize: 16)),
            ]),
          ),
          isLinked
              ? const Icon(Icons.favorite, color: Colors.white, size: 40)
              : ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: Text(buttonText ?? 'Link Caregiver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_ios, color: Colors.white),
        ],
      ),
    ),
  );
}

  Widget _buildQuickNavigation() {
    return Container(
      width: 60,
      color: Colors.deepPurple.shade200,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          _buildNavLink(Icons.campaign, 'Announce', () => _scrollToSection(_announcementsKey)),
          _buildNavLink(Icons.calendar_today, 'Events', () => _scrollToSection(_eventsKey)),
          _buildNavLink(Icons.lightbulb_outline, 'Learn', () => _scrollToSection(_recommendationsKey)),
          _buildNavLink(Icons.people_outline, 'Community', () => _scrollToSection(_communityKey)),
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

  Widget _buildCaregiverContact(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunicatePage()));
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
            onPressed: _updateStatus,
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

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "Immediate Medical Access", GlobalKey(), showSeeAll: false),
        const SizedBox(height: 10),
        _buildActionGrid([
          _buildActionButton(context, 'See GP now', Icons.local_hospital, Colors.red.shade100, Colors.red.shade800, GPConsultationPage()),
          _buildActionButton(context, 'Book an appointment', Icons.calendar_month, Colors.blue.shade100, Colors.blue.shade800, AppointmentBookingPage(userProfile: widget.userProfile)),
          _buildActionButton(context, 'Consultation History', Icons.history, Colors.purple.shade100, Colors.purple.shade800, ch.ConsultationHistoryPage()),
        ]),
        const SizedBox(height: 24),
        _buildSectionTitle(context, "Health Records & Shop Medicine", GlobalKey(), showSeeAll: false),
        const SizedBox(height: 10),
        _buildActionGrid([
          _buildActionButton(context, 'My Health records', Icons.folder_open, Colors.green.shade100, Colors.green.shade800, hr.HealthRecordsPage(userProfile: widget.userProfile)),
          _buildActionButton(
            context,
            'Shop Meds & wellness',
            Icons.shopping_bag,
            Colors.orange.shade100,
            Colors.orange.shade800,
            ChangeNotifierProvider(
              create: (_) => CartController(),
              child: const shop.MedicationShopPage(),
            ),
          ),
          _buildActionButton(context, 'Wellness Tips', Icons.self_improvement, Colors.cyan.shade100, Colors.cyan.shade800, CommunityPage()),
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

  Widget _buildSharedMemoriesSection() {
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: const Text('Shared Post with Added Friends/Caregivers/Elderly Memories (Placeholder)'),
    );
  }

  Widget _buildFeedbackSection() {
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
      child: const Text('Shared Feedback on Platform (Placeholder)'),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Welcome Back,", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54)),
          Text(widget.userProfile.displayName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletPage(userProfile: widget.userProfile))),
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        if (showSeeAll)
          TextButton(
            onPressed: () {
              if (title == "Upcoming Events") {
                Navigator.push(context, MaterialPageRoute(builder: (_) => EventsPage()));
              } else {
                debugPrint("See all $title");
              }
            },
            child: const Text("See all", style: TextStyle(color: Colors.blue)),
          ),
      ]),
    );
  }


  Widget _buildEventsSection() {
    return StreamBuilder<List<ehc.UpcomingEvent>>(
      stream: _homeController.getUpcomingEventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Events Home Page Error: ${snapshot.error}");
          return Center(child: Text("Error loading events"));
        }

        final events = snapshot.data ?? const <ehc.UpcomingEvent>[];
        if (events.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No upcoming events scheduled by you or your caregiver."),
            ),
          );
        }

        return Column(
          children: events.map((e) {
            final start = DateFormat('EEE, MMM d, h:mm a').format(e.start);
            final end   = DateFormat('h:mm a').format(e.end);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(Icons.event, color: Colors.orange.shade700),
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('$start – $end\nTap to see details'),
                isThreeLine: true,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: navigate to details if you have a page
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAnnouncementsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _homeController.getAnnouncementsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading announcements."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No new announcements."));
        }

        final titles = snapshot.data!.docs
            .map((d) => (d.data() as Map<String, dynamic>?)?['title'] as String? ?? 'Announcement')
            .toList();

        return Column(
          children: titles
              .map((t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    child: ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.blue),
                      title: Text(t),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildLearningRecommendationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _homeController.getLearningRecommendationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading recommendations."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No recommendations for you."));
        }

        final topics = snapshot.data!.docs
            .map((d) => (d.data() as Map<String, dynamic>?)?['title'] as String? ?? 'Topic')
            .toList();

        return Column(
          children: topics
              .map((t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    child: ListTile(
                      leading: const Icon(Icons.school, color: Colors.green),
                      title: Text(t),
                      trailing: const Icon(Icons.arrow_forward_ios),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildCommunityButton(BuildContext context, GlobalKey key) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 8.0),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityPage())),
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
}
