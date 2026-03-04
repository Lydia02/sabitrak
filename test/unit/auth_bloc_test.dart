// Unit tests for AuthBloc using bloc_test and mockito
//
// Tests cover:
//   - Registration flow (sign-up info, profile details, security setup)
//   - Email verification flow
//   - Sign-in flow (success, invalid credentials, network errors)
//   - Google sign-in (new user, existing user, no profile)
//   - Forgot-password OTP flow
//   - Password validation rules
//   - Step-back / reset navigation events

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:sabitrak/data/repositories/auth_repository.dart';
import 'package:sabitrak/presentation/blocs/auth/auth_bloc.dart';
import 'package:sabitrak/presentation/blocs/auth/auth_event.dart';
import 'package:sabitrak/presentation/blocs/auth/auth_state.dart';
import 'package:sabitrak/services/connectivity_service.dart';
import 'package:sabitrak/services/password_reset_service.dart';
import 'package:sabitrak/services/verification_service.dart';

import 'auth_bloc_test.mocks.dart';

@GenerateMocks([
  AuthRepository,
  VerificationService,
  PasswordResetService,
  ConnectivityService,
  User,
])
void main() {
  late MockAuthRepository mockAuthRepository;
  late MockVerificationService mockVerificationService;
  late MockPasswordResetService mockPasswordResetService;
  late MockConnectivityService mockConnectivity;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockVerificationService = MockVerificationService();
    mockPasswordResetService = MockPasswordResetService();
    mockConnectivity = MockConnectivityService();

    // Default: online
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
  });

  AuthBloc buildBloc() => AuthBloc(
        authRepository: mockAuthRepository,
        verificationService: mockVerificationService,
        passwordResetService: mockPasswordResetService,
        connectivityService: mockConnectivity,
      );

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('starts as AuthInitial', () {
      expect(buildBloc().state, isA<AuthInitial>());
    });
  });

  // ── Registration: step 1 — sign-up info ───────────────────────────────────

  group('SignUpInfoSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'emits SignUpInfoCollected with provided data',
      build: buildBloc,
      act: (bloc) => bloc.add(const SignUpInfoSubmitted(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@example.com',
      )),
      expect: () => [
        isA<SignUpInfoCollected>()
            .having((s) => s.registrationData.firstName, 'firstName', 'Ada')
            .having((s) => s.registrationData.lastName, 'lastName', 'Lovelace')
            .having((s) => s.registrationData.email, 'email', 'ada@example.com'),
      ],
    );
  });

  // ── Registration: step 2 — profile details ────────────────────────────────

  group('ProfileDetailsSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'emits ProfileDetailsCollected with occupation and country',
      build: buildBloc,
      seed: () => AuthInitial(),
      act: (bloc) {
        bloc.add(const SignUpInfoSubmitted(
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: 'ada@example.com',
        ));
        bloc.add(const ProfileDetailsSubmitted(
          occupation: 'Engineer',
          country: 'Nigeria',
        ));
      },
      expect: () => [
        isA<SignUpInfoCollected>(),
        isA<ProfileDetailsCollected>()
            .having((s) => s.registrationData.occupation, 'occupation', 'Engineer')
            .having((s) => s.registrationData.country, 'country', 'Nigeria'),
      ],
    );
  });

  // ── Registration: step 3 — security setup ─────────────────────────────────

  group('SecuritySetupSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'emits AuthError when passwords do not match',
      build: buildBloc,
      act: (bloc) => bloc.add(const SecuritySetupSubmitted(
        password: 'Pass@1234',
        confirmPassword: 'Different@1',
      )),
      expect: () => [
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          contains('do not match'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError when password is too short',
      build: buildBloc,
      act: (bloc) => bloc.add(const SecuritySetupSubmitted(
        password: 'ab@1',
        confirmPassword: 'ab@1',
      )),
      expect: () => [
        isA<AuthError>().having((s) => s.message, 'message', contains('8 characters')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError when password has no number',
      build: buildBloc,
      act: (bloc) => bloc.add(const SecuritySetupSubmitted(
        password: 'Password@',
        confirmPassword: 'Password@',
      )),
      expect: () => [
        isA<AuthError>().having((s) => s.message, 'message', contains('number')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError when password has no symbol',
      build: buildBloc,
      act: (bloc) => bloc.add(const SecuritySetupSubmitted(
        password: 'Password1',
        confirmPassword: 'Password1',
      )),
      expect: () => [
        isA<AuthError>().having((s) => s.message, 'message', contains('symbol')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError when offline',
      build: () {
        when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SecuritySetupSubmitted(
        password: 'Pass@1234',
        confirmPassword: 'Pass@1234',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having((s) => s.message, 'message', contains('No internet')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits VerificationCodeSentSuccess when valid password and online',
      build: () {
        when(mockVerificationService.sendVerificationCode(
          email: anyNamed('email'),
          firstName: anyNamed('firstName'),
        )).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => AuthInitial(),
      act: (bloc) {
        bloc.add(const SignUpInfoSubmitted(
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: 'ada@example.com',
        ));
        bloc.add(const SecuritySetupSubmitted(
          password: 'Pass@1234',
          confirmPassword: 'Pass@1234',
        ));
      },
      expect: () => [
        isA<SignUpInfoCollected>(),
        isA<AuthLoading>(),
        isA<VerificationCodeSentSuccess>()
            .having((s) => s.email, 'email', 'ada@example.com'),
      ],
    );
  });

  // ── Email verification ─────────────────────────────────────────────────────

  group('VerificationCodeSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'emits RegistrationSuccess when code is valid and password set',
      build: () {
        when(mockVerificationService.verifyCode(
          email: anyNamed('email'),
          code: anyNamed('code'),
        )).thenAnswer((_) async => true);

        final mockUser = MockUser();
        when(mockUser.displayName).thenReturn('Ada Lovelace');
        when(mockUser.email).thenReturn('ada@example.com');
        when(mockAuthRepository.registerWithEmailAndPassword(any))
            .thenAnswer((_) async => mockUser);
        return buildBloc();
      },
      seed: () => AuthInitial(),
      act: (bloc) {
        // Set up registration data with password
        bloc.add(const SignUpInfoSubmitted(
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: 'ada@example.com',
        ));
        bloc.add(const ProfileDetailsSubmitted(
          occupation: 'Engineer',
          country: 'Nigeria',
        ));
        bloc.add(const SecuritySetupSubmitted(
          password: 'Pass@1234',
          confirmPassword: 'Pass@1234',
        ));
        bloc.add(const VerificationCodeSubmitted(
          email: 'ada@example.com',
          code: '1234',
        ));
      },
      skip: 4, // skip SignUpInfoCollected, ProfileDetailsCollected, AuthLoading, VerificationCodeSentSuccess
      // Note: VerificationCodeSubmitted's AuthLoading is Equatable-deduplicated
      // when running in multi-event bloc_test; only RegistrationSuccess is captured
      expect: () => [
        isA<RegistrationSuccess>()
            .having((s) => s.email, 'email', 'ada@example.com')
            .having((s) => s.firstName, 'firstName', 'Ada'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits VerificationFailed when code is invalid',
      build: () {
        when(mockVerificationService.verifyCode(
          email: anyNamed('email'),
          code: anyNamed('code'),
        )).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const VerificationCodeSubmitted(
        email: 'ada@example.com',
        code: '9999',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<VerificationFailed>().having(
          (s) => s.message,
          'message',
          contains('invalid or expired'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits VerificationFailed when offline',
      build: () {
        when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const VerificationCodeSubmitted(
        email: 'ada@example.com',
        code: '1234',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<VerificationFailed>().having(
          (s) => s.message,
          'message',
          contains('No internet'),
        ),
      ],
    );
  });

  // ── Sign-in ────────────────────────────────────────────────────────────────

  group('SignInSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'emits SignInSuccess on valid credentials',
      build: () {
        final mockUser = MockUser();
        when(mockUser.displayName).thenReturn('Ada Lovelace');
        when(mockUser.email).thenReturn('ada@example.com');
        when(mockAuthRepository.signInWithEmailAndPassword(any, any))
            .thenAnswer((_) async => mockUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SignInSubmitted(
        email: 'ada@example.com',
        password: 'Pass@1234',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<SignInSuccess>().having(
          (s) => s.displayName,
          'displayName',
          'Ada Lovelace',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError with user-friendly message on wrong-password',
      build: () {
        when(mockAuthRepository.signInWithEmailAndPassword(any, any))
            .thenThrow(FirebaseAuthException(code: 'wrong-password'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SignInSubmitted(
        email: 'ada@example.com',
        password: 'WrongPass@1',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          contains('Incorrect password'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError with user-friendly message on user-not-found',
      build: () {
        when(mockAuthRepository.signInWithEmailAndPassword(any, any))
            .thenThrow(FirebaseAuthException(code: 'user-not-found'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SignInSubmitted(
        email: 'nobody@example.com',
        password: 'Pass@1234',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          contains('No account found'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError when offline',
      build: () {
        when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SignInSubmitted(
        email: 'ada@example.com',
        password: 'Pass@1234',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having((s) => s.message, 'message', contains('No internet')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError on invalid-credential code',
      build: () {
        when(mockAuthRepository.signInWithEmailAndPassword(any, any))
            .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SignInSubmitted(
        email: 'ada@example.com',
        password: 'Pass@1234',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          contains('Invalid email or password'),
        ),
      ],
    );
  });

  // ── Google sign-in ─────────────────────────────────────────────────────────

  group('GoogleSignInRequested — sign-in flow', () {
    blocTest<AuthBloc, AuthState>(
      'emits SignInSuccess when existing user with profile signs in via Google',
      build: () {
        final mockUser = MockUser();
        when(mockUser.displayName).thenReturn('Ada Lovelace');
        when(mockUser.email).thenReturn('ada@example.com');
        when(mockUser.uid).thenReturn('uid-123');
        when(mockAuthRepository.signInWithGoogle())
            .thenAnswer((_) async => (user: mockUser, isNewUser: false));
        when(mockAuthRepository.userProfileExists('uid-123'))
            .thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GoogleSignInRequested(isSignUp: false)),
      expect: () => [
        isA<AuthLoading>(),
        isA<SignInSuccess>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits GoogleSignUpRequired when Google account has no SabiTrak profile',
      build: () {
        final mockUser = MockUser();
        when(mockUser.displayName).thenReturn('New User');
        when(mockUser.email).thenReturn('new@example.com');
        when(mockUser.uid).thenReturn('uid-new');
        when(mockAuthRepository.signInWithGoogle())
            .thenAnswer((_) async => (user: mockUser, isNewUser: false));
        when(mockAuthRepository.userProfileExists('uid-new'))
            .thenAnswer((_) async => false);
        when(mockAuthRepository.signOut()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GoogleSignInRequested(isSignUp: false)),
      expect: () => [
        isA<AuthLoading>(),
        isA<GoogleSignUpRequired>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError when offline',
      build: () {
        when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GoogleSignInRequested(isSignUp: false)),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having((s) => s.message, 'message', contains('No internet')),
      ],
    );
  });

  // ── Forgot password OTP flow ───────────────────────────────────────────────

  group('ForgotPasswordOtpRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits ForgotPasswordOtpSent on success',
      build: () {
        when(mockPasswordResetService.sendOtp(email: anyNamed('email')))
            .thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const ForgotPasswordOtpRequested(email: 'ada@example.com'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<ForgotPasswordOtpSent>()
            .having((s) => s.email, 'email', 'ada@example.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError when offline',
      build: () {
        when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const ForgotPasswordOtpRequested(email: 'ada@example.com'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having((s) => s.message, 'message', contains('No internet')),
      ],
    );
  });

  group('ForgotPasswordOtpVerified', () {
    blocTest<AuthBloc, AuthState>(
      'emits ForgotPasswordOtpVerifiedState when OTP is correct',
      build: () {
        when(mockPasswordResetService.verifyOtp(
          email: anyNamed('email'),
          code: anyNamed('code'),
        )).thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const ForgotPasswordOtpVerified(email: 'ada@example.com', otp: '5678'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<ForgotPasswordOtpVerifiedState>()
            .having((s) => s.email, 'email', 'ada@example.com')
            .having((s) => s.otp, 'otp', '5678'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits ForgotPasswordOtpFailed when OTP is wrong',
      build: () {
        when(mockPasswordResetService.verifyOtp(
          email: anyNamed('email'),
          code: anyNamed('code'),
        )).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const ForgotPasswordOtpVerified(email: 'ada@example.com', otp: '0000'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<ForgotPasswordOtpFailed>().having(
          (s) => s.message,
          'message',
          contains('Invalid or expired'),
        ),
      ],
    );
  });

  group('ForgotPasswordReset', () {
    blocTest<AuthBloc, AuthState>(
      'emits ForgotPasswordResetSuccess on success',
      build: () {
        when(mockPasswordResetService.resetPassword(
          email: anyNamed('email'),
          newPassword: anyNamed('newPassword'),
          resetToken: anyNamed('resetToken'),
        )).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ForgotPasswordReset(
        email: 'ada@example.com',
        newPassword: 'NewPass@99',
        resetToken: 'tok123',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<ForgotPasswordResetSuccess>(),
      ],
    );
  });

  // ── Navigation events ──────────────────────────────────────────────────────

  group('RegistrationStepBack', () {
    blocTest<AuthBloc, AuthState>(
      'goes back to SignUpInfoCollected from ProfileDetailsCollected',
      build: buildBloc,
      seed: () => AuthInitial(),
      act: (bloc) {
        bloc.add(const SignUpInfoSubmitted(
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: 'ada@example.com',
        ));
        bloc.add(const ProfileDetailsSubmitted(
          occupation: 'Engineer',
          country: 'Nigeria',
        ));
        bloc.add(RegistrationStepBack());
      },
      expect: () => [
        isA<SignUpInfoCollected>(),
        isA<ProfileDetailsCollected>(),
        isA<SignUpInfoCollected>(),
      ],
    );
  });

  group('RegistrationReset', () {
    blocTest<AuthBloc, AuthState>(
      'resets to AuthInitial from any state',
      build: buildBloc,
      seed: () => AuthInitial(),
      act: (bloc) {
        bloc.add(const SignUpInfoSubmitted(
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: 'ada@example.com',
        ));
        bloc.add(RegistrationReset());
      },
      expect: () => [
        isA<SignUpInfoCollected>(),
        isA<AuthInitial>(),
      ],
    );
  });
}
