import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'features/controller/community_controller.dart';
import 'main_wrapper.dart';
import 'welcome.dart';
import 'controller/app_settings.dart';
import 'package:firebase_database/firebase_database.dart';
import 'features/share_experiences_service.dart';
import 'features/controller/share_experience_controller.dart';
import 'medical/controller/cart_controller.dart';
import 'services/cart_repository.dart';


Future<DocumentReference<Map<String, dynamic>>> _accountDocRefByUid(String uid) async {
  final byUid = await FirebaseFirestore.instance
      .collection('Account')
      .where('uid', isEqualTo: uid)
      .limit(1)
      .get();
  if (byUid.docs.isNotEmpty) return byUid.docs.first.reference;

  // Fallback: in case some accounts were already migrated to uid docIds
  final byId = FirebaseFirestore.instance.collection('Account').doc(uid);
  final snap = await byId.get();
  if (snap.exists) return byId;

  throw StateError('Account doc not found for uid=$uid');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[BOOT] Initializing Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('[BOOT] Firebase initialized. Apps: ${Firebase.apps}');

  //Realtime Database: optional but recommended
  try {
    // enable local cache
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    // optional: help debug RTDB traffic
    // FirebaseDatabase.instance.setLoggingEnabled(true);

    // (Optional) if your app uses a non-default DB instance:
    // FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: 'https://<your-db>.firebaseio.com')
    //   .setPersistenceEnabled(true);
  } catch (e) {
    // don't crash if called twice (hot restart) or on web
    debugPrint('RTDB persistence enable error (usually safe to ignore): $e');
  }

  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Firebase Auth stream
  Stream<User?> get _authStream => FirebaseAuth.instance.authStateChanges();

  /// Firestore profile stream (email-keyed Account docs)
Stream<UserProfile?> get _userProfileStream {
  return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(null);

    // wrap in a stream from a future so we can listen to snapshots()
    return Stream.fromFuture(_accountDocRefByUid(user.uid)).asyncExpand((ref) {
      return ref.snapshots().map<UserProfile?>((snap) {
        if (!snap.exists) return null;
        try {
          return UserProfile.fromDocumentSnapshot(snap);
        } catch (e) {
          debugPrint('UserProfile parse error: $e');
          return null;
        }
      });
    }).handleError((err, _) {
      debugPrint('userProfileStream Firestore error: $err');
    });
  });
}


  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Firebase Auth stream
        StreamProvider<User?>.value(
          value: _authStream,
          initialData: null,
          catchError: (_, __) => null,
        ),

        // Firestore profile stream
        StreamProvider<UserProfile?>.value(
          value: _userProfileStream,
          initialData: null,
          catchError: (_, __) => null,
        ),

        // App-level controller
        ChangeNotifierProvider(
          create: (_) => CommunityController(),
        ),
        ChangeNotifierProvider(create: (_) => AppSettings()),
        ChangeNotifierProvider(
            create: (_) => ShareExperienceController(),
          ),

          ChangeNotifierProvider(create: (_) => CartController()),


        Provider<ShareExperienceService>.value(
        value: ShareExperienceService.instance,
    ),
      ],
      child: Consumer<AppSettings>(
        builder: (context, appSettings, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'AllCare Assistant',
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF6A1B9A),
              useMaterial3: true,
            ),
            // The builder belongs to MaterialApp (not MultiProvider)
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                // Flutter 3.13+: TextScaler; if older, use textScaleFactor
                data: mq.copyWith(
                  textScaler: TextScaler.linear(appSettings.textScale),
                ),
                child: child!,
              );
            },
            home: const _RootGate(),
          );
        },
      )
    );
  }
}

/// Root gate decides where to go next
class _RootGate extends StatelessWidget {
  const _RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final profile = context.watch<UserProfile?>();

    if (user == null) return const _NotSignedInScreen();
    if (profile == null) return const WelcomeScreen();

    // one-shot attach (idempotent)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cart = context.read<CartController>();
  cart.attachRepository(CartRepository());
  await cart.loadFromFirestore();
    });

    return MainWrapper(userProfile: profile);
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
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signInAnonymously();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign-in failed: $e')),
                  );
                }
              }
            },
            child: const Text('Continue (Anonymous)'),
          ),
        ]),
      ),
    );
  }
}
