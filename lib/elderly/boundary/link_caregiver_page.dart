import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../caregiver_signup_page.dart';

class LinkCaregiverPage extends StatefulWidget {
  const LinkCaregiverPage({Key? key}) : super(key: key);

  @override
  _LinkCaregiverPageState createState() => _LinkCaregiverPageState();
}

class _LinkCaregiverPageState extends State<LinkCaregiverPage> {
  final _formKey = GlobalKey<FormState>();
  final _caregiverIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _linkCaregiver() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final elderlyUserId = FirebaseAuth.instance.currentUser!.uid;
      final caregiverId = _caregiverIdController.text.trim();
      final firestore = FirebaseFirestore.instance;

      try {
        // 1. Check if the entered caregiverId is a valid user and a caregiver
        final caregiverDoc = await firestore.collection('users').doc(caregiverId).get();
        if (!caregiverDoc.exists || caregiverDoc.data()?['userType'] != 'caregiver') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid Caregiver ID. Please try again.')),
          );
          return;
        }

        // 2. Link the caregiver to the elderly user
        await firestore.collection('users').doc(elderlyUserId).update({
          'linkedCaregivers': FieldValue.arrayUnion([caregiverId]),
        });

        // 3. Link the elderly user to the caregiver
        await firestore.collection('users').doc(caregiverId).update({
          'linkedElders': FieldValue.arrayUnion([elderlyUserId]),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caregiver linked successfully!')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to link caregiver: $e')),
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
        title: const Text('Link a Caregiver'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter your caregiver\'s User ID to link your accounts.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _caregiverIdController,
                    decoration: const InputDecoration(
                      labelText: 'Caregiver User ID',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a Caregiver ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _linkCaregiver,
                          child: const Text('Link Account'),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),
            const Text(
              'Or, create a new account for your caregiver:',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CaregiverSignUpPage()),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Create Caregiver Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}