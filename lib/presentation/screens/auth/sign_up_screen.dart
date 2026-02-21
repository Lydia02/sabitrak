import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/sabitrak_logo.dart';
import 'profile_details_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onProceed() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(SignUpInfoSubmitted(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            email: _emailController.text.trim(),
          ));
    }
  }

  void _onGoogleSignIn() {
    context.read<AuthBloc>().add(const GoogleSignInRequested(isSignUp: true));
  }

  void _navigateToProfileDetails({bool isGoogleUser = false}) {
    final authBloc = context.read<AuthBloc>();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            BlocProvider.value(
          value: authBloc,
          child: ProfileDetailsScreen(isGoogleUser: isGoogleUser),
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
        if (state is SignUpInfoCollected) {
          _navigateToProfileDetails();
        } else if (state is GoogleSignInSuccess) {
          _navigateToProfileDetails(isGoogleUser: true);
        } else if (state is RegistrationSuccess) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (state is GoogleAccountAlreadyExists) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Account Already Exists',
                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
              content: const Text(
                'An account with this Google account already exists. Please log in instead.',
                style: TextStyle(fontFamily: 'Roboto'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.subtitleGrey)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pop(); // back to welcome screen
                  },
                  child: const Text('Go to Login', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
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
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
          final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;

          return Scaffold(
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Icon(
                                Icons.arrow_back,
                                color: textColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Center(child: SabiTrakLogo(iconSize: 40, showText: false)),
                            const SizedBox(height: 8),
                            Text(
                              'Create your account',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _firstNameController,
                              style: TextStyle(color: textColor),
                              decoration: const InputDecoration(
                                hintText: 'First Name',
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your first name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lastNameController,
                              style: TextStyle(color: textColor),
                              decoration: const InputDecoration(
                                hintText: 'Last Name',
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your last name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: textColor),
                              decoration: const InputDecoration(
                                hintText: 'Email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value.trim())) {
                                  return 'Please enter a valid email (e.g. name@example.com)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Format: name@example.com',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                final isLoading = state is AuthLoading;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ElevatedButton(
                                      onPressed: isLoading ? null : _onProceed,
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.white,
                                              ),
                                            )
                                          : const Text('Proceed'),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: isLoading ? null : _onGoogleSignIn,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? AppTheme.darkCard
                                            : const Color(0xFF4A5A2C),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: AppTheme.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'G',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.primaryGreen,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text('Continue with Google'),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: subtitleColor,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
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
        },
      ),
    );
  }
}
