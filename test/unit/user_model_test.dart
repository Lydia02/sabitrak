// Unit tests for UserModel
//
// Tests cover:
//   - Constructor and field assignment
//   - toFirestore() serialisation
//   - Default/optional photoUrl handling

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/models/user_model.dart';

void main() {
  final DateTime testDate = DateTime(2024, 1, 15, 10, 30);

  group('UserModel constructor', () {
    test('creates model with all required fields', () {
      final user = UserModel(
        id: 'uid123',
        firstName: 'Lydia',
        lastName: 'Ojoawo',
        email: 'lydia@example.com',
        occupation: 'Student',
        country: 'Nigeria',
        createdAt: testDate,
      );

      expect(user.id, 'uid123');
      expect(user.firstName, 'Lydia');
      expect(user.lastName, 'Ojoawo');
      expect(user.email, 'lydia@example.com');
      expect(user.occupation, 'Student');
      expect(user.country, 'Nigeria');
      expect(user.photoUrl, isNull);
      expect(user.createdAt, testDate);
    });

    test('creates model with optional photoUrl', () {
      final user = UserModel(
        id: 'uid456',
        firstName: 'Jane',
        lastName: 'Doe',
        email: 'jane@example.com',
        occupation: 'Engineer',
        country: 'Ghana',
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: testDate,
      );

      expect(user.photoUrl, 'https://example.com/photo.jpg');
    });
  });

  group('UserModel toFirestore()', () {
    test('serialises all fields correctly', () {
      final user = UserModel(
        id: 'uid123',
        firstName: 'Lydia',
        lastName: 'Ojoawo',
        email: 'lydia@example.com',
        occupation: 'Student',
        country: 'Nigeria',
        createdAt: testDate,
      );

      final map = user.toFirestore();

      expect(map['firstName'], 'Lydia');
      expect(map['lastName'], 'Ojoawo');
      expect(map['email'], 'lydia@example.com');
      expect(map['occupation'], 'Student');
      expect(map['country'], 'Nigeria');
      expect(map['photoUrl'], isNull);
      expect(map.containsKey('createdAt'), isTrue);
    });

    test('serialises photoUrl when present', () {
      final user = UserModel(
        id: 'uid456',
        firstName: 'Jane',
        lastName: 'Doe',
        email: 'jane@example.com',
        occupation: 'Engineer',
        country: 'Ghana',
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: testDate,
      );

      final map = user.toFirestore();
      expect(map['photoUrl'], 'https://example.com/photo.jpg');
    });

    test('does not include id in toFirestore map', () {
      final user = UserModel(
        id: 'uid123',
        firstName: 'Lydia',
        lastName: 'Ojoawo',
        email: 'lydia@example.com',
        occupation: 'Student',
        country: 'Nigeria',
        createdAt: testDate,
      );

      final map = user.toFirestore();
      expect(map.containsKey('id'), isFalse);
    });

    test('round-trip: toFirestore contains all expected keys', () {
      final user = UserModel(
        id: 'uid789',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        occupation: 'Developer',
        country: 'Kenya',
        createdAt: testDate,
      );

      final map = user.toFirestore();
      expect(
        map.keys.toSet(),
        containsAll([
          'firstName',
          'lastName',
          'email',
          'occupation',
          'country',
          'photoUrl',
          'createdAt',
        ]),
      );
    });
  });

  group('UserModel field validation', () {
    test('accepts empty string for optional fields gracefully', () {
      final user = UserModel(
        id: '',
        firstName: '',
        lastName: '',
        email: '',
        occupation: '',
        country: '',
        createdAt: testDate,
      );

      expect(user.id, '');
      expect(user.firstName, '');
    });

    test('createdAt is stored correctly', () {
      final specificDate = DateTime(2025, 6, 15, 12, 0, 0);
      final user = UserModel(
        id: 'uid',
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.com',
        occupation: 'X',
        country: 'Y',
        createdAt: specificDate,
      );

      expect(user.createdAt.year, 2025);
      expect(user.createdAt.month, 6);
      expect(user.createdAt.day, 15);
    });
  });
}
