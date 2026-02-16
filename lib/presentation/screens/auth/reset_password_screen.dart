import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/error_modal.dart';
import 'sign_in_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String resetToken;
  const ResetPasswordScreen({super.key, required this.email, required this.resetToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _validatePassword(String pw) {
    if (pw.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[0-9]').hasMatch(pw)) return 'Must contain a number';
    if (!RegExp(r'[!@#\$%\^&\*\.\-_]').hasMatch(pw)) return 'Must contain a symbol';
    return null;
  }

  void _submit() {
    final pw = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    final error = _validatePassword(pw);
    if (error != null) {
      showErrorModal(context, title: 'Weak Password', message: error);
      return;
    }
    if (pw != confirm) {
      showErrorModal(context, title: 'Mismatch', message: 'Passwords do not match.');
      return;
    }

    context.read<AuthBloc>().add(ForgotPasswordReset(
          email: widget.email,
          newPassword: pw,
          resetToken: widget.resetToken,
        ));
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.fieldBorderColor;
    final fieldBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.transparent;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ForgotPasswordResetSuccess) {
          _showSuccessDialog(context, isDark, textColor, subtitleColor);
        } else if (state is AuthError) {
          showErrorModal(context, title: 'Error', message: state.message);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Blurred sign-in background
            SizedBox.expand(
              child: _BlurredSignInBackground(isDark: isDark),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: (isDark ? Colors.black : Colors.white)
                    .withValues(alpha: 0.45),
              ),
            ),

            // Floating card
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return Container(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : AppTheme.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Lock icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_reset_outlined,
                              color: AppTheme.primaryGreen,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            'New Password',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your new password below',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // New Password
                          _buildField(
                            controller: _passwordCtrl,
                            label: 'New Password',
                            obscure: _obscurePassword,
                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                            textColor: textColor,
                            borderColor: borderColor,
                            fieldBg: fieldBg,
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password
                          _buildField(
                            controller: _confirmCtrl,
                            label: 'Confirm Password',
                            obscure: _obscureConfirm,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            textColor: textColor,
                            borderColor: borderColor,
                            fieldBg: fieldBg,
                          ),
                          const SizedBox(height: 24),

                          // Confirm button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                disabledBackgroundColor:
                                    AppTheme.primaryGreen.withValues(alpha: 0.5),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Confirm',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Cancel
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).popUntil((r) => r.isFirst),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required Color textColor,
    required Color borderColor,
    required Color fieldBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(fontFamily: 'Roboto', color: textColor, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: textColor.withValues(alpha: 0.4),
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(
      BuildContext context, bool isDark, Color textColor, Color subtitleColor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.primaryGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Password Reset!',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your password has been updated.\nYou can now sign in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider(
                          create: (_) => AuthBloc(),
                          child: const SignInScreen(),
                        ),
                      ),
                      (r) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Back to Sign In',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Blurred background widget ────────────────────────────────────────────────

class _BlurredSignInBackground extends StatelessWidget {
  final bool isDark;
  const _BlurredSignInBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final bg = isDark ? AppTheme.darkSurface : const Color(0xFFF7F7F6);

    return Container(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    child: const Icon(Icons.eco, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SabiTrak',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _FakeField(label: 'Email', isDark: isDark),
            const SizedBox(height: 24),
            _FakeField(label: 'Password', isDark: isDark, isPassword: true),
            const SizedBox(height: 32),
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeField extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool isPassword;
  const _FakeField(
      {required this.label, required this.isDark, this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.fieldBorderColor;
    final bg =
        isDark ? Colors.white.withValues(alpha: 0.04) : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isPassword ? '••••••••' : '',
                  style: TextStyle(color: textColor.withValues(alpha: 0.3)),
                ),
              ),
              if (isPassword)
                Icon(Icons.visibility_off,
                    color: textColor.withValues(alpha: 0.3), size: 18),
            ],
          ),
        ),
      ],
    );
  }
}
