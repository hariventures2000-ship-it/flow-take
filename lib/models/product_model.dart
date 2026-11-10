import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final List<String> images;
  final String? description;
  final double sellingPrice;
  final double? compareAtPrice;
  final String? sku;
  final int stockQuantity;
  final String category;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.images = const [],
    this.description,
    required this.sellingPrice,
    this.compareAtPrice,
    this.sku,
    this.stockQuantity = 0,
    required this.category,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromFirestore(
    String storeId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ProductModel(
      id: doc.id,
      storeId: storeId,
      name: data['name'] as String? ?? '',
      images: (data['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      description: data['description'] as String?,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      compareAtPrice: (data['compareAtPrice'] as num?)?.toDouble(),
      sku: data['sku'] as String?,
      stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
      category: data['category'] as String? ?? 'General',
      isAvailable: data['isAvailable'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'images': images,
      'description': description,
      'sellingPrice': sellingPrice,
      'compareAtPrice': compareAtPrice,
      'sku': sku,
      'stockQuantity': stockQuantity,
      'category': category,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

