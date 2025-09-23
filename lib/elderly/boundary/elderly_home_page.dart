import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/elderly_home_controller.dart';
import '../../models/user_profile.dart';
import 'account/caregiver_access_page.dart';
import 'community_page.dart';
import 'link_caregiver_page.dart';

class ElderlyHomePage extends StatefulWidget {
  final UserProfile userProfile;

  const ElderlyHomePage({Key? key, required this.userProfile}) : super(key: key);

  @override
  _ElderlyHomePageState createState() => _ElderlyHomePageState();
}

class _ElderlyHomePageState extends State<ElderlyHomePage> {
  late final ElderlyHomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ElderlyHomeController(elderlyUid: widget.userProfile.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              // Updated to use a StreamBuilder for real-time caregiver info
              _buildCaregiverInfoCard(context),
              const SizedBox(height: 24),
              _buildSectionTitle(context, "Announcements"),
              _buildAnnouncementsSection(),
              const SizedBox(height: 24),
              _buildSectionTitle(context, "Upcoming Events"),
              _buildEventsSection(),
              const SizedBox(height: 24),
              _buildSectionTitle(context, "Learning Recommendations"),
              _buildLearningRecommendationsSection(),
              const SizedBox(height: 24),
              _buildCommunityButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome Back,",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
        ),
        Text(
          widget.userProfile.displayName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCaregiverInfoCard(BuildContext context) {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(widget.userProfile.uid).snapshots(),
    builder: (context, snapshot) {
      String caregiverName = 'No Caregiver Linked';
      String buttonText = 'Link First Caregiver';
      VoidCallback? onPressed;

      if (snapshot.hasData && snapshot.data!.exists) {
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('linkedCaregivers') && data['linkedCaregivers'] is List) {
          final caregivers = data['linkedCaregivers'] as List;

          if (caregivers.isNotEmpty) {
            // If a caregiver exists, show their name
            final primaryCaregiverId = caregivers.first;
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(primaryCaregiverId).get(),
              builder: (context, caregiverSnap) {
                if (caregiverSnap.hasData && caregiverSnap.data!.exists) {
                  final caregiverData = caregiverSnap.data!.data() as Map<String, dynamic>?;
                  caregiverName = caregiverData?['displayName'] ?? 'Caregiver';
                }
                return _buildElderlyInfoCard(
                  context, // Pass context
                  name: widget.userProfile.displayName,
                  id: widget.userProfile.uid,
                  caregiver: caregiverName,
                  isLinked: true,
                );
              },
            );
          } else {
            // No caregivers linked, show the link button
            onPressed = () {
              // Navigate to a new page to handle linking
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LinkCaregiverPage()),
              );
            };
            return _buildElderlyInfoCard(
              context, // Pass context
              name: widget.userProfile.displayName,
              id: widget.userProfile.uid,
              caregiver: caregiverName,
              isLinked: false,
              onPressed: onPressed,
              buttonText: buttonText,
            );
          }
        }
      }

      // Default state for no data
      onPressed = () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LinkCaregiverPage()),
        );
      };
      return _buildElderlyInfoCard(
        context, // Pass context
        name: widget.userProfile.displayName,
        id: widget.userProfile.uid,
        caregiver: 'No Caregiver Linked',
        isLinked: false,
        onPressed: onPressed,
        buttonText: 'Link First Caregiver',
      );
    },
  );
}

// Helper method to build the card with optional button
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
      if (isLinked) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CaregiverAccessPage()),
        );
      } else {
        onPressed?.call();
      }
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
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Caregiver: $caregiver',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          isLinked
              ? const Icon(Icons.favorite_border, color: Colors.white, size: 60)
              : ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: Text(buttonText!),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextButton(
          onPressed: () {
            print("See all $title");
          },
          child: const Text("See all", style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }

  Widget _buildAnnouncementsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _controller.getAnnouncementsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading announcements."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No new announcements."));
        }

        final announcements = snapshot.data!.docs.map((doc) => doc['title'] as String).toList();

        return Column(
          children: announcements.map((announcement) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: Text(announcement),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEventsSection() {
  return StreamBuilder<List<DocumentSnapshot>>( // <--- Change this type
    stream: _controller.getEventsStream(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return const Center(child: Text("Error loading events."));
      }
      if (!snapshot.hasData || snapshot.data!.isEmpty) { // <--- Check for empty list
        return const Center(child: Text("No upcoming events."));
      }

      final events = snapshot.data!; // Now a List<DocumentSnapshot>

      return Column(
        children: events.map((doc) {
          final eventData = doc.data() as Map<String, dynamic>;
          final eventTitle = eventData['title'] as String;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.event, color: Colors.orange),
              title: Text(eventTitle),
            ),
          );
        }).toList(),
      );
    },
  );
}

  Widget _buildLearningRecommendationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _controller.getLearningRecommendationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading recommendations."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No recommendations for you."));
        }

        final recommendations = snapshot.data!.docs.map((doc) => doc['title'] as String).toList();

        return Column(
          children: recommendations.map((topic) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.school, color: Colors.green),
                title: Text(topic),
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCommunityButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CommunityPage()),
        );
      },
      icon: const Icon(Icons.people, size: 24),
      label: const Text(
        "Connect with the Community",
        style: TextStyle(fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}