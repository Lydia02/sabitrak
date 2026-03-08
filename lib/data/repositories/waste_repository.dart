import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../models/waste_log.dart';
import '../../services/firebase_service.dart';

class WasteRepository {
  final FirebaseService _firebaseService = FirebaseService();

  /// Log an expired food item as wasted.
  Future<void> logWaste(FoodItem item) async {
    final entry = WasteLog(
      id: '',
      itemId: item.id,
      itemName: item.name,
      category: item.category,
      quantity: item.quantity,
      unit: item.unit,
      householdId: item.householdId,
      addedBy: item.addedBy,
      expiryDate: item.expiryDate,
      wastedAt: DateTime.now(),
    );
    await _firebaseService.wasteLog.add(entry.toFirestore());
  }

  /// Stream of waste log entries for a household, newest first.
  Stream<List<WasteLog>> getWasteLogs(String householdId) {
    return _firebaseService.wasteLog
        .where('householdId', isEqualTo: householdId)
        .orderBy('wastedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => WasteLog.fromFirestore(doc)).toList(),
        );
  }

  /// Total number of items wasted for a household.
  Future<int> getWasteCount(String householdId) async {
    final snap =
        await _firebaseService.wasteLog
            .where('householdId', isEqualTo: householdId)
            .get();
    return snap.docs.length;
  }

  /// Waste entries for the current calendar month.
  Future<int> getWasteCountThisMonth(String householdId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final snap =
        await _firebaseService.wasteLog
            .where('householdId', isEqualTo: householdId)
            .where(
              'wastedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .get();
    return snap.docs.length;
  }
}
