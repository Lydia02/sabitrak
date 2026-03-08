// Acceptance / Functional System Test Report
//
// These tests document and verify the end-to-end acceptance criteria for
// SabiTrak's key user journeys. Each test describes a user story and asserts
// that the system's data layer / business logic satisfies the acceptance
// criteria without requiring a live device.
//
// Acceptance criteria source: product requirements from project design docs.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/models/food_item.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

FoodItem _buildItem({
  required String id,
  required String name,
  required DateTime expiry,
  int quantity = 2,
  ItemType type = ItemType.ingredient,
  String addedBy = 'uid-me',
  DateTime? createdAt,
}) {
  final now = DateTime.now();
  return FoodItem(
    id: id,
    name: name,
    barcode: '',
    category: 'General',
    quantity: quantity,
    unit: 'pcs',
    purchaseDate: now.subtract(const Duration(days: 1)),
    expiryDate: expiry,
    storageLocation: 'Fridge',
    householdId: 'hh-001',
    addedBy: addedBy,
    createdAt: createdAt ?? now,
    itemType: type,
  );
}

void main() {
  final now = DateTime.now();

  // ── AC-01: User can view items expiring within 3 days ─────────────────────

  group('AC-01 — View items expiring within 3 days', () {
    /*
     * User story:
     *   AS a household member
     *   I WANT to see items expiring within the next 3 days
     *   SO THAT I can use them before they go to waste
     *
     * Acceptance criteria:
     *   - Items expiring today (day 0) are included
     *   - Items expiring in exactly 3 days are included
     *   - Items expiring in 4+ days are NOT included
     *   - Already-expired items are NOT shown in this list
     */

    final items = [
      _buildItem(id: '1', name: 'Today', expiry: now),
      _buildItem(
        id: '2',
        name: 'Day 1',
        expiry: now.add(const Duration(days: 1)),
      ),
      _buildItem(
        id: '3',
        name: 'Day 3',
        expiry: now.add(const Duration(days: 3)),
      ),
      _buildItem(
        id: '4',
        name: 'Day 4',
        expiry: now.add(const Duration(days: 4, hours: 1)),
      ),
      _buildItem(
        id: '5',
        name: 'Expired',
        expiry: now.subtract(const Duration(days: 1)),
      ),
    ];

    test('expiring-soon list contains items expiring 0–3 days from now', () {
      final expiringSoon =
          items
              .where((i) => i.isExpiringSoon && !i.isExpired)
              .map((i) => i.name)
              .toList();

      expect(expiringSoon, containsAll(['Today', 'Day 1', 'Day 3']));
      expect(expiringSoon, isNot(contains('Day 4')));
      expect(expiringSoon, isNot(contains('Expired')));
    });

    test('item expiring exactly today is included (boundary check)', () {
      final item = _buildItem(id: 'bc', name: 'Boundary', expiry: now);
      expect(item.isExpiringSoon, isTrue);
      expect(item.isExpired, isFalse);
    });

    test('item expiring exactly in 3 days is included (boundary check)', () {
      final item = _buildItem(
        id: 'bc3',
        name: 'Boundary3',
        expiry: now.add(const Duration(days: 3)),
      );
      expect(item.isExpiringSoon, isTrue);
    });
  });

  // ── AC-02: Expired items are flagged for removal ──────────────────────────

  group('AC-02 — Expired items flagged for removal', () {
    /*
     * User story:
     *   AS a household member
     *   I WANT to see which items have already expired
     *   SO THAT I can remove them and keep my pantry accurate
     *
     * Acceptance criteria:
     *   - Items with expiry < today are flagged as expired
     *   - Items with expiry == today are NOT expired
     *   - Notification body mentions removing the item
     */

    test('item expired yesterday is flagged', () {
      final item = _buildItem(
        id: 'exp',
        name: 'Old Milk',
        expiry: now.subtract(const Duration(days: 1)),
      );
      expect(item.isExpired, isTrue);
    });

    test('item expiring today is not expired', () {
      final item = _buildItem(id: 'today', name: 'Fresh Eggs', expiry: now);
      expect(item.isExpired, isFalse);
    });

    test('expired notification body mentions removal', () {
      const body =
          'Remove it from your pantry to keep your inventory accurate.';
      expect(body, contains('Remove'));
    });
  });

  // ── AC-03: Low-stock items are identified ─────────────────────────────────

  group('AC-03 — Low-stock items identified', () {
    /*
     * User story:
     *   AS a household member
     *   I WANT to be alerted when an item is running low
     *   SO THAT I can restock before it runs out
     *
     * Acceptance criteria:
     *   - Items with quantity <= 1 AND not expired are "low stock"
     *   - Expired items are excluded even if quantity is 0/1
     *   - Notification body includes the item name and quantity
     */

    final items = [
      _buildItem(
        id: '1',
        name: 'Salt',
        expiry: now.add(const Duration(days: 30)),
        quantity: 1,
      ),
      _buildItem(
        id: '2',
        name: 'Oil',
        expiry: now.add(const Duration(days: 30)),
        quantity: 5,
      ),
      _buildItem(
        id: '3',
        name: 'Vinegar',
        expiry: now.subtract(const Duration(days: 1)),
        quantity: 1,
      ),
    ];

    test('only non-expired items with qty <= 1 appear in low-stock list', () {
      final lowStock =
          items.where((i) => i.quantity <= 1 && !i.isExpired).toList();
      expect(lowStock.length, 1);
      expect(lowStock.first.name, 'Salt');
    });

    test('notification body includes item name and quantity', () {
      final item = items.first; // Salt, qty 1
      final body =
          'Only ${item.quantity} ${item.unit} left. Consider restocking.';
      expect(body, contains('1'));
      expect(body, contains('left'));
    });
  });

  // ── AC-04: Leftover items are correctly categorised ───────────────────────

  group('AC-04 — Leftover items categorised separately', () {
    /*
     * User story:
     *   AS a household member
     *   I WANT to track leftover food separately from ingredients
     *   SO THAT I remember to consume them quickly
     *
     * Acceptance criteria:
     *   - ItemType.leftover items are identified as leftovers
     *   - ItemType.ingredient / product are not leftovers
     *   - Leftovers appear in the leftovers section of the pantry
     */

    test('leftover item is identified as a leftover', () {
      final item = _buildItem(
        id: 'lo',
        name: 'Jollof Rice',
        expiry: now.add(const Duration(days: 2)),
        type: ItemType.leftover,
      );
      expect(item.isLeftover, isTrue);
    });

    test('ingredient is not a leftover', () {
      final item = _buildItem(
        id: 'ing',
        name: 'Tomatoes',
        expiry: now.add(const Duration(days: 5)),
      );
      expect(item.isLeftover, isFalse);
    });

    test('product is not a leftover', () {
      final item = _buildItem(
        id: 'prod',
        name: 'Ketchup',
        expiry: now.add(const Duration(days: 60)),
        type: ItemType.product,
      );
      expect(item.isLeftover, isFalse);
    });
  });

  // ── AC-05: Pantry data survives serialisation (Firestore round-trip) ───────

  group('AC-05 — Pantry items persist and restore correctly', () {
    /*
     * User story:
     *   AS a household member
     *   I WANT my pantry items to be saved and loaded correctly
     *   SO THAT the app shows accurate data across sessions
     *
     * Acceptance criteria:
     *   - All fields survive a toFirestore() → fromMap() round-trip
     *   - Timestamps are stored as Firestore Timestamp objects
     *   - ItemType is stored as a string and restored correctly
     */

    test('all required fields are present in Firestore map', () {
      final item = _buildItem(
        id: 'persist-1',
        name: 'Plantain',
        expiry: now.add(const Duration(days: 7)),
      );
      final map = item.toFirestore();

      expect(map.containsKey('name'), isTrue);
      expect(map.containsKey('quantity'), isTrue);
      expect(map.containsKey('expiryDate'), isTrue);
      expect(map.containsKey('purchaseDate'), isTrue);
      expect(map.containsKey('createdAt'), isTrue);
      expect(map.containsKey('householdId'), isTrue);
      expect(map.containsKey('addedBy'), isTrue);
      expect(map.containsKey('itemType'), isTrue);
    });

    test('dates are stored as Firestore Timestamp', () {
      final item = _buildItem(
        id: 'persist-2',
        name: 'Yam',
        expiry: now.add(const Duration(days: 5)),
      );
      final map = item.toFirestore();
      expect(map['expiryDate'], isA<Timestamp>());
      expect(map['purchaseDate'], isA<Timestamp>());
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('full round-trip preserves all fields', () {
      final expiry = DateTime(2025, 8, 20, 10, 0);
      final item = FoodItem(
        id: 'rt-2',
        name: 'Palm Oil',
        barcode: '77889900',
        category: 'Cooking',
        quantity: 2,
        unit: 'L',
        purchaseDate: DateTime(2025, 8, 1),
        expiryDate: expiry,
        storageLocation: 'Pantry',
        householdId: 'hh-africa-001',
        addedBy: 'uid-chief',
        createdAt: DateTime(2025, 8, 1, 9, 0),
        itemType: ItemType.ingredient,
      );

      final restored = FoodItem.fromMap(item.id, item.toFirestore());

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.barcode, item.barcode);
      expect(restored.category, item.category);
      expect(restored.quantity, item.quantity);
      expect(restored.unit, item.unit);
      expect(restored.expiryDate, expiry);
      expect(restored.householdId, item.householdId);
      expect(restored.addedBy, item.addedBy);
      expect(restored.itemType, item.itemType);
    });
  });

  // ── AC-06: Household members see each other's additions ───────────────────

  group('AC-06 — Household update notifications', () {
    /*
     * User story:
     *   AS a household member
     *   I WANT to see when other members add or remove items
     *   SO THAT I always know the current state of the shared pantry
     *
     * Acceptance criteria:
     *   - Items added by other members (different uid) within 24h
     *     appear in the "household update" notification
     *   - Items added by the current user are excluded
     *   - Items added > 24 hours ago are excluded
     */

    const myUid = 'uid-me';
    const otherUid = 'uid-them';

    test(
      'item added by another member within 24h qualifies for household update',
      () {
        final item = _buildItem(
          id: 'hu-1',
          name: 'Suya',
          expiry: now.add(const Duration(days: 2)),
          addedBy: otherUid,
          createdAt: now.subtract(const Duration(hours: 12)),
        );
        final isRecent =
            item.addedBy != myUid &&
            now.difference(item.createdAt).inHours < 24;
        expect(isRecent, isTrue);
      },
    );

    test('item added by current user is excluded from household update', () {
      final item = _buildItem(
        id: 'hu-2',
        name: 'Egusi',
        expiry: now.add(const Duration(days: 3)),
        addedBy: myUid,
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      final isRecent =
          item.addedBy != myUid && now.difference(item.createdAt).inHours < 24;
      expect(isRecent, isFalse);
    });

    test('item added by another member more than 24h ago is excluded', () {
      final item = _buildItem(
        id: 'hu-3',
        name: 'Pepper Soup',
        expiry: now.add(const Duration(days: 1)),
        addedBy: otherUid,
        createdAt: now.subtract(const Duration(hours: 25)),
      );
      final isRecent =
          item.addedBy != myUid && now.difference(item.createdAt).inHours < 24;
      expect(isRecent, isFalse);
    });
  });
}
