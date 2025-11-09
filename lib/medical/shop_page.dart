import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'medical_products_entity.dart';
import 'controller/medical_products_controller.dart';
import '../services/cart_services.dart';
import 'cart_page.dart';

// -------- helpers (email key) --------
String emailKeyFrom(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain'; // e.g. user@gmail_com
}

// -------- local helpers used in this file --------
double parsePrice(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  final s = v.toString();
  final cleaned = s.replaceAll(RegExp(r'[^\d\.]'), '');
  return double.tryParse(cleaned) ?? 0.0;
}

ImageProvider getImageProvider(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.isEmpty) {
    return const AssetImage('assets/placeholder.png');
  }
  if (pathOrUrl.startsWith('http')) return NetworkImage(pathOrUrl);
  if (pathOrUrl.startsWith('data:')) {
    final base64Data = pathOrUrl.split(',').last;
    return MemoryImage(base64Decode(base64Data));
  }
  // fallback to bundled asset
  return AssetImage('assets/medicineandproductimages/$pathOrUrl');
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final _auth = FirebaseAuth.instance;
  late final MedicalProductsController _controller;

  late String _email;
  late CartServiceFs _cartSvc;

  List<MedicalProductsEntity> _products = [];
  String _activeCategory = 'all';
  bool _loading = true;
  String? _error;
  int _cartCount = 0;
  final Map<String, String> _messages = {};

  final _categories = const [
    {'key': 'all', 'label': 'Shop All'},
    {'key': 'mobility-safety', 'label': 'Mobility and Safety'},
    {'key': 'health-and-wellness', 'label': 'Health and Wellness'},
    {'key': 'pain-relief', 'label': 'Pain Relief'},
    {'key': 'personal-care', 'label': 'Personal Care'},
    {'key': 'monitoring-and-essentials', 'label': 'Monitoring and Essentials'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = MedicalProductsController();
    final user = _auth.currentUser;
    _email = (user?.email ?? '').trim().toLowerCase();
    _cartSvc = CartServiceFs(email: _email, db: FirebaseFirestore.instance);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
  try {
    setState(() { _loading = true; _error = null; });

    final res = await _controller.getAllProducts(); // returns Result<List<MedicalProductsEntity>>

    if (!res.success) {
      setState(() {
        _error = res.error ?? 'Failed to load products.';
        _loading = false;
      });
      return;
    }

    await _loadCartCount();

    setState(() {
      _products = res.data ?? <MedicalProductsEntity>[];
      _loading = false;
    });
  } catch (e) {
    setState(() { _error = 'Failed to load products.'; _loading = false; });
  }
}


  Future<void> _loadCartCount() async {
    try {
      final items = await _cartSvc.getCart();
      final total =
          items.fold<int>(0, (s, it) => s + ((it['quantity'] ?? 0) as int));
      setState(() => _cartCount = total);
    } catch (_) {
      // optional fallback
    }
  }

  Future<void> _addToCart(MedicalProductsEntity p) async {
    await _cartSvc.ensureCartDoc();
    final id = MedicalProductsEntity.generateProductId(p);
    final price = parsePrice(p.price);
    try {
      await _cartSvc.upsertItem(
        productId: id,
        name: p.title,
        price: price,
        imageUrl: p.img ?? '',
        deltaQty: 1,
        productData: {
          'category': p.category,
          'description': p.description,
          'oldPrice': p.oldPrice,
          'img': p.img,
          'id': p.id,
          'title': p.title,
          'price': p.price,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _loadCartCount();
      setState(() => _messages[p.id] = 'Product is added to cart.');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _messages.remove(p.id));
      });
    } catch (e) {
      setState(() => _messages[p.id] = 'Failed to add to cart.');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _messages.remove(p.id));
      });
    }
  }

  List<MedicalProductsEntity> get _filtered {
    if (_activeCategory == 'all') return _products;
    return _products.where((p) => p.category == _activeCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$');

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AllCare Shop')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _bootstrap, child: const Text('Try Again')),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AllCare Shop'),
        actions: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartPage()),);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('🛒'),
                const SizedBox(width: 6),
                CircleAvatar(radius: 12, child: Text('$_cartCount')),
              ]),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = _activeCategory == c['key'];
                return ChoiceChip(
                  label: Text(c['label']!),
                  selected: sel,
                  onSelected: (_) =>
                      setState(() => _activeCategory = c['key']!),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final p = _filtered[i];
                final price = parsePrice(p.price);
                final oldPrice = parsePrice(p.oldPrice);
                final hasOld = oldPrice > price && oldPrice > 0;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(blurRadius: 6, color: Color(0x14000000))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Discount badge removed to avoid NoSuchMethodError on p.discount
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image(
                            image: getImageProvider(p.img),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                'Image not available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Text(
                          p.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: 12),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: Row(children: [
                          Text(
                            money.format(price),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          if (hasOld)
                            Text(
                              money.format(oldPrice),
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                        ]),
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.fromLTRB(12, 2, 12, 0),
                        child: Text('🚚 Same day delivery',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _addToCart(p),
                            child: const Text('Add to Cart'),
                          ),
                        ),
                      ),
                      if (_messages[p.id] != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              12, 0, 12, 10),
                          child: Text(
                            _messages[p.id]!,
                            style:
                                const TextStyle(color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
