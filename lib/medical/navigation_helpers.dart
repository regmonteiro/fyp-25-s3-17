
// navigation_helpers.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../medical/consultation_request_page.dart';
import '../models/user_profile.dart';

Future<void> goToConsultationWithProfile(BuildContext context) async {
  try {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('Account')
        .doc(authUser.uid)
        .get();

    if (!snap.exists || snap.data() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not found.')),
      );
      return;
    }

    final profile = UserProfile.fromDocumentSnapshot(snap);

    // If caregiver, act on elder’s UID; else use own UID
    final patientUid =
        (profile.userType == 'caregiver' && (profile.elderlyId?.isNotEmpty ?? false))
            ? profile.elderlyId!
            : profile.uid;

    // Navigate (
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultationRequestPage(
          userProfile: profile,
          patientUid: patientUid,
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to open consultation: $e')),
    );
  }
}
