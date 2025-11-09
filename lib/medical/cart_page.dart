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

  late final String _email;
  late final CartServiceFs _cartSvc;
  late final PaymentMethodsServiceFs _pmSvc;
  late final OrderServiceFs _orderSvc;
  late final AddressServiceFs _addrSvc;
  late final WalletServicePs _walletSvc;

  bool _loading = true;
  String? _err;

  List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _orders = [];
  double _walletBalance = 0.0;

  String? _selectedAddressId;
  String? _selectedCardId;
  String? _payment; // 'wallet' | 'paynow' | 'card'

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _email = (user?.email ?? '').trim().toLowerCase();

    final db = FirebaseFirestore.instance;
    _cartSvc  = CartServiceFs(email: _email, db: db);
    _pmSvc    = PaymentMethodsServiceFs(email: _email, db: db);
    _orderSvc = OrderServiceFs(email: _email, db: db);
    _addrSvc  = AddressServiceFs(db: db);
    _walletSvc = WalletServicePs(email: _email);

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      setState(() { _loading = true; _err = null; });

      // 1) Guarantee cart doc exists before any reads
      await _cartSvc.ensureCartDoc();

      // 2) Load data
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
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _loading = false; });
    }
  }

  double _total() {
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

  Future<void> _removeOne(String productId) async {
    // update local list instantly for snappy UI
    final idx = _cart.indexWhere((e) => e['id'] == productId);
    if (idx < 0) return;

    final q = (_cart[idx]['quantity'] ?? 1) as int;
    if (q <= 1) {
      _cart.removeAt(idx);
    } else {
      _cart[idx] = {..._cart[idx], 'quantity': q - 1};
    }
    setState(() {});

    // persist to Firestore via service
    await _cartSvc.removeItem(productId);
  }

  bool _canPay() {
    if (_cart.isEmpty) return false;
    if (_selectedAddressId == null) return false;
    if (_payment == null) return false;
    if (_payment == 'card' && _selectedCardId == null) return false;
    if (_payment == 'wallet') return _walletBalance >= _total();
    return true;
  }

  Future<void> _completePayment() async {
    if (!_canPay()) return;

    try {
      final amt = _total();

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

      Map<String, dynamic> payment;
      if (_payment == 'wallet') {
        final ok = await _walletSvc.makePayment(
          amt,
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
        setState(() => _walletBalance -= amt);
        payment = {'method': 'wallet', 'amount': amt, 'status': 'Confirmed'};
      } else if (_payment == 'paynow') {
        payment = {'method': 'paynow', 'amount': amt, 'status': 'Confirmed'};
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
          'amount': amt,
          'status': 'Confirmed',
        };
      }

      // Create final order doc at /MedicalProducts/orders/orders/{autoId}
      await _orderSvc.createOrder(
        items: _cart,
        totalAmount: amt,
        deliveryAddress: addr,
        paymentMethod: payment,
      );

      // Clear the user's cart doc
      await _cartSvc.clearCart();

      if (!mounted) return;
      setState(() => _cart = []);
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

  Future<void> _showOrders() async {
    final orders = await _orderSvc.getUserOrders();
    if (!mounted) return;
    setState(() => _orders = orders);

    final f = NumberFormat.currency(symbol: 'S\$');
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _orders.isEmpty
              ? const Text('No orders yet.')
              : ListView.separated(
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final o = _orders[i];
                    final id = (o['id'] as String?) ?? 'N/A';
                    return ListTile(
                      title: Text('Order #${id.length > 8 ? id.substring(id.length - 8) : id}'),
                      subtitle: Text('${o['status']} • ${o['createdAt']}'),
                      trailing: Text(f.format((o['totalAmount'] ?? 0).toDouble())),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _openCheckout() {
    final f = NumberFormat.currency(symbol: 'S\$');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Total: ${f.format(_total())}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Wallet: ${f.format(_walletBalance)}'),
                  const Divider(height: 24),

                  const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_addresses.isEmpty)
                    const Text('No saved addresses. Add one in Profile > Addresses.')
                  else
                    Column(
                      children: _addresses.map((a) {
                        final sel = _selectedAddressId == a['id'];
                        return ListTile(
                          dense: true,
                          onTap: () => setSheet(() => _selectedAddressId = a['id']),
                          leading: Radio<String>(
                            value: a['id'],
                            groupValue: _selectedAddressId,
                            onChanged: (v) => setSheet(() => _selectedAddressId = v),
                          ),
                          title: Text(a['name'] ?? ''),
                          subtitle: Text(
                            '${a['recipientName']}\n'
                            '${a['blockStreet']}\n'
                            '${a['unitNumber']}, Singapore ${a['postalCode']}',
                          ),
                          trailing: sel ? const Icon(Icons.check_circle, color: Colors.green) : null,
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
                    title: const Text('PayNow'),
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Card'),
                      onPressed: () async {
                        final numberCtrl = TextEditingController();
                        final holderCtrl = TextEditingController();
                        final expiryCtrl = TextEditingController();
                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Add Card'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(controller: numberCtrl, decoration: const InputDecoration(labelText: 'Card Number')),
                                TextField(controller: holderCtrl, decoration: const InputDecoration(labelText: 'Cardholder Name')),
                                TextField(controller: expiryCtrl, decoration: const InputDecoration(labelText: 'Expiry (MM/YY)')),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () async {
                                  final saved = await _pmSvc.saveCard({
                                    'cardHolder': holderCtrl.text.trim(),
                                    'fullNumber': numberCtrl.text.trim(),
                                    'expiryDate': expiryCtrl.text.trim(),
                                  });
                                  setState(() {
                                    _cards.add(saved);
                                    _selectedCardId = saved['id'] as String;
                                  });
                                  if (mounted) Navigator.pop(context);
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                      },
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
              child: Text(
                'Total: ${f.format(_total())}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
