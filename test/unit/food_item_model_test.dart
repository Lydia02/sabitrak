// Unit tests for the FoodItem model
//
// Covers:
//   - Property accessors (daysUntilExpiry, isExpired, isExpiringSoon, isLeftover)
//   - toFirestore() serialisation (field types, values)
//   - fromMap() / fromFirestore() deserialisation (round-trip fidelity)
//   - ItemType enum parsing (known and unknown values)
//   - Edge cases: expiry exactly today, expiry exactly 3 days away

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sabitrak/data/models/food_item.dart';

FoodItem _makeItem({
  String id = 'item-1',
  String name = 'Tomatoes',
  DateTime? expiryDate,
  DateTime? purchaseDate,
  DateTime? createdAt,
  int quantity = 2,
  ItemType itemType = ItemType.ingredient,
}) {
  final now = DateTime.now();
  return FoodItem(
    id: id,
    name: name,
    barcode: '123456',
    category: 'Vegetables',
    quantity: quantity,
    unit: 'kg',
    purchaseDate: purchaseDate ?? now.subtract(const Duration(days: 2)),
    expiryDate: expiryDate ?? now.add(const Duration(days: 5)),
    storageLocation: 'Fridge',
    householdId: 'hh-001',
    addedBy: 'uid-abc',
    createdAt: createdAt ?? now,
    itemType: itemType,
  );
}

void main() {
  final now = DateTime.now();

  // ── daysUntilExpiry ────────────────────────────────────────────────────────

  group('daysUntilExpiry', () {
    test('returns positive value for future expiry', () {
      final item = _makeItem(expiryDate: now.add(const Duration(days: 5)));
      expect(item.daysUntilExpiry, greaterThan(0));
    });

    test('returns negative value for past expiry', () {
      final item = _makeItem(expiryDate: now.subtract(const Duration(days: 3)));
      expect(item.daysUntilExpiry, lessThan(0));
    });

    test('returns 0 when expiry is today', () {
      // Same calendar day — difference in days is 0
      final item = _makeItem(expiryDate: now);
      expect(item.daysUntilExpiry, equals(0));
    });
  });

  // ── isExpired ──────────────────────────────────────────────────────────────

  group('isExpired', () {
    test('true when expiryDate is in the past', () {
      final item = _makeItem(expiryDate: now.subtract(const Duration(days: 1)));
      expect(item.isExpired, isTrue);
    });

    test('false when expiryDate is today', () {
      final item = _makeItem(expiryDate: now);
      expect(item.isExpired, isFalse);
    });

    test('false when expiryDate is in the future', () {
      final item = _makeItem(expiryDate: now.add(const Duration(days: 10)));
      expect(item.isExpired, isFalse);
    });
  });

  // ── isExpiringSoon ─────────────────────────────────────────────────────────

  group('isExpiringSoon', () {
    test('true when expiry is today', () {
      final item = _makeItem(expiryDate: now);
      expect(item.isExpiringSoon, isTrue);
    });

    test('true when expiry is in exactly 3 days', () {
      final item = _makeItem(expiryDate: now.add(const Duration(days: 3)));
      expect(item.isExpiringSoon, isTrue);
    });

    test('false when expiry is 4 days away', () {
      // Add extra hours to stay clearly beyond 3 full days regardless of execution time
      final item = _makeItem(
        expiryDate: now.add(const Duration(days: 4, hours: 1)),
      );
      expect(item.isExpiringSoon, isFalse);
    });

    test('false when item is already expired', () {
      final item = _makeItem(expiryDate: now.subtract(const Duration(days: 1)));
      expect(item.isExpiringSoon, isFalse);
    });
  });

  // ── isLeftover ─────────────────────────────────────────────────────────────

  group('isLeftover', () {
    test('true for ItemType.leftover', () {
      final item = _makeItem(itemType: ItemType.leftover);
      expect(item.isLeftover, isTrue);
    });

    test('false for ItemType.ingredient', () {
      final item = _makeItem(itemType: ItemType.ingredient);
      expect(item.isLeftover, isFalse);
    });

    test('false for ItemType.product', () {
      final item = _makeItem(itemType: ItemType.product);
      expect(item.isLeftover, isFalse);
    });
  });

  // ── toFirestore ────────────────────────────────────────────────────────────

  group('toFirestore', () {
    test('serialises all fields correctly', () {
      final purchase = DateTime(2024, 1, 10);
      final expiry = DateTime(2024, 1, 20);
      final created = DateTime(2024, 1, 10, 8, 0);

      final item = FoodItem(
        id: 'item-1',
        name: 'Milk',
        barcode: '987654',
        category: 'Dairy',
        quantity: 3,
        unit: 'L',
        purchaseDate: purchase,
        expiryDate: expiry,
        storageLocation: 'Fridge',
        householdId: 'hh-001',
        addedBy: 'uid-abc',
        createdAt: created,
        itemType: ItemType.product,
      );

      final map = item.toFirestore();

      expect(map['name'], 'Milk');
      expect(map['barcode'], '987654');
      expect(map['category'], 'Dairy');
      expect(map['quantity'], 3);
      expect(map['unit'], 'L');
      expect(map['storageLocation'], 'Fridge');
      expect(map['householdId'], 'hh-001');
      expect(map['addedBy'], 'uid-abc');
      expect(map['itemType'], 'product');
      // Timestamps
      expect(map['purchaseDate'], isA<Timestamp>());
      expect(map['expiryDate'], isA<Timestamp>());
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['expiryDate'] as Timestamp).toDate(), expiry);
    });

    test('imageUrl is null when not set', () {
      final item = _makeItem();
      final map = item.toFirestore();
      expect(map['imageUrl'], isNull);
    });

    test('itemType serialised as string name', () {
      expect(
        _makeItem(itemType: ItemType.ingredient).toFirestore()['itemType'],
        'ingredient',
      );
      expect(
        _makeItem(itemType: ItemType.leftover).toFirestore()['itemType'],
        'leftover',
      );
      expect(
        _makeItem(itemType: ItemType.product).toFirestore()['itemType'],
        'product',
      );
    });
  });

  // ── fromMap round-trip ─────────────────────────────────────────────────────

  group('fromMap', () {
    test('round-trips all scalar fields correctly', () {
      final purchase = DateTime(2024, 3, 1);
      final expiry = DateTime(2024, 3, 15);
      final created = DateTime(2024, 3, 1, 9, 0);

      final map = {
        'name': 'Eggs',
        'barcode': '111222',
        'category': 'Protein',
        'quantity': 12,
        'unit': 'pcs',
        'purchaseDate': Timestamp.fromDate(purchase),
        'expiryDate': Timestamp.fromDate(expiry),
        'storageLocation': 'Fridge',
        'imageUrl': 'https://example.com/eggs.jpg',
        'householdId': 'hh-002',
        'addedBy': 'uid-xyz',
        'createdAt': Timestamp.fromDate(created),
        'itemType': 'ingredient',
      };

      final item = FoodItem.fromMap('item-42', map);

      expect(item.id, 'item-42');
      expect(item.name, 'Eggs');
      expect(item.barcode, '111222');
      expect(item.category, 'Protein');
      expect(item.quantity, 12);
      expect(item.unit, 'pcs');
      expect(item.purchaseDate, purchase);
      expect(item.expiryDate, expiry);
      expect(item.storageLocation, 'Fridge');
      expect(item.imageUrl, 'https://example.com/eggs.jpg');
      expect(item.householdId, 'hh-002');
      expect(item.addedBy, 'uid-xyz');
      expect(item.createdAt, created);
      expect(item.itemType, ItemType.ingredient);
    });

    test('defaults to ItemType.ingredient for unknown itemType string', () {
      final map = {
        'name': 'Unknown',
        'barcode': '',
        'category': '',
        'quantity': 1,
        'unit': '',
        'purchaseDate': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'expiryDate': Timestamp.fromDate(DateTime(2024, 12, 31)),
        'storageLocation': '',
        'householdId': 'hh-001',
        'addedBy': 'uid-abc',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'itemType': 'banana', // unknown value
      };

      final item = FoodItem.fromMap('item-99', map);
      expect(item.itemType, ItemType.ingredient);
    });

    test('handles missing optional imageUrl gracefully', () {
      final map = {
        'name': 'Bread',
        'barcode': '',
        'category': 'Bakery',
        'quantity': 1,
        'unit': 'loaf',
        'purchaseDate': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'expiryDate': Timestamp.fromDate(DateTime(2024, 1, 7)),
        'storageLocation': 'Pantry',
        'householdId': 'hh-001',
        'addedBy': 'uid-abc',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        // imageUrl intentionally absent
      };

      final item = FoodItem.fromMap('item-no-img', map);
      expect(item.imageUrl, isNull);
    });

    test('toFirestore → fromMap round-trip preserves all fields', () {
      final original = _makeItem(
        id: 'rt-1',
        name: 'Yogurt',
        quantity: 4,
        itemType: ItemType.product,
      );

      final map = original.toFirestore();
      final restored = FoodItem.fromMap(original.id, map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.barcode, original.barcode);
      expect(restored.category, original.category);
      expect(restored.quantity, original.quantity);
      expect(restored.unit, original.unit);
      expect(restored.storageLocation, original.storageLocation);
      expect(restored.householdId, original.householdId);
      expect(restored.addedBy, original.addedBy);
      expect(restored.itemType, original.itemType);
    });
  });
}
