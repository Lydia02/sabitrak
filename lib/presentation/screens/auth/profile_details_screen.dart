import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import 'email_verification_screen.dart';
import 'security_setup_screen.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final bool isGoogleUser;

  const ProfileDetailsScreen({super.key, this.isGoogleUser = false});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  String _selectedOccupation = 'Student';
  String _selectedCountry = 'Nigeria';

  static const List<String> _occupations = [
    'Student',
    'Professional',
    'Business Owner',
    'Homemaker',
    'Other',
  ];

  static const List<String> _countries = [
    'Nigeria',
    'Ghana',
    'Kenya',
    'South Africa',
    'Tanzania',
    'Uganda',
    'Rwanda',
    'Ethiopia',
    'Cameroon',
    'Senegal',
    'Egypt',
    'Morocco',
    'Other',
  ];

  void _onProceed() {
    if (widget.isGoogleUser) {
      context.read<AuthBloc>().add(GoogleProfileDetailsSubmitted(
            occupation: _selectedOccupation,
            country: _selectedCountry,
          ));
    } else {
      context.read<AuthBloc>().add(ProfileDetailsSubmitted(
            occupation: _selectedOccupation,
            country: _selectedCountry,
          ));
    }
  }

  void _navigateToSecuritySetup() {
    final authBloc = context.read<AuthBloc>();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            BlocProvider.value(
          value: authBloc,
          child: const SecuritySetupScreen(),
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ProfileDetailsCollected) {
          _navigateToSecuritySetup();
        } else if (state is RegistrationSuccess) {
          final email = state.email;
          final firstName = state.firstName;
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => BlocProvider(
                create: (_) => AuthBloc(),
                child: EmailVerificationScreen(
                  email: email,
                  firstName: firstName,
                ),
              ),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
            (route) => route.isFirst,
          );
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppTheme.primaryGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Profile Details',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Occupation',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedOccupation,
                              items: _occupations
                                  .map((o) => DropdownMenuItem(
                                        value: o,
                                        child: Text(o),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedOccupation = value!;
                                });
                              },
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppTheme.fieldBorderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryGreen,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Country',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedCountry,
                              items: _countries
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCountry = value!;
                                });
                              },
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppTheme.fieldBorderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryGreen,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 32),
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                final isLoading = state is AuthLoading;
                                return Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.backButtonColor,
                                        ),
                                        child: const Text('Back'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            isLoading ? null : _onProceed,
                                        child: isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppTheme.white,
                                                ),
                                              )
                                            : const Text('Proceed'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
