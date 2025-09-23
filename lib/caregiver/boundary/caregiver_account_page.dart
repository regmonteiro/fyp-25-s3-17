import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../models/user_profile.dart';
import '../../welcome.dart';
class CaregiverAccountPage extends StatelessWidget {
  final UserProfile userProfile;
  const CaregiverAccountPage({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Caregiver Account')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() ?? {};
          final displayName = (data['displayName'] ?? 'Caregiver').toString();
          final caregiverCode = (data['caregiverCode'] ?? '—').toString();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $displayName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Your Caregiver Code:', style: TextStyle(color: Colors.grey)),
                SelectableText(caregiverCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;

                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      _logoutRoute(context),
                      (route) => false,
                    );
                  },
                  label: const Text("Log out"),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "UID: ${FirebaseAuth.instance.currentUser?.uid ?? '-'}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Route _logoutRoute(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      );
    }
    return MaterialPageRoute(
      builder: (context) => const WelcomeScreen(),
    );
  }

  Widget _tile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}