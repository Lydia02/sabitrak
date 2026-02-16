import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class SignUpInfoSubmitted extends AuthEvent {
  final String firstName;
  final String lastName;
  final String email;

  const SignUpInfoSubmitted({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  @override
  List<Object?> get props => [firstName, lastName, email];
}

class ProfileDetailsSubmitted extends AuthEvent {
  final String occupation;
  final String country;

  const ProfileDetailsSubmitted({
    required this.occupation,
    required this.country,
  });

  @override
  List<Object?> get props => [occupation, country];
}

class SecuritySetupSubmitted extends AuthEvent {
  final String password;
  final String confirmPassword;

  const SecuritySetupSubmitted({
    required this.password,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [password, confirmPassword];
}

class GoogleSignInRequested extends AuthEvent {}

class GoogleProfileDetailsSubmitted extends AuthEvent {
  final String occupation;
  final String country;

  const GoogleProfileDetailsSubmitted({
    required this.occupation,
    required this.country,
  });

  @override
  List<Object?> get props => [occupation, country];
}

class VerificationCodeSent extends AuthEvent {
  final String email;
  final String firstName;

  const VerificationCodeSent({
    required this.email,
    required this.firstName,
  });

  @override
  List<Object?> get props => [email, firstName];
}

class VerificationCodeSubmitted extends AuthEvent {
  final String email;
  final String code;

  const VerificationCodeSubmitted({
    required this.email,
    required this.code,
  });

  @override
  List<Object?> get props => [email, code];
}

class ResendVerificationCode extends AuthEvent {
  final String email;
  final String firstName;

  const ResendVerificationCode({
    required this.email,
    required this.firstName,
  });

  @override
  List<Object?> get props => [email, firstName];
}

class SignInSubmitted extends AuthEvent {
  final String email;
  final String password;

  const SignInSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class ForgotPasswordSubmitted extends AuthEvent {
  final String email;

  const ForgotPasswordSubmitted({required this.email});

  @override
  List<Object?> get props => [email];
}

class RegistrationStepBack extends AuthEvent {}

class RegistrationReset extends AuthEvent {}

// ── Forgot password OTP flow ──────────────────────────────────────────────────

class ForgotPasswordOtpRequested extends AuthEvent {
  final String email;
  const ForgotPasswordOtpRequested({required this.email});
  @override
  List<Object?> get props => [email];
}

class ForgotPasswordOtpVerified extends AuthEvent {
  final String email;
  final String otp;
  const ForgotPasswordOtpVerified({required this.email, required this.otp});
  @override
  List<Object?> get props => [email, otp];
}

/// Step 3a: user entered new password in our UI after OTP — trigger Firebase reset email
class ForgotPasswordReset extends AuthEvent {
  final String email;
  final String newPassword;
  final String resetToken;
  const ForgotPasswordReset({required this.email, required this.newPassword, required this.resetToken});
  @override
  List<Object?> get props => [email, newPassword, resetToken];
}

