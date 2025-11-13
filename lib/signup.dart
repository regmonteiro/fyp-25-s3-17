import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'payment.dart';
import 'caregiver/boundary/caregiver_dashboard_page.dart';
import 'models/user_profile.dart';

/// Same helper as MainWrapper
String emailKeyFrom(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain';
}

// Enum if you ever want to reuse roles, but not required
// enum UserRole { elderly, caregiver, admin }

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final String _adminKey = "fyp2025s317";

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _elderlyIdController = TextEditingController();
  final _adminKeyController = TextEditingController();

  DateTime? _dob;
  String? _role; // 'elderly' | 'caregiver' | 'admin'
  bool _isCaregiver = false;
  bool _isAdmin = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _elderlyIdController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  String _randId() => FirebaseFirestore.instance.collection('_ids').doc().id;

  Future<void> _selectDOB(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1960),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  void _showTermsAndConditionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Terms and Conditions"),
        content: const SingleChildScrollView(
          child: Text(
            """
Last Updated: August 10, 2025

Welcome to Allcare! These Terms and Conditions govern your access to and use of the Allcare Platform.

1. You must be at least 18 years old to create or manage an account.
2. Allcare supports elderly users and caregivers with AI assistance and scheduling tools.
3. You must provide accurate information and protect your login credentials.
4. Your data is handled according to our Privacy Policy.
5. The Platform is provided “as is”; Allcare is not liable for indirect damages.
6. These Terms are governed by Singapore law.

For questions, contact admin@allcare.com.
            """,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must accept the terms and conditions.")),
      );
      return;
    }

    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Date of Birth is required.")),
      );
      return;
    }

    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User type is required.")),
      );
      return;
    }

    if (_isAdmin && _adminKeyController.text.trim() != _adminKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Admin Key.")),
      );
      return;
    }

    final age = DateTime.now().difference(_dob!).inDays ~/ 365;
    if (_role == "elderly" && age < 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Elderly users must be at least 60 years old.")),
      );
      return;
    }

    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match.")),
      );
      return;
    }

    try {
      // 1) Create Firebase Auth user
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;
      final email = _emailController.text.trim().toLowerCase();
      final emailKey = emailKeyFrom(email); // main Account doc id

      final role = _role!.toLowerCase();
      final elderlyId = _isCaregiver ? _elderlyIdController.text.trim() : null;

      final accountColl = FirebaseFirestore.instance.collection('Account');

      // 2) If caregiver, check if there is already a caregiver linked to this elderlyId
      bool hasExistingCaregiver = false;
      if (role == 'caregiver' && elderlyId != null && elderlyId.isNotEmpty) {
        final existingCaregiversSnap = await accountColl
            .where('userType', isEqualTo: 'caregiver')
            .where('elderlyId', isEqualTo: elderlyId)
            .limit(1)
            .get();

        hasExistingCaregiver = existingCaregiversSnap.docs.isNotEmpty;
      }

      // 3) Build profile data
      final data = <String, dynamic>{
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'email': email,
        'phoneNum': _phoneController.text.trim(),
        'userType': role,
        'dob': Timestamp.fromDate(_dob!),
        'elderlyId': elderlyId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginDate': FieldValue.serverTimestamp(),
        'lastPasswordUpdate': FieldValue.serverTimestamp(),
        'status': 'Active',
        'uid': uid,
        'loginLogs': {
          _randId(): {'date': FieldValue.serverTimestamp()},
        },
        'tosAccepted': {
          'version': '2025-08-10',
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      };

      // 4) Canonical profile: /Account/{emailKey}
      await accountColl.doc(emailKey).set(data, SetOptions(merge: true));

      // 5) Mirror profile: /Account/{uid}  (for PaymentPage, etc.)
      await accountColl.doc(uid).set(data, SetOptions(merge: true));

      if (!mounted) return;

      // 6) Smart navigation logic
      if (role == 'caregiver') {
        if (hasExistingCaregiver) {
          // Elderly already has at least one caregiver linked
          // -> new caregiver must pay for additional caregiver subscription
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentPage()),
          );
        } else {
          // First caregiver for this elderlyId
          // -> go straight to caregiver dashboard
          final userProfile = UserProfile.fromMap(data, uid);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CaregiverDashboardPage(userProfile: userProfile),
            ),
          );
        }
      } else {
        // Elderly or admin accounts go to payment as usual
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'weak-password':
          msg = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          msg = 'The account already exists for that email.';
          break;
        case 'invalid-email':
          msg = 'The email address is invalid.';
          break;
        default:
          msg = 'An error occurred during signup: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
      debugPrint('Signup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create an Account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // First name
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: "First Name"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              // Last name
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: "Last Name"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Phone Number"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                validator: (val) =>
                    val == null || val.isEmpty || !val.contains("@")
                        ? "Valid email required"
                        : null,
              ),
              // Password
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (val) =>
                    val == null || val.length < 8 ? "Min 8 characters" : null,
              ),
              // Confirm password
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: "Confirm Password"),
                obscureText: true,
                validator: (val) =>
                    val != _passwordController.text ? "Passwords do not match" : null,
              ),
              const SizedBox(height: 10),

              // DOB
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dob == null
                          ? "Date of Birth"
                          : "DOB: ${DateFormat.yMMMd().format(_dob!)}",
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectDOB(context),
                    child: const Text("Select Date"),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Role
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: "User Type"),
                items: const ["admin", "elderly", "caregiver"]
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _role = val;
                    _isCaregiver = val == "caregiver";
                    _isAdmin = val == "admin";
                  });
                },
                validator: (val) => val == null ? "Required" : null,
              ),

              // Admin key
              if (_isAdmin)
                TextFormField(
                  controller: _adminKeyController,
                  decoration: const InputDecoration(labelText: "Admin Key"),
                  obscureText: true,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Admin key is required" : null,
                ),

              // Caregiver elderlyId
              if (_isCaregiver)
                TextFormField(
                  controller: _elderlyIdController,
                  decoration: const InputDecoration(
                    labelText: "Elderly ID (to match with user)",
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Required for caregiver" : null,
                ),

              const SizedBox(height: 20),

              // Terms & conditions
              Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (val) =>
                        setState(() => _acceptedTerms = val ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showTermsAndConditionsDialog,
                      child: const Text(
                        "I agree to the Terms and Conditions",
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Submit
              ElevatedButton(
                onPressed: _signup,
                child: const Text("Continue"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
