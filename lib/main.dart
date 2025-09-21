import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'welcome.dart';
import 'main_wrapper.dart';

Future<void> _ensureSignedInUserIsValid() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;
  try {
    await u.reload(); // if user was deleted/disabled, this will throw
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-token-expired' || e.code == 'user-not-found' || e.code == 'user-disabled') {
      await FirebaseAuth.instance.signOut();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FIREBASE PROJECT: ${app.options.projectId}');
  await _ensureSignedInUserIsValid();  // <— key line
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AllCare',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        return user == null ? WelcomeScreen() : const MainWrapper();
      },
    );
  }
}