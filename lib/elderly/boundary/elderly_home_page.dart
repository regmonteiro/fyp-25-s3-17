import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/elderly_home_controller.dart';
import '../../models/user_profile.dart';
import 'account/caregiver_access_page.dart';

class ElderlyHomePage extends StatefulWidget {
  final UserProfile userProfile;

  const ElderlyHomePage({Key? key, required this.userProfile}) : super(key: key);

  @override
  _ElderlyHomePageState createState() => _ElderlyHomePageState();
}

class _ElderlyHomePageState extends State<ElderlyHomePage> {
  final ElderlyHomeController _controller = ElderlyHomeController();

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
              _buildElderlyInfoCard(
                widget.userProfile.displayName,
                widget.userProfile.uid,
                'Loading Caregiver...',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(context, "Announcements"),
              _buildAnnouncementsSection(),
              const SizedBox(height: 24),
              _buildSectionTitle(context, "Upcoming Events"),
              _buildEventsSection(),
              const SizedBox(height: 24),
              _buildSectionTitle(context, "Learning Recommendations"),
              _buildLearningRecommendationsSection(),
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

  Widget _buildElderlyInfoCard(String name, String id, String caregiver) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CaregiverAccessPage()),
        );
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
            const Icon(Icons.favorite_border, color: Colors.white, size: 60),
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
    return StreamBuilder<QuerySnapshot>(
      stream: _controller.getEventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading events."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No upcoming events."));
        }

        final events = snapshot.data!.docs.map((doc) => doc['title'] as String).toList();

        return Column(
          children: events.map((event) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.event, color: Colors.orange),
                title: Text(event),
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
}