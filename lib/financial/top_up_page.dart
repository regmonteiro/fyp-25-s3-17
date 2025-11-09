import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'wallet_controller.dart';
import 'payment_methods_page.dart';
import '../models/user_profile.dart';


class TopUpPage extends StatefulWidget {
  final UserProfile userProfile;
  const TopUpPage({super.key, required this.userProfile});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.userProfile;
    final wallet = context.read<WalletController>(); // reuse parent provider

    return Scaffold(
      appBar: AppBar(title: const Text('Top Up Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (\$)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  child: const Text('Confirm Top Up'),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final amount = double.parse(_amountCtrl.text);

                    // 1) Ask for payment method
                    final selection = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentMethodsPage(
                          currentUserUid: profile.uid,
                          targetElderUid: profile.userType == 'caregiver'
                              ? (profile.elderlyId ?? profile.uid)
                              : profile.uid,
                          caregiverUid: profile.userType == 'caregiver'
                              ? profile.uid
                              : null,
                        ),
                      ),
                    );

                    if (selection == null) return;

                    try {
                      await wallet.topUpWallet(
                        amount: amount,
                        paymentMethod: selection.method,
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Top up successful')),
                      );
                      Navigator.pop(context);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
