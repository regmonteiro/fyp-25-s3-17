import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartRepository {
  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  CartRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('Not signed in');
    }
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _itemsCol =>
      _fs.collection('Account').doc(_uid).collection('cartItems');

  Future<List<Map<String, dynamic>>> fetchItems() async {
    final q = await _itemsCol.get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> upsertItem({
    required String productId,
    required String name,
    required double price,
    required String imageUrl,
    required int deltaQty, // +1 / -1 / +N
  }) async {
    final ref = _itemsCol.doc(productId);
    await ref.set(
      {
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'quantity': FieldValue.increment(deltaQty),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Clean up zero/negative qty
    final snap = await ref.get();
    final q = (snap.data()?['quantity'] ?? 0) as int;
    if (q <= 0) {
      await ref.delete();
    }
  }

  Future<void> removeItem(String productId) async {
    await _itemsCol.doc(productId).delete();
  }

  Future<void> clear() async {
    final batch = _fs.batch();
    final q = await _itemsCol.get();
    for (final d in q.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
