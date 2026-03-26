// Unit tests for AuthEvent classes
//
// Tests cover:
//   - All event constructors and field assignments
//   - props equality for equatable
//   - Default values

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/presentation/blocs/auth/auth_event.dart';

void main() {
  group('SignUpInfoSubmitted', () {
    test('stores firstName, lastName, email', () {
      const e = SignUpInfoSubmitted(
        firstName: 'Lydia',
        lastName: 'Ojoawo',
        email: 'lydia@example.com',
      );
      expect(e.firstName, 'Lydia');
      expect(e.lastName, 'Ojoawo');
      expect(e.email, 'lydia@example.com');
    });

    test('props contains all fields', () {
      const e = SignUpInfoSubmitted(
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.com',
      );
      expect(e.props, ['A', 'B', 'a@b.com']);
    });

    test('two equal instances are equal', () {
      const e1 = SignUpInfoSubmitted(
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.com',
      );
      const e2 = SignUpInfoSubmitted(
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.com',
      );
      expect(e1, equals(e2));
    });
  });

  group('ProfileDetailsSubmitted', () {
    test('stores occupation and country', () {
      const e = ProfileDetailsSubmitted(
        occupation: 'Student',
        country: 'Nigeria',
      );
      expect(e.occupation, 'Student');
      expect(e.country, 'Nigeria');
    });

    test('props contains occupation and country', () {
      const e = ProfileDetailsSubmitted(
        occupation: 'Engineer',
        country: 'Ghana',
      );
      expect(e.props, ['Engineer', 'Ghana']);
    });
  });

  group('SecuritySetupSubmitted', () {
    test('stores password and confirmPassword', () {
      const e = SecuritySetupSubmitted(
        password: 'test-password-value',
        confirmPassword: 'test-password-value',
      );
      expect(e.password, 'test-password-value');
      expect(e.confirmPassword, 'test-password-value');
    });

    test('props contains password fields', () {
      const e = SecuritySetupSubmitted(
        password: 'test-password-value',
        confirmPassword: 'test-password-value',
      );
      expect(e.props, ['test-password-value', 'test-password-value']);
    });
  });

  group('GoogleSignInRequested', () {
    test('default isSignUp is false', () {
      const e = GoogleSignInRequested();
      expect(e.isSignUp, isFalse);
    });

    test('isSignUp can be set to true', () {
      const e = GoogleSignInRequested(isSignUp: true);
      expect(e.isSignUp, isTrue);
    });

    test('props contains isSignUp', () {
      const e = GoogleSignInRequested(isSignUp: true);
      expect(e.props, [true]);
    });
  });

  group('GoogleProfileDetailsSubmitted', () {
    test('stores occupation and country', () {
      const e = GoogleProfileDetailsSubmitted(
        occupation: 'Developer',
        country: 'Kenya',
      );
      expect(e.occupation, 'Developer');
      expect(e.country, 'Kenya');
    });

    test('props contains both fields', () {
      const e = GoogleProfileDetailsSubmitted(
        occupation: 'Developer',
        country: 'Kenya',
      );
      expect(e.props, ['Developer', 'Kenya']);
    });
  });

  group('VerificationCodeSent', () {
    test('stores email and firstName', () {
      const e = VerificationCodeSent(email: 'test@test.com', firstName: 'Test');
      expect(e.email, 'test@test.com');
      expect(e.firstName, 'Test');
    });

    test('props contains email and firstName', () {
      const e = VerificationCodeSent(email: 'test@test.com', firstName: 'Test');
      expect(e.props, ['test@test.com', 'Test']);
    });
  });

  group('VerificationCodeSubmitted', () {
    test('stores email and code', () {
      const e = VerificationCodeSubmitted(email: 'test@test.com', code: '1234');
      expect(e.email, 'test@test.com');
      expect(e.code, '1234');
    });

    test('props contains email and code', () {
      const e = VerificationCodeSubmitted(email: 'test@test.com', code: '5678');
      expect(e.props, ['test@test.com', '5678']);
    });
  });

  group('ResendVerificationCode', () {
    test('stores email and firstName', () {
      const e = ResendVerificationCode(
        email: 'test@test.com',
        firstName: 'Test',
      );
      expect(e.email, 'test@test.com');
      expect(e.firstName, 'Test');
    });
  });

  group('SignInSubmitted', () {
    test('stores email and password', () {
      const e = SignInSubmitted(
        email: 'user@example.com',
        password: 'test-password-value',
      );
      expect(e.email, 'user@example.com');
      expect(e.password, 'test-password-value');
    });

    test('props contains email and password', () {
      const e = SignInSubmitted(
        email: 'user@example.com',
        password: 'test-password-value',
      );
      expect(e.props, ['user@example.com', 'test-password-value']);
    });
  });

  group('ForgotPasswordSubmitted', () {
    test('stores email', () {
      const e = ForgotPasswordSubmitted(email: 'forgot@example.com');
      expect(e.email, 'forgot@example.com');
    });

    test('props contains email', () {
      const e = ForgotPasswordSubmitted(email: 'forgot@example.com');
      expect(e.props, ['forgot@example.com']);
    });
  });

  group('RegistrationStepBack', () {
    test('can be instantiated', () {
      final e = RegistrationStepBack();
      expect(e, isA<RegistrationStepBack>());
    });

    test('props is empty', () {
      final e = RegistrationStepBack();
      expect(e.props, isEmpty);
    });
  });

  group('RegistrationReset', () {
    test('can be instantiated', () {
      final e = RegistrationReset();
      expect(e, isA<RegistrationReset>());
    });

    test('props is empty', () {
      final e = RegistrationReset();
      expect(e.props, isEmpty);
    });
  });

  group('ForgotPasswordOtpRequested', () {
    test('stores email', () {
      const e = ForgotPasswordOtpRequested(email: 'otp@example.com');
      expect(e.email, 'otp@example.com');
    });

    test('props contains email', () {
      const e = ForgotPasswordOtpRequested(email: 'otp@example.com');
      expect(e.props, ['otp@example.com']);
    });
  });

  group('ForgotPasswordOtpVerified', () {
    test('stores email and otp', () {
      const e = ForgotPasswordOtpVerified(email: 'test@test.com', otp: '1234');
      expect(e.email, 'test@test.com');
      expect(e.otp, '1234');
    });

    test('props contains email and otp', () {
      const e = ForgotPasswordOtpVerified(email: 'test@test.com', otp: '5678');
      expect(e.props, ['test@test.com', '5678']);
    });
  });

  group('ForgotPasswordReset', () {
    test('stores email, newPassword, resetToken', () {
      const e = ForgotPasswordReset(
        email: 'test@test.com',
        newPassword: 'test-new-password',
        resetToken: 'token123',
      );
      expect(e.email, 'test@test.com');
      expect(e.newPassword, 'test-new-password');
      expect(e.resetToken, 'token123');
    });

    test('props contains all three fields', () {
      const e = ForgotPasswordReset(
        email: 'test@test.com',
        newPassword: 'test-new-password',
        resetToken: 'token123',
      );
      expect(e.props, ['test@test.com', 'test-new-password', 'token123']);
    });
  });
}
