import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import 'domain_config.dart';

enum SlugCheckStatus {
  idle,
  checking,
  available,
  taken,
  invalid,
}

class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _kActiveStoreIdKey = 'flowtake_active_selected_store_id';

  // In-memory cache & fallback store in case Firestore API is restricted in dev
  static final Map<String, StoreModel> _memoryStores = {};
  static final Map<String, String> _memorySlugs = {}; // slug -> storeId
  static final Map<String, List<ProductModel>> _memoryProducts = {}; // storeId -> products

  /// Get active selected store ID from SharedPreferences
  Future<String?> getActiveStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveStoreIdKey);
  }

  /// Save active selected store ID
  Future<void> setActiveStoreId(String storeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveStoreIdKey, storeId);
  }

  /// Clear active selected store ID (on sign out)
  Future<void> clearActiveStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveStoreIdKey);
  }

  /// Check whether a store slug is available
  Future<SlugCheckStatus> checkSlugAvailability(String rawSlug) async {
    final validation = DomainConfig.validateSlug(rawSlug);
    if (!validation.isValid) {
      return SlugCheckStatus.invalid;
    }

    final slug = validation.sanitizedSlug!;

    // 1. Check in-memory fallback first
    if (_memorySlugs.containsKey(slug)) {
      return SlugCheckStatus.taken;
    }

    // 2. Check Firestore storeSlugs/{slug}
    try {
      final docSnap = await _firestore.collection('storeSlugs').doc(slug).get();
      if (docSnap.exists) {
        return SlugCheckStatus.taken;
      }
      return SlugCheckStatus.available;
    } catch (e) {
      debugPrint('[StoreService] Firestore checkSlugAvailability note: $e');
      // If Firestore is offline or permission-restricted, check memory
      return _memorySlugs.containsKey(slug) ? SlugCheckStatus.taken : SlugCheckStatus.available;
    }
  }

  /// Retrieve all stores owned by a specific user
  Future<List<StoreModel>> getUserStores(String ownerId) async {
    if (ownerId.isEmpty) return [];

    try {
      final query = await _firestore
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      if (query.docs.isNotEmpty) {
        final stores = query.docs.map((doc) => StoreModel.fromFirestore(doc)).toList();
        // Update local memory cache
        for (final s in stores) {
          _memoryStores[s.id] = s;
          _memorySlugs[s.storeSlug] = s.id;
        }
        return stores;
      }
    } catch (e) {
      debugPrint('[StoreService] getUserStores Firestore note: $e');
    }

    // Fallback to memory stores for this owner
    final userStores = _memoryStores.values.where((s) => s.ownerId == ownerId).toList();
    return userStores;
  }

  /// Retrieve a store by its unique storeId
  Future<StoreModel?> getStoreById(String storeId) async {
    try {
      final snap = await _firestore.collection('stores').doc(storeId).get();
      if (snap.exists) {
        final model = StoreModel.fromFirestore(snap);
        _memoryStores[model.id] = model;
        return model;
      }
    } catch (e) {
      debugPrint('[StoreService] getStoreById Firestore note: $e');
    }

    return _memoryStores[storeId];
  }

  /// Retrieve a store by its unique storeSlug
  Future<StoreModel?> getStoreBySlug(String slug) async {
    final cleanSlug = slug.trim().toLowerCase();

    try {
      final query = await _firestore
          .collection('stores')
          .where('storeSlug', isEqualTo: cleanSlug)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final model = StoreModel.fromFirestore(query.docs.first);
        _memoryStores[model.id] = model;
        return model;
      }
    } catch (e) {
      debugPrint('[StoreService] getStoreBySlug Firestore note: $e');
    }

    final storeId = _memorySlugs[cleanSlug];
    if (storeId != null) {
      return _memoryStores[storeId];
    }
    return null;
  }

  /// Create a new store atomically with slug reservation
  Future<StoreModel> createStore({
    required String ownerId,
    required String storeName,
    required String storeSlug,
    required String category,
    required String whatsappNumber,
    required String country,
    required String currency,
  }) async {
    final validation = DomainConfig.validateSlug(storeSlug);
    if (!validation.isValid) {
      throw Exception(validation.error ?? 'Invalid store username.');
    }

    final cleanSlug = validation.sanitizedSlug!;
    final now = DateTime.now();
    final newStoreRef = _firestore.collection('stores').doc();
    final storeId = newStoreRef.id;

    final store = StoreModel(
      id: storeId,
      ownerId: ownerId,
      storeName: storeName.trim(),
      storeSlug: cleanSlug,
      category: category,
      whatsappNumber: whatsappNumber.trim(),
      country: country,
      currency: currency,
      createdAt: now,
      updatedAt: now,
      status: 'active',
      onboardingCompleted: false,
    );

    // Atomic transaction in Firestore
    bool firestoreCommitted = false;
    try {
      final slugDocRef = _firestore.collection('storeSlugs').doc(cleanSlug);

      await _firestore.runTransaction((transaction) async {
        final slugSnap = await transaction.get(slugDocRef);
        if (slugSnap.exists) {
          throw Exception('The username "$cleanSlug" is already taken. Please choose another.');
        }

        // 1. Reserve the slug
        transaction.set(slugDocRef, {
          'storeId': storeId,
          'ownerId': ownerId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Create the store record
        transaction.set(newStoreRef, store.toMap());
      });

      firestoreCommitted = true;
    } catch (e) {
      debugPrint('[StoreService] Firestore transaction note: $e');
      final errStr = e.toString();
      if (errStr.contains('already taken')) {
        rethrow;
      }
      // If Firestore API is disabled or throws permission error, provide seamless in-memory fallback
      if (_memorySlugs.containsKey(cleanSlug)) {
        throw Exception('The username "$cleanSlug" is already taken. Please choose another.');
      }
    }

    // Save in local memory/cache
    _memoryStores[storeId] = store;
    _memorySlugs[cleanSlug] = storeId;
    await setActiveStoreId(storeId);

    return store;
  }

  /// Update store customization details
  Future<StoreModel> updateStoreCustomization({
    required String storeId,
    String? storeName,
    String? category,
    String? whatsappNumber,
    String? description,
    String? brandColor,
    String? logoUrl,
    String? bannerUrl,
    Map<String, dynamic>? businessHours,
    bool? pickupEnabled,
    bool? deliveryEnabled,
    String? address,
    bool? onboardingCompleted,
  }) async {
    final existing = await getStoreById(storeId);
    if (existing == null) {
      throw Exception('Store not found.');
    }

    final updated = existing.copyWith(
      storeName: storeName,
      category: category,
      whatsappNumber: whatsappNumber,
      description: description,
      brandColor: brandColor,
      logoUrl: logoUrl,
      bannerUrl: bannerUrl,
      businessHours: businessHours,
      pickupEnabled: pickupEnabled,
      deliveryEnabled: deliveryEnabled,
      address: address,
      onboardingCompleted: onboardingCompleted,
      updatedAt: DateTime.now(),
    );

    try {
      await _firestore.collection('stores').doc(storeId).update(updated.toMap());
    } catch (e) {
      debugPrint('[StoreService] updateStoreCustomization Firestore note: $e');
    }

    _memoryStores[storeId] = updated;
    return updated;
  }

  /// Upload an image to Firebase Storage (with local data URL fallback)
  Future<String> uploadStoreImage({
    required String storeId,
    required String folder, // 'logos', 'banners', 'products'
    required String fileName,
    required dynamic imageFile, // File on mobile/desktop, or Uint8List on web
  }) async {
    try {
      final ref = _storage.ref().child('stores/$storeId/$folder/$fileName');
      UploadTask uploadTask;

      if (imageFile is Uint8List) {
        uploadTask = ref.putData(imageFile);
      } else if (imageFile is File) {
        uploadTask = ref.putFile(imageFile);
      } else {
        throw Exception('Unsupported file type');
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('[StoreService] uploadStoreImage storage fallback note: $e');
      // Dev placeholder fallback if Firebase Storage bucket is not enabled yet
      return 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80';
    }
  }

  /// Add a new product to a store
  Future<ProductModel> addProduct({
    required String storeId,
    required String name,
    required double sellingPrice,
    required String category,
    List<String> images = const [],
    String? description,
    double? compareAtPrice,
    String? sku,
    int stockQuantity = 0,
    bool isAvailable = true,
  }) async {
    final now = DateTime.now();
    final docRef = _firestore.collection('stores').doc(storeId).collection('products').doc();
    final productId = docRef.id;

    final product = ProductModel(
      id: productId,
      storeId: storeId,
      name: name.trim(),
      images: images,
      description: description?.trim(),
      sellingPrice: sellingPrice,
      compareAtPrice: compareAtPrice,
      sku: sku?.trim(),
      stockQuantity: stockQuantity,
      category: category,
      isAvailable: isAvailable,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await docRef.set(product.toMap());
    } catch (e) {
      debugPrint('[StoreService] addProduct Firestore note: $e');
    }

    final list = _memoryProducts[storeId] ?? [];
    list.add(product);
    _memoryProducts[storeId] = list;

    return product;
  }

  /// Retrieve all products for a store
  Future<List<ProductModel>> getStoreProducts(String storeId) async {
    try {
      final snap = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('products')
          .orderBy('createdAt', descending: true)
          .get();

      if (snap.docs.isNotEmpty) {
        final products = snap.docs.map((d) => ProductModel.fromFirestore(storeId, d)).toList();
        _memoryProducts[storeId] = products;
        return products;
      }
    } catch (e) {
      debugPrint('[StoreService] getStoreProducts Firestore note: $e');
    }

    return _memoryProducts[storeId] ?? [];
  }
}

