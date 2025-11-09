import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';

class PaymentConfirmationPage extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> cartItems;
  final UserProfile userProfile;
  final String? targetUid;


  const PaymentConfirmationPage({
    super.key,
    required this.totalAmount,
    required this.cartItems,
    required this.userProfile,
    this.targetUid,
  });

  @override
  State<PaymentConfirmationPage> createState() => _PaymentConfirmationPageState();
}

class _PaymentConfirmationPageState extends State<PaymentConfirmationPage> {
  String _method = 'paynow';
  bool _isProcessing = false;

  String get _effectiveTargetUid {
    if (widget.userProfile.userType == 'elderly') {
      return widget.userProfile.uid;
    } else if (widget.userProfile.userType == 'caregiver') {
      final eId = widget.userProfile.elderlyId;
      if (eId != null && eId.isNotEmpty) return eId;
      final list = widget.userProfile.elderlyIds ?? [];
      if (list.isNotEmpty) return list.first;
    }
    return widget.userProfile.uid;
  }

  Future<void> _confirmPayment() async {
    setState(() => _isProcessing = true);

    final paymentDetails = {
      'method': _method,
      'status': 'Confirmed',
      'amount': widget.totalAmount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'targetUid': _effectiveTargetUid,
      'address': {
        'name': 'Home',
        'recipientName': widget.userProfile.firstname,
        'phoneNumber': widget.userProfile.phoneNum ?? '',
        'blockStreet': 'Default',
        'unitNumber': '',
        'postalCode': '000000',
      }
    };

    await Future.delayed(const Duration(seconds: 2)); // simulate gateway
    if (!mounted) return;
    Navigator.pop(context, paymentDetails);
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(symbol: 'S\$');
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Confirmation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Total: ${f.format(widget.totalAmount)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Select payment method:'),
            RadioListTile<String>(
              value: 'paynow',
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
              title: const Text('PayNow'),
            ),
            RadioListTile<String>(
              value: 'card',
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
              title: const Text('Credit/Debit Card'),
            ),
            RadioListTile<String>(
              value: 'applepay',
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
              title: const Text('Apple Pay'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _confirmPayment,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.payment),
              label: Text(_isProcessing ? 'Processing...' : 'Confirm & Pay'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            ),
            const SizedBox(height: 16),
            Text('Paying for UID: ${_effectiveTargetUid}',
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
