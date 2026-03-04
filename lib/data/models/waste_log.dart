import 'package:cloud_firestore/cloud_firestore.dart';

class WasteLog {
  final String id;
  final String itemId;
  final String itemName;
  final String category;
  final int quantity;
  final String unit;
  final String householdId;
  final String addedBy;
  final DateTime expiryDate;
  final DateTime wastedAt;

  WasteLog({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.householdId,
    required this.addedBy,
    required this.expiryDate,
    required this.wastedAt,
  });

  factory WasteLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WasteLog(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      category: data['category'] ?? '',
      quantity: data['quantity'] ?? 0,
      unit: data['unit'] ?? '',
      householdId: data['householdId'] ?? '',
      addedBy: data['addedBy'] ?? '',
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      wastedAt: (data['wastedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'householdId': householdId,
      'addedBy': addedBy,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'wastedAt': Timestamp.fromDate(wastedAt),
    };
  }
}
