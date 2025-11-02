import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartRepository {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No signed-in user');
    return u.uid;
  }

  String? get _emailKey {
    final e = _auth.currentUser?.email;
    if (e == null || e.isEmpty) return null;
    // email->key like your legacy style
    return e.toLowerCase().replaceAll(RegExp(r'[.#$/\[\]]'), '_');
  }

  /// Preferred doc: MedicalProducts/carts/users/<uid>
  DocumentReference<Map<String, dynamic>> _uidDoc() {
    return _fs.collection('MedicalProducts').doc('carts')
      .collection('users').doc(_uid);
  }

  /// Legacy doc: MedicalProducts/carts/carts/<emailKey>
  DocumentReference<Map<String, dynamic>>? _emailDocOrNull() {
    final key = _emailKey;
    if (key == null) return null;
    return _fs.collection('MedicalProducts').doc('carts')
      .collection('carts').doc(key);
  }

  Future<List<Map<String, dynamic>>> fetchItems() async {
    // Try UID first
    final uidSnap = await _uidDoc().get();
    if (uidSnap.exists) {
      final data = uidSnap.data() ?? {};
      final list = (data['items'] as List?) ?? const [];
      return List<Map<String, dynamic>>.from(list.map((e) => {
        'id'       : e['id'],
        'name'     : e['name'],
        'price'    : (e['price'] as num?)?.toDouble() ?? 0.0,
        'imageUrl' : (e['imageUrl'] ?? '').toString(),
        'quantity' : (e['quantity'] ?? 1) as int,
      }));
    }

    // Fallback: email-path
    final eDoc = _emailDocOrNull();
    if (eDoc != null) {
      final eSnap = await eDoc.get();
      if (eSnap.exists) {
        final data = eSnap.data() ?? {};
        final list = (data['items'] as List?) ?? const [];
        return List<Map<String, dynamic>>.from(list.map((e) => {
          'id'       : e['id'],
          'name'     : e['name'],
          'price'    : (e['price'] as num?)?.toDouble() ?? 0.0,
          'imageUrl' : (e['imageUrl'] ?? '').toString(),
          'quantity' : (e['quantity'] ?? 1) as int,
        }));
      }
    }

    return const [];
  }

  /// Adds deltaQty (+/-) to a product line. Creates line if missing.
  Future<void> upsertItem({
    required String productId,
    required String name,
    required double price,
    required String imageUrl,
    required int deltaQty,
  }) async {
    await _upsertOnDoc(_uidDoc(), productId, name, price, imageUrl, deltaQty);

    // keep legacy in sync if it exists
    final eDoc = _emailDocOrNull();
    if (eDoc != null) {
      final eSnap = await eDoc.get();
      if (eSnap.exists) {
        await _upsertOnDoc(eDoc, productId, name, price, imageUrl, deltaQty);
      }
    }
  }

  Future<void> _upsertOnDoc(
    DocumentReference<Map<String, dynamic>> doc,
    String id, String name, double price, String imageUrl, int deltaQty,
  ) async {
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final data = snap.data() ?? {};
      final items = List<Map<String, dynamic>>.from((data['items'] as List?) ?? const []);
      final idx = items.indexWhere((e) => e['id'] == id);
      if (idx >= 0) {
        final q = ((items[idx]['quantity'] ?? 1) as int) + deltaQty;
        if (q <= 0) {
          items.removeAt(idx);
        } else {
          items[idx]['quantity'] = q;
        }
      } else if (deltaQty > 0) {
        items.add({
          'id': id,
          'name': name,
          'price': price,
          'imageUrl': imageUrl,
          'quantity': deltaQty,
        });
      }
      tx.set(doc, {
        'ownerUid': _uid,
        'items': items,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Remove a line completely (regardless of qty)
  Future<void> removeItem(String productId) async {
    await _removeOnDoc(_uidDoc(), productId);
    final eDoc = _emailDocOrNull();
    if (eDoc != null) {
      final eSnap = await eDoc.get();
      if (eSnap.exists) await _removeOnDoc(eDoc, productId);
    }
  }

  Future<void> _removeOnDoc(
    DocumentReference<Map<String, dynamic>> doc,
    String id,
  ) async {
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final data = snap.data() ?? {};
      final items = List<Map<String, dynamic>>.from((data['items'] as List?) ?? const []);
      items.removeWhere((e) => e['id'] == id);
      tx.set(doc, {
        'ownerUid': _uid,
        'items': items,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Clear everything
  Future<void> clearCart() async {
    await _uidDoc().set({
      'ownerUid': _uid,
      'items': <Map<String, dynamic>>[],
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final eDoc = _emailDocOrNull();
    if (eDoc != null) {
      final eSnap = await eDoc.get();
      if (eSnap.exists) {
        await eDoc.set({
          'ownerUid': _uid,
          'items': <Map<String, dynamic>>[],
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  // Small alias so your controller can call clear()
  Future<void> clear() => clearCart();
}
