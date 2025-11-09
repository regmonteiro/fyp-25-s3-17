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
import 'services/cart_services.dart';
import 'assistant_chat.dart';
import 'services/account_bootstrap.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final p = await SharedPreferences.getInstance();
  await p.setString("selectedLang", "zh");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (_) {}

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Stream<User?> get _authStream => FirebaseAuth.instance.authStateChanges();

Stream<UserProfile?> get _userProfileStream {
  final auth = FirebaseAuth.instance;
  final fs = FirebaseFirestore.instance;

  Future<DocumentReference<Map<String, dynamic>>> _pickReadableAccountDoc(User u) async {
    final uidRef = fs.collection('Account').doc(u.uid);

    final email = u.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      final emailRef = fs.collection('Account').doc(email);
      try {

        await emailRef.get(const GetOptions(source: Source.server));
        await upsertAccountMapping();
        await verifyReminderAccess();
        return emailRef;
      } catch (_) {
      }
    }
    return uidRef;
  }

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(null);

    final controller = StreamController<UserProfile?>();
    _pickReadableAccountDoc(user).then((ref) {
      final sub = ref.snapshots().listen(
        (snap) {
          if (!snap.exists) {
            controller.add(null);
            return;
          }
          try {
            controller.add(UserProfile.fromDocumentSnapshot(snap));
          } catch (e) {
            debugPrint('UserProfile parse error: $e');
            controller.add(null);
          }
        },
        onError: (e, st) {
          debugPrint('userProfileStream error on ${ref.path}: $e');
          controller.add(null);
        },
      );
      controller.onCancel = () => sub.cancel();
    }).catchError((e, st) {
      debugPrint('userProfileStream failed to pick doc: $e');
      controller.add(null);
      controller.close();
    });

    return controller.stream;
  });
}


  @override
  Widget build(BuildContext context) {
          return MultiProvider(
        providers: [
          // Auth stream
          StreamProvider<User?>.value(
            value: _authStream,
            initialData: null,
            catchError: (_, __) => null,
          ),

          // Profile stream
          StreamProvider<UserProfile?>.value(
            value: _userProfileStream,
            initialData: null,
            catchError: (_, __) => null,
          ),

          ChangeNotifierProvider(create: (_) => CommunityController()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
          ChangeNotifierProvider(create: (_) => ShareExperienceController()),
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
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(appSettings.textScale),
                ),
                child: child!,
              );
            },
            home: const _RootGate(),
            routes: {
              '/assistant': (context) {
                final email = FirebaseAuth.instance.currentUser?.email ?? 'guest@allcare.ai';
                return AssistantChat(userEmail: email);
              },
            },
          );
        },
      )
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final profile = context.watch<UserProfile?>();

    if (user == null) return const _NotSignedInScreen();
    if (profile == null) return const WelcomeScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
        final profile = context.read<UserProfile>();
        String targetUid;

        if (profile.userType == 'elderly') {
          targetUid = profile.uid;
        } else if (profile.userType == 'caregiver') {
          targetUid = profile.elderlyId ??
              ((profile.elderlyIds != null && profile.elderlyIds!.isNotEmpty)
                  ? profile.elderlyIds!.first
                  : profile.uid);
        } else {
          targetUid = profile.uid;
        }

        final cart = context.read<CartController>();
        final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
        if (email != null && email.isNotEmpty) {
          cart.service = CartServiceFs(email: email, db: FirebaseFirestore.instance);
          await cart.loadFromFirestore();
        }
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
