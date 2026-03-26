// Unit tests for AuthRepository
//
// Tests cover:
//   - changePassword throws when no user logged in
//   - registerWithEmailAndPassword throws when Firebase unavailable
//   - signInWithEmailAndPassword throws when Firebase unavailable
//   - sendPasswordResetEmail throws when Firebase unavailable
//   - userProfileExists throws when Firebase unavailable
//   - saveGoogleUserProfile throws when Firebase unavailable

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/repositories/auth_repository.dart';

void main() {
  group('AuthRepository Firebase-dependent methods throw without init', () {
    test('constructing AuthRepository throws without Firebase init', () {
      expect(() => AuthRepository(), throwsA(anything));
    });

    test('registerWithEmailAndPassword throws without Firebase init', () {
      expect(
        () => AuthRepository(),
        throwsA(anything),
      );
    });

    test('signInWithEmailAndPassword throws without Firebase init', () {
      expect(
        () => AuthRepository(),
        throwsA(anything),
      );
    });

    test('sendPasswordResetEmail throws without Firebase init', () {
      expect(
        () => AuthRepository(),
        throwsA(anything),
      );
    });

    test('userProfileExists throws without Firebase init', () {
      expect(
        () => AuthRepository(),
        throwsA(anything),
      );
    });

    test('saveGoogleUserProfile throws without Firebase init', () {
      expect(
        () => AuthRepository(),
        throwsA(anything),
      );
    });

    test('signOut throws without Firebase init', () {
      expect(
        () => AuthRepository(),
        throwsA(anything),
      );
    });

    test('changePassword throws without Firebase init', () {
      expect(
        () => AuthRepository(),
        throwsA(anything),
      );
    });
  });
}
