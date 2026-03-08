// Integration tests — Authentication flow
//
// These tests verify the interaction between AuthBloc, AuthRepository,
// VerificationService, and ConnectivityService as a system.
//
// All external services (Firebase, network) are mocked so tests run
// fully offline without any real infrastructure.

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:sabitrak/data/repositories/auth_repository.dart';
import 'package:sabitrak/presentation/blocs/auth/auth_bloc.dart';
import 'package:sabitrak/presentation/blocs/auth/auth_event.dart';
import 'package:sabitrak/presentation/blocs/auth/auth_state.dart';
import 'package:sabitrak/services/connectivity_service.dart';
import 'package:sabitrak/services/password_reset_service.dart';
import 'package:sabitrak/services/verification_service.dart';

// Re-use mocks generated for unit tests
import '../unit/auth_bloc_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuth;
  late MockVerificationService mockVerify;
  late MockPasswordResetService mockReset;
  late MockConnectivityService mockConn;

  setUp(() {
    mockAuth = MockAuthRepository();
    mockVerify = MockVerificationService();
    mockReset = MockPasswordResetService();
    mockConn = MockConnectivityService();
    when(mockConn.isConnected()).thenAnswer((_) async => true);
  });

  AuthBloc buildBloc() => AuthBloc(
    authRepository: mockAuth,
    verificationService: mockVerify,
    passwordResetService: mockReset,
    connectivityService: mockConn,
  );

  // ── Full registration flow ─────────────────────────────────────────────────

  group('Full registration flow (step 1 → 2 → 3 → verify)', () {
    blocTest<AuthBloc, AuthState>(
      'completes successfully: SignUpInfo → ProfileDetails → SecuritySetup → Verify',
      build: () {
        when(
          mockVerify.sendVerificationCode(
            email: anyNamed('email'),
            firstName: anyNamed('firstName'),
          ),
        ).thenAnswer((_) async {});

        when(
          mockVerify.verifyCode(
            email: anyNamed('email'),
            code: anyNamed('code'),
          ),
        ).thenAnswer((_) async => true);

        final mockUser = MockUser();
        when(mockUser.displayName).thenReturn('Ada Lovelace');
        when(mockUser.email).thenReturn('ada@test.com');
        when(
          mockAuth.registerWithEmailAndPassword(any),
        ).thenAnswer((_) async => mockUser);

        return buildBloc();
      },
      act: (bloc) {
        bloc.add(
          const SignUpInfoSubmitted(
            firstName: 'Ada',
            lastName: 'Lovelace',
            email: 'ada@test.com',
          ),
        );
        bloc.add(
          const ProfileDetailsSubmitted(
            occupation: 'Developer',
            country: 'Nigeria',
          ),
        );
        bloc.add(
          const SecuritySetupSubmitted(
            password: 'T3st_Fixture@99',
            confirmPassword: 'T3st_Fixture@99',
          ),
        );
        bloc.add(
          const VerificationCodeSubmitted(
            email: 'ada@test.com',
            code: '123456',
          ),
        );
      },
      expect:
          () => [
            isA<SignUpInfoCollected>(),
            isA<ProfileDetailsCollected>(),
            isA<AuthLoading>(), // SecuritySetupSubmitted loading
            isA<VerificationCodeSentSuccess>(),
            // VerificationCodeSubmitted emits AuthLoading then RegistrationSuccess;
            // the second AuthLoading is deduplicated by Equatable so only one AuthLoading total
            isA<RegistrationSuccess>().having(
              (s) => s.firstName,
              'firstName',
              'Ada',
            ),
          ],
    );

    blocTest<AuthBloc, AuthState>(
      'aborts at SecuritySetup when offline — no OTP sent',
      build: () {
        when(mockConn.isConnected()).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) {
        bloc.add(
          const SignUpInfoSubmitted(
            firstName: 'Ada',
            lastName: 'Lovelace',
            email: 'ada@test.com',
          ),
        );
        bloc.add(
          const ProfileDetailsSubmitted(
            occupation: 'Developer',
            country: 'Nigeria',
          ),
        );
        bloc.add(
          const SecuritySetupSubmitted(
            password: 'T3st_Fixture@99',
            confirmPassword: 'T3st_Fixture@99',
          ),
        );
      },
      expect:
          () => [
            isA<SignUpInfoCollected>(),
            isA<ProfileDetailsCollected>(),
            isA<AuthLoading>(),
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              contains('No internet'),
            ),
          ],
      verify: (_) {
        verifyNever(
          mockVerify.sendVerificationCode(
            email: anyNamed('email'),
            firstName: anyNamed('firstName'),
          ),
        );
      },
    );
  });

  // ── Step-back navigation ───────────────────────────────────────────────────

  group('Step-back navigation through registration', () {
    blocTest<AuthBloc, AuthState>(
      'stepping back from ProfileDetails returns to SignUpInfo',
      build: buildBloc,
      act: (bloc) {
        bloc.add(
          const SignUpInfoSubmitted(
            firstName: 'Ada',
            lastName: 'Lovelace',
            email: 'ada@test.com',
          ),
        );
        bloc.add(
          const ProfileDetailsSubmitted(
            occupation: 'Developer',
            country: 'Nigeria',
          ),
        );
        bloc.add(RegistrationStepBack());
      },
      expect:
          () => [
            isA<SignUpInfoCollected>(),
            isA<ProfileDetailsCollected>(),
            isA<SignUpInfoCollected>().having(
              (s) => s.registrationData.firstName,
              'firstName',
              'Ada',
            ),
          ],
    );

    blocTest<AuthBloc, AuthState>(
      'RegistrationReset from mid-flow returns to AuthInitial and clears data',
      build: buildBloc,
      act: (bloc) {
        bloc.add(
          const SignUpInfoSubmitted(
            firstName: 'Ada',
            lastName: 'Lovelace',
            email: 'ada@test.com',
          ),
        );
        bloc.add(
          const ProfileDetailsSubmitted(
            occupation: 'Developer',
            country: 'Nigeria',
          ),
        );
        bloc.add(RegistrationReset());
      },
      expect:
          () => [
            isA<SignUpInfoCollected>(),
            isA<ProfileDetailsCollected>(),
            isA<AuthInitial>(),
          ],
    );
  });

  // ── Sign-in flow ───────────────────────────────────────────────────────────

  group('Sign-in flow', () {
    blocTest<AuthBloc, AuthState>(
      'successful sign-in emits SignInSuccess with display name',
      build: () {
        final user = MockUser();
        when(user.displayName).thenReturn('Ada Lovelace');
        when(user.email).thenReturn('ada@test.com');
        when(
          mockAuth.signInWithEmailAndPassword(any, any),
        ).thenAnswer((_) async => user);
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const SignInSubmitted(
              email: 'ada@test.com',
              password: 'T3st_Fixture@99',
            ),
          ),
      expect:
          () => [
            isA<AuthLoading>(),
            isA<SignInSuccess>().having(
              (s) => s.displayName,
              'displayName',
              'Ada Lovelace',
            ),
          ],
    );

    blocTest<AuthBloc, AuthState>(
      'sign-in with invalid-credential maps to user-friendly error',
      build: () {
        when(
          mockAuth.signInWithEmailAndPassword(any, any),
        ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
        return buildBloc();
      },
      act:
          (bloc) => bloc.add(
            const SignInSubmitted(
              email: 'ada@test.com',
              password: 'Wrong_Fixture@1',
            ),
          ),
      expect:
          () => [
            isA<AuthLoading>(),
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              contains('Invalid email or password'),
            ),
          ],
    );
  });

  // ── Forgot-password OTP flow ───────────────────────────────────────────────

  group('Forgot-password full flow', () {
    blocTest<AuthBloc, AuthState>(
      'OTP request → verify → reset completes successfully',
      build: () {
        when(
          mockReset.sendOtp(email: anyNamed('email')),
        ).thenAnswer((_) async {});
        when(
          mockReset.verifyOtp(email: anyNamed('email'), code: anyNamed('code')),
        ).thenAnswer((_) async => true);
        when(
          mockReset.resetPassword(
            email: anyNamed('email'),
            newPassword: anyNamed('newPassword'),
            resetToken: anyNamed('resetToken'),
          ),
        ).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) {
        bloc.add(const ForgotPasswordOtpRequested(email: 'ada@test.com'));
        bloc.add(
          const ForgotPasswordOtpVerified(email: 'ada@test.com', otp: '4321'),
        );
        bloc.add(
          const ForgotPasswordReset(
            email: 'ada@test.com',
            newPassword: 'NewFixture@99',
            resetToken: '4321',
          ),
        );
      },
      expect:
          () => [
            isA<AuthLoading>(),
            isA<ForgotPasswordOtpSent>(),
            isA<AuthLoading>(),
            isA<ForgotPasswordOtpVerifiedState>(),
            isA<ForgotPasswordResetSuccess>(),
          ],
    );
  });
}
