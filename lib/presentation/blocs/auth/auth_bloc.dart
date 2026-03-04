import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/registration_data.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/verification_service.dart';
import '../../../services/password_reset_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final VerificationService _verificationService;
  final PasswordResetService _passwordResetService;
  late final ConnectivityService _connectivity;
  RegistrationData _registrationData = const RegistrationData();

  AuthBloc({
    AuthRepository? authRepository,
    VerificationService? verificationService,
    PasswordResetService? passwordResetService,
    ConnectivityService? connectivityService,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _verificationService = verificationService ?? VerificationService(),
        _passwordResetService = passwordResetService ?? PasswordResetService(),
        super(AuthInitial()) {
    _connectivity = connectivityService ?? ConnectivityService();
    on<SignUpInfoSubmitted>(_onSignUpInfoSubmitted);
    on<ProfileDetailsSubmitted>(_onProfileDetailsSubmitted);
    on<SecuritySetupSubmitted>(_onSecuritySetupSubmitted);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<GoogleProfileDetailsSubmitted>(_onGoogleProfileDetailsSubmitted);
    on<VerificationCodeSent>(_onVerificationCodeSent);
    on<VerificationCodeSubmitted>(_onVerificationCodeSubmitted);
    on<ResendVerificationCode>(_onResendVerificationCode);
    on<SignInSubmitted>(_onSignInSubmitted);
    on<ForgotPasswordSubmitted>(_onForgotPasswordSubmitted);
    on<ForgotPasswordOtpRequested>(_onForgotPasswordOtpRequested);
    on<ForgotPasswordOtpVerified>(_onForgotPasswordOtpVerified);
    on<ForgotPasswordReset>(_onForgotPasswordReset);
    on<RegistrationStepBack>(_onRegistrationStepBack);
    on<RegistrationReset>(_onRegistrationReset);
  }

  void _onSignUpInfoSubmitted(
    SignUpInfoSubmitted event,
    Emitter<AuthState> emit,
  ) {
    _registrationData = _registrationData.copyWith(
      firstName: event.firstName,
      lastName: event.lastName,
      email: event.email,
    );
    emit(SignUpInfoCollected(_registrationData));
  }

  void _onProfileDetailsSubmitted(
    ProfileDetailsSubmitted event,
    Emitter<AuthState> emit,
  ) {
    _registrationData = _registrationData.copyWith(
      occupation: event.occupation,
      country: event.country,
    );
    emit(ProfileDetailsCollected(_registrationData));
  }

  Future<void> _onSecuritySetupSubmitted(
    SecuritySetupSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (event.password != event.confirmPassword) {
      emit(AuthError('Passwords do not match',
          registrationData: _registrationData));
      return;
    }

    if (!_isPasswordValid(event.password)) {
      emit(AuthError(
          'Password must be at least 8 characters, including a number and a symbol',
          registrationData: _registrationData));
      return;
    }

    // Save password but do NOT create account yet — wait for email verification
    _registrationData = _registrationData.copyWith(password: event.password);

    emit(AuthLoading());

    if (!await _connectivity.isConnected()) {
      emit(AuthError('No internet connection. Please check your network and try again.',
          registrationData: _registrationData));
      return;
    }

    try {
      // Send OTP — account creation happens AFTER verification succeeds
      await _verificationService.sendVerificationCode(
        email: _registrationData.email,
        firstName: _registrationData.firstName,
      );
      emit(VerificationCodeSentSuccess(
        email: _registrationData.email,
        firstName: _registrationData.firstName,
      ));
    } catch (e) {
      if (_isNetworkError(e)) {
        emit(AuthError('No internet connection. Please check your network and try again.',
            registrationData: _registrationData));
      } else {
        emit(AuthError('Failed to send verification code. Please try again.',
            registrationData: _registrationData));
      }
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(const AuthError('No internet connection. Please check your network and try again.'));
      return;
    }
    try {
      final result = await _authRepository.signInWithGoogle();
      final user = result.user;

      final nameParts = (user.displayName ?? '').split(' ');
      _registrationData = RegistrationData(
        firstName: nameParts.isNotEmpty ? nameParts.first : '',
        lastName:
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
        email: user.email ?? '',
      );

      final profileExists = await _authRepository.userProfileExists(user.uid);

      if (event.isSignUp) {
        // Called from the signup screen
        if (!result.isNewUser && profileExists) {
          // Account already fully registered — tell user to log in
          // Delete the newly created Firebase session (don't keep them logged in)
          await _authRepository.signOut();
          _registrationData = const RegistrationData();
          emit(const GoogleAccountAlreadyExists());
        } else {
          // New Google user — store pending UID so splash can clean up if abandoned
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_google_uid', user.uid);
          emit(GoogleSignInSuccess(_registrationData));
        }
      } else {
        // Called from sign-in screen — existing user logging in
        if (profileExists) {
          final email = _registrationData.email;
          final firstName = _registrationData.firstName;
          _registrationData = const RegistrationData();
          emit(SignInSuccess(displayName: firstName.isNotEmpty ? firstName : email));
        } else {
          // Google account exists in Firebase Auth but has NO SabiTrak profile —
          // they never completed signup. Sign them out and prompt to create an account.
          await _authRepository.signOut();
          _registrationData = const RegistrationData();
          emit(const GoogleSignUpRequired());
        }
      }
    } catch (e) {
      if (_isNetworkError(e)) {
        emit(const AuthError('No internet connection. Please check your network and try again.'));
      } else {
        emit(AuthError(e.toString()));
      }
    }
  }

  Future<void> _onGoogleProfileDetailsSubmitted(
    GoogleProfileDetailsSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    _registrationData = _registrationData.copyWith(
      occupation: event.occupation,
      country: event.country,
    );

    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(AuthError('No internet connection. Please check your network and try again.',
          registrationData: _registrationData));
      return;
    }
    try {
      final user = _authRepository.currentUser;
      await _authRepository.saveGoogleUserProfile(
        uid: user!.uid,
        firstName: _registrationData.firstName,
        lastName: _registrationData.lastName,
        email: _registrationData.email,
        occupation: _registrationData.occupation,
        country: _registrationData.country,
        photoUrl: user.photoURL,
      );
      // Profile saved — clear pending flag (Google signup is now complete)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_google_uid');
      final email = _registrationData.email;
      final firstName = _registrationData.firstName;
      _registrationData = const RegistrationData();
      emit(RegistrationSuccess(email: email, firstName: firstName));
    } catch (e) {
      if (_isNetworkError(e)) {
        emit(AuthError('No internet connection. Please check your network and try again.',
            registrationData: _registrationData));
      } else {
        emit(AuthError(e.toString(), registrationData: _registrationData));
      }
    }
  }

  Future<void> _onVerificationCodeSent(
    VerificationCodeSent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(VerificationFailed(
        message: 'No internet connection. Please check your network and try again.',
        email: event.email,
        firstName: event.firstName,
      ));
      return;
    }
    try {
      await _verificationService.sendVerificationCode(
        email: event.email,
        firstName: event.firstName,
      );
      emit(VerificationCodeSentSuccess(
        email: event.email,
        firstName: event.firstName,
      ));
    } catch (e) {
      emit(VerificationFailed(
        message: _isNetworkError(e)
            ? 'No internet connection. Please check your network and try again.'
            : 'Failed to send verification code. Please try again.',
        email: event.email,
        firstName: event.firstName,
      ));
    }
  }

  Future<void> _onVerificationCodeSubmitted(
    VerificationCodeSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(VerificationFailed(
        message: 'No internet connection. Please check your network and try again.',
        email: event.email,
        firstName: '',
      ));
      return;
    }
    try {
      final isValid = await _verificationService.verifyCode(
        email: event.email,
        code: event.code,
      );

      if (isValid) {
        // OTP verified — now create the Firebase account if password is set
        if (_registrationData.password.isNotEmpty) {
          try {
            await _authRepository.registerWithEmailAndPassword(_registrationData);
            final email = _registrationData.email;
            final firstName = _registrationData.firstName;
            _registrationData = const RegistrationData();
            emit(RegistrationSuccess(email: email, firstName: firstName));
          } on FirebaseAuthException catch (e) {
            emit(AuthError(_mapFirebaseError(e.code)));
          } catch (e) {
            emit(AuthError('Account creation failed: $e'));
          }
        } else {
          // No password means this is just a standalone verification (not signup)
          emit(VerificationSuccess());
        }
      } else {
        emit(VerificationFailed(
          message: 'Code is invalid or expired. Please check or request a new one.',
          email: event.email,
          firstName: '',
        ));
      }
    } catch (e) {
      emit(VerificationFailed(
        message: _isNetworkError(e)
            ? 'No internet connection. Please check your network and try again.'
            : 'Verification failed. Please try again.',
        email: event.email,
        firstName: '',
      ));
    }
  }

  Future<void> _onResendVerificationCode(
    ResendVerificationCode event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(VerificationFailed(
        message: 'No internet connection. Please check your network and try again.',
        email: event.email,
        firstName: event.firstName,
      ));
      return;
    }
    try {
      await _verificationService.sendVerificationCode(
        email: event.email,
        firstName: event.firstName,
      );
      emit(VerificationCodeSentSuccess(
        email: event.email,
        firstName: event.firstName,
      ));
    } catch (e) {
      emit(VerificationFailed(
        message: _isNetworkError(e)
            ? 'No internet connection. Please check your network and try again.'
            : 'Failed to resend code. Please try again.',
        email: event.email,
        firstName: event.firstName,
      ));
    }
  }

  Future<void> _onSignInSubmitted(
    SignInSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(const AuthError('No internet connection. Please check your network and try again.'));
      return;
    }
    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        event.email,
        event.password,
      );
      emit(SignInSuccess(displayName: user.displayName ?? user.email ?? ''));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapSignInError(e.code)));
    } catch (e) {
      if (_isNetworkError(e)) {
        emit(const AuthError('No internet connection. Please check your network and try again.'));
      } else {
        emit(AuthError(e.toString()));
      }
    }
  }

  Future<void> _onForgotPasswordSubmitted(
    ForgotPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(const AuthError('No internet connection. Please check your network and try again.'));
      return;
    }
    try {
      await _authRepository.sendPasswordResetEmail(event.email);
      emit(ForgotPasswordSuccess());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapSignInError(e.code)));
    } catch (e) {
      if (_isNetworkError(e)) {
        emit(const AuthError('No internet connection. Please check your network and try again.'));
      } else {
        emit(AuthError(e.toString()));
      }
    }
  }

  // Step 1 — send OTP email
  Future<void> _onForgotPasswordOtpRequested(
    ForgotPasswordOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(const AuthError('No internet connection. Please check your network and try again.'));
      return;
    }
    try {
      await _passwordResetService.sendOtp(email: event.email);
      emit(ForgotPasswordOtpSent(email: event.email));
    } catch (e) {
      if (_isNetworkError(e)) {
        emit(const AuthError('No internet connection. Please check your network and try again.'));
      } else {
        emit(AuthError(e.toString()));
      }
    }
  }

  // Step 2 — verify OTP
  Future<void> _onForgotPasswordOtpVerified(
    ForgotPasswordOtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(ForgotPasswordOtpFailed(
        message: 'No internet connection. Please check your network and try again.',
        email: event.email,
      ));
      return;
    }
    try {
      final valid = await _passwordResetService.verifyOtp(
        email: event.email,
        code: event.otp,
      );
      if (valid) {
        emit(ForgotPasswordOtpVerifiedState(email: event.email, otp: event.otp));
      } else {
        emit(ForgotPasswordOtpFailed(
          message: 'Invalid or expired code. Please try again.',
          email: event.email,
        ));
      }
    } catch (e) {
      emit(ForgotPasswordOtpFailed(
        message: _isNetworkError(e)
            ? 'No internet connection. Please check your network and try again.'
            : 'Verification failed. Please try again.',
        email: event.email,
      ));
    }
  }

  // Step 3 — call Cloud Function to update password after OTP is verified
  Future<void> _onForgotPasswordReset(
    ForgotPasswordReset event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await _connectivity.isConnected()) {
      emit(const AuthError('No internet connection. Please check your network and try again.'));
      return;
    }
    try {
      await _passwordResetService.resetPassword(
        email: event.email,
        newPassword: event.newPassword,
        resetToken: event.resetToken,
      );
      emit(ForgotPasswordResetSuccess());
    } catch (e) {
      if (_isNetworkError(e)) {
        emit(const AuthError('No internet connection. Please check your network and try again.'));
      } else {
        emit(AuthError(e.toString()));
      }
    }
  }


  String _mapSignInError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Sign in failed. Please try again.';
    }
  }

  void _onRegistrationStepBack(
    RegistrationStepBack event,
    Emitter<AuthState> emit,
  ) {
    if (state is ProfileDetailsCollected) {
      emit(SignUpInfoCollected(_registrationData));
    } else if (state is SignUpInfoCollected || state is GoogleSignInSuccess) {
      emit(AuthInitial());
    }
  }

  void _onRegistrationReset(
    RegistrationReset event,
    Emitter<AuthState> emit,
  ) {
    _registrationData = const RegistrationData();
    emit(AuthInitial());
  }

  /// Returns true for socket/network-level failures (no connectivity).
  bool _isNetworkError(Object e) {
    if (e is SocketException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('unreachable') ||
        msg.contains('failed host lookup') ||
        msg.contains('no address associated');
  }

  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      default:
        return 'Registration failed. Please try again.';
    }
  }
}
