import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'payment_methods_controller.dart';

class PaymentMethodsPage extends StatefulWidget {
  final String currentUserUid;  // who’s using the app
  final String targetElderUid;  // which elderly wallet to top up
  final String? caregiverUid;   // optional caregiver payer

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
  /// 'card-user:<cardId>' | 'card-caregiver:<cardId>' | 'paynow' | 'applepay' | 'googlepay'
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

        // make caregiver stream NON-null here (even if controller exposes nullable)
        final Stream<List<SavedCard>> caregiverStream =
            widget.caregiverUid == null
                ? const Stream<List<SavedCard>>.empty()
                : ctrl.caregiverCards ?? const Stream<List<SavedCard>>.empty();

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(title: const Text('Payment method')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Current user cards ─────────────────────────────────────────
                _SectionHeader(
                  title: 'Credit/Debit card',
                  trailing: _AddCardButton(forUid: widget.currentUserUid),
                ),
                StreamBuilder<List<SavedCard>>(
                  stream: ctrl.myCards,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final cards = snap.data ?? const <SavedCard>[];
                    if (cards.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No card saved. Tap "Add card" to link one.',
                          style: TextStyle(color: Colors.black54),
                        ),
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

                // ── Caregiver cards (optional) ────────────────────────────────
                if (widget.caregiverUid != null) ...[
                  _SectionHeader(
                    title: "Caregiver’s card",
                    trailing: _AddCardButton(forUid: widget.caregiverUid!),
                  ),
                  StreamBuilder<List<SavedCard>>(
                    stream: caregiverStream, // NEVER null
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final cards = snap.data ?? const <SavedCard>[];
                      if (cards.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No caregiver card saved yet.',
                            style: TextStyle(color: Colors.black54),
                          ),
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

                // ── PayNow / Apple Pay / Google Pay ──────────────────────────
                RadioListTile<String>(
                  value: 'paynow',
                  groupValue: _selected,
                  onChanged: (v) => setState(() => _selected = v),
                  title: Row(
                    children: [
                      Image.asset(
                        'assets/paynow.png',
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2),
                      ),
                      const SizedBox(width: 12),
                      const Text('PayNow'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
              ],
            ),
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
        final localFormKey = GlobalKey<FormState>();
        final name   = TextEditingController();
        final number = TextEditingController();
        final expiry = TextEditingController();
        final cvc    = TextEditingController();

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: AlertDialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                title: const Text('Add card'),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
                  child: SingleChildScrollView(
                    child: Form(
                      key: localFormKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Cardholder name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: number,
                            decoration: const InputDecoration(
                              labelText: 'Card number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final s = (v ?? '').replaceAll(' ', '');
                              return s.length == 16 ? null : '16 digits';
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: expiry,
                                  decoration: const InputDecoration(
                                    labelText: 'MM/YY',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: cvc,
                                  decoration: const InputDecoration(
                                    labelText: 'CVC',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  obscureText: true,
                                  validator: (v) => (v != null && v.length == 3) ? null : '3 digits',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      if (!localFormKey.currentState!.validate()) return;
                      await ctrl.saveCard(
                        forUid: forUid,
                        brand: 'Visa',
                        number16: number.text,
                        holder: name.text,
                        expiryMMYY: expiry.text,
                      );
                      if (context.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );

        name.dispose();
        number.dispose();
        expiry.dispose();
        cvc.dispose();
      },
      child: const Text('Add card'),
    );
  }
}
