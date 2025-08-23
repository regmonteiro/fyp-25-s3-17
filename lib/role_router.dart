import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import the top-level dashboard pages for each user type
import 'elderly/boundary/elderly_dashboard_page.dart';
import 'caregiver/boundary/caregiver_dashboard.dart';
import 'admin/boundary/admin_dashboard.dart';

// Import the user profile model to hold user data
import 'models/user_profile.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({Key? key}) : super(key: key);

  Future<UserProfile?> _getUserProfile(String uid) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return UserProfile.fromMap(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      print("Error fetching user profile: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    return FutureBuilder<UserProfile?>(
      future: _getUserProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(body: Center(child: Text("Error fetching user data or data not found.")));
        }

        final userProfile = snapshot.data!;
        
        // Convert the role to lowercase to ensure a case-insensitive match
        final String role = userProfile.role.toLowerCase();

        switch (role) {
          case 'elderly':
            return ElderlyDashboardPage(userProfile: userProfile);
          case 'caregiver':
            return CaregiverDashboard(userProfile: userProfile);
          case 'admin':
            return AdminDashboard(userProfile: userProfile);
          default:
            return const Scaffold(body: Center(child: Text("Unknown user role.")));
        }
      },
    );
  }
}