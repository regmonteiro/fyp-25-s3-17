import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'elderly/boundary/elderly_dashboard_page.dart';
import 'elderly/controller/community_controller.dart';
import 'models/user_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Stream of the signed-in Firebase user
  Stream<User?> get _authStream => FirebaseAuth.instance.authStateChanges();

  // Stream of the signed-in user's profile document (or null when signed out)
  Stream<UserProfile?> get _userProfileStream {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<UserProfile?>.value(null);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snap) => snap.exists ? UserProfile.fromDocumentSnapshot(snap) : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Signed-in Firebase user (nullable)
        StreamProvider<User?>.value(
          value: _authStream,
          initialData: null,
        ),

        // Signed-in user's profile (nullable)
        StreamProvider<UserProfile?>.value(
          value: _userProfileStream,
          initialData: null,
        ),

        // CommunityController available app-wide and kept in sync with auth/profile
        ChangeNotifierProxyProvider2<User?, UserProfile?, CommunityController>(
          create: (_) => CommunityController(),
          update: (_, user, profile, controller) {
            controller ??= CommunityController();
            controller.overrideUserId = user?.uid;
            controller.currentUserProfile = profile;
            return controller;
          },
),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Elderly AI Assistant',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF6A1B9A),
          useMaterial3: true,
        ),
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final profile = context.watch<UserProfile?>();

    if (user == null) {
      // Not signed in — show a simple placeholder or your real SignIn page
      return const _NotSignedInScreen();
    }

    if (profile == null) {
      // Signed in but profile not yet loaded
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Signed in + profile loaded → go to home
    return ElderlyDashboardPage(userProfile: profile);
  }
}

class _NotSignedInScreen extends StatelessWidget {
  const _NotSignedInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('You are not signed in.'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // TODO: navigate to your real sign-in flow
            },
            child: const Text('Go to Sign In'),
          ),
        ]),
      ),
    );
  }
}
