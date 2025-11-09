import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddressServiceFs {
  final FirebaseFirestore _db;
  final String ownerUid;

  AddressServiceFs({FirebaseFirestore? db, String? ownerUid})
      : _db = db ?? FirebaseFirestore.instance,
        ownerUid = ownerUid ?? FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('Account').doc(ownerUid).collection('addresses');

  Future<List<Map<String, dynamic>>> getAddresses() async {
    final qs = await _col.get();
    final list = qs.docs.map((d) => d.data()..['id'] = d.id).toList();
    // put default first
    list.sort((a, b) => (b['isDefault'] == true ? 1 : 0)
        .compareTo(a['isDefault'] == true ? 1 : 0));
    return list;
  }

  Future<Map<String, dynamic>> saveAddress(Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final ref = _col.doc();
    final payload = {
      'id': ref.id,
      'name': data['name'],
      'recipientName': data['recipientName'],
      'phoneNumber': data['phoneNumber'],
      'blockStreet': data['blockStreet'],
      'unitNumber': data['unitNumber'],
      'postalCode': data['postalCode'],
      'isDefault': data['isDefault'] ?? false,
      'createdAt': now,
      'updatedAt': now,
    };
    await ref.set(payload);
    return payload;
  }

  Future<void> deleteAddress(String addressId) async {
    await _col.doc(addressId).delete();
  }

  /// Make exactly one default: set target true, others false
  Future<void> setDefaultAddress(String addressId) async {
    final batch = _db.batch();
    final qs = await _col.get();
    for (final d in qs.docs) {
      final isTarget = d.id == addressId;
      batch.update(d.reference, {
        'isDefault': isTarget,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
    await batch.commit();
  }
}
