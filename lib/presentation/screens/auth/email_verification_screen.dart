import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import 'verification_success_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String firstName;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.firstName,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  Timer? _resendTimer;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    // Send verification code when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(VerificationCodeSent(
            email: widget.email,
            firstName: widget.firstName,
          ));
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 0) {
        timer.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String get _code =>
      _controllers.map((c) => c.text).join();

  void _onVerifyCode() {
    final code = _code;
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the full 4-digit code'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(VerificationCodeSubmitted(
          email: widget.email,
          code: code,
        ));
  }

  void _onResendCode() {
    if (_resendCooldown > 0) return;
    _startResendCooldown();
    context.read<AuthBloc>().add(ResendVerificationCode(
          email: widget.email,
          firstName: widget.firstName,
        ));
  }

  void _clearFields() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _showVerificationFailedDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: dialogColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verification Failed',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _clearFields();
                      },
                      child: const Text('Try Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _clearFields();
                        _onResendCode();
                      },
                      child: const Text('Resend Code'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is VerificationCodeSentSuccess) {
          _startResendCooldown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent to your email'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        } else if (state is VerificationSuccess) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => BlocProvider.value(
                value: authBloc,
                child: const VerificationSuccessScreen(),
              ),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        } else if (state is VerificationFailed) {
          _showVerificationFailedDialog(state.message);
        }
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
          final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
          final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
          final borderColor = isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppTheme.fieldBorderColor;

          return Scaffold(
            body: SafeArea(
              child: Stack(
                children: [
                  // Back arrow
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back,
                        color: textColor,
                        size: 24,
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 40),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Leaf icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco,
                            color: AppTheme.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Email Verification',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "We've sent a 4-digit verification code to your email.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // 4 digit code input
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            return Container(
                              width: 56,
                              height: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              child: TextFormField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: borderColor,
                                        width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: AppTheme.primaryGreen, width: 2),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 3) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                  // Auto-verify when all 4 digits entered
                                  if (index == 3 && value.isNotEmpty && _code.length == 4) {
                                    _onVerifyCode();
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 32),
                        // Verify button
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return ElevatedButton(
                              onPressed: isLoading ? null : _onVerifyCode,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.white,
                                      ),
                                    )
                                  : const Text('Verify Code'),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Resend code
                        GestureDetector(
                          onTap: _resendCooldown > 0 ? null : _onResendCode,
                          child: Text(
                            _resendCooldown > 0
                                ? 'Resend Code (${_resendCooldown}s)'
                                : 'Resend Code',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _resendCooldown > 0
                                  ? subtitleColor
                                  : AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
        },
      ),
    );
  }
}
