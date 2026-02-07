import 'package:cloud_firestore/cloud_firestore.dart';

class FoodItem {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final int quantity;
  final String unit;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final String storageLocation;
  final String? imageUrl;
  final String householdId;
  final String addedBy;
  final DateTime createdAt;

  FoodItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.purchaseDate,
    required this.expiryDate,
    required this.storageLocation,
    this.imageUrl,
    required this.householdId,
    required this.addedBy,
    required this.createdAt,
  });

  // Convert Firestore document to FoodItem
  factory FoodItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FoodItem(
      id: doc.id,
      name: data['name'] ?? '',
      barcode: data['barcode'] ?? '',
      category: data['category'] ?? '',
      quantity: data['quantity'] ?? 0,
      unit: data['unit'] ?? '',
      purchaseDate: (data['purchaseDate'] as Timestamp).toDate(),
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      storageLocation: data['storageLocation'] ?? '',
      imageUrl: data['imageUrl'],
      householdId: data['householdId'] ?? '',
      addedBy: data['addedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Convert FoodItem to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'barcode': barcode,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'storageLocation': storageLocation,
      'imageUrl': imageUrl,
      'householdId': householdId,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Calculate days until expiry
  int get daysUntilExpiry {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  // Check if item is expired
  bool get isExpired => daysUntilExpiry < 0;

  // Check if item is expiring soon (within 3 days)
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 3;
}
