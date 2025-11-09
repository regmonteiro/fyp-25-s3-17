// lib/medical/entity/medical_products_entity.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalProductsEntity {
  final String id;
  final String title;
  final String description;
  final String? img;
  final String category;
  final String price;     // string or currency-like
  final String? oldPrice; // optional

  MedicalProductsEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.oldPrice,
    this.img,
  });

  factory MedicalProductsEntity.fromMap(String id, Map<String, dynamic> m) {
    return MedicalProductsEntity(
      id: id,
      title: (m['title'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      category: (m['category'] ?? 'all').toString(),
      price: (m['price'] ?? '0').toString(),
      oldPrice: m['oldPrice']?.toString(),
      img: m['img']?.toString(),
    );
  }

  static String generateProductId(MedicalProductsEntity p) {
    final base = '${p.category}_${p.title}'.toLowerCase();
    return base.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}

