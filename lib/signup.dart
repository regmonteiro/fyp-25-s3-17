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

  // Helper functions
  String _isoNow() => DateTime.now().toUtc().toIso8601String();
  String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toUtc());
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
          child: Text("""
Last Updated: August 10, 2025

Welcome to Allcare! These Terms and Conditions govern your access to and use of the Allcare website and mobile application (the "Platform"). By creating an account or using the Platform, you agree to be bound by these terms. If you do not agree, you may not use the Platform.

1. Acceptance of Terms: You must be at least 18 years old to create or manage an account.
2. Platform Purpose: Allcare supports elderly users and caregivers with AI assistance, scheduling, learning, and community features.
3. Responsibilities: You must provide accurate information and protect your account credentials.
4. Privacy Policy: Your data is handled per our Privacy Policy.
5. Limitation of Liability: The Platform is provided “as is”. Allcare is not liable for damages arising from its use.
6. Governing Law: These Terms are governed by Singapore law.

For questions, contact admin@allcare.com.
"""),
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
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;
      final nowIso = _isoNow();

      final data = <String, dynamic>{
  'firstname': _firstNameController.text.trim(),
  'lastname': _lastNameController.text.trim(),
  'email': _emailController.text.trim(),
  'phoneNum': _phoneController.text.trim(),
  'userType': _role,
  'dob': Timestamp.fromDate(_dob!), // <— use Timestamp
  'elderlyId': _isCaregiver ? _elderlyIdController.text.trim() : null,
  'createdAt': FieldValue.serverTimestamp(),
  'lastLoginDate': FieldValue.serverTimestamp(),
  'lastPasswordUpdate': FieldValue.serverTimestamp(),
  'status': 'Active',
  'uid': uid,
  'loginLogs': {
    _randId(): {'date': FieldValue.serverTimestamp()},
  },
  // Optional: record ToS version
  'tosAccepted': {
    'version': '2025-08-10',
    'acceptedAt': FieldValue.serverTimestamp(),
  },
};

      await FirebaseFirestore.instance.collection('Account').doc(uid).set(data);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaymentPage()),
      );
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
                    val!.isEmpty || !val.contains("@") ? "Valid email required" : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (val) => val!.length < 8 ? "Min 8 characters" : null,
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
                items: ["admin", "elderly", "caregiver"]
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
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
              if (_isAdmin)
                TextFormField(
                  controller: _adminKeyController,
                  decoration: const InputDecoration(labelText: "Admin Key"),
                  obscureText: true,
                  validator: (val) =>
                      val!.isEmpty ? "Admin key is required" : null,
                ),
              if (_isCaregiver)
                TextFormField(
                  controller: _elderlyIdController,
                  decoration:
                      const InputDecoration(labelText: "Elderly ID (to match with user)"),
                  validator: (val) =>
                      val!.isEmpty ? "Required for caregiver" : null,
                ),
              const SizedBox(height: 20),
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
