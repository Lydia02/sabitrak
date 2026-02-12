import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme/app_theme.dart';
import '../../../services/firebase_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../household/household_setup_screen.dart';
import '../main/main_shell.dart';
import '../../widgets/error_modal.dart';
import 'forgot_password_screen.dart';
import 'profile_details_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignIn() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(SignInSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ));
    }
  }

  void _onGoogleSignIn() {
    context.read<AuthBloc>().add(GoogleSignInRequested());
  }

  Future<void> _routeAfterSignIn(BuildContext ctx) async {
    final hasHousehold = await FirebaseService().hasHousehold();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (hasHousehold) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } else {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HouseholdSetupScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is SignInSuccess) {
          _routeAfterSignIn(context);
        } else if (state is RegistrationSuccess) {
          _routeAfterSignIn(context);
        } else if (state is GoogleSignInSuccess) {
          final authBloc = context.read<AuthBloc>();
          Navigator.of(context).push(PageRouteBuilder(
            pageBuilder: (_, __, ___) => BlocProvider.value(
              value: authBloc,
              child: const ProfileDetailsScreen(isGoogleUser: true),
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ));
        } else if (state is AuthError) {
          showErrorModal(context,
              title: 'Sign In Failed', message: state.message);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
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
                          child: const Icon(Icons.arrow_back,
                              color: AppTheme.primaryGreen, size: 28),
                        ),
                        // Logo + Title
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.eco,
                                    color: AppTheme.white, size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'SabiTrak',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Email
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Enter your email',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        // Password
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppTheme.subtitleGrey,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        // Sign In button
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return ElevatedButton(
                              onPressed: isLoading ? null : _onSignIn,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.white,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Continue with Google
                        OutlinedButton.icon(
                          onPressed: _onGoogleSignIn,
                          icon: const Text('G',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 24),
                        // Forgot password + Create Account
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (_) => AuthBloc(),
                                    child: const ForgotPasswordScreen(),
                                  ),
                                ));
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider(
                                      create: (_) => AuthBloc(),
                                      child: const SignUpScreen(),
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
      ),
    );
  }
}


