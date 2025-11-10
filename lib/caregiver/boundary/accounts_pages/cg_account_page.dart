import 'package:elderly_aiassistant/welcome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../controller/account/cg_account_controller.dart';
import 'cg_profile_details_page.dart';
import 'payment_details_page.dart';
import 'elderly_access_page.dart';
import 'password_settings_page.dart';
import 'settings_page.dart';
import '../../../models/user_profile.dart';
import '../../../assistant_chat.dart';



class CgAccountPage extends StatelessWidget {
  final UserProfile userProfile;
  const CgAccountPage({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final ctrl = CgAccountController();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
  backgroundColor: Colors.deepPurple,
  onPressed: () {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'guest@allcare.ai';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssistantChat(userEmail: email),
      ),
    );
  },
  child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
),

      appBar: AppBar(title: const Text("Account Details")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(
            icon: Icons.person,
            title: "Caregiver Profile Details",
            subtitle: "Name, contact, DOB, caregiver link",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileDetailsPage()),
            ),
          ),
          _tile(
            icon: Icons.settings,
            title: "Account Settings",
            subtitle: "Notification, privacy, data",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          _tile(
            icon: Icons.credit_card,
            title: "Payment / Card Details",
            subtitle: "Saved cards, plan, next charge, change or cancel",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentDetailsPage()),
            ),
          ),
          _tile(
            icon: Icons.group,
            title: "Elderly Accessibility",
            subtitle: "Add / remove elderly, feature access",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ElderlyAccessPage()),
            ),
          ),
          _tile(
            icon: Icons.lock,
            title: "Password Settings",
            subtitle: "Change your password",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PasswordSettingsPage()),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;

              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                _logoutRoute(),
                (route) => false,
              );
            },
            label: const Text("Log out"),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              "UID: ${FirebaseAuth.instance.currentUser?.uid ?? '-'}",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
  Route _logoutRoute(){
    if (!kIsWeb && Platform.isIOS){
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      );
    }
    return MaterialPageRoute(
      builder:(context) => const WelcomeScreen(),
    );
  }

  Widget _tile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
