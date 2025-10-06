import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'payment_methods_controller.dart';

class PaymentMethodsPage extends StatefulWidget {
  /// who’s using the app
  final String currentUserUid;
  /// which elderly wallet to top up
  final String targetElderUid;
  /// if a caregiver is paying, pass caregiver uid here (can be same as currentUserUid)
  final String? caregiverUid;

  const PaymentMethodsPage({
    super.key,
    required this.currentUserUid,
    required this.targetElderUid,
    this.caregiverUid,
  });

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  /// radio value:
  /// 'card-user:<cardId>', 'card-caregiver:<cardId>', 'paynow', 'applepay', 'googlepay'
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaymentMethodsController(
        currentUserUid: widget.currentUserUid,
        targetElderUid: widget.targetElderUid,
        caregiverUid: widget.caregiverUid,
      ),
      builder: (context, _) {
        final ctrl = context.read<PaymentMethodsController>();
        return Scaffold(
          appBar: AppBar(title: const Text('Payment method')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // CREDIT/DEBIT CARD (current user)
              _SectionHeader(title: 'Credit/Debit card', trailing: _AddCardButton(forUid: widget.currentUserUid)),
              StreamBuilder<List<SavedCard>>(
                stream: ctrl.myCards,
                builder: (_, snap) {
                  final cards = snap.data ?? const <SavedCard>[];
                  if (cards.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No card saved. Tap "Add card" to link one.', style: TextStyle(color: Colors.black54)),
                    );
                  }
                  return Column(
                    children: cards.map((c) {
                      final value = 'card-user:${c.id}';
                      return RadioListTile<String>(
                        value: value,
                        groupValue: _selected,
                        onChanged: (v) => setState(() => _selected = v),
                        title: Text('${c.brand}  ${c.masked}'),
                        subtitle: Text('Exp: ${c.expiry}   ${c.holder}'),
                      );
                    }).toList(),
                  );
                },
              ),
              const Divider(height: 32),

              // CAREGIVER PAYS (optional)
              if (widget.caregiverUid != null) ...[
                _SectionHeader(
                  title: "Caregiver’s card",
                  trailing: _AddCardButton(forUid: widget.caregiverUid!), // caregivers can add their card too
                ),
                StreamBuilder<List<SavedCard>>(
                  stream: ctrl.caregiverCards,
                  builder: (_, snap) {
                    final cards = snap.data ?? const <SavedCard>[];
                    if (cards.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No caregiver card saved yet.', style: TextStyle(color: Colors.black54)),
                      );
                    }
                    return Column(
                      children: cards.map((c) {
                        final value = 'card-caregiver:${c.id}';
                        return RadioListTile<String>(
                          value: value,
                          groupValue: _selected,
                          onChanged: (v) => setState(() => _selected = v),
                          title: Text('${c.brand}  ${c.masked}'),
                          subtitle: Text('Exp: ${c.expiry}   ${c.holder}'),
                        );
                      }).toList(),
                    );
                  },
                ),
                const Divider(height: 32),
              ],

              // PAYNOW
              RadioListTile<String>(
                value: 'paynow',
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                title: Row(
                  children: [
                    Image.asset('assets/paynow.png', width: 28, height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2)),
                    const SizedBox(width: 12),
                    const Text('PayNow'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // APPLE/GOGLE PAY (UI only – wire to your gateway if you add one)
              RadioListTile<String>(
                value: 'applepay',
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                title: Row(
                  children: const [
                    Icon(Icons.phone_iphone),
                    SizedBox(width: 12),
                    Text('Apple Pay'),
                  ],
                ),
              ),
              RadioListTile<String>(
                value: 'googlepay',
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                title: Row(
                  children: const [
                    Icon(Icons.android),
                    SizedBox(width: 12),
                    Text('Google Pay'),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () {
                        final sel = _selected!;
                        String method = sel;
                        String? cardId;
                        String payer = widget.currentUserUid;

                        if (sel.startsWith('card-user:')) {
                          method = 'card-user';
                          cardId = sel.split(':').last;
                          payer = widget.currentUserUid;
                        } else if (sel.startsWith('card-caregiver:')) {
                          method = 'card-caregiver';
                          cardId = sel.split(':').last;
                          payer = widget.caregiverUid ?? widget.currentUserUid;
                        }

                        Navigator.pop(
                          context,
                          PaymentSelection(
                            method: method,
                            cardId: cardId,
                            payerUid: payer,
                            targetElderUid: widget.targetElderUid,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                child: const Text('Confirm'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _AddCardButton extends StatelessWidget {
  final String forUid;
  const _AddCardButton({required this.forUid});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<PaymentMethodsController>();
    return TextButton(
      onPressed: () async {
        final formKey = GlobalKey<FormState>();
        final name = TextEditingController();
        final number = TextEditingController();
        final expiry = TextEditingController();
        final cvc = TextEditingController();

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Add card'),
            content: SingleChildScrollView(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Cardholder name'), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                TextFormField(controller: number, decoration: const InputDecoration(labelText: 'Card number'), keyboardType: TextInputType.number, validator: (v) => (v?.length == 16) ? null : '16 digits'),
                TextFormField(controller: expiry, decoration: const InputDecoration(labelText: 'MM/YY'), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                TextFormField(controller: cvc, decoration: const InputDecoration(labelText: 'CVC'), keyboardType: TextInputType.number, obscureText: true, validator: (v) => (v?.length == 3) ? null : '3 digits'),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await ctrl.saveCard(
                    forUid: forUid,
                    brand: 'Visa',
                    number16: number.text,
                    holder: name.text,
                    expiryMMYY: expiry.text,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
      child: const Text('Add card'),
    );
  }
}
