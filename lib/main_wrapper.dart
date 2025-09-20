import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_aiassistant/caregiver/boundary/caregiver_dashboard_page.dart';
import 'package:elderly_aiassistant/elderly/boundary/elderly_dashboard_page.dart';
import 'package:elderly_aiassistant/admin/boundary/admin_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:elderly_aiassistant/models/user_profile.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({Key? key}) : super(key: key);

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  late Future<Widget> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _determineDashboard();
  }

  Future<Widget> _determineDashboard() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return const Scaffold(body: Center(child: Text('Please log in.')));
  }

  final snap = await FirebaseFirestore.instance
      .collection('users') // <- exact name matters (case-sensitive)
      .doc(user.uid)
      .get();

  if (!snap.exists) {
    return const Scaffold(body: Center(child: Text('User profile not found.')));
  }

  final data = snap.data() as Map<String, dynamic>;
  // Read the raw field directly to avoid model surprises
  final rawRole = data['role'];
  final role = (rawRole is String) ? rawRole.trim().toLowerCase() : null;

  // TEMP debug log (check your run console)
  // ignore: avoid_print
  print('[MainWrapper] uid=${user.uid} roleRaw="$rawRole" roleNorm="$role"');

  switch (role) {
    case 'caregiver':
      return CaregiverDashboardPage(userProfile: UserProfile.fromMap(data, user.uid));
    case 'elderly':
      return ElderlyDashboardPage(userProfile: UserProfile.fromMap(data, user.uid));
    case 'admin':
      return AdminDashboard(userProfile: UserProfile.fromMap(data, user.uid));
    default:
      // Show exactly what we read so you know what to fix in Firestore
      return Scaffold(
        body: Center(
          child: Text('User role is invalid or not set. Read: "$rawRole"'),
        ),
      );
  }
}


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('An error occurred during routing.')),
          );
        } else if (snapshot.hasData) {
          return snapshot.data!;
        } else {
          return const Scaffold(
            body: Center(child: Text('No data available.')),
          );
        }
      },
    );
  }
}