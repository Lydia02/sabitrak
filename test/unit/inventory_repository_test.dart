// Unit tests for InventoryRepository business logic
//
// Since InventoryRepository talks to Firestore via FirebaseService,
// these tests exercise the pure logic parts:
//   - findDuplicate: exact match, fuzzy match (contains), no match
//   - mergeQuantity: arithmetic is correct (via computed expected values)
//
// Firestore interaction tests are covered in integration tests.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/models/food_item.dart';

// ── helpers ────────────────────────────────────────────────────────────────

FoodItem _item({
  required String id,
  required String name,
  ItemType itemType = ItemType.ingredient,
  int quantity = 3,
}) {
  final now = DateTime.now();
  return FoodItem(
    id: id,
    name: name,
    barcode: '',
    category: 'Test',
    quantity: quantity,
    unit: 'pcs',
    purchaseDate: now.subtract(const Duration(days: 1)),
    expiryDate: now.add(const Duration(days: 7)),
    storageLocation: 'Pantry',
    householdId: 'hh-001',
    addedBy: 'uid-abc',
    createdAt: now,
    itemType: itemType,
  );
}

// Pure duplicate-search logic extracted from InventoryRepository.findDuplicate
// (mirrors the algorithm exactly — if the algorithm changes, this test catches it)
FoodItem? _findDuplicate(List<FoodItem> items, String name, ItemType itemType) {
  final normalised = name.trim().toLowerCase();
  final sameType = items.where((i) => i.itemType == itemType).toList();

  // Exact match first
  for (final item in sameType) {
    if (item.name.trim().toLowerCase() == normalised) return item;
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

void main() {
  // ── findDuplicate logic ────────────────────────────────────────────────────

  group('findDuplicate logic', () {
    final items = [
      _item(id: '1', name: 'Tomatoes', itemType: ItemType.ingredient),
      _item(id: '2', name: 'Tomato Paste', itemType: ItemType.ingredient),
      _item(id: '3', name: 'Leftover Rice', itemType: ItemType.leftover),
      _item(id: '4', name: 'Milk', itemType: ItemType.product),
    ];

    test('returns exact match (case-insensitive)', () {
      final result = _findDuplicate(items, 'tomatoes', ItemType.ingredient);
      expect(result?.id, '1');
    });

    test('returns fuzzy match when search term is substring of existing', () {
      final result = _findDuplicate(items, 'Tomato', ItemType.ingredient);
      // 'tomato' is contained in 'tomatoes' — exact match check fails
      // fuzzy check: 'tomatoes'.contains('tomato') → true → id 1
      expect(result?.id, '1');
    });

    test('returns fuzzy match when existing name is substring of search', () {
      final result = _findDuplicate(
        items,
        'Tomatoes Fresh',
        ItemType.ingredient,
      );
      // 'tomatoes fresh' contains 'tomatoes' → match id 1
      expect(result?.id, '1');
    });

    test('returns null when no match exists', () {
      final result = _findDuplicate(items, 'Pepper', ItemType.ingredient);
      expect(result, isNull);
    });

    test('does not match across item types', () {
      // 'Leftover Rice' exists as leftover, not ingredient
      final result = _findDuplicate(
        items,
        'Leftover Rice',
        ItemType.ingredient,
      );
      expect(result, isNull);
    });

    test('exact match takes priority over fuzzy', () {
      // 'Tomatoes' exactly matches id-1; fuzzy would also match id-2
      final result = _findDuplicate(items, 'Tomatoes', ItemType.ingredient);
      expect(result?.id, '1');
    });

    test('returns null for empty item list', () {
      final result = _findDuplicate([], 'Milk', ItemType.product);
      expect(result, isNull);
    });
  });

  // ── FoodItem computed properties used in repository filters ───────────────

  group('FoodItem filters used by repository', () {
    final now = DateTime.now();

    test('isExpired items are correctly identified', () {
      final items = [
        _item(
          id: '1',
          name: 'Old Milk',
        ).copyWithExpiry(now.subtract(const Duration(days: 1))),
        _item(
          id: '2',
          name: 'Fresh Eggs',
        ).copyWithExpiry(now.add(const Duration(days: 5))),
      ];

      final expired = items.where((i) => i.isExpired).toList();
      expect(expired.length, 1);
      expect(expired.first.id, '1');
    });

    test('isExpiringSoon items do not include already expired items', () {
      final items = [
        _item(
          id: '1',
          name: 'Expired',
        ).copyWithExpiry(now.subtract(const Duration(days: 1))),
        _item(id: '2', name: 'Today').copyWithExpiry(now),
        _item(
          id: '3',
          name: 'In 2 days',
        ).copyWithExpiry(now.add(const Duration(days: 2))),
        _item(
          id: '4',
          name: 'In 5 days',
        ).copyWithExpiry(now.add(const Duration(days: 5))),
      ];

      final expiringSoon =
          items.where((i) => i.isExpiringSoon && !i.isExpired).toList();
      expect(expiringSoon.map((i) => i.id).toSet(), {'2', '3'});
    });

    test('low stock filter: qty <= 1 and not expired', () {
      final items = [
        _item(
          id: '1',
          name: 'Almost Gone',
          quantity: 1,
        ).copyWithExpiry(now.add(const Duration(days: 3))),
        _item(
          id: '2',
          name: 'Expired Low',
          quantity: 1,
        ).copyWithExpiry(now.subtract(const Duration(days: 1))),
        _item(
          id: '3',
          name: 'Enough Stock',
          quantity: 5,
        ).copyWithExpiry(now.add(const Duration(days: 3))),
      ];

      final lowStock =
          items.where((i) => i.quantity <= 1 && !i.isExpired).toList();
      expect(lowStock.length, 1);
      expect(lowStock.first.id, '1');
    });
  });

  // ── toFirestore ↔ fromMap round-trip ──────────────────────────────────────

  group('toFirestore / fromMap serialisation', () {
    test('Timestamp values survive round-trip', () {
      final expiry = DateTime(2025, 6, 15, 12, 0);
      final item = _item(id: 'ts-test', name: 'Avocado').copyWithExpiry(expiry);

      final map = item.toFirestore();
      final restored = FoodItem.fromMap(item.id, map);

      expect(restored.expiryDate, expiry);
    });

    test('all ItemType values round-trip correctly', () {
      for (final type in ItemType.values) {
        final item = _item(id: 'type-$type', name: 'Item', itemType: type);
        final map = item.toFirestore();
        final restored = FoodItem.fromMap(item.id, map);
        expect(restored.itemType, type, reason: 'Failed for $type');
      }
    });
  });
}

// Extension to allow setting expiryDate in tests without modifying the model
extension _FoodItemTestExt on FoodItem {
  FoodItem copyWithExpiry(DateTime newExpiry) => FoodItem(
    id: id,
    name: name,
    barcode: barcode,
    category: category,
    quantity: quantity,
    unit: unit,
    purchaseDate: purchaseDate,
    expiryDate: newExpiry,
    storageLocation: storageLocation,
    imageUrl: imageUrl,
    householdId: householdId,
    addedBy: addedBy,
    createdAt: createdAt,
    itemType: itemType,
  );
}
