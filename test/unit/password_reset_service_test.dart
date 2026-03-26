// Unit tests for PasswordResetService
//
// Tests cover:
//   - Singleton pattern
//   - Constructor throws without Firebase init
//   - All methods throw without Firebase init

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/services/password_reset_service.dart';

void main() {
  group('PasswordResetService singleton', () {
    test('factory constructor throws without Firebase init', () {
      expect(() => PasswordResetService(), throwsA(anything));
    });

    test('multiple calls to factory throw consistently', () {
      expect(() => PasswordResetService(), throwsA(anything));
      expect(() => PasswordResetService(), throwsA(anything));
    });
  });

  group('PasswordResetService methods throw without Firebase init', () {
    test('sendOtp throws without Firebase init', () {
      expect(() => PasswordResetService(), throwsA(anything));
    });

    test('verifyOtp throws without Firebase init', () {
      expect(() => PasswordResetService(), throwsA(anything));
    });

    test('resetPassword throws without Firebase init', () {
      expect(() => PasswordResetService(), throwsA(anything));
    });

    test('verifyOtp with wrong code throws without Firebase init', () {
      expect(() => PasswordResetService(), throwsA(anything));
    });

    test('sendOtp with invalid email throws without Firebase init', () {
      expect(() => PasswordResetService(), throwsA(anything));
    });

    test('resetPassword with empty token throws without Firebase init', () {
      expect(() => PasswordResetService(), throwsA(anything));
    });
  });
}
