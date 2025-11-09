
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String emailKeyFrom(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain';
}

class CartServiceFs {
  final String email;
  final FirebaseFirestore db;
  CartServiceFs({required this.email, required this.db});

  String get _emailLower => email.trim().toLowerCase();
  String get _emailKey   => emailKeyFrom(email);

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      db.collection('MedicalProducts').doc('orders').collection('orders');

  // ⬇️ cart doc id is exactly the emailKey, no prefix
  DocumentReference<Map<String, dynamic>> get _cartDoc =>
      _ordersCol.doc(_emailKey);

  Future<void> ensureCartDoc() async {
    await _cartDoc.set({
      'docType': 'cart',
      'emailKey': _emailKey,
      'userEmail': _emailLower,
      'userEmailMirror': _emailLower,
      'items': FieldValue.arrayUnion(const []),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

    Future<List<Map<String, dynamic>>> _safeGetCartOrCreate() async {
  try {
    final snap = await _cartDoc.get();
    if (!snap.exists) {
      await ensureCartDoc(); // create it once
      return <Map<String, dynamic>>[];
    }
    final d = snap.data() ?? const {};
    final items = (d['items'] as List?) ?? const [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    // If rules denied the read on a missing doc, create the doc then continue.
    await ensureCartDoc();
    return <Map<String, dynamic>>[];
  }
}

  Future<List<Map<String, dynamic>>> getCart() => _safeGetCartOrCreate();


  Future<void> saveCart(List<Map<String, dynamic>> items) async {
    await _cartDoc.set({
      'docType': 'cart',
      'userEmail': email.trim().toLowerCase(),   // matches what you see in console
      'emailKey': _emailKey,
      'items': items,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveItems(List<Map<String, dynamic>> items) async {
    await _cartDoc.set({
      'docType': 'cart',
      'userEmailMirror': email.trim().toLowerCase(), // for rules checks
      'emailKey': _emailKey,
      'items': items,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  

  Future<void> clearCart() async {
    final snap = await _cartDoc.get();
    if (snap.exists) await _cartDoc.delete();
  }

  Future<void> removeItem(String productId) async {
    final items = await getCart();
    items.removeWhere((e) => (e['id']?.toString() ?? '') == productId);
    if (items.isEmpty) {
      await clearCart();
    } else {
      await _saveItems(items);
    }
  }

  Future<void> upsertItem({
  required String productId,
  required String name,
  required double price,
  required String imageUrl,
  int deltaQty = 1,
  Map<String, dynamic>? productData,
}) async {
  // Guarantee doc exists and get current items (or empty)
  final items = await _safeGetCartOrCreate();

  final idx = items.indexWhere((e) => (e['id']?.toString() ?? '') == productId);
  if (idx >= 0) {
    final q = (items[idx]['quantity'] ?? 0) + deltaQty;
    if (q <= 0) {
      items.removeAt(idx);
    } else {
      items[idx] = {
        ...items[idx],
        'name': name,
        'price': price,
        'image': imageUrl,
        'quantity': q,
        if (productData != null) 'productData': productData,
      };
    }
  } else if (deltaQty > 0) {
    items.add({
      'id': productId,
      'name': name,
      'price': price,
      'image': imageUrl,
      'quantity': deltaQty,
      if (productData != null) 'productData': productData,
    });
  }

  if (items.isEmpty) {
    await clearCart(); // allowed by rule change below
  } else {
    await saveCart(items);
  }
}
}

class PaymentMethodsServiceFs {
  final String email;
  final FirebaseFirestore db;
  PaymentMethodsServiceFs({required this.email, required this.db});

  String get _emailKey => emailKeyFrom(email);
  // /paymentsubscriptions/{emailKey}
  DocumentReference<Map<String, dynamic>> get _subDoc =>
      db.collection('paymentsubscriptions').doc(_emailKey);

  String _cardType(String num) {
    final n = num.replaceAll(' ', '');
    if (n.startsWith('4')) return 'Visa';
    if (RegExp(r'^5[1-5]').hasMatch(n)) return 'Mastercard';
    if (RegExp(r'^3[47]').hasMatch(n)) return 'American Express';
    return 'Card';
  }

  Future<List<Map<String, dynamic>>> getSavedCards() async {
    final snap = await _subDoc.get();
    if (!snap.exists) return <Map<String, dynamic>>[];
    final d = snap.data() ?? const {};
    final raw = (d['cardNumber'] ?? '').toString().replaceAll(' ', '');
    if (raw.isEmpty) return <Map<String, dynamic>>[];
    final last4 = raw.length >= 4 ? raw.substring(raw.length - 4) : raw;
    return [
      {
        'id': 'primary',
        'cardType': _cardType(raw),
        'lastFour': last4,
        'expiryDate': (d['expiryDate'] ?? '').toString(),
        'cardHolder': (d['cardName'] ?? '').toString(),
      }
    ];
  }

  Future<Map<String, dynamic>> saveCard(Map<String, dynamic> cardData) async {
    final toSave = {
      'cardName': cardData['cardHolder'] ?? cardData['cardName'] ?? '',
      'cardNumber': cardData['fullNumber'] ?? cardData['cardNumber'] ?? '',
      'expiryDate': cardData['expiryDate'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _subDoc.set(toSave, SetOptions(merge: true));
    final raw = (toSave['cardNumber'] as String).replaceAll(' ', '');
    final last4 = raw.isNotEmpty && raw.length >= 4 ? raw.substring(raw.length - 4) : raw;
    return {
      'id': 'primary',
      'cardType': _cardType(raw),
      'lastFour': last4,
      'expiryDate': toSave['expiryDate'],
      'cardHolder': toSave['cardName'],
    };
  }

  Future<void> deleteCard(String _ignored) async {
    await _subDoc.set({
      'cardName': FieldValue.delete(),
      'cardNumber': FieldValue.delete(),
      'expiryDate': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class OrderServiceFs {
  final String email;
  final FirebaseFirestore db;
  OrderServiceFs({required this.email, required this.db});

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      db.collection('MedicalProducts').doc('orders').collection('orders');

  /// Create order USING your target schema
  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required Map<String, dynamic> deliveryAddress, // we’ll store it as `address`
    required Map<String, dynamic> paymentMethod,   // we’ll flatten to amount/method/status
  }) async {
    final now = DateTime.now().toUtc();
    final emailLower = email.trim().toLowerCase();

    final docRef = _ordersCol.doc(); // auto ID

    final payload = {
      'id': docRef.id,

      // 📌 Your schema starts here
      'address': {
        'recipientName': deliveryAddress['recipientName'] ?? '',
        'phoneNumber' : deliveryAddress['phoneNumber']  ?? '',
        'name'        : deliveryAddress['name']         ?? '',
        'blockStreet' : deliveryAddress['blockStreet']  ?? '',
        'unitNumber'  : deliveryAddress['unitNumber']   ?? '',
        'postalCode'  : deliveryAddress['postalCode']   ?? '',
      },

      // Flatten payment
      'amount': (paymentMethod['amount'] as num?)?.toDouble() ?? totalAmount,
      'method': (paymentMethod['method'] ?? '').toString(),
      'status': (paymentMethod['status'] ?? 'Confirmed').toString(),

      // Optional - if you use it elsewhere
      'targetUid': FirebaseAuth.instance.currentUser?.uid ?? '',

      // Order meta
      'userEmail'  : emailLower,
      'items'      : items,
      'totalAmount': totalAmount,
      'timestamp'  : now.millisecondsSinceEpoch,
      'createdAt'  : now.toIso8601String(),
    };

    await docRef.set(payload);
    return payload;
  }

  Future<List<Map<String, dynamic>>> getUserOrders() async {
    final emailLower = email.trim().toLowerCase();

    final qs = await _ordersCol
        .where('userEmail', isEqualTo: emailLower)
        .orderBy('timestamp', descending: true)
        .get();

    return qs.docs.map((d) => d.data()).toList();
  }

  Future<void> clearUserCartDoc(String email) async {
  final key = emailKeyFrom(email);
  final cartDoc = db
    .collection('MedicalProducts')
    .doc('orders')
    .collection('orders')
    .doc(key);
  final snap = await cartDoc.get();
  if (snap.exists) await cartDoc.delete();
}

}