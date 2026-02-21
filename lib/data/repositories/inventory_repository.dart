import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../../services/firebase_service.dart';

class InventoryRepository {
  final FirebaseService _firebaseService = FirebaseService();

  // Add food item
  Future<void> addFoodItem(FoodItem item) async {
    await _firebaseService.foodItems.add(item.toFirestore());
  }

  // Get all food items for a household
  Stream<List<FoodItem>> getFoodItems(String householdId) {
    return _firebaseService.foodItems
        .where('householdId', isEqualTo: householdId)
        .orderBy('expiryDate')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList());
  }

  // Get expiring items (within 3 days)
  Stream<List<FoodItem>> getExpiringItems(String householdId) {
    DateTime threeDaysFromNow = DateTime.now().add(const Duration(days: 3));

    return _firebaseService.foodItems
        .where('householdId', isEqualTo: householdId)
        .where('expiryDate', isLessThan: Timestamp.fromDate(threeDaysFromNow))
        .orderBy('expiryDate')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FoodItem.fromFirestore(doc)).toList());
  }

  // Update food item — auto-converts DateTime values to Firestore Timestamp
  Future<void> updateFoodItem(
      String itemId, Map<String, dynamic> updates) async {
    final converted = updates.map((k, v) {
      if (v is DateTime) return MapEntry(k, Timestamp.fromDate(v));
      return MapEntry(k, v);
    });
    await _firebaseService.foodItems.doc(itemId).update(converted);
  }

  // Delete food item
  Future<void> deleteFoodItem(String itemId) async {
    await _firebaseService.foodItems.doc(itemId).delete();
  }

  // Search food items by barcode
  Future<FoodItem?> findByBarcode(String barcode, String householdId) async {
    final QuerySnapshot snapshot = await _firebaseService.foodItems
        .where('barcode', isEqualTo: barcode)
        .where('householdId', isEqualTo: householdId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return FoodItem.fromFirestore(snapshot.docs.first);
  }
}
