import 'package:equatable/equatable.dart';
import '../../../data/models/registration_data.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class SignUpInfoCollected extends AuthState {
  final RegistrationData registrationData;

  const SignUpInfoCollected(this.registrationData);

  @override
  List<Object?> get props => [registrationData];
}

class ProfileDetailsCollected extends AuthState {
  final RegistrationData registrationData;

  const ProfileDetailsCollected(this.registrationData);

  @override
  List<Object?> get props => [registrationData];
}

class GoogleSignInSuccess extends AuthState {
  final RegistrationData registrationData;

  const GoogleSignInSuccess(this.registrationData);

  @override
  List<Object?> get props => [registrationData];
}

// Emitted when a Google account already exists in Firebase — user should log in instead
class GoogleAccountAlreadyExists extends AuthState {
  const GoogleAccountAlreadyExists();
}

class AuthLoading extends AuthState {}

class RegistrationSuccess extends AuthState {
  final String email;
  final String firstName;

  const RegistrationSuccess({required this.email, required this.firstName});

  @override
  List<Object?> get props => [email, firstName];
}

class VerificationCodeSentSuccess extends AuthState {
  final String email;
  final String firstName;

  const VerificationCodeSentSuccess({
    required this.email,
    required this.firstName,
  });

  @override
  List<Object?> get props => [email, firstName];
}

class SignInSuccess extends AuthState {
  final String displayName;
  const SignInSuccess({required this.displayName});

  @override
  List<Object?> get props => [displayName];
}

class ForgotPasswordSuccess extends AuthState {}

// OTP sent — move to OTP entry screen
class ForgotPasswordOtpSent extends AuthState {
  final String email;
  const ForgotPasswordOtpSent({required this.email});
  @override
  List<Object?> get props => [email];
}

// OTP verified — move to reset password screen
class ForgotPasswordOtpVerifiedState extends AuthState {
  final String email;
  final String otp;
  const ForgotPasswordOtpVerifiedState({required this.email, required this.otp});
  @override
  List<Object?> get props => [email, otp];
}

// OTP wrong / expired
class ForgotPasswordOtpFailed extends AuthState {
  final String message;
  final String email;
  const ForgotPasswordOtpFailed({required this.message, required this.email});
  @override
  List<Object?> get props => [message, email];
}

// Firebase reset email triggered — user needs to click the link
class ForgotPasswordResetSuccess extends AuthState {}

class VerificationSuccess extends AuthState {}

class VerificationFailed extends AuthState {
  final String message;
  final String email;
  final String firstName;

  const VerificationFailed({
    required this.message,
    required this.email,
    required this.firstName,
  });

  @override
  List<Object?> get props => [message, email, firstName];
}

class AuthError extends AuthState {
  final String message;
  final RegistrationData? registrationData;

  const AuthError(this.message, {this.registrationData});

  @override
  List<Object?> get props => [message, registrationData];
}
