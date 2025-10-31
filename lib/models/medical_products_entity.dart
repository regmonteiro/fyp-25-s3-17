class MedicalProductsEntity {
  final String id;
  final String title;
  final String description;
  final String category;
  final dynamic price;      // keep dynamic; parse to double when showing
  final dynamic oldPrice;
  final String? discount;
  final String? img;
  final String? createdAt;

  MedicalProductsEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.oldPrice,
    this.discount,
    this.img,
    this.createdAt,
  });

  factory MedicalProductsEntity.fromFirestore(String id, Map<String, dynamic> data) {
    return MedicalProductsEntity(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      price: data['price'],
      oldPrice: data['oldPrice'],
      discount: data['discount']?.toString(),
      img: data['img']?.toString(),
      createdAt: data['createdAt']?.toString(),
    );
  }

  static String generateProductId(MedicalProductsEntity p) => p.id;
}
