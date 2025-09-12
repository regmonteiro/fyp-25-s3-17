import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'elderly/boundary/elderly_dashboard_page.dart'; // Import the new home page
import 'models/user_profile.dart'; // Import the UserProfile model

// Enum to represent the different subscription plans
enum SubscriptionPlan { monthly, annual, threeYear, none }

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PaymentPage({super.key, required this.userData});

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

  // Method to handle a successful subscription (either paid or trial)
  Future<void> _handleSubscriptionSuccess({required SubscriptionPlan plan, bool isTrial = false}) async {
    try {
      // 1. Create the user's Firebase account
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: widget.userData['email'],
        password: widget.userData['password'],
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();
      
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
        default:
          endDate = DateTime.now().add(const Duration(days: 15)); // For free trial
          break;
      }

      // Add subscription details and a uid to the userData map
      final Map<String, dynamic> userProfileData = {
        ...widget.userData,
        'uid': userCredential.user!.uid, // Add UID here for the UserProfile model
        'subscriptionStatus': isTrial ? 'freeTrial' : plan.name,
        'subscriptionEndDate': endDate.toIso8601String(),
        'isTrialing': isTrial,
        'createdAt': DateTime.now(),
      };

      // 2. Save user profile details to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userProfileData);
      
      // 3. Save additional caregiver details if provided
      if (_addCaregiver) {
        // You should have a separate process to create this caregiver's account and link it.
        // For this project, we'll just save their details to a sub-collection.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .collection('caregivers')
            .add({
          'name': _caregiverNameController.text.trim(),
          'email': _caregiverEmailController.text.trim(),
          'phone': _caregiverPhoneController.text.trim(),
          'linkedAt': DateTime.now(),
        });
      }

      // 4. Show success message and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTrial 
                ? "Free trial activated! Enjoy Allcare."
                : "Payment successful! Your subscription is now active."
            ),
          ),
        );
        
        // Create the UserProfile object from the data we just saved
        final UserProfile userProfile = UserProfile.fromMap(userProfileData);
        
        // Navigate to the main app page, passing the userProfile object
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ElderlyDashboardPage(userProfile: userProfile)),
        );
      }
      
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = "Email is already registered. Please login instead.";
      } else {
        errorMessage = "Signup failed: ${e.message}";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred: ${e.toString()}")),
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

    } on FirebaseAuthException catch (e) {
      // Catch and re-throw Firebase errors to be handled by _handleSubscriptionSuccess
      rethrow;
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
    setState(() {
      _isProcessingPayment = true;
    });
    
    // Caregiver validation is not needed for the free trial button
    if (_addCaregiver && !_caregiverFormKey.currentState!.validate()) {
      setState(() { _isProcessingPayment = false; });
      return;
    }

    try {
      await Future.delayed(const Duration(seconds: 1)); // Simulate a short delay
      await _handleSubscriptionSuccess(plan: SubscriptionPlan.none, isTrial: true);

    } on FirebaseAuthException catch (e) {
      // Catch and re-throw Firebase errors to be handled by _handleSubscriptionSuccess
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
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
                    "Welcome to Allcare! To activate your profile and begin using Allcare's premium features, please select a subscription plan. All subscriptions are auto-deducted from the card provided.",
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
                          validator: (val) => val!.isEmpty ? "Required" : null,
                        ),
                        TextFormField(
                          controller: _cardNumberController,
                          decoration: const InputDecoration(labelText: "Card Number"),
                          keyboardType: TextInputType.number,
                          validator: (val) => val!.length != 16 ? "Must be 16 digits" : null,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _expiryDateController,
                                decoration: const InputDecoration(labelText: "MM/YY"),
                                validator: (val) => val!.isEmpty ? "Required" : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _cvcController,
                                decoration: const InputDecoration(labelText: "CVC"),
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                validator: (val) => val!.length != 3 ? "Must be 3 digits" : null,
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
                      const Text(
                        "Add additional caregiver (+\$25/month)",
                        style: TextStyle(fontSize: 16),
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
                            decoration: const InputDecoration(labelText: "Caregiver's Name"),
                            validator: (val) => val!.isEmpty ? "Required" : null,
                          ),
                          TextFormField(
                            controller: _caregiverEmailController,
                            decoration: const InputDecoration(labelText: "Caregiver's Email"),
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) =>
                                val!.isEmpty || !val.contains("@") ? "Valid email" : null,
                          ),
                          TextFormField(
                            controller: _caregiverPhoneController,
                            decoration: const InputDecoration(labelText: "Caregiver's Phone Number"),
                            keyboardType: TextInputType.phone,
                            validator: (val) => val!.isEmpty ? "Required" : null,
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

  // Method to build a navigation item
  Widget _buildNavItem(IconData icon, String label, int index) {
    // Note: This method is not used in this specific widget, but is a good practice.
    // It's part of the ElderlyDashboardPage code.
    return Container();
  }
}