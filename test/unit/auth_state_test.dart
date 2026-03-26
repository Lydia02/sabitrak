// Unit tests for AuthState classes
//
// Tests cover:
//   - All state constructors and field assignments
//   - props equality
//   - State type checks

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/models/registration_data.dart';
import 'package:sabitrak/presentation/blocs/auth/auth_state.dart';

const _reg = RegistrationData(
  firstName: 'Lydia',
  lastName: 'Ojoawo',
  email: 'lydia@example.com',
  occupation: 'Student',
  country: 'Nigeria',
  password: 'test-password-value',
);

void main() {
  group('AuthInitial', () {
    test('can be instantiated', () {
      expect(AuthInitial(), isA<AuthInitial>());
    });

    test('props is empty', () {
      expect(AuthInitial().props, isEmpty);
    });
  });

  group('AuthLoading', () {
    test('can be instantiated', () {
      expect(AuthLoading(), isA<AuthLoading>());
    });
  });

  group('SignUpInfoCollected', () {
    test('stores registrationData', () {
      final s = SignUpInfoCollected(_reg);
      expect(s.registrationData, _reg);
    });

    test('props contains registrationData', () {
      final s = SignUpInfoCollected(_reg);
      expect(s.props, [_reg]);
    });
  });

  group('ProfileDetailsCollected', () {
    test('stores registrationData', () {
      final s = ProfileDetailsCollected(_reg);
      expect(s.registrationData, _reg);
    });

    test('props contains registrationData', () {
      final s = ProfileDetailsCollected(_reg);
      expect(s.props, [_reg]);
    });
  });

  group('GoogleSignInSuccess', () {
    test('stores registrationData', () {
      final s = GoogleSignInSuccess(_reg);
      expect(s.registrationData, _reg);
    });
  });

  group('GoogleAccountAlreadyExists', () {
    test('can be instantiated', () {
      expect(
        const GoogleAccountAlreadyExists(),
        isA<GoogleAccountAlreadyExists>(),
      );
    });
  });

  group('GoogleSignUpRequired', () {
    test('can be instantiated', () {
      expect(const GoogleSignUpRequired(), isA<GoogleSignUpRequired>());
    });
  });

  group('RegistrationSuccess', () {
    test('stores email and firstName', () {
      const s = RegistrationSuccess(
        email: 'lydia@example.com',
        firstName: 'Lydia',
      );
      expect(s.email, 'lydia@example.com');
      expect(s.firstName, 'Lydia');
    });

    test('props contains email and firstName', () {
      const s = RegistrationSuccess(
        email: 'lydia@example.com',
        firstName: 'Lydia',
      );
      expect(s.props, ['lydia@example.com', 'Lydia']);
    });
  });

  group('VerificationCodeSentSuccess', () {
    test('stores email and firstName', () {
      const s = VerificationCodeSentSuccess(
        email: 'test@test.com',
        firstName: 'Test',
      );
      expect(s.email, 'test@test.com');
      expect(s.firstName, 'Test');
    });

    test('props contains email and firstName', () {
      const s = VerificationCodeSentSuccess(
        email: 'test@test.com',
        firstName: 'Test',
      );
      expect(s.props, ['test@test.com', 'Test']);
    });
  });

  group('SignInSuccess', () {
    test('stores displayName', () {
      const s = SignInSuccess(displayName: 'Lydia Ojoawo');
      expect(s.displayName, 'Lydia Ojoawo');
    });

    test('props contains displayName', () {
      const s = SignInSuccess(displayName: 'Lydia Ojoawo');
      expect(s.props, ['Lydia Ojoawo']);
    });
  });

  group('ForgotPasswordSuccess', () {
    test('can be instantiated', () {
      expect(ForgotPasswordSuccess(), isA<ForgotPasswordSuccess>());
    });
  });

  group('ForgotPasswordOtpSent', () {
    test('stores email', () {
      const s = ForgotPasswordOtpSent(email: 'otp@test.com');
      expect(s.email, 'otp@test.com');
    });

    test('props contains email', () {
      const s = ForgotPasswordOtpSent(email: 'otp@test.com');
      expect(s.props, ['otp@test.com']);
    });
  });

  group('ForgotPasswordOtpVerifiedState', () {
    test('stores email and otp', () {
      const s = ForgotPasswordOtpVerifiedState(
        email: 'test@test.com',
        otp: '1234',
      );
      expect(s.email, 'test@test.com');
      expect(s.otp, '1234');
    });

    test('props contains email and otp', () {
      const s = ForgotPasswordOtpVerifiedState(
        email: 'test@test.com',
        otp: '1234',
      );
      expect(s.props, ['test@test.com', '1234']);
    });
  });

  group('ForgotPasswordOtpFailed', () {
    test('stores message and email', () {
      const s = ForgotPasswordOtpFailed(
        message: 'Invalid OTP',
        email: 'test@test.com',
      );
      expect(s.message, 'Invalid OTP');
      expect(s.email, 'test@test.com');
    });

    test('props contains message and email', () {
      const s = ForgotPasswordOtpFailed(
        message: 'Invalid OTP',
        email: 'test@test.com',
      );
      expect(s.props, ['Invalid OTP', 'test@test.com']);
    });
  });

  group('ForgotPasswordResetSuccess', () {
    test('can be instantiated', () {
      expect(ForgotPasswordResetSuccess(), isA<ForgotPasswordResetSuccess>());
    });
  });

  group('VerificationSuccess', () {
    test('can be instantiated', () {
      expect(VerificationSuccess(), isA<VerificationSuccess>());
    });
  });

  group('VerificationFailed', () {
    test('stores message, email, firstName', () {
      const s = VerificationFailed(
        message: 'Wrong code',
        email: 'test@test.com',
        firstName: 'Test',
      );
      expect(s.message, 'Wrong code');
      expect(s.email, 'test@test.com');
      expect(s.firstName, 'Test');
    });

    test('props contains all fields', () {
      const s = VerificationFailed(
        message: 'Wrong code',
        email: 'test@test.com',
        firstName: 'Test',
      );
      expect(s.props, ['Wrong code', 'test@test.com', 'Test']);
    });
  });

  group('AuthError', () {
    test('stores message', () {
      const s = AuthError('Something went wrong');
      expect(s.message, 'Something went wrong');
    });

    test('registrationData defaults to null', () {
      const s = AuthError('Error');
      expect(s.registrationData, isNull);
    });

    test('stores optional registrationData', () {
      const s = AuthError('Error', registrationData: _reg);
      expect(s.registrationData, _reg);
    });

    test('props contains message and registrationData', () {
      const s = AuthError('Error', registrationData: _reg);
      expect(s.props, ['Error', _reg]);
    });
  });
}
