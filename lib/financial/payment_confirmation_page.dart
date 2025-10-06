import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_profile.dart';

class PaymentConfirmationPage extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> cartItems;
  final UserProfile userProfile;
  final String? elderlyUidOverride;

  const PaymentConfirmationPage({
    Key? key,
    required this.totalAmount,
    required this.cartItems,
    required this.userProfile,
    this.elderlyUidOverride,
  }) : super(key: key);

  @override
  State<PaymentConfirmationPage> createState() => _PaymentConfirmationPageState();
}

class _PaymentConfirmationPageState extends State<PaymentConfirmationPage> {
  String _selectedPaymentMethod = 'Credit/Debit Card';
  bool _isProcessing = false;

  String get _elderlyUid {
    if (widget.elderlyUidOverride != null && widget.elderlyUidOverride!.isNotEmpty) {
      return widget.elderlyUidOverride!;
    }
    final isCaregiver = widget.userProfile.role == 'caregiver';
    if (isCaregiver && (widget.userProfile.uidOfElder?.isNotEmpty ?? false)) {
      return widget.userProfile.uidOfElder!;
    }
    return widget.userProfile.uid;
  }

  double _computedTotal() {
    return widget.cartItems.fold<double>(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      return sum + price;
    });
  }

  Future<void> _processPayment() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // simulate gateway
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Harden item mapping
      final items = widget.cartItems.map((item) {
        final name = (item['name'] ?? '').toString();
        final id = (item['id'] ?? '').toString();
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        return {'productId': id, 'name': name, 'price': price};
      }).toList();

      // Recompute/verify total for integrity
      final calcTotal = _computedTotal();
      final orderTotal = calcTotal; // or compare with widget.totalAmount if you want to assert

      final orderData = {
        'purchaserUid': widget.userProfile.uid,
        'purchaserName': widget.userProfile.displayName,
        'elderlyUid': _elderlyUid,
        'orderType': 'OTC',
        'items': items,
        'totalAmount': orderTotal,
        'paymentMethod': _selectedPaymentMethod,
        'status': 'processing', // keep consistent across the app
        'orderedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('orders').add(orderData);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showOrderConfirmation(context, orderTotal);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showOrderConfirmation(BuildContext context, double total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 60)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Order Placed Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Your OTC medication will be delivered soon.',
                style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Text('Total Paid: S\$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Back to Shop', style: TextStyle(color: Colors.blue)),
            onPressed: () {
              Navigator.of(context).pop();       // close dialog
              Navigator.of(context).pop();       // close payment page
              // or: Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTotal = _computedTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Confirmation'),
        backgroundColor: Colors.lightGreen.shade700,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Method',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.lightGreen.shade800)),
                const SizedBox(height: 15),
                _buildPaymentOption(title: 'Credit/Debit Card', icon: FontAwesomeIcons.creditCard, value: 'Credit/Debit Card'),
                _buildPaymentOption(title: 'E-Wallet (PayNow)', icon: FontAwesomeIcons.qrcode, value: 'E-Wallet'),
                _buildPaymentOption(title: 'Digital Health Voucher', icon: FontAwesomeIcons.receipt, value: 'Voucher'),
                const SizedBox(height: 30),

                Text('Order Summary (${widget.cartItems.length} items)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.lightGreen.shade800)),
                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ...widget.cartItems.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${item['name']}', style: const TextStyle(fontSize: 16)),
                                Text('S\$${((item['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('S\$${safeTotal.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.pink.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -5)),
              ]),
              child: SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('Confirm Payment', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({required String title, required IconData icon, required String value}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: _selectedPaymentMethod == value ? Colors.blue.shade400 : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              FaIcon(icon, size: 24, color: Colors.blue.shade600),
              const SizedBox(width: 15),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              Radio<String>(
                value: value,
                groupValue: _selectedPaymentMethod,
                onChanged: (v) => setState(() => _selectedPaymentMethod = v ?? _selectedPaymentMethod),
                activeColor: Colors.blue.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
