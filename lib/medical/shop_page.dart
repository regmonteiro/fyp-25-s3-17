import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controller/medical_products_controller.dart';   // ensure this path matches your project
import '../models/medical_products_entity.dart';           // ensure relative path
import '../services/cart_repository.dart';                 // Firestore repo (NOT CartService)

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final _controller = MedicalProductsController();
  late final CartRepository _cartRepo;

  List<MedicalProductsEntity> _products = [];
  String _activeCategory = 'all';
  bool _loading = true;
  String? _error;
  int _cartCount = 0;
  final Map<String, String> _messages = {};

  final _categories = const [
    {'key': 'all', 'label': 'Shop All'},
    {'key': 'personal-care', 'label': 'Personal Care'},
    {'key': 'mobility-safety', 'label': 'Mobility and Safety'},
    {'key': 'health-and-wellness', 'label': 'Health and Wellness'},
    {'key': 'pain-relief', 'label': 'Pain Relief'},
    {'key': 'monitoring-and-essentials', 'label': 'Monitoring and Essentials'},
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _error = 'Please sign in to view the shop.';
        _loading = false;
      });
      return;
    }
    _cartRepo = CartRepository(); // Firestore-backed
    await _loadCartCount();
    await _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _controller.getAllProducts();
      items.sort((a, b) => a.title.compareTo(b.title));
      setState(() => _products = items);
    } catch (_) {
      setState(() => _error = 'Failed to load products.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final items = await _cartRepo.fetchItems();
      final total = items.fold<int>(0, (s, it) => s + ((it['quantity'] ?? 0) as int));
      setState(() => _cartCount = total);
    } catch (_) {
      // local fallback
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('shoppingCart');
      if (raw != null) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
        final total = list.fold<int>(0, (s, it) => s + ((it['quantity'] ?? 0) as int));
        setState(() => _cartCount = total);
      }
    }
  }

  double _parsePrice(dynamic v) {
    if (v is num) return v.toDouble();
    final s = v?.toString() ?? '';
    final cleaned = s.replaceAll(RegExp(r'[^\d\.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  ImageProvider _imageProvider(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      return const AssetImage('assets/placeholder.png'); // add a tiny png in assets
    }
    if (pathOrUrl.startsWith('http')) return NetworkImage(pathOrUrl);
    if (pathOrUrl.startsWith('data:')) {
      final base64Data = pathOrUrl.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    }
    return AssetImage('assets/elderly/medicineandproductimages/$pathOrUrl');
  }

  Future<void> _addToCart(MedicalProductsEntity p) async {
    final id = MedicalProductsEntity.generateProductId(p);
    final price = _parsePrice(p.price);

    try {
      // Single upsert with deltaQty=1 (no FieldValue import needed here)
      await _cartRepo.upsertItem(
        productId: id,
        name: p.title,
        price: price,
        imageUrl: p.img ?? '',
        deltaQty: 1,
      );

      await _loadCartCount();
      setState(() { _messages[p.id] = 'Product is added to cart.'; });
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _messages.remove(p.id));
      });
    } catch (_) {
      // local fallback
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('shoppingCart');
      final list = raw != null ? List<Map<String, dynamic>>.from(jsonDecode(raw)) : <Map<String, dynamic>>[];
      final idx = list.indexWhere((e) => e['id'] == id);

      if (idx >= 0) {
        list[idx]['quantity'] = (list[idx]['quantity'] ?? 0) + 1;
      } else {
        list.add({
          'id': id,
          'name': p.title,
          'price': price,
          'imageUrl': p.img ?? '',   // <- standardize on imageUrl
          'quantity': 1,
          'productData': {
            'category': p.category,
            'description': p.description,
            'oldPrice': p.oldPrice,
            'discount': p.discount,
            'img': p.img,
          },
        });
      }
      await sp.setString('shoppingCart', jsonEncode(list));
      await _loadCartCount();
      setState(() { _messages[p.id] = 'Product is added to cart.'; });
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AllCare Shop')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchProducts, child: const Text('Try Again')),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AllCare Shop'),
        actions: [
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/elderly/cart'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('🛒'), const SizedBox(width: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = _activeCategory == c['key'];
                return ChoiceChip(
                  label: Text(c['label']!),
                  selected: sel,
                  onSelected: (_) => setState(() => _activeCategory = c['key']!),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.66,
              ),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final p = _filtered[i];
                final price = _parsePrice(p.price);
                final oldPrice = _parsePrice(p.oldPrice);
                final hasOld = oldPrice > price && oldPrice > 0;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x14000000))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (p.discount != null && p.discount!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                        child: Text(p.discount!, style: const TextStyle(color: Colors.white)),
                      ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image(
                          image: _imageProvider(p.img),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text('Image not available', style: TextStyle(color: Colors.grey[600])),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: Row(children: [
                        Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        if (hasOld) Text('\$${oldPrice.toStringAsFixed(2)}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                      ]),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 2, 12, 0),
                      child: Text('🚚 Same day delivery', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(onPressed: () => _addToCart(p), child: const Text('Add to Cart')),
                      ),
                    ),
                    if (_messages[p.id] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Text(_messages[p.id]!, style: const TextStyle(color: Colors.green)),
                      ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
