import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'welcome.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AllCareApp());
}

class AllCareApp extends StatelessWidget {
  const AllCareApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AllCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: WelcomeScreen(),
    );
  }
}

