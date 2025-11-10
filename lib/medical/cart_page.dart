import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cart_services.dart';
import '../financial/wallet_service_ps.dart';
import '../services/address_service_fs.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _auth = FirebaseAuth.instance;

  late String _email;
  late CartServiceFs _cartSvc;
  late PaymentMethodsServiceFs _pmSvc;
  late OrderServiceFs _orderSvc;
  late AddressServiceFs _addrSvc;
  late WalletServicePs _walletSvc;

  bool _loading = true;
  String? _err;

  // data
  List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _orders = [];
  double _walletBalance = 0.0;

  // selection
  String? _selectedAddressId;
  String? _selectedCardId;
  String? _payment; // 'wallet' | 'paynow' | 'card'

  // checkout extras
  String _voucherCode = '';
  double _voucherDiscount = 0.0;
  double _deliveryFee = 0.0;

  // delivery fee rules
  static const double _deliveryFlat = 3.50;
  static const double _freeDeliveryThreshold = 50.00;

  @override
  void initState() {
    super.initState();

    final user = _auth.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();
    if (user == null || email.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in with an email to use the cart.')),
        );
        Navigator.of(context).pop();
      });
      return;
    }

    _initWithFreshToken();
  }

  Future<void> _initWithFreshToken() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      _email = (_auth.currentUser!.email ?? '').trim().toLowerCase();
      final db = FirebaseFirestore.instance;

      _cartSvc   = CartServiceFs(email: _email, db: db);
      _pmSvc     = PaymentMethodsServiceFs(email: _email, db: db);
      _orderSvc  = OrderServiceFs(email: _email, db: db);
      _addrSvc   = AddressServiceFs(db: db);
      _walletSvc = WalletServicePs(email: _email);

      await _bootstrap();
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Auth refresh failed: $e');
    }
  }

  Future<void> _bootstrap() async {
    try {
      if (mounted) setState(() { _loading = true; _err = null; });

      await _cartSvc.ensureCartDoc();

      final cart  = await _cartSvc.getCart();
      final cards = await _pmSvc.getSavedCards();

      await _walletSvc.initialize();
      final bal   = await _walletSvc.getWalletBalance();

      final addrs = await _addrSvc.getAddresses();
      String? defaultAddrId;
      if (addrs.isNotEmpty) {
        final def = addrs.firstWhere(
          (a) => a['isDefault'] == true,
          orElse: () => addrs.first,
        );
        defaultAddrId = def['id'] as String?;
      }

      if (!mounted) return;
      setState(() {
        _cart = cart;
        _cards = cards;
        _addresses = addrs;
        _selectedAddressId = defaultAddrId;
        _walletBalance = bal;
        _loading = false;
      });

      _recalcFees(); // compute delivery fee (and keep voucher if any)
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _loading = false; });
    }
  }

  // ---------- Money math ----------
  double _subtotal() {
    return _cart.fold<double>(
      0.0,
      (sum, it) {
        final price = (it['price'] is num)
            ? (it['price'] as num).toDouble()
            : double.tryParse('${it['price']}') ?? 0.0;
        final qty = (it['quantity'] ?? 1) as int;
        return sum + price * qty;
      },
    );
  }

  void _recalcFees() {
    // delivery fee:
    final sub = _subtotal();
    _deliveryFee = (sub >= _freeDeliveryThreshold) ? 0.0 : _deliveryFlat;

    // re-validate voucher discount to avoid negative totals
    _voucherDiscount = _clampVoucherDiscount(_voucherCode, sub, _deliveryFee, _voucherDiscount);
    setState(() {}); // refresh UI
  }

  double _grandTotal() {
    final g = _subtotal() + _deliveryFee - _voucherDiscount;
    return g < 0 ? 0 : g;
  }

  String _fmt(double v) => NumberFormat.currency(symbol: 'S\$').format(v);

  // ---------- Cart actions ----------
  Future<void> _removeOne(String productId) async {
    final idx = _cart.indexWhere((e) => e['id'] == productId);
    if (idx < 0) return;

    final q = (_cart[idx]['quantity'] ?? 1) as int;
    if (q <= 1) {
      _cart.removeAt(idx);
    } else {
      _cart[idx] = {..._cart[idx], 'quantity': q - 1};
    }
    if (mounted) setState(() {});
    _recalcFees();

    await _cartSvc.removeItem(productId);
  }

  // ---------- Voucher logic ----------
  double _clampVoucherDiscount(String code, double subtotal, double delivery, double requested) {
    // supported:
    //  - WELCOME5  => S$5 off
    //  - FREEDEL   => sets delivery fee to 0 (handled by applyVoucher)
    // cap: cannot result in negative payable
    final maxDiscount = subtotal + delivery;
    return requested.clamp(0.0, maxDiscount);
  }

  void _applyVoucher(String raw) {
    final code = raw.trim().toUpperCase();
    double discount = 0.0;

    // evaluate code
    if (code == 'WELCOME5') {
      discount = 5.0;
      // delivery normal
      final sub = _subtotal();
      _deliveryFee = (sub >= _freeDeliveryThreshold) ? 0.0 : _deliveryFlat;
    } else if (code == 'FREEDEL') {
      _deliveryFee = 0.0;
      discount = 0.0;
    } else if (code.isEmpty) {
      // reset
      final sub = _subtotal();
      _deliveryFee = (sub >= _freeDeliveryThreshold) ? 0.0 : _deliveryFlat;
      discount = 0.0;
    } else {
      // unknown
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid voucher code')),
      );
      return;
    }

    _voucherCode = code;
    _voucherDiscount = _clampVoucherDiscount(code, _subtotal(), _deliveryFee, discount);
    setState(() {});
  }

  // ---------- Pay gating ----------
  bool _canPay() {
    if (_cart.isEmpty) return false;
    if (_selectedAddressId == null) return false;
    if (_payment == null) return false;
    if (_payment == 'card' && _selectedCardId == null) return false;
    if (_payment == 'wallet') return _walletBalance >= _grandTotal();
    return true;
  }

  // ---------- PayNow Mock Flow ----------
  Future<bool> _payNowFlow(double amount) async {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('PayNow — Scan & Pay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Amount: ${_fmt(amount)}'),
            const SizedBox(height: 12),
            // Mock QR panel
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.qr_code_2, size: 120),
                  SizedBox(height: 6),
                  Text('Mock QR'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Use any banking app to “simulate” payment.\nThis is a demo flow and does not charge real money.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('I’ve paid'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ) ?? false;
  }

  // ---------- Complete payment ----------
  Future<void> _completePayment() async {
    if (!_canPay()) return;

    try {
      final addr = _addresses.firstWhere(
        (a) => a['id'] == _selectedAddressId,
        orElse: () => <String, dynamic>{},
      );
      if (addr.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a delivery address')),
        );
        return;
      }

      final subtotal = _subtotal();
      final delivery = _deliveryFee;
      final discount = _voucherDiscount;
      final total = _grandTotal();

      Map<String, dynamic> payment;

      if (_payment == 'wallet') {
        final ok = await _walletSvc.makePayment(
          total,
          'AllCare Shop Purchase',
          paymentMethod: 'wallet',
        );
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wallet payment failed')),
          );
          return;
        }
        setState(() => _walletBalance -= total);
        payment = {'method': 'wallet', 'amount': total, 'status': 'Confirmed'};
      } else if (_payment == 'paynow') {
        final ok = await _payNowFlow(total);
        if (!ok) return;
        payment = {'method': 'paynow', 'amount': total, 'status': 'Confirmed'};
      } else {
        final card = _cards.firstWhere(
          (c) => c['id'] == _selectedCardId,
          orElse: () => <String, dynamic>{},
        );
        if (card.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a card')),
          );
          return;
        }
        payment = {
          'method': 'card',
          'cardType': card['cardType'],
          'lastFour': card['lastFour'],
          'amount': total,
          'status': 'Confirmed',
        };
      }

      // Create final order doc at /MedicalProducts/orders/orders/{autoId}
      await _orderSvc.createOrder(
        items: _cart,
        totalAmount: total,
        deliveryAddress: addr,
        paymentMethod: payment,
      );

      await _cartSvc.clearCart();

      if (!mounted) return;
      setState(() {
        _cart = [];
        _voucherCode = '';
        _voucherDiscount = 0.0;
        _deliveryFee = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order confirmed!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  // ---------- Orders (with Reorder) ----------
  Future<void> _showOrders() async {
    final orders = await _orderSvc.getUserOrders();
    if (!mounted) return;
    setState(() => _orders = orders);

    final f = NumberFormat.currency(symbol: 'S\$');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _orders.isEmpty
              ? const Text('No orders yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final o = _orders[i];
                    final id = (o['id'] as String?) ?? 'N/A';
                    final short = id.length > 8 ? id.substring(id.length - 8) : id;
                    final createdAt = (o['createdAt'] ?? '').toString();
                    final items = (o['items'] ?? []) as List;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          title: Text('Order #$short'),
                          subtitle: Text('${o['status']} • $createdAt'),
                          trailing: Text(f.format((o['totalAmount'] ?? 0).toDouble())),
                        ),
                        // Reorder button
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.shopping_bag),
                            label: const Text('Reorder'),
                            onPressed: () async {
                              // Rehydrate cart with past items
                              final past = items.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
                              setState(() => _cart = past);
                              // Persist (try common method names)
                              try {
                                await _cartSvc.saveCart(past);
                              } catch (_) {
                                try { await _cartSvc.saveCart(past); } catch (_) {/* ignore */ }
                              }
                              _recalcFees();
                              if (mounted) Navigator.of(context).pop();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Cart updated with past order items.')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  // ---------- Checkout Sheet ----------
  void _openCheckout() {
    final f = NumberFormat.currency(symbol: 'S\$');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Checkout', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),

                  // Totals block
                  _totalsBlock(setSheet),

                  const Divider(height: 24),
                  const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_addresses.isEmpty)
                    const Text('No saved addresses. Add one in Profile > Addresses.')
                  else
                    Column(
                      children: _addresses.map((a) {
                        final sel = _selectedAddressId == a['id'];
                        return Card(
                          child: ListTile(
                            onTap: () => setSheet(() => _selectedAddressId = a['id']),
                            leading: Radio<String>(
                              value: a['id'],
                              groupValue: _selectedAddressId,
                              onChanged: (v) => setSheet(() => _selectedAddressId = v),
                            ),
                            title: Row(
                              children: [
                                Text(a['name'] ?? ''),
                                const SizedBox(width: 6),
                                if (a['isDefault'] == true)
                                  const Chip(label: Text('Default'), visualDensity: VisualDensity.compact),
                              ],
                            ),
                            subtitle: Text(
                              '${a['recipientName']}\n'
                              '${a['blockStreet']}\n'
                              '${a['unitNumber']}, Singapore ${a['postalCode']}',
                            ),
                            trailing: sel ? const Icon(Icons.check_circle, color: Colors.green) : null,
                          ),
                        );
                      }).toList(),
                    ),

                  const Divider(height: 24),
                  const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile<String>(
                    value: 'wallet',
                    groupValue: _payment,
                    onChanged: (v) => setSheet(() => _payment = v),
                    title: const Text('Wallet'),
                    subtitle: Text('Available: ${f.format(_walletBalance)}'),
                  ),
                  RadioListTile<String>(
                    value: 'paynow',
                    groupValue: _payment,
                    onChanged: (v) => setSheet(() => _payment = v),
                    title: const Text('PayNow (QR)'),
                  ),
                  RadioListTile<String>(
                    value: 'card',
                    groupValue: _payment,
                    onChanged: (v) => setSheet(() => _payment = v),
                    title: const Text('Bank Card'),
                  ),
                  if (_payment == 'card') ...[
                    const SizedBox(height: 8),
                    if (_cards.isEmpty)
                      const Text('No saved cards.')
                    else
                      Column(
                        children: _cards.map((c) {
                          return ListTile(
                            dense: true,
                            onTap: () => setSheet(() => _selectedCardId = c['id']),
                            leading: Radio<String>(
                              value: c['id'],
                              groupValue: _selectedCardId,
                              onChanged: (v) => setSheet(() => _selectedCardId = v),
                            ),
                            title: Text('${c['cardType']} •••• ${c['lastFour']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await _pmSvc.deleteCard(c['id']);
                                setSheet(() {
                                  _cards.removeWhere((x) => x['id'] == c['id']);
                                  if (_selectedCardId == c['id']) _selectedCardId = null;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                  ],

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _canPay()
                        ? () async {
                            Navigator.of(context).pop();
                            await _completePayment();
                          }
                        : null,
                    child: const Text('Complete Payment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalsBlock(void Function(void Function()) setSheet) {
    final sub = _subtotal();
    final total = _grandTotal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            children: [
              const Text('Subtotal'),
              const Spacer(),
              Text(_fmt(sub)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Delivery'),
              const Spacer(),
              Text(_deliveryFee == 0 ? 'Free' : _fmt(_deliveryFee)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Voucher'),
              const Spacer(),
              Text(_voucherDiscount == 0 ? '—' : '- ${_fmt(_voucherDiscount)}'),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              labelText: 'Voucher code',
              hintText: 'WELCOME5 / FREEDEL',
              suffixIcon: TextButton(
                onPressed: () => setSheet(() => _applyVoucher(_voucherCode)),
                child: const Text('Apply'),
              ),
            ),
            onChanged: (v) => setSheet(() => _voucherCode = v),
          ),
          const SizedBox(height: 10),
          const Divider(),
          Row(
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(_fmt(total), style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          if (_subtotal() >= _freeDeliveryThreshold)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('🎉 You’ve unlocked free delivery!', style: TextStyle(color: Colors.green)),
            ),
        ]),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(symbol: 'S\$');

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_err != null) {
      return Scaffold(body: Center(child: Text(_err!)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _showOrders),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _bootstrap),
        ],
      ),
      body: _cart.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cart.length,
              itemBuilder: (_, i) {
                final it = _cart[i];
                final price = (it['price'] is num)
                    ? (it['price'] as num).toDouble()
                    : double.tryParse('${it['price']}') ?? 0.0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: (it['image'] != null && '${it['image']}'.startsWith('http'))
                        ? Image.network('${it['image']}', width: 56, height: 56,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image))
                        : const Icon(Icons.shopping_bag),
                    title: Text('${it['name'] ?? ''}'),
                    subtitle: Text('${it['quantity']} × ${f.format(price)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeOne('${it['id']}'),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subtotal: ${_fmt(_subtotal())}'),
                  Text('Delivery: ${_deliveryFee == 0 ? 'Free' : _fmt(_deliveryFee)}'),
                  Text('Total: ${_fmt(_grandTotal())}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _cart.isEmpty ? null : _openCheckout,
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
