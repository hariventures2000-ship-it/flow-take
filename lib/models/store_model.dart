import 'package:cloud_firestore/cloud_firestore.dart';

class StoreModel {
  final String id;
  final String ownerId;
  final String storeName;
  final String storeSlug;
  final String category;
  final String whatsappNumber;
  final String country;
  final String currency;
  final String? logoUrl;
  final String? bannerUrl;
  final String? description;
  final String brandColor; // Hex string e.g. '#000000'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'active', 'inactive', 'draft'
  final bool onboardingCompleted;

  // Customization fields
  final Map<String, dynamic>? businessHours;
  final bool pickupEnabled;
  final bool deliveryEnabled;
  final String? address;

  const StoreModel({
    required this.id,
    required this.ownerId,
    required this.storeName,
    required this.storeSlug,
    required this.category,
    required this.whatsappNumber,
    required this.country,
    required this.currency,
    this.logoUrl,
    this.bannerUrl,
    this.description,
    this.brandColor = '#111827',
    required this.createdAt,
    required this.updatedAt,
    this.status = 'active',
    this.onboardingCompleted = false,
    this.businessHours,
    this.pickupEnabled = true,
    this.deliveryEnabled = true,
    this.address,
  });

  factory StoreModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StoreModel.fromMap(doc.id, data);
  }

  factory StoreModel.fromMap(String docId, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return StoreModel(
      id: docId,
      ownerId: data['ownerId'] as String? ?? '',
      storeName: data['storeName'] as String? ?? '',
      storeSlug: data['storeSlug'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      whatsappNumber: data['whatsappNumber'] as String? ?? '',
      country: data['country'] as String? ?? 'India',
      currency: data['currency'] as String? ?? 'INR',
      logoUrl: data['logoUrl'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      description: data['description'] as String?,
      brandColor: data['brandColor'] as String? ?? '#111827',
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      status: data['status'] as String? ?? 'active',
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      businessHours: data['businessHours'] as Map<String, dynamic>?,
      pickupEnabled: data['pickupEnabled'] as bool? ?? true,
      deliveryEnabled: data['deliveryEnabled'] as bool? ?? true,
      address: data['address'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'storeName': storeName,
      'storeSlug': storeSlug,
      'category': category,
      'whatsappNumber': whatsappNumber,
      'country': country,
      'currency': currency,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'description': description,
      'brandColor': brandColor,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status,
      'onboardingCompleted': onboardingCompleted,
      'businessHours': businessHours,
      'pickupEnabled': pickupEnabled,
      'deliveryEnabled': deliveryEnabled,
      'address': address,
    };
  }

  StoreModel copyWith({
    String? storeName,
    String? category,
    String? whatsappNumber,
    String? country,
    String? currency,
    String? logoUrl,
    String? bannerUrl,
    String? description,
    String? brandColor,
    DateTime? updatedAt,
    String? status,
    bool? onboardingCompleted,
    Map<String, dynamic>? businessHours,
    bool? pickupEnabled,
    bool? deliveryEnabled,
    String? address,
  }) {
    return StoreModel(
      id: id,
      ownerId: ownerId,
      storeName: storeName ?? this.storeName,
      storeSlug: storeSlug,
      category: category ?? this.category,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      country: country ?? this.country,
      currency: currency ?? this.currency,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      brandColor: brandColor ?? this.brandColor,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      status: status ?? this.status,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      businessHours: businessHours ?? this.businessHours,
      pickupEnabled: pickupEnabled ?? this.pickupEnabled,
      deliveryEnabled: deliveryEnabled ?? this.deliveryEnabled,
      address: address ?? this.address,
    );
  }
}

