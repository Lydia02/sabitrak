import 'package:equatable/equatable.dart';

class RegistrationData extends Equatable {
  final String firstName;
  final String lastName;
  final String email;
  final String occupation;
  final String country;
  final String password;

  const RegistrationData({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.occupation = 'Student',
    this.country = 'Nigeria',
    this.password = '',
  });

  RegistrationData copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? occupation,
    String? country,
    String? password,
  }) {
    return RegistrationData(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      occupation: occupation ?? this.occupation,
      country: country ?? this.country,
      password: password ?? this.password,
    );
  }

  @override
  List<Object?> get props =>
      [firstName, lastName, email, occupation, country, password];
}
