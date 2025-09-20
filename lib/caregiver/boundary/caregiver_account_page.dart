import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';

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
          final caregiverCode = (data['caregiverCode'] ?? '—').toString();  // make sure you store this field

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
                // Add more caregiver-specific actions here…
              ],
            ),
          );
        },
      ),
    );
  }
}
