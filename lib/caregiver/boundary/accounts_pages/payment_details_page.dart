import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controller/account/payment_details_controller.dart';
// import 'package:elderly_aiassistant/payment.dart'; // keep if you actually navigate to it

class PaymentDetailsPage extends StatefulWidget {
  const PaymentDetailsPage({Key? key}) : super(key: key);

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  final _ctrl = PaymentController();
  Map<String, dynamic>? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _ctrl.loadSubscription();
      if (!mounted) return;
      setState(() {
        _sub = data ?? {};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load subscription')),
      );
    }
  }

  String _countdownText() {
    try {
      final endIso = _sub?['subscriptionEndDate'];
      if (endIso == null) return '-';
      final end = DateTime.parse(endIso.toString());
      final diff = end.difference(DateTime.now());
      if (diff.inDays >= 1) return "${diff.inDays} days";
      if (diff.inHours >= 1) return "${diff.inHours} hours";
      if (diff.inMinutes >= 1) return "${diff.inMinutes} minutes";
      return "due soon";
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_sub?['subscriptionStatus'] ?? 'none').toString();
    final endIso = _sub?['subscriptionEndDate'];
    final nextRenewal = (endIso != null)
        ? DateFormat.yMMMd().format(DateTime.parse(endIso.toString()))
        : '-';

    return Scaffold(
      appBar: AppBar(title: const Text("Payment / Card Details")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _kv("Plan", status),
                _kv("Next Renewal", nextRenewal),
                _kv("Countdown", _countdownText()),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: wire to your PaymentPage
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Change plan flow not wired")),
                          );
                        },
                        child: const Text("Change Plan"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showAddCardDialog,
                        child: const Text("Update/Add Card"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Saved Cards", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _ctrl.cardsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) return const Text("No saved cards.");
                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        final masked = (data['masked'] ?? '**** **** **** ****').toString();
                        final brand  = (data['brand'] ?? 'Card').toString();
                        final expiry = (data['expiry'] ?? '').toString();
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.credit_card),
                            title: Text("$brand  $masked"),
                            subtitle: Text("Exp: $expiry"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _ctrl.deleteCard(d.id),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await _ctrl.cancelSubscription();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Subscription canceled")),
                    );
                    _load();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Cancel Subscription"),
                ),
              ],
            ),
    );
  }

  Widget _kv(String k, String v) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(v),
        ]),
      );

  Future<void> _showAddCardDialog() async {
    final name = TextEditingController();
    final number = TextEditingController();
    final expiry = TextEditingController();
    final cvc = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add / Update Card"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: "Cardholder Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: number,
                decoration: const InputDecoration(labelText: "Card Number"),
                keyboardType: TextInputType.number,
                validator: (v) => (v != null && v.replaceAll(' ', '').length == 16)
                    ? null
                    : "16 digits",
              ),
              TextFormField(
                controller: expiry,
                decoration: const InputDecoration(labelText: "MM/YY"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: cvc,
                decoration: const InputDecoration(labelText: "CVC"),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (v) => (v != null && v.length == 3) ? null : "3 digits",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final digits = number.text.replaceAll(' ', '');
              final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : '0000';
              await _ctrl.addOrUpdateCard({
                'brand': 'Visa',
                'masked': "**** **** **** $last4",
                'expiry': expiry.text.trim(),
                'holder': name.text.trim(),
                'last4': last4,
                'addedAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
