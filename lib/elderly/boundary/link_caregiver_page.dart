import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../caregiver_signup_page.dart';


class LinkCaregiverPage extends StatefulWidget {
  const LinkCaregiverPage({Key? key}) : super(key: key);

  @override
  State<LinkCaregiverPage> createState() => _LinkCaregiverPageState();
}

class _LinkCaregiverPageState extends State<LinkCaregiverPage> {
  final _formKey = GlobalKey<FormState>();
  final _caregiverIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _caregiverIdController.dispose();
    super.dispose();
  }

  Future<void> _linkCaregiver() async {
  final form = _formKey.currentState;
  if (form == null || !form.validate()) return;

  setState(() => _isLoading = true);

  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final uid = auth.currentUser?.uid;
  final caregiverId = _caregiverIdController.text.trim();

  try {
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You must be signed in.')));
      return;
    }

    // ---- 1) Read MY Account doc to resolve the elderly identity ----
    final myDoc = await firestore.collection('Account').doc(uid).get();
    if (!myDoc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your Account record was not found.')),
      );
      return;
    }
    final myData = myDoc.data()!;
    final elderId = _resolveElderId(myDoc); // uid / elderlyId / elderlyIds

    // Prevent self-linking (if the caregiver typed the elderId or vice versa)
    if (caregiverId == elderId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot link yourself as caregiver.')),
      );
      return;
    }

    // ---- 2) Validate the caregiver doc and role ----
    final caregiverDoc =
        await firestore.collection('Account').doc(caregiverId).get();

    final caregiverData = caregiverDoc.data();
    final isCaregiver = caregiverDoc.exists &&
        (caregiverData?['userType']?.toString().toLowerCase() == 'caregiver');

    if (!isCaregiver) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Caregiver ID. Please try again.')),
      );
      return;
    }

    // ---- 3) Link BOTH SIDES using merge + arrayUnion ----
    // elder side
    await firestore.collection('Account').doc(elderId).set({
      'linkedCaregivers': FieldValue.arrayUnion([caregiverId]),
    }, SetOptions(merge: true));

    // caregiver side
    await firestore.collection('Account').doc(caregiverId).set({
      'linkedElders': FieldValue.arrayUnion([elderId]),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caregiver linked successfully!')),
    );
    Navigator.of(context).pop();
  } on FirebaseException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Failed to link caregiver: ${e.message ?? e.code}')));
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Failed to link caregiver: $e')));
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

/// Prefer elderlyId -> first elderlyIds -> fallback to the doc id (uid)
String _resolveElderId(DocumentSnapshot<Map<String, dynamic>> me) {
  final data = me.data() ?? {};
  final elderlyId = data['elderlyId'];
  if (elderlyId is String && elderlyId.trim().isNotEmpty) return elderlyId.trim();

  final elderlyIds = data['elderlyIds'];
  if (elderlyIds is List && elderlyIds.isNotEmpty && elderlyIds.first is String) {
    final first = (elderlyIds.first as String).trim();
    if (first.isNotEmpty) return first;
  }
  return me.id; // fallback to uid
}


  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Link a Caregiver')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Enter your caregiver's User ID to link your accounts.",
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
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a Caregiver ID';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _linkCaregiver();
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
                    MaterialPageRoute(
                      builder: (_) => const CaregiverSignUpPage(),
                    ),
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
      ),
    );
  }
}
