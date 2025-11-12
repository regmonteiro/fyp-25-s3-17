import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminProfileController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late User? currentUser;
  bool isLoading = true;

  // Controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final birthDateController = TextEditingController();
  final phoneController = TextEditingController();

  // Extra info
  String accountCreated = 'Loading...';
  String lastLogin = 'Loading...';

  AdminProfileController() {
    currentUser = _auth.currentUser;
  }

  /// Load admin data from Firestore
  Future<void> loadProfile(BuildContext context) async {
    if (currentUser == null) {
      _setDefaultValues();
      _showError(context, "No user logged in");
      return;
    }

    isLoading = true;

    try {
      final doc = await _db.collection("Account").doc(currentUser!.uid).get();
      if (!doc.exists) {
        _setDefaultValues();
        _showError(context, "User profile not found in database");
        return;
      }

      final data = doc.data() ?? {};
      // Safely map fields
      firstNameController.text =
          (data['firstname'] ?? data['firstName'] ?? 'Not provided').toString();
      lastNameController.text =
          (data['lastname'] ?? data['lastName'] ?? 'Not provided').toString();
      phoneController.text =
          (data['phoneNum'] ?? data['phone'] ?? 'Not provided').toString();

      final dob = _parseDate(data['dob'] ?? data['birthDate']);
      birthDateController.text = dob != null
          ? _formatDate(dob)
          : 'Not provided';

      final createdAt = _parseDate(data['createdAt'] ?? data['created_at']);
      accountCreated = createdAt != null
          ? _formatDate(createdAt)
          : 'Not available';

      lastLogin = 'Recently'; // You can load actual last login if stored

      isLoading = false;
    } catch (e) {
      _setDefaultValues();
      _showError(context, "Failed to load profile: $e");
      isLoading = false;
    }
  }

  /// Update admin profile
  Future<void> updateProfile(BuildContext context) async {
    if (currentUser == null) return;

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();
    final dob = birthDateController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || dob.isEmpty || phone.isEmpty) {
      _showError(context, "All fields are required");
      return;
    }

    final updates = {
      'firstname': firstName,
      'lastname': lastName,
      'phoneNum': phone,
      'dob': dob, // or convert to Timestamp if needed
    };

    try {
      await _db.collection("Account").doc(currentUser!.uid).update(updates);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );
    } catch (e) {
      _showError(context, "Failed to update profile: $e");
    }
  }

  /// Helper to parse any date type
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Format date
  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}";

  String _month(int m) => const [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ][m - 1];

  void _setDefaultValues() {
    firstNameController.text = 'Not provided';
    lastNameController.text = 'Not provided';
    birthDateController.text = 'Not provided';
    phoneController.text = 'Not provided';
    accountCreated = 'Not available';
    lastLogin = 'Not available';
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    birthDateController.dispose();
    phoneController.dispose();
  }
}
