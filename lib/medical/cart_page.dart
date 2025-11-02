import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../services/cart_repository.dart';
import '../financial/payment_confirmation_page.dart';

class CartPage extends StatefulWidget {
  final UserProfile userProfile;
  const CartPage({super.key, required this.userProfile});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final CartRepository _repo;
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _repo = CartRepository();
    // Migrate possible legacy UID cart once, then load
    migrateUidCartToEmailCart().then((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final list = await _repo.fetchItems();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Failed to load cart: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// One-time migration of old UID path -> email-keyed path
  Future<void> migrateUidCartToEmailCart() async {
    final fs = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final emailLower = user.email!.toLowerCase();
    final emailDocId = emailLower.replaceAll('.', '_'); // match your existing pattern

    // OLD: MedicalProducts/carts/users/{uid}
    final oldDoc = fs
        .collection('MedicalProducts')
        .doc('carts')
        .collection('users')
        .doc(user.uid);

    // NEW (your live schema from logs): MedicalProducts/carts/carts/{email_doc_id}
    final newDoc = fs
        .collection('MedicalProducts')
        .doc('carts')
        .collection('carts')
        .doc(emailDocId);

    try {
      final oldSnap = await oldDoc.get(const GetOptions(source: Source.server));
      if (!oldSnap.exists) return;

      final data = oldSnap.data() ?? {};
      await newDoc.set({
        'ownerEmail': emailLower,
        'items': data['items'] ?? [],
        'lastUpdated': FieldValue.serverTimestamp(),
        'migratedFromUid': user.uid,
      }, SetOptions(merge: true));

      // Optional: clean up old doc
      // await oldDoc.delete();
    } catch (_) {
      // ignore migration errors; cart will still load from new path if present
    }
  }

  double _total() {
    return _items.fold<double>(0.0, (s, it) {
      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final q = (it['quantity'] as int?) ?? 0;
      return s + price * q;
    });
  }

  Future<void> _inc(String id) async {
    final it = _items.firstWhere((e) => e['id'] == id, orElse: () => {});
    if (it.isEmpty) return;
    await _repo.upsertItem(
      productId: id,
      name: (it['name'] ?? '').toString(),
      price: ((it['price'] as num?) ?? 0).toDouble(),
      imageUrl: (it['imageUrl'] ?? '').toString(),
      deltaQty: 1,
    );
    await _load();
  }

  Future<void> _dec(String id) async {
    final it = _items.firstWhere((e) => e['id'] == id, orElse: () => {});
    if (it.isEmpty) return;
    await _repo.upsertItem(
      productId: id,
      name: (it['name'] ?? '').toString(),
      price: ((it['price'] as num?) ?? 0).toDouble(),
      imageUrl: (it['imageUrl'] ?? '').toString(),
      deltaQty: -1,
    );
    await _load();
  }

  Future<void> _remove(String id) async {
    await _repo.removeItem(id);
    await _load();
  }

  void _checkout() {
    if (_items.isEmpty) return;

    // Flatten items to PaymentConfirmationPage format
    final flat = <Map<String, dynamic>>[];
    for (final it in _items) {
      final price = ((it['price'] as num?) ?? 0).toDouble();
      final qty = (it['quantity'] as int?) ?? 0;
      for (int i = 0; i < qty; i++) {
        flat.add({
          'id': it['id'],
          'name': it['name'],
          'price': price,
        });
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationPage(
          totalAmount: _total(),
          cartItems: flat,
          userProfile: widget.userProfile,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: Center(child: Text(_err!)),
      );
    }

    final f = NumberFormat.currency(symbol: 'S\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: _items.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final it = _items[i];
                final price = ((it['price'] as num?) ?? 0).toDouble();
                final qty = (it['quantity'] as int?) ?? 0;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x14000000))],
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: (it['imageUrl']?.toString().startsWith('http') ?? false)
                          ? Image.network(it['imageUrl'], width: 56, height: 56, fit: BoxFit.cover)
                          : const Icon(Icons.medication_outlined, size: 36),
                    ),
                    title: Text(it['name'] ?? ''),
                    subtitle: Text('${f.format(price)}  •  Qty $qty'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(onPressed: () => _dec(it['id']), icon: const Icon(Icons.remove_circle_outline)),
                        IconButton(onPressed: () => _inc(it['id']), icon: const Icon(Icons.add_circle_outline)),
                        IconButton(onPressed: () => _remove(it['id']), icon: const Icon(Icons.delete_outline)),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -5)),
          ]),
          child: Row(
            children: [
              Expanded(
                child: Text('Total: ${f.format(_total())}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                onPressed: _items.isEmpty ? null : _checkout,
                style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
                child: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
