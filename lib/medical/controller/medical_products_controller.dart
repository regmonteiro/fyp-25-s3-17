// medical_products_controller_fs.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../medical_products_entity.dart';

class Result<T> {
  final bool success;
  final T? data;
  final String? error;
  const Result._(this.success, this.data, this.error);
  factory Result.ok(T data) => Result._(true, data, null);
  factory Result.err(String message) => Result._(false, null, message);
}

class MedicalProductsController {
  final String collectionName;
  final FirebaseFirestore _db;

  /// Firestore version
  MedicalProductsController({this.collectionName = 'MedicalProducts'})
      : _db = FirebaseFirestore.instance;

  /// Load all products from the top-level "MedicalProducts" collection.
  /// Skips the special "orders" doc used as a container for orders.
  Future<Result<List<MedicalProductsEntity>>> getAllProducts() async {
    try {
      final qs = await _db.collection(collectionName).get();

      final list = qs.docs
          .where((d) => d.id != 'orders' && (d.data()['docType'] ?? 'product') != 'order')
          .map((d) => MedicalProductsEntity.fromMap(d.id, d.data()))
          .toList();

      return Result.ok(list);
    } catch (e) {
      return Result.err(e.toString());
    }
  }

  /// Filter by category (requires a "category" field in each product doc).
  Future<Result<List<MedicalProductsEntity>>> getProductsByCategory(String category) async {
    try {
      // If you tagged products with docType: "product", keep the extra where:
      // final qs = await _db.collection(collectionName)
      //   .where('docType', isEqualTo: 'product')
      //   .where('category', isEqualTo: category)
      //   .get();

      final qs = await _db.collection(collectionName)
          .where('category', isEqualTo: category)
          .get();

      final list = qs.docs
          .where((d) => d.id != 'orders' && (d.data()['docType'] ?? 'product') != 'order')
          .map((d) => MedicalProductsEntity.fromMap(d.id, d.data()))
          .toList();

      return Result.ok(list);
    } catch (e) {
      return Result.err(e.toString());
    }
  }

  /// Get a single product by its Firestore doc id.
  Future<Result<MedicalProductsEntity>> getProductById(String productId) async {
    try {
      final doc = await _db.collection(collectionName).doc(productId).get();
      if (!doc.exists) return Result.err('Product not found');

      // Guard against the special "orders" doc
      final data = doc.data()!;
      if (doc.id == 'orders' || (data['docType'] ?? 'product') == 'order') {
        return Result.err('Product not found');
      }

      return Result.ok(MedicalProductsEntity.fromMap(doc.id, data));
    } catch (e) {
      return Result.err(e.toString());
    }
  }
}
