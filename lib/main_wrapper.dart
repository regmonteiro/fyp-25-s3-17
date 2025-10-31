import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'caregiver/boundary/caregiver_dashboard_page.dart';
import 'elderly/boundary/elderly_dashboard_page.dart';
import 'admin/boundary/admin_dashboard.dart';
import 'models/user_profile.dart';
import 'features/controller/community_controller.dart';
import 'medical/controller/cart_controller.dart';
import 'services/cart_repository.dart';

class MainWrapper extends StatefulWidget {
  final UserProfile? userProfile;
  const MainWrapper({super.key, required this.userProfile});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  Future<void>? _ensureFuture;

  @override
void initState() {
  super.initState();
  final user = FirebaseAuth.instance.currentUser;

  _ensureFuture = (user == null)
      ? Future.value()
      : _ensureUidDoc(user)
          .timeout(const Duration(seconds: 8), onTimeout: () {
            debugPrint('[MainWrapper] ensureUidDoc timed out — SKIPPING WRITE (UI will continue).');
            return;
          });
}


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return FutureBuilder<void>(
      future: _ensureFuture,
      builder: (context, migSnap) {
        if (migSnap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (migSnap.hasError) {
          return _ProblemScreen(
            message: 'Could not prepare your profile.\n${migSnap.error}',
            tip: 'If you see "permission-denied", check /Account rules for uid OR email match.',
          );
        }

        final uidDocRef = FirebaseFirestore.instance.collection('Account').doc(user.uid);
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uidDocRef.snapshots(includeMetadataChanges: true),
          builder: (context, snap) {
            if (snap.hasError) {
              final err = snap.error;
              if (err is FirebaseException && err.code == 'permission-denied') {
                return _ProblemScreen(
                  message: 'No permission to read Account/${user.uid}.',
                  tip: 'Rules: allow read when request.auth.uid == uid OR doc.email == auth.email.',
                );
              }
              return _ProblemScreen(message: 'Failed to load profile.\n$err');
            }

            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final doc = snap.data;
            if (doc == null || !doc.exists) {
              return _CreateProfileScreen(uid: user.uid, email: user.email);
            }

            final data = doc.data()!;
            final rawUserType = data['userType'];
            final userType = (rawUserType is String) ? rawUserType.trim().toLowerCase() : '';

            final profile = UserProfile.fromMap(data, user.uid);

            switch (userType) {
              case 'caregiver':
                return CaregiverDashboardPage(userProfile: profile);
              case 'elderly':
                return ChangeNotifierProvider(
                  create: (_) => CommunityController(),
                  child: ElderlyDashboardPage(userProfile: profile),
                );
              case 'admin':
                return AdminDashboard(userProfile: profile);
              default:
                return _ProblemScreen(
                  message: 'Profile exists but role is missing/invalid. Got: "$rawUserType".',
                  tip: 'Set userType to one of: elderly, caregiver, admin.',
                );
            }
          },
        );
      },
    );
  }
}

String _legacyIdFromEmail(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower;
  final local = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain';
}
Future<void> _ensureUidDoc(User user) async {
  final fs = FirebaseFirestore.instance;
  final uidRef = fs.collection('Account').doc(user.uid);

  Future<void> _mirrorLegacyIfExists() async {
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;

    final legacyId = _legacyIdFromEmail(email);
    final legacyRef = fs.collection('Account').doc(legacyId);

    try {
      final legacySnap = await legacyRef.get(const GetOptions(source: Source.server));
      if (!legacySnap.exists) return;

      final legacy = legacySnap.data() ?? {};
      final uidSnap = await uidRef.get(const GetOptions(source: Source.server));
      final existing = uidSnap.data() ?? {};

      final desired = {
        ...legacy,
        'uid': user.uid,
        'email': email,
        'migratedFrom': legacyId,
      };

      bool needsWrite = false;
      for (final k in desired.keys) {
        if ('migratedAt' == k) continue;
        if (existing[k] != desired[k]) {
          needsWrite = true;
          break;
        }
      }
      if (!needsWrite && existing.containsKey('migratedFrom')) return;

      await uidRef.set({
        ...desired,
        if (!existing.containsKey('migratedFrom'))
          'migratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ensureUidDoc] legacy mirror skipped: $e');
    }
  }

  try {
    final serverSnap = await uidRef.get(const GetOptions(source: Source.server));
    if (!serverSnap.exists) {
      await _mirrorLegacyIfExists();
      final after = await uidRef.get(const GetOptions(source: Source.server));
      if (!after.exists) {
        // create minimal doc once
        await uidRef.set({
          'uid': user.uid,
          'email': user.email?.trim().toLowerCase() ?? '',
          'userType': '', // forces profile creation screen
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } else {
      final data = serverSnap.data() ?? {};
      final wantEmail = user.email?.trim().toLowerCase();
      final needUid = data['uid'] != user.uid;
      final needEmail = (wantEmail != null && (data['email']?.toString().toLowerCase() != wantEmail));
      if (needUid || needEmail) {
        await uidRef.set({
          if (needUid) 'uid': user.uid,
          if (needEmail) 'email': wantEmail,
        }, SetOptions(merge: true));
      }
    }
  } catch (e) {
    // Network/rules hiccups: create a minimal shell so UI can proceed
    debugPrint('[ensureUidDoc] error: $e — creating minimal shell.');
    await uidRef.set({
      'uid': user.uid,
      'email': user.email?.trim().toLowerCase() ?? '',
      'userType': '',
      'createdAt': FieldValue.serverTimestamp(),
      'ensureUidFallback': true,
    }, SetOptions(merge: true));
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

  Future<void> _create() async {
    setState(() { _busy = true; _err = null; });
    try {
      await FirebaseFirestore.instance.collection('Account').doc(widget.uid).set({
        'uid': widget.uid,
        'email': (widget.email ?? '').trim().toLowerCase(),
        'userType': _userType.toLowerCase(),
        'firstname': '',
        'lastname': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
