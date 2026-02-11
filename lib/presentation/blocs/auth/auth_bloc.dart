import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/registration_data.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  RegistrationData _registrationData = const RegistrationData();

  AuthBloc({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository(),
        super(AuthInitial()) {
    on<SignUpInfoSubmitted>(_onSignUpInfoSubmitted);
    on<ProfileDetailsSubmitted>(_onProfileDetailsSubmitted);
    on<SecuritySetupSubmitted>(_onSecuritySetupSubmitted);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<GoogleProfileDetailsSubmitted>(_onGoogleProfileDetailsSubmitted);
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

    _registrationData = _registrationData.copyWith(password: event.password);

    emit(AuthLoading());

    try {
      await _authRepository.registerWithEmailAndPassword(_registrationData);
      _registrationData = const RegistrationData();
      emit(RegistrationSuccess());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code),
          registrationData: _registrationData));
    } catch (e) {
      final message = e.toString();
      // Check if it's a Firebase error with a code we can extract
      if (e is FirebaseException) {
        emit(AuthError(_mapFirebaseError(e.code),
            registrationData: _registrationData));
      } else {
        emit(AuthError(message, registrationData: _registrationData));
      }
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
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

      if (result.isNewUser ||
          !(await _authRepository.userProfileExists(user.uid))) {
        emit(GoogleSignInSuccess(_registrationData));
      } else {
        _registrationData = const RegistrationData();
        emit(RegistrationSuccess());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
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
      _registrationData = const RegistrationData();
      emit(RegistrationSuccess());
    } catch (e) {
      emit(AuthError(e.toString(), registrationData: _registrationData));
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
