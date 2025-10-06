import 'package:flutter/foundation.dart';

class CartController extends ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  int get count => _items.length;

  double get subtotal => _items.fold<double>(
        0.0,
        (sum, it) => sum + ((it['price'] as num?)?.toDouble() ?? 0.0),
      );

  void add(Map<String, dynamic> product) {
    _items.add({
      'id': product['id'],
      'name': product['name'],
      'price': (product['price'] as num).toDouble(),
      'imageUrl': product['imageUrl'],
    });
    notifyListeners();
  }

  void removeAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

