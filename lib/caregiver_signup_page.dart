// You will need a similar file for caregiver_signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverSignUpPage extends StatefulWidget {
  const CaregiverSignUpPage({Key? key}) : super(key: key);

  @override
  _CaregiverSignUpPageState createState() => _CaregiverSignUpPageState();
}

class _CaregiverSignUpPageState extends State<CaregiverSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUpCaregiver() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final elderlyUserId = FirebaseAuth.instance.currentUser!.uid;

      try {
        // 1. Create the new caregiver user with Firebase Auth
        final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final newCaregiverUser = userCredential.user;
        if (newCaregiverUser == null) {
          throw 'User creation failed';
        }

        // 2. Create a user profile in Firestore
        await FirebaseFirestore.instance.collection('users').doc(newCaregiverUser.uid).set({
          'uid': newCaregiverUser.uid,
          'displayName': _nameController.text.trim(),
          'email': newCaregiverUser.email,
          'userType': 'caregiver',
          'linkedElders': [elderlyUserId], // Automatically link the elderly user
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Link the new caregiver to the elderly user
        await FirebaseFirestore.instance.collection('users').doc(elderlyUserId).update({
          'linkedCaregivers': FieldValue.arrayUnion([newCaregiverUser.uid]),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caregiver account created and linked successfully!')),
        );

        Navigator.pop(context); // Pop back to LinkCaregiverPage
        Navigator.pop(context); // Pop back to ElderlyHomePage
      } on FirebaseAuthException catch (e) {
        String message = 'An error occurred. Please try again.';
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'The account already exists for that email.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create account: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Caregiver Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Please enter an email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _signUpCaregiver,
                      child: const Text('Create Account and Link'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}