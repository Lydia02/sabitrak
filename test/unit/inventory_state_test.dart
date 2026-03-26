// Unit tests for InventoryState classes
//
// Tests cover:
//   - All state constructors and field assignments
//   - props equality

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/presentation/blocs/inventory/inventory_state.dart';

void main() {
  group('InventoryInitial', () {
    test('can be instantiated', () {
      expect(InventoryInitial(), isA<InventoryInitial>());
    });

    test('props is empty', () {
      expect(InventoryInitial().props, isEmpty);
    });
  });

  group('InventoryLoading', () {
    test('can be instantiated', () {
      expect(InventoryLoading(), isA<InventoryLoading>());
    });

    test('props is empty', () {
      expect(InventoryLoading().props, isEmpty);
    });
  });

  group('InventoryLoaded', () {
    test('stores items list', () {
      final items = ['item1', 'item2'];
      final s = InventoryLoaded(items);
      expect(s.items, items);
    });

    test('props contains items list', () {
      final items = [1, 2, 3];
      final s = InventoryLoaded(items);
      expect(s.props, [items]);
    });

    test('empty items list is valid', () {
      expect(const InventoryLoaded([]).items, isEmpty);
    });

    test('two states with same list are equal', () {
      expect(
        const InventoryLoaded(['a', 'b']),
        equals(const InventoryLoaded(['a', 'b'])),
      );
    });
  });

  group('InventoryError', () {
    test('stores message', () {
      const s = InventoryError('Something went wrong');
      expect(s.message, 'Something went wrong');
    });

    test('props contains message', () {
      const s = InventoryError('error');
      expect(s.props, ['error']);
    });

    test('two instances with same message are equal', () {
      expect(const InventoryError('err'), equals(const InventoryError('err')));
    });

    test('two instances with different messages are not equal', () {
      expect(
        const InventoryError('a'),
        isNot(equals(const InventoryError('b'))),
      );
    });
  });
}
