import 'package:cloud_firestore/cloud_firestore.dart';

class CartRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String targetUid; // elderly UID or current user's UID

  CartRepository({required this.targetUid});

  // -------- Paths --------
  DocumentReference<Map<String, dynamic>> get _cartDoc =>
      _db.collection('MedicalProducts')
         .doc('carts')
         .collection(targetUid)
         .doc('items'); // single doc that holds { items: [...] }

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _db.collection('MedicalProducts')
         .doc('orders')
         .collection('orders'); // /MedicalProducts/orders/orders/{orderId}

  // -------- Fetch items --------
  Future<List<Map<String, dynamic>>> fetchItems() async {
    final snap = await _cartDoc.get();
    if (!snap.exists) return [];
    final items = (snap.data()?['items'] as List?) ?? [];
    return List<Map<String, dynamic>>.from(items);
  }

  // -------- Add / update an item --------
  Future<void> upsertItem({
    required String productId,
    required String name,
    required double price,
    required String imageUrl,
    required int deltaQty,
    Map<String, dynamic>? productData,
  }) async {
    await _db.runTransaction((txn) async {
      final snap = await txn.get(_cartDoc);
      final data = snap.data() ?? {};
      final items = List<Map<String, dynamic>>.from((data['items'] ?? []));

      final idx = items.indexWhere((e) => e['id'] == productId);
      if (idx >= 0) {
        final q = (items[idx]['quantity'] ?? 0) + deltaQty;
        if (q <= 0) {
          items.removeAt(idx);
        } else {
          items[idx]['quantity'] = q;
        }
      } else if (deltaQty > 0) {
        items.add({
          'id': productId,
          'name': name,
          'price': price,
          'imageUrl': imageUrl,
          'quantity': deltaQty,
          if (productData != null) 'productData': productData,
        });
      }

      txn.set(_cartDoc, {'items': items}, SetOptions(merge: true));
    });
  }

  // -------- Remove one item --------
  Future<void> removeItem(String productId) async {
    await _db.runTransaction((txn) async {
      final snap = await txn.get(_cartDoc);
      final data = snap.data() ?? {};
      final items = List<Map<String, dynamic>>.from((data['items'] ?? []));
      items.removeWhere((e) => e['id'] == productId);
      txn.set(_cartDoc, {'items': items}, SetOptions(merge: true));
    });
  }

  // -------- Clear cart --------
  Future<void> clear() async {
    await _cartDoc.set({'items': []}, SetOptions(merge: true));
  }

  // -------- Confirm order --------
  Future<void> confirmOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String userEmail,
    required Map<String, dynamic> deliveryAddress,
    required Map<String, dynamic> paymentMethod,
  }) async {
    final id = _ordersCol.doc().id;
    await _ordersCol.doc(id).set({
      'id': id,
      'items': items,
      'totalAmount': totalAmount,
      'userEmail': userEmail,
      'deliveryAddress': deliveryAddress,
      'paymentMethod': paymentMethod,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'Confirmed',
    });

    await clear();
  }
}
