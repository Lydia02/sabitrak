import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../../services/firebase_service.dart';
import '../../services/local_cache_service.dart';

class InventoryRepository {
  final FirebaseService _firebaseService = FirebaseService();
  final LocalCacheService _cache = LocalCacheService();

  // Add food item
  Future<void> addFoodItem(FoodItem item) async {
    await _firebaseService.foodItems.add(item.toFirestore());
  }

  // Get all food items for a household.
  // Emits cached data immediately (so the UI shows something while offline),
  // then keeps updating from Firestore whenever connectivity is restored.
  Stream<List<FoodItem>> getFoodItems(String householdId) async* {
    // 1. Yield cached items instantly so the screen is never blank offline
    final cached = _cache.getCachedFoodItems(householdId);
    if (cached.isNotEmpty) yield cached;

    // 2. Stream live updates from Firestore and keep the cache in sync.
    //    If offline or Firestore unreachable the stream stalls — we catch
    //    errors so the UI keeps showing the already-yielded cached data.
    try {
      await for (final snapshot
          in _firebaseService.foodItems
              .where('householdId', isEqualTo: householdId)
              .orderBy('expiryDate')
              .snapshots()) {
        final items =
            snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList();
        // Persist to Hive so offline reads are fresh
        await _cache.saveFoodItems(householdId, items);
        yield items;
      }
    } catch (_) {
      // Network unavailable — cached data already yielded above, nothing more to do.
    }
  }

  // Get expiring items (within 3 days)
  Stream<List<FoodItem>> getExpiringItems(String householdId) {
    DateTime threeDaysFromNow = DateTime.now().add(const Duration(days: 3));

    return _firebaseService.foodItems
        .where('householdId', isEqualTo: householdId)
        .where('expiryDate', isLessThan: Timestamp.fromDate(threeDaysFromNow))
        .orderBy('expiryDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList(),
        );
  }

  // Update food item — auto-converts DateTime values to Firestore Timestamp
  Future<void> updateFoodItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    final converted = updates.map((k, v) {
      if (v is DateTime) return MapEntry(k, Timestamp.fromDate(v));
      return MapEntry(k, v);
    });
    // Tag who made the edit so Cloud Functions can attribute the notification
    final uid = _firebaseService.currentUser?.uid;
    if (uid != null) converted['lastEditedBy'] = uid;
    await _firebaseService.foodItems.doc(itemId).update(converted);
  }

  // Delete food item — stamps lastEditedBy before deleting so the Cloud
  // Function onFoodItemDeleted can read the correct actor from the snapshot
  Future<void> deleteFoodItem(String itemId) async {
    final uid = _firebaseService.currentUser?.uid;
    if (uid != null) {
      await _firebaseService.foodItems.doc(itemId).update({
        'lastEditedBy': uid,
      });
    }
    await _firebaseService.foodItems.doc(itemId).delete();
  }

  // Search food items by barcode
  Future<FoodItem?> findByBarcode(String barcode, String householdId) async {
    final QuerySnapshot snapshot =
        await _firebaseService.foodItems
            .where('barcode', isEqualTo: barcode)
            .where('householdId', isEqualTo: householdId)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) return null;
    return FoodItem.fromFirestore(snapshot.docs.first);
  }

  // Synonym groups — names that refer to the same food item.
  // Both directions are checked so order within the group doesn't matter.
  static const List<List<String>> _synonymGroups = [
    ['okra', 'okro', 'ladies finger', 'lady finger'],
    ['yam', 'yams'],
    ['plantain', 'plantains'],
    ['tomato', 'tomatoes'],
    ['pepper', 'peppers'],
    ['onion', 'onions'],
    ['carrot', 'carrots'],
    ['potato', 'potatoes', 'irish potato', 'irish potatoes'],
    ['sweet potato', 'sweet potatoes'],
    ['garlic', 'garlics'],
    ['ginger', 'gingers'],
    ['bean', 'beans', 'black-eyed peas', 'black eyed peas'],
    ['pea', 'peas', 'green peas'],
    ['corn', 'maize', 'sweetcorn', 'sweet corn'],
    ['spinach', 'ugwu', 'pumpkin leaves'],
    ['egg', 'eggs'],
    ['banana', 'bananas'],
    ['orange', 'oranges'],
    ['apple', 'apples'],
    ['mango', 'mangoes'],
    ['fish', 'fishes'],
    ['chicken', 'chickens'],
    ['rice', 'white rice'],
    ['peanut', 'groundnut', 'groundnuts', 'peanuts'],
    ['palm oil', 'red oil'],
    ['vegetable oil', 'cooking oil', 'veg oil'],
    ['spaghetti', 'pasta', 'macaroni', 'noodles'],
    ['bread', 'loaf', 'loaves'],
    ['milk', 'whole milk', 'skimmed milk'],
    ['flour', 'wheat flour', 'plain flour', 'all-purpose flour'],
  ];

  // Returns the canonical synonym key for a name, or the name itself.
  static String _synonymKey(String name) {
    final lower = name.trim().toLowerCase();
    for (final group in _synonymGroups) {
      if (group.any((s) => lower == s || lower.contains(s) || s.contains(lower))) {
        return group.first; // canonical form
      }
    }
    return lower;
  }

  // Find existing item by name + itemType (case-insensitive, synonym-aware)
  Future<FoodItem?> findDuplicate(
    String name,
    String householdId, {
    ItemType itemType = ItemType.ingredient,
  }) async {
    final normalised = name.trim().toLowerCase();
    final canonicalKey = _synonymKey(normalised);

    // Fetch all items of the same type for this household (no compound index needed)
    final snapshot =
        await _firebaseService.foodItems
            .where('householdId', isEqualTo: householdId)
            .get();

    final sameType =
        snapshot.docs
            .map((doc) => FoodItem.fromFirestore(doc))
            .where((item) => item.itemType == itemType)
            .toList();

    // Exact match first
    for (final item in sameType) {
      if (item.name.trim().toLowerCase() == normalised) return item;
    }
    // Synonym match — same canonical key
    for (final item in sameType) {
      final existingKey = _synonymKey(item.name.trim().toLowerCase());
      if (existingKey == canonicalKey) return item;
    }
    // Fuzzy: one name contains the other
    for (final item in sameType) {
      final existing = item.name.trim().toLowerCase();
      if (existing.contains(normalised) || normalised.contains(existing)) {
        return item;
      }
    }
    return null;
  }

  // Merge: add quantity to existing item instead of creating a duplicate
  Future<void> mergeQuantity(String itemId, int additionalQty) async {
    final doc = await _firebaseService.foodItems.doc(itemId).get();
    if (!doc.exists) return;
    final current =
        (doc.data() as Map<String, dynamic>)['quantity'] as int? ?? 0;
    await _firebaseService.foodItems.doc(itemId).update({
      'quantity': current + additionalQty,
    });
  }
}
