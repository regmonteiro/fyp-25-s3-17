import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controller/account/account_controller.dart';
import 'profile_details_page.dart';
import 'payment_details_page.dart';
import 'caregiver_access_page.dart';
import 'password_settings_page.dart';
import 'support_feedback_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ctrl = AccountController();

    return Scaffold(
      appBar: AppBar(title: const Text("Account")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(
            icon: Icons.person,
            title: "Elderly Profile Details",
            subtitle: "Name, contact, DOB, caregiver link",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileDetailsPage()),
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
            title: "Caregiver Accessibility",
            subtitle: "Add / remove caregivers, feature access",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CaregiverAccessPage()),
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
          _tile(
            icon: Icons.support_agent,
            title: "Support / Feedback",
            subtitle: "Rate us, write feedback, chat with bot",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportFeedbackPage()),
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
              await ctrl.signOut(context);
              // Optional: Navigator.of(context).pushReplacementNamed('/login');
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
