// Unit tests for InventoryEvent classes
//
// Tests cover:
//   - All event constructors and field assignments
//   - props equality

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/presentation/blocs/inventory/inventory_event.dart';

void main() {
  group('LoadInventory', () {
    test('can be instantiated', () {
      expect(LoadInventory(), isA<LoadInventory>());
    });

    test('props is empty', () {
      expect(LoadInventory().props, isEmpty);
    });

    test('two instances are equal', () {
      expect(LoadInventory(), equals(LoadInventory()));
    });
  });

  group('AddFoodItem', () {
    final expiry = DateTime(2024, 12, 31);

    test('stores name, barcode, expiryDate', () {
      final e = AddFoodItem(
        name: 'Milk',
        barcode: '123456',
        expiryDate: expiry,
      );
      expect(e.name, 'Milk');
      expect(e.barcode, '123456');
      expect(e.expiryDate, expiry);
    });

    test('props contains all three fields', () {
      final e = AddFoodItem(
        name: 'Milk',
        barcode: '123456',
        expiryDate: expiry,
      );
      expect(e.props, ['Milk', '123456', expiry]);
    });

    test('two equal instances are equal', () {
      final e1 = AddFoodItem(name: 'Rice', barcode: '789', expiryDate: expiry);
      final e2 = AddFoodItem(name: 'Rice', barcode: '789', expiryDate: expiry);
      expect(e1, equals(e2));
    });
  });

  group('RemoveFoodItem', () {
    test('stores itemId', () {
      const e = RemoveFoodItem('item-42');
      expect(e.itemId, 'item-42');
    });

    test('props contains itemId', () {
      const e = RemoveFoodItem('item-42');
      expect(e.props, ['item-42']);
    });

    test('two instances with same id are equal', () {
      expect(const RemoveFoodItem('x'), equals(const RemoveFoodItem('x')));
    });

    test('two instances with different ids are not equal', () {
      expect(
        const RemoveFoodItem('a'),
        isNot(equals(const RemoveFoodItem('b'))),
      );
    });
  });
}
