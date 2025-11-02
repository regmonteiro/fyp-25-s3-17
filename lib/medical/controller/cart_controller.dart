import 'package:flutter/foundation.dart';
import '../../services/cart_repository.dart';

class CartController extends ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];
  CartRepository? _repo;

  void attachRepository(CartRepository repo) {
    _repo = repo;
  }

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  int get count => _items.length;
  int get totalCount =>
      _items.fold<int>(0, (sum, it) => sum + ((it['quantity'] ?? 1) as int));
  double get subtotal => _items.fold<double>(
        0.0,
        (sum, it) =>
            sum +
            (_asDouble(it['price']) * ((it['quantity'] ?? 1) as int)),
      );

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^\d\.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
    }

  Future<void> loadFromFirestore() async {
    if (_repo == null) return;
    try {
      final list = await _repo!.fetchItems();
      _items
        ..clear()
        ..addAll(list.map((e) => {
              'id': e['id'],
              'name': e['name'],
              'price': _asDouble(e['price']),
              'imageUrl': (e['imageUrl'] ?? '').toString(),
              'quantity': (e['quantity'] ?? 1) as int,
            }));
    } catch (_) {
      // keep UI usable if permission denied / offline
    }
    notifyListeners();
  }

  Future<void> addOrIncrement(Map<String, dynamic> product) async {
    final id = product['id'].toString();
    final price = _asDouble(product['price']);
    final imageUrl = (product['imageUrl'] ?? '').toString();
    final idx = _items.indexWhere((e) => e['id'] == id);

    if (idx >= 0) {
      _items[idx]['quantity'] = ((_items[idx]['quantity'] ?? 1) as int) + 1;
    } else {
      _items.add({
        'id': id,
        'name': product['name'],
        'price': price,
        'imageUrl': imageUrl,
        'quantity': 1,
      });
    }
    notifyListeners();

    if (_repo != null) {
      await _repo!.upsertItem(
        productId: id,
        name: product['name'],
        price: price,
        imageUrl: imageUrl,
        deltaQty: 1,
      );
      // optional strict sync:
      // await loadFromFirestore();
    }
  }

  Future<void> decrement(String id) async {
    final idx = _items.indexWhere((e) => e['id'] == id);
    if (idx < 0) return;

    final q = ((_items[idx]['quantity'] ?? 1) as int) - 1;
    if (q <= 0) {
      _items.removeAt(idx);
      notifyListeners();
      if (_repo != null) await _repo!.removeItem(id);
    } else {
      _items[idx]['quantity'] = q;
      notifyListeners();
      if (_repo != null) {
        await _repo!.upsertItem(
          productId: id,
          name: _items[idx]['name'],
          price: _asDouble(_items[idx]['price']),
          imageUrl: (_items[idx]['imageUrl'] ?? '').toString(),
          deltaQty: -1,
        );
      }
    }
    // optional strict sync:
    // if (_repo != null) await loadFromFirestore();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    final id = _items[index]['id'].toString();
    _items.removeAt(index);
    notifyListeners();
    if (_repo != null) await _repo!.removeItem(id);
    // optional: await loadFromFirestore();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    if (_repo != null) await _repo!.clear(); // alias to clearCart()
  }
}
