import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'payment.dart';

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
  String? _role;
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

  Future<void> _selectDOB(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1960),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
      });
    }
  }

  void _showTermsAndConditionsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Terms and Conditions"),
          content: const SingleChildScrollView(
            child: Text(
              """
              Last Updated: August 10, 2025

              Welcome to Allcare! These Terms and Conditions govern your access to and use of the Allcare website and mobile application (the "Platform"). By creating an account or using the Platform, you agree to be bound by these terms. If you do not agree, you may not use the Platform.

              1. Acceptance of Terms: By using the Allcare Platform, you confirm that you are at least 18 years of age or a legal guardian of an elderly user. All caregivers and administrators must be at least 18 years of age. Elderly users who are not of legal age to enter into a contract must have their account created and managed by a legal guardian.

              2. Platform Purpose and Features: Allcare is a digital platform designed to assist elderly individuals and their caregivers. The Platform's features include, but are not limited to: an AI assistant to provide personalized support; scheduling and reminders for appointments and events; learning resources and social activities; experience sharing and social media integration.

              3. User Accounts and Responsibilities: You are responsible for providing accurate and complete information during registration. You are responsible for safeguarding your password and for all activities that occur under your account. You must notify us immediately of any unauthorized use.

              4. Content and Conduct: You agree to use the Platform for its intended purpose and not for any unlawful or prohibited activities. You are solely responsible for any content you post, share, or submit on the Platform.

              5. Privacy Policy: Your privacy is important to us. Our Privacy Policy, which is incorporated into these Terms by reference, explains how we collect, use, and protect your personal information. By using the Platform, you consent to our collection and use of your data as described in the Privacy Policy.

              6. Disclaimers and Limitation of Liability: The Platform is provided "as is" and "as available" without any warranties of any kind, whether express or implied. Allcare, its developers, and its affiliates will not be liable for any damages, including but not limited to direct, indirect, or incidental damages, arising from your use or inability to use the Platform.

              7. Changes to Terms: We may revise these Terms and Conditions from time to time. The most current version will always be posted on the Platform. By continuing to use the Platform after changes have been made, you agree to be bound by the revised terms.

              8. Governing Law: These Terms and Conditions are governed by the laws of Singapore. Any disputes arising from these terms will be resolved in the courts of Singapore.

              9. Contact Information: If you have any questions about these Terms and Conditions, please contact us at admin@allcare.com.
              """,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
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
    if (_role == "Elderly" && DateTime.now().difference(_dob!).inDays ~/ 365 < 60) {
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
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _role,
        'phone': _phoneController.text.trim(),
        'dob': _dob?.toIso8601String(),
        'elderlyId': _isCaregiver ? _elderlyIdController.text.trim() : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PaymentPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage;
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'The account already exists for that email.';
        } else {
          errorMessage = 'An error occurred during signup: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred.')),
        );
      }
      debugPrint('Signup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create an account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: "First Name"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: "Last Name"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Phone Number"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                validator: (val) =>
                val!.isEmpty || !val.contains("@") ? "Valid email" : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (val) =>
                val!.length < 8 ? "Min 8 characters" : null,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: "Confirm Password"),
                obscureText: true,
                validator: (val) =>
                val != _passwordController.text ? "Passwords do not match" : null,
              ),
              const SizedBox(height: 10),
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
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: "User Type"),
                items: ["Admin", "Elderly", "Caregiver"]
                    .map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role),
                ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _role = val;
                    _isCaregiver = val == "Caregiver";
                    _isAdmin = val == "Admin";
                  });
                },
                validator: (val) => val == null ? "Required" : null,
              ),
              if (_isAdmin)
                TextFormField(
                  controller: _adminKeyController,
                  decoration: const InputDecoration(
                    labelText: "Admin Key",
                  ),
                  obscureText: true,
                  validator: (val) =>
                  val!.isEmpty ? "Admin key is required" : null,
                ),
              if (_isCaregiver)
                TextFormField(
                  controller: _elderlyIdController,
                  decoration: const InputDecoration(
                    labelText: "Elderly ID (to match with user)",
                  ),
                  validator: (val) =>
                  val!.isEmpty ? "Required for caregiver" : null,
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (val) {
                      setState(() {
                        _acceptedTerms = val ?? false;
                      });
                    },
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
              ElevatedButton(
                onPressed: _signup,
                child: const Text("Continue to Payment"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}