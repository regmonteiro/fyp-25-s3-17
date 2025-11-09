// lib/medical/controller/medical_products_controller.dart
import 'package:firebase_database/firebase_database.dart';
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
  final FirebaseDatabase _db;

  MedicalProductsController({this.collectionName = 'MedicalProducts'})
      : _db = FirebaseDatabase.instance;

  // Normalize RTDB snapshot to entries of (id, map)
  Iterable<MapEntry<String, Map<String, dynamic>>> _entriesFromSnap(DataSnapshot snap) sync* {
    final v = snap.value;
    if (v == null) return;

    if (v is Map) {
      final m = v.cast<dynamic, dynamic>();
      for (final e in m.entries) {
        if (e.value is Map) {
          yield MapEntry(
            e.key.toString(),
            Map<String, dynamic>.from(e.value as Map),
          );
        }
      }
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        final row = v[i];
        if (row is Map) {
          yield MapEntry(
            i.toString(),
            Map<String, dynamic>.from(row),
          );
        }
      }
    }
  }

  Future<Result<List<MedicalProductsEntity>>> getAllProducts() async {
    try {
      final ref = _db.ref(collectionName);
      final snap = await ref.get();
      if (!snap.exists || snap.value == null) {
        return Result.ok(<MedicalProductsEntity>[]);
      }

      final list = _entriesFromSnap(snap)
          .map((e) => MedicalProductsEntity.fromMap(e.key, e.value))
          .toList();

      return Result.ok(list);
    } catch (e) {
      return Result.err(e.toString());
    }
  }

  Future<Result<List<MedicalProductsEntity>>> getProductsByCategory(String category) async {
    try {
      final q = _db.ref(collectionName).orderByChild('category').equalTo(category);
      final snap = await q.get();
      if (!snap.exists || snap.value == null) {
        return Result.ok(<MedicalProductsEntity>[]);
      }

      final list = _entriesFromSnap(snap)
          .map((e) => MedicalProductsEntity.fromMap(e.key, e.value))
          .toList();

      return Result.ok(list);
    } catch (e) {
      return Result.err(e.toString());
    }
  }

  Future<Result<MedicalProductsEntity>> getProductById(String productId) async {
    try {
      final snap = await _db.ref('$collectionName/$productId').get();
      if (!snap.exists || snap.value == null || snap.value is! Map) {
        return Result.err('Product not found');
      }
      final m = Map<String, dynamic>.from(snap.value as Map);
      final entity = MedicalProductsEntity.fromMap(productId, m);
      return Result.ok(entity);
    } catch (e) {
      return Result.err(e.toString());
    }
  }
}
