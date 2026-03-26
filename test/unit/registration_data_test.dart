// Unit tests for RegistrationData model
//
// Tests cover:
//   - Default field values
//   - Constructor field assignment
//   - copyWith() partial and full updates
//   - props equality (Equatable)

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/models/registration_data.dart';

void main() {
  const full = RegistrationData(
    firstName: 'Lydia',
    lastName: 'Ojoawo',
    email: 'lydia@example.com',
    occupation: 'Engineer',
    country: 'Nigeria',
    password: 'fixture9.test',
  );

  group('RegistrationData defaults', () {
    test('default occupation is Student', () {
      const r = RegistrationData();
      expect(r.occupation, 'Student');
    });

    test('default country is Nigeria', () {
      const r = RegistrationData();
      expect(r.country, 'Nigeria');
    });

    test('default firstName, lastName, email, password are empty', () {
      const r = RegistrationData();
      expect(r.firstName, '');
      expect(r.lastName, '');
      expect(r.email, '');
      expect(r.password, '');
    });
  });

  group('RegistrationData constructor', () {
    test('stores all provided fields', () {
      expect(full.firstName, 'Lydia');
      expect(full.lastName, 'Ojoawo');
      expect(full.email, 'lydia@example.com');
      expect(full.occupation, 'Engineer');
      expect(full.country, 'Nigeria');
      expect(full.password, 'fixture9.test');
    });
  });

  group('RegistrationData props', () {
    test('props contains all six fields in order', () {
      expect(full.props, [
        'Lydia',
        'Ojoawo',
        'lydia@example.com',
        'Engineer',
        'Nigeria',
        'fixture9.test',
      ]);
    });

    test('two instances with same values are equal', () {
      const r1 = RegistrationData(
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.com',
        occupation: 'Dev',
        country: 'Ghana',
        password: 'pw',
      );
      const r2 = RegistrationData(
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.com',
        occupation: 'Dev',
        country: 'Ghana',
        password: 'pw',
      );
      expect(r1, equals(r2));
    });

    test('two instances with different values are not equal', () {
      const r1 = RegistrationData(firstName: 'A');
      const r2 = RegistrationData(firstName: 'B');
      expect(r1, isNot(equals(r2)));
    });
  });

  group('RegistrationData copyWith', () {
    test('copyWith with no args returns equal instance', () {
      final copy = full.copyWith();
      expect(copy, equals(full));
    });

    test('copyWith updates only firstName', () {
      final copy = full.copyWith(firstName: 'Ada');
      expect(copy.firstName, 'Ada');
      expect(copy.lastName, full.lastName);
      expect(copy.email, full.email);
      expect(copy.occupation, full.occupation);
      expect(copy.country, full.country);
      expect(copy.password, full.password);
    });

    test('copyWith updates only email', () {
      final copy = full.copyWith(email: 'new@example.com');
      expect(copy.email, 'new@example.com');
      expect(copy.firstName, full.firstName);
    });

    test('copyWith updates all fields at once', () {
      final copy = full.copyWith(
        firstName: 'X',
        lastName: 'Y',
        email: 'x@y.com',
        occupation: 'Student',
        country: 'Ghana',
        password: 'newPwd',
      );
      expect(copy.firstName, 'X');
      expect(copy.lastName, 'Y');
      expect(copy.email, 'x@y.com');
      expect(copy.occupation, 'Student');
      expect(copy.country, 'Ghana');
      expect(copy.password, 'newPwd');
    });

    test('copyWith returns new instance (not same reference)', () {
      final copy = full.copyWith(firstName: 'Z');
      expect(identical(full, copy), isFalse);
    });
  });
}
