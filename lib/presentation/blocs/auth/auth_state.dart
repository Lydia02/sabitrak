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

class AuthLoading extends AuthState {}

class RegistrationSuccess extends AuthState {}

class AuthError extends AuthState {
  final String message;
  final RegistrationData? registrationData;

  const AuthError(this.message, {this.registrationData});

  @override
  List<Object?> get props => [message, registrationData];
}
