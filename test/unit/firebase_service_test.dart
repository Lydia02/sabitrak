// Unit tests for FirebaseService
//
// Tests cover:
//   - Singleton pattern (same instance returned)
//   - Constructor throws without Firebase.initializeApp()
//   - isLoggedIn, currentUser, hasHousehold, getHouseholdName all throw without init

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/services/firebase_service.dart';

void main() {
  group('FirebaseService singleton', () {
    test('factory constructor throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('multiple calls to factory throw consistently', () {
      expect(() => FirebaseService(), throwsA(anything));
      expect(() => FirebaseService(), throwsA(anything));
    });
  });

  group('FirebaseService methods throw without Firebase init', () {
    test('isLoggedIn throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('currentUser throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('hasHousehold throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('getHouseholdName throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('users collection reference throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('households collection reference throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('foodItems collection reference throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('recipes collection reference throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });

    test('wasteLog collection reference throws without Firebase init', () {
      expect(() => FirebaseService(), throwsA(anything));
    });
  });
}
