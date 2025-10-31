import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/medical_products_entity.dart';

class MedicalProductsController {
  final _col = FirebaseFirestore.instance.collection('MedicalProducts');

  Future<List<MedicalProductsEntity>> getAllProducts() async {
    final snap = await _col.get();
    return snap.docs.map((d) =>
      MedicalProductsEntity.fromFirestore(d.id, d.data())
    ).toList();
  }

  Future<List<MedicalProductsEntity>> getProductsByCategory(String category) async {
    final snap = await _col.where('category', isEqualTo: category).get();
    return snap.docs.map((d) =>
      MedicalProductsEntity.fromFirestore(d.id, d.data())
    ).toList();
  }

  Future<MedicalProductsEntity?> getProductById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return MedicalProductsEntity.fromFirestore(doc.id, doc.data()!);
  }
}
