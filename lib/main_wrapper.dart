import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'caregiver/boundary/caregiver_dashboard_page.dart';
import 'elderly/boundary/elderly_dashboard_page.dart';
import 'admin/boundary/admin_dashboard.dart';
import 'models/user_profile.dart';

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    // 1) Ensure the local session is still valid (user not deleted)
    final reloadFuture = user.reload();

    return FutureBuilder<void>(
      future: reloadFuture,
      builder: (context, reloadSnap) {
        if (reloadSnap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (reloadSnap.hasError) {
          // Stale/invalid auth -> sign out and show message
          FirebaseAuth.instance.signOut();
          return const Scaffold(body: Center(child: Text('Session expired. Please log in again.')));
        }

        // 2) Live stream of the profile doc so the UI updates immediately after creation
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (snap.hasError) {
              final err = snap.error;
              if (err is FirebaseException && err.code == 'permission-denied') {
                return _ProblemScreen(
                  message:
                      'No permission to read your profile. Check Firestore security rules for /users/{uid}.',
                  tip:
                      'Dev rule: allow read/write if request.auth.uid == uid. Then reload.',
                );
              }
              return _ProblemScreen(message: 'Failed to load profile. ${snap.error}');
            }

            final doc = snap.data;
            if (doc == null || !doc.exists) {
              // 3) Profile missing -> let user create it in one tap
              return _CreateProfileScreen(uid: user.uid, email: user.email);
            }

            final data = doc.data()!;
            final rawRole = data['role'];
            final role = (rawRole is String) ? rawRole.trim().toLowerCase() : '';

            // TEMP debug log
            // ignore: avoid_print
            print('[MainWrapper] uid=${user.uid} roleRaw="$rawRole" roleNorm="$role"');

            // 4) Route by role
                final userProfile = UserProfile.fromMap(data, user.uid);

                switch (role) {
                  case 'caregiver':
                    return CaregiverDashboardPage(userProfile: userProfile);
                  case 'elderly':
                    return ElderlyDashboardPage(userProfile: userProfile);
                  case 'admin':
                    return AdminDashboard(userProfile: userProfile);
                  default:
                    return _ProblemScreen(
                      message: 'Profile exists but role is missing/invalid. Read: "$rawRole"',
                      tip: 'Set role to one of: Elderly, Caregiver, Admin.',
                    );
                }
          },
        );
      },
    );
  }
}

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
  String _role = 'Elderly'; // default; change if you want a picker

  bool _busy = false;
  String? _err;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'email': widget.email ?? '',
        'role': _role.toLowerCase(),
        'firstName': '',
        'lastName': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // No nav needed — the StreamBuilder above will rebuild automatically.
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
            value: _role,
            items: const [
              DropdownMenuItem(value: 'Elderly', child: Text('Elderly')),
              DropdownMenuItem(value: 'Caregiver', child: Text('Caregiver')),
              DropdownMenuItem(value: 'Admin', child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'Elderly'),
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