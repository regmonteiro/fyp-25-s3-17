import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';

class AdminDashboard extends StatefulWidget {
  final UserProfile userProfile;
  const AdminDashboard({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _userName = "";

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final firstName = doc['firstName'] ?? '';
          final lastName = doc['lastName'] ?? '';
          setState(() {
            _userName = "$firstName $lastName";
          });
        }
      }
    } catch (e) {
      setState(() {
        _userName = "User";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: Center(
        child: Text(
          _userName.isEmpty ? "Loading..." : "Welcome, $_userName!",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}