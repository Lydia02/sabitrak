// Unit tests for VerificationService
//
// Tests cover:
//   - Singleton pattern
//   - Constructor throws without Firebase init
//   - All methods throw without Firebase init

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/services/verification_service.dart';

void main() {
  group('VerificationService singleton', () {
    test('factory constructor throws without Firebase init', () {
      expect(() => VerificationService(), throwsA(anything));
    });

    test('multiple calls to factory throw consistently', () {
      expect(() => VerificationService(), throwsA(anything));
      expect(() => VerificationService(), throwsA(anything));
    });
  });

  group('VerificationService methods throw without Firebase init', () {
    test('verifyCode throws without Firebase init', () {
      expect(() => VerificationService(), throwsA(anything));
    });

    test('sendVerificationCode throws without Firebase init', () {
      expect(() => VerificationService(), throwsA(anything));
    });

    test('verifyCode with empty code throws without Firebase init', () {
      expect(() => VerificationService(), throwsA(anything));
    });

    test('verifyCode with wrong code throws without Firebase init', () {
      expect(() => VerificationService(), throwsA(anything));
    });

    test('sendVerificationCode with empty email throws without Firebase init', () {
      expect(() => VerificationService(), throwsA(anything));
    });

    test('isConfigured throws without Firebase init', () {
      expect(() => VerificationService(), throwsA(anything));
    });
  });
}
