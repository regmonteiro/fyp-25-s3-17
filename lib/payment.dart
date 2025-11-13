import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'elderly/boundary/elderly_dashboard_page.dart';
import 'caregiver/boundary/caregiver_dashboard_page.dart';
import 'admin/admin_dashboard.dart';
import 'models/user_profile.dart';

// Enum to represent the different subscription plans
enum SubscriptionPlan { monthly, annual, threeYear, none }

/// Same helper as in MainWrapper / Signup
String emailKeyFrom(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local  = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain';
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({Key? key}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  SubscriptionPlan _selectedPlan = SubscriptionPlan.none;
  bool _isProcessingPayment = false;
  bool _addCaregiver = false;

  // Controllers for the simulated card details
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvcController = TextEditingController();
  final _cardNameController = TextEditingController();

  // Controllers for the additional caregiver
  final _caregiverNameController = TextEditingController();
  final _caregiverEmailController = TextEditingController();
  final _caregiverPhoneController = TextEditingController();

  // Form key for payment details
  final _paymentFormKey = GlobalKey<FormState>();

  // Form key for additional caregiver details
  final _caregiverFormKey = GlobalKey<FormState>();

  Future<void> _handleSubscriptionSuccess({
    required SubscriptionPlan plan,
    bool isTrial = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not authenticated. Please log in again.")),
        );
      }
      return;
    }

    try {
      final email = (user.email ?? '').trim().toLowerCase();
      final emailKey = emailKeyFrom(email);
      final coll = FirebaseFirestore.instance.collection('Account');

      // Fetch both docs: by uid and by emailKey
      final uidDocFuture   = coll.doc(user.uid).get();
      final emailDocFuture = coll.doc(emailKey).get();

      final uidDoc   = await uidDocFuture;
      final emailDoc = await emailDocFuture;

      Map<String, dynamic>? userProfileData;

      if (uidDoc.exists) {
        userProfileData = uidDoc.data()!;
      } else if (emailDoc.exists) {
        userProfileData = emailDoc.data()!;
      }

      if (userProfileData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User profile not found in database.")),
          );
        }
        return;
      }

      // Calculate the subscription end date
      DateTime endDate;
      switch (plan) {
        case SubscriptionPlan.monthly:
          endDate = DateTime.now().add(const Duration(days: 30));
          break;
        case SubscriptionPlan.annual:
          endDate = DateTime.now().add(const Duration(days: 365));
          break;
        case SubscriptionPlan.threeYear:
          endDate = DateTime.now().add(const Duration(days: 3 * 365));
          break;
        case SubscriptionPlan.none:
        default:
          endDate = DateTime.now().add(const Duration(days: 15)); // For free trial
          break;
      }

      // Data to update
      final Map<String, dynamic> updatedData = {
        'subscriptionStatus': isTrial ? 'freeTrial' : plan.name,
        'subscriptionEndDate': endDate.toIso8601String(),
        'isTrialing': isTrial,
      };

      // Update both docs if they exist; if not, set with merge
      if (uidDoc.exists) {
        await coll.doc(user.uid).set(updatedData, SetOptions(merge: true));
      }
      if (emailDoc.exists) {
        await coll.doc(emailKey).set(updatedData, SetOptions(merge: true));
      }

      // Save additional caregiver details if provided (under uid doc)
      if (_addCaregiver) {
        await coll
            .doc(user.uid)
            .collection('caregivers')
            .add({
          'name': _caregiverNameController.text.trim(),
          'email': _caregiverEmailController.text.trim(),
          'phone': _caregiverPhoneController.text.trim(),
          'linkedAt': DateTime.now(),
        });
      }

      // Merge for navigation (so userProfile sees latest subscription fields)
      final mergedProfileData = {
        ...userProfileData,
        ...updatedData,
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTrial
                  ? "Free trial activated! Enjoy Allcare."
                  : "Payment successful! Your subscription is now active.",
            ),
          ),
        );

        // Build UserProfile
        final userProfile = UserProfile.fromMap(mergedProfileData, user.uid);

        // Decide where to go based on userType
        final role = (mergedProfileData['userType'] as String? ?? '').trim().toLowerCase();

        Widget next;
        if (role == 'caregiver') {
          next = CaregiverDashboardPage(userProfile: userProfile);
        } else if (role == 'admin') {
          next = AdminDashboard(userProfile: userProfile);
        } else {
          // default fallback = elderly
          next = ElderlyDashboardPage(userProfile: userProfile);
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => next),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  // Method to simulate a payment process
  Future<void> _processPayment() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_selectedPlan == SubscriptionPlan.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a subscription plan.")),
      );
      return;
    }

    // Validate card details form
    if (!_paymentFormKey.currentState!.validate()) return;

    // Validate caregiver form if applicable
    if (_addCaregiver && !_caregiverFormKey.currentState!.validate()) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Simulate a network delay for payment processing
      await Future.delayed(const Duration(seconds: 2));
      await _handleSubscriptionSuccess(plan: _selectedPlan);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  // Method to handle the free trial option
  Future<void> _startFreeTrial() async {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isProcessingPayment = true;
    });

    // Caregiver validation is needed for the free trial button if extra caregiver added
    if (_addCaregiver && !_caregiverFormKey.currentState!.validate()) {
      setState(() {
        _isProcessingPayment = false;
      });
      return;
    }

    try {
      await Future.delayed(const Duration(seconds: 1)); // Simulate a short delay
      await _handleSubscriptionSuccess(plan: SubscriptionPlan.none, isTrial: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvcController.dispose();
    _cardNameController.dispose();
    _caregiverNameController.dispose();
    _caregiverEmailController.dispose();
    _caregiverPhoneController.dispose();
    super.dispose();
  }

  // Widget to display a single subscription card
  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required String title,
    required String price,
    required String duration,
  }) {
    final bool isSelected = _selectedPlan == plan;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
        });
      },
      child: Card(
        color: isSelected ? Colors.blue.shade100 : Colors.white,
        elevation: isSelected ? 8 : 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue.shade900 : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(duration),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscription"),
      ),
      body: _isProcessingPayment
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Welcome to Allcare! To activate your profile and enjoy Allcare's premium features, please select a subscription plan or start a free trial.",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Subscription Plans
                  _buildPlanCard(
                    plan: SubscriptionPlan.monthly,
                    title: "Monthly Plan",
                    price: "\$90",
                    duration: "Recurring every 30 days",
                  ),
                  const SizedBox(height: 10),
                  _buildPlanCard(
                    plan: SubscriptionPlan.annual,
                    title: "Annual Plan",
                    price: "\$1080",
                    duration: "Recurring every calendar year",
                  ),
                  const SizedBox(height: 10),
                  _buildPlanCard(
                    plan: SubscriptionPlan.threeYear,
                    title: "3-Year Plan",
                    price: "\$3000",
                    duration: "Recurring every 3 years",
                  ),

                  const SizedBox(height: 20),

                  // Payment Form
                  const Text(
                    "Payment Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Form(
                    key: _paymentFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _cardNameController,
                          decoration: const InputDecoration(labelText: "Cardholder Name"),
                          validator: (val) => val == null || val.isEmpty ? "Required" : null,
                        ),
                        TextFormField(
                          controller: _cardNumberController,
                          decoration: const InputDecoration(labelText: "Card Number"),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                              val == null || val.length != 16 ? "Must be 16 digits" : null,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _expiryDateController,
                                decoration: const InputDecoration(labelText: "MM/YY"),
                                validator: (val) =>
                                    val == null || val.isEmpty ? "Required" : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _cvcController,
                                decoration: const InputDecoration(labelText: "CVC"),
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                validator: (val) =>
                                    val == null || val.length != 3 ? "Must be 3 digits" : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Caregiver Information
                  Row(
                    children: [
                      Checkbox(
                        value: _addCaregiver,
                        onChanged: (val) {
                          setState(() {
                            _addCaregiver = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "Add additional caregiver (+\$25/month)",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),

                  // Additional caregiver form, only visible if checkbox is checked
                  if (_addCaregiver)
                    Form(
                      key: _caregiverFormKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _caregiverNameController,
                            decoration:
                                const InputDecoration(labelText: "Caregiver's Name"),
                            validator: (val) => val == null || val.isEmpty ? "Required" : null,
                          ),
                          TextFormField(
                            controller: _caregiverEmailController,
                            decoration:
                                const InputDecoration(labelText: "Caregiver's Email"),
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) =>
                                val == null || val.isEmpty || !val.contains("@")
                                    ? "Valid email required"
                                    : null,
                          ),
                          TextFormField(
                            controller: _caregiverPhoneController,
                            decoration: const InputDecoration(
                              labelText: "Caregiver's Phone Number",
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (val) => val == null || val.isEmpty ? "Required" : null,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  ElevatedButton(
                    onPressed: _processPayment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Proceed to Payment"),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _startFreeTrial,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.blue.shade600, width: 2),
                      foregroundColor: Colors.blue.shade600,
                    ),
                    child: const Text("Start 15-day Free Trial"),
                  ),
                ],
              ),
            ),
    );
  }
}
