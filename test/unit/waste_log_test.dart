// Unit tests for WasteLog model
//
// Tests cover:
//   - Constructor field assignment
//   - toFirestore() serialisation (Timestamps, scalar fields)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/models/waste_log.dart';

WasteLog _makeLog() => WasteLog(
  id: 'log-1',
  itemId: 'item-99',
  itemName: 'Milk',
  category: 'Dairy',
  quantity: 2,
  unit: 'L',
  householdId: 'hh-001',
  addedBy: 'uid-abc',
  expiryDate: DateTime(2024, 3, 10),
  wastedAt: DateTime(2024, 3, 12),
);

void main() {
  group('WasteLog constructor', () {
    test('stores all fields', () {
      final log = _makeLog();
      expect(log.id, 'log-1');
      expect(log.itemId, 'item-99');
      expect(log.itemName, 'Milk');
      expect(log.category, 'Dairy');
      expect(log.quantity, 2);
      expect(log.unit, 'L');
      expect(log.householdId, 'hh-001');
      expect(log.addedBy, 'uid-abc');
      expect(log.expiryDate, DateTime(2024, 3, 10));
      expect(log.wastedAt, DateTime(2024, 3, 12));
    });
  });

  group('WasteLog toFirestore', () {
    test('serialises all scalar fields', () {
      final map = _makeLog().toFirestore();
      expect(map['itemId'], 'item-99');
      expect(map['itemName'], 'Milk');
      expect(map['category'], 'Dairy');
      expect(map['quantity'], 2);
      expect(map['unit'], 'L');
      expect(map['householdId'], 'hh-001');
      expect(map['addedBy'], 'uid-abc');
    });

    test('serialises expiryDate as Timestamp', () {
      final map = _makeLog().toFirestore();
      expect(map['expiryDate'], isA<Timestamp>());
      expect((map['expiryDate'] as Timestamp).toDate(), DateTime(2024, 3, 10));
    });

    test('serialises wastedAt as Timestamp', () {
      final map = _makeLog().toFirestore();
      expect(map['wastedAt'], isA<Timestamp>());
      expect((map['wastedAt'] as Timestamp).toDate(), DateTime(2024, 3, 12));
    });

    test('does not include id in serialised map', () {
      final map = _makeLog().toFirestore();
      expect(map.containsKey('id'), isFalse);
    });
  });
}
