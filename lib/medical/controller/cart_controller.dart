import 'package:flutter/foundation.dart';
import '../../services/cart_services.dart';

class CartController extends ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];
  CartServiceFs? _svc;

  void attachService(CartServiceFs svc) {
    _svc = svc;
  }

  set service(CartServiceFs svc) {
  _svc = svc;
}

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  int get count => _items.length;

  int get totalCount =>
      _items.fold<int>(0, (sum, it) => sum + ((it['quantity'] ?? 1) as int));

  double get subtotal => _items.fold<double>(
        0.0,
        (sum, it) => sum + (_asDouble(it['price']) * ((it['quantity'] ?? 1) as int)),
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
    if (_svc == null) return;
    try {
      final list = await _svc!.getCart();
      _items
        ..clear()
        ..addAll(list.map((e) => {
              'id': e['id'],
              'name': e['name'],
              'price': _asDouble(e['price']),
              'image': (e['image'] ?? '').toString(),
              'quantity': (e['quantity'] ?? 1) as int,
              if (e['productData'] != null) 'productData': e['productData'],
            }));
    } catch (_) {
    }
    notifyListeners();
  }

  Future<void> addOrIncrement(Map<String, dynamic> product,
      {Map<String, dynamic>? productData}) async {
    final id = product['id'].toString();
    final price = _asDouble(product['price']);
    final imageUrl = (product['imageUrl'] ?? product['image'] ?? '').toString();
    final idx = _items.indexWhere((e) => e['id'] == id);

    if (idx >= 0) {
      _items[idx]['quantity'] = ((_items[idx]['quantity'] ?? 1) as int) + 1;
    } else {
      _items.add({
        'id': id,
        'name': product['name'],
        'price': price,
        'image': imageUrl,
        'quantity': 1,
        if (productData != null) 'productData': productData,
      });
    }
    notifyListeners();

    if (_svc != null) {
      await _svc!.upsertItem(
        productId: id,
        name: product['name'],
        price: price,
        imageUrl: imageUrl,
        deltaQty: 1,
        productData: productData,
      );
    }
  }

  Future<void> decrement(String id) async {
    final idx = _items.indexWhere((e) => e['id'] == id);
    if (idx < 0) return;

    final q = ((_items[idx]['quantity'] ?? 1) as int) - 1;
    if (q <= 0) {
      _items.removeAt(idx);
      notifyListeners();
      if (_svc != null) await _svc!.removeItem(id);
    } else {
      _items[idx]['quantity'] = q;
      notifyListeners();
      if (_svc != null) {
        await _svc!.upsertItem(
          productId: id,
          name: _items[idx]['name'],
          price: _asDouble(_items[idx]['price']),
          imageUrl: (_items[idx]['image'] ?? '').toString(),
          deltaQty: -1,
        );
      }
    }
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    final id = _items[index]['id'].toString();
    _items.removeAt(index);
    notifyListeners();
    if (_svc != null) await _svc!.removeItem(id);
  }


  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    if (_svc != null) await _svc!.clearCart();
  }
}
