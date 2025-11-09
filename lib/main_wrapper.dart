import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'caregiver/boundary/caregiver_dashboard_page.dart';
import 'elderly/boundary/elderly_dashboard_page.dart';
import 'admin/boundary/admin_dashboard.dart';
import 'models/user_profile.dart';
import 'features/controller/community_controller.dart';
import 'services/account_bootstrap.dart';

class MainWrapper extends StatefulWidget {
  final UserProfile? userProfile; // (kept for compatibility; not used)
  const MainWrapper({super.key, required this.userProfile});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  // ───────── helpers ─────────
  String _emailKeyFor(String email) => emailKeyFrom(email);

  bool _isValidRole(dynamic v) {
    final s = (v is String) ? v.trim().toLowerCase() : '';
    return s == 'elderly' || s == 'caregiver' || s == 'admin';
  }

  Widget _uidOrCreate(String uid, String email) {
  // If you no longer use UID docs, jump straight to create:
  return _CreateProfileScreen(uid: uid, email: email);
}

@override
Widget build(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Scaffold(body: Center(child: Text('Please log in.')));

  final email = user.email?.trim().toLowerCase() ?? '';
  final emailDocId = emailKeyFrom(email);
  final emailRef = FirebaseFirestore.instance.collection('Account').doc(emailDocId);

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: emailRef.snapshots(includeMetadataChanges: true),
    builder: (context, snap) {
      // If rules say permission-denied, *don’t* show an error page — continue.
      if (snap.hasError) {
        final err = snap.error;
        if (err is FirebaseException && err.code == 'permission-denied') {
          return _uidOrCreate(user.uid, email);
        }
        return _ProblemScreen(message: 'Failed to load profile.\n$err');
      }

      if (snap.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final doc = snap.data;
      if (doc == null || !doc.exists) {
        // Nothing at /Account/{emailKey} yet → create
        return _uidOrCreate(user.uid, email);
      }

      final data = doc.data()!;
      final role = (data['userType'] as String? ?? '').trim().toLowerCase();
      if (role == 'elderly') {
        final profile = UserProfile.fromMap(data, user.uid);
        return ChangeNotifierProvider(create: (_) => CommunityController(),
          child: ElderlyDashboardPage(userProfile: profile));
      }
      if (role == 'caregiver') return CaregiverDashboardPage(userProfile: UserProfile.fromMap(data, user.uid));
      if (role == 'admin')     return AdminDashboard(userProfile: UserProfile.fromMap(data, user.uid));

      // Doc exists but no role yet → create/complete profile
      return _CreateProfileScreen(uid: user.uid, email: email);
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
      floatingActionButton: FloatingActionButton(
    backgroundColor: Colors.deepPurple,
    onPressed: () => Navigator.pushNamed(context, '/assistant'),
    child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
  ),
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

  String _emailKeyFor(String email) => emailKeyFrom(email);

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
        final emailDocId = _emailKeyFor(email); // was _emailDocIdFor
        final emailRef   = FirebaseFirestore.instance.collection('Account').doc(emailDocId);
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
      floatingActionButton: FloatingActionButton(
    backgroundColor: Colors.deepPurple,
    onPressed: () => Navigator.pushNamed(context, '/assistant'),
    child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
  ),
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
