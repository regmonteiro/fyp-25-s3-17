import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'caregiver/boundary/caregiver_dashboard_page.dart';
import 'elderly/boundary/elderly_dashboard_page.dart';
import 'admin/boundary/admin_dashboard.dart';
import 'models/user_profile.dart';
import 'features/controller/community_controller.dart';

class MainWrapper extends StatefulWidget {
  final UserProfile? userProfile; // (kept for compatibility; not used)
  const MainWrapper({super.key, required this.userProfile});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  // ───────── helpers ─────────
  String _emailDocIdFor(String email) {
    final lower = email.trim().toLowerCase();
    final at = lower.indexOf('@');
    if (at < 0) return lower;
    final local = lower.substring(0, at);
    final domain = lower.substring(at + 1).replaceAll('.', '_');
    return '$local@$domain';
  }

  bool _isValidRole(dynamic v) {
    final s = (v is String) ? v.trim().toLowerCase() : '';
    return s == 'elderly' || s == 'caregiver' || s == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return const _ProblemScreen(
        message: 'This account has no email.',
        tip: 'Use a non-anonymous account with a verified email.',
      );
    }

    final emailDocId = _emailDocIdFor(email);
    final emailRef = FirebaseFirestore.instance.collection('Account').doc(emailDocId);
    final uidRef   = FirebaseFirestore.instance.collection('Account').doc(user.uid);

    // First try: email-keyed doc stream
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: emailRef.snapshots(includeMetadataChanges: true),
      builder: (context, emailSnap) {
        // If listener itself errors (e.g., rules)
        if (emailSnap.hasError) {
          final err = emailSnap.error;
          if (err is FirebaseException && err.code == 'permission-denied') {
            return _ProblemScreen(
              message: 'No permission to read Account/$emailDocId.',
              tip: 'Rules must allow read when doc.email == auth.email.',
            );
          }
          return _ProblemScreen(message: 'Failed to load profile.\n$err');
        }

        // While waiting, show spinner
        if (emailSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final emailDoc = emailSnap.data;
        final emailExists = emailDoc != null && emailDoc.exists;

        // If email doc exists and role is valid → route by this doc
        if (emailExists) {
          final data = emailDoc!.data() ?? {};
          final rawRole = data['userType'];
          final role = (rawRole is String) ? rawRole.trim().toLowerCase() : '';

          debugPrint('[MainWrapper] emailDoc=$emailDocId role="$role"');

          if (_isValidRole(role)) {
            final profile = UserProfile.fromMap(data, user.uid);
            switch (role) {
              case 'caregiver':
                return CaregiverDashboardPage(userProfile: profile);
              case 'elderly':
                return ChangeNotifierProvider(
                  create: (_) => CommunityController(),
                  child: ElderlyDashboardPage(userProfile: profile),
                );
              case 'admin':
                return AdminDashboard(userProfile: profile);
            }
          }
          // If email doc exists but missing/invalid role, let user set it.
          return _CreateProfileScreen(uid: user.uid, email: email);
        }

        // Email doc not found → fall back to UID doc stream (allowed by rules)
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uidRef.snapshots(includeMetadataChanges: true),
          builder: (context, uidSnap) {
            if (uidSnap.hasError) {
              final err = uidSnap.error;
              if (err is FirebaseException && err.code == 'permission-denied') {
                return _ProblemScreen(
                  message: 'No permission to read Account/${user.uid}.',
                  tip: 'Rules: allow read when request.auth.uid == uid OR doc.email == auth.email.',
                );
              }
              return _ProblemScreen(message: 'Failed to load profile.\n$err');
            }

            if (uidSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final uidDoc = uidSnap.data;
            if (uidDoc == null || !uidDoc.exists) {
              // Nothing at UID either → create profile
              return _CreateProfileScreen(uid: user.uid, email: email);
            }

            final data = uidDoc.data()!;
            final rawRole = data['userType'];
            final role = (rawRole is String) ? rawRole.trim().toLowerCase() : '';
            debugPrint('[MainWrapper] uidDoc=${user.uid} role="$role"');

            if (_isValidRole(role)) {
              final profile = UserProfile.fromMap(data, user.uid);
              switch (role) {
                case 'caregiver':
                  return CaregiverDashboardPage(userProfile: profile);
                case 'elderly':
                  return ChangeNotifierProvider(
                    create: (_) => CommunityController(),
                    child: ElderlyDashboardPage(userProfile: profile),
                  );
                case 'admin':
                  return AdminDashboard(userProfile: profile);
              }
            }

            // UID doc exists but invalid role
            return _CreateProfileScreen(uid: user.uid, email: email);
          },
        );
      },
    );
  }
}

// ─────────────────── UI helpers ───────────────────
class _ProblemScreen extends StatelessWidget {
  final String message;
  final String? tip;
  const _ProblemScreen({required this.message, this.tip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Issue')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(message, textAlign: TextAlign.center),
          if (tip != null) ...[
            const SizedBox(height: 8),
            Text(tip!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Sign out'),
          ),
        ]),
      ),
    );
  }
}

class _CreateProfileScreen extends StatefulWidget {
  final String uid;
  final String? email;
  const _CreateProfileScreen({required this.uid, this.email, super.key});

  @override
  State<_CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<_CreateProfileScreen> {
  String _userType = 'elderly';
  bool _busy = false;
  String? _err;

  String _emailDocIdFor(String email) {
    final lower = email.trim().toLowerCase();
    final at = lower.indexOf('@');
    if (at < 0) return lower;
    final local = lower.substring(0, at);
    final domain = lower.substring(at + 1).replaceAll('.', '_');
    return '$local@$domain';
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final email = (widget.email ?? '').trim().toLowerCase();

    try {
      // Always write to UID doc (allowed by your rules)
      final uidRef = FirebaseFirestore.instance.collection('Account').doc(widget.uid);
      await uidRef.set({
        'uid': widget.uid,
        'email': email,
        'userType': _userType.toLowerCase(),
        'firstname': '',
        'lastname': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Best-effort mirror to email-keyed doc if rules allow it
      if (email.isNotEmpty) {
        final emailId = _emailDocIdFor(email);
        final emailRef = FirebaseFirestore.instance.collection('Account').doc(emailId);
        try {
          await emailRef.set({
            'uid': widget.uid,
            'email': email,
            'userType': _userType.toLowerCase(),
            'firstname': '',
            'lastname': '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {
          // ignore if rules disallow; app will still work via UID doc fallback
        }
      }
    } on FirebaseException catch (e) {
      setState(() => _err = '${e.code}: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('No profile found for this account. Create one to continue.'),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: _userType,
            items: const [
              DropdownMenuItem(value: 'elderly', child: Text('elderly')),
              DropdownMenuItem(value: 'caregiver', child: Text('caregiver')),
              DropdownMenuItem(value: 'admin', child: Text('admin')),
            ],
            onChanged: (v) => setState(() => _userType = v ?? 'elderly'),
          ),
          const SizedBox(height: 12),
          if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _create,
            child: _busy ? const CircularProgressIndicator() : const Text('Create Profile'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => FirebaseAuth.instance.signOut(),
            child: const Text('Use a different account'),
          ),
        ]),
      ),
    );
  }
}
