import 'package:flutter/foundation.dart';
import '../../services/cart_repository.dart';

class CartController extends ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];
  CartRepository? _repo;

  /// Optionally attach a repository (Firestore)
  void attachRepository(CartRepository repo) {
    _repo = repo;
  }

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  /// Number of distinct line items
  int get count => _items.length;

  /// Total units across all items
  int get totalCount =>
      _items.fold<int>(0, (sum, it) => sum + ((it['quantity'] ?? 1) as int));

  /// Sum of price * quantity
  double get subtotal => _items.fold<double>(
        0.0,
        (sum, it) =>
            sum +
            (((it['price'] as num?)?.toDouble() ?? 0.0) *
                ((it['quantity'] ?? 1) as int)),
      );

  /// Load from Firestore (if attached), else do nothing
  Future<void> loadFromFirestore() async {
    if (_repo == null) return;
    final list = await _repo!.fetchItems();
    _items
      ..clear()
      ..addAll(list.map((e) => {
            'id': e['id'],
            'name': e['name'],
            'price': (e['price'] as num?)?.toDouble() ?? 0.0,
            'imageUrl': (e['imageUrl'] ?? '').toString(),
            'quantity': (e['quantity'] ?? 1) as int,
          }));
    notifyListeners();
  }

  /// Add or increment by 1
  Future<void> addOrIncrement(Map<String, dynamic> product) async {
    final id = product['id'].toString();
    final price = (product['price'] as num).toDouble();
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
    }
  }

  /// Decrement by 1; remove if quantity hits 0
  Future<void> decrement(String id) async {
    final idx = _items.indexWhere((e) => e['id'] == id);
    if (idx < 0) return;
    final q = ((_items[idx]['quantity'] ?? 1) as int) - 1;
    if (q <= 0) {
      _items.removeAt(idx);
      if (_repo != null) await _repo!.removeItem(id);
    } else {
      _items[idx]['quantity'] = q;
      if (_repo != null) {
        await _repo!.upsertItem(
          productId: id,
          name: _items[idx]['name'],
          price: (_items[idx]['price'] as num).toDouble(),
          imageUrl: (_items[idx]['imageUrl'] ?? '').toString(),
          deltaQty: -1,
        );
      }
    }
    notifyListeners();
  }

  /// Remove the whole line (no matter the quantity)
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    final id = _items[index]['id'].toString();
    _items.removeAt(index);
    notifyListeners();
    if (_repo != null) await _repo!.removeItem(id);
  }

  /// Clear all items
  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    if (_repo != null) await _repo!.clear();
  }
}
