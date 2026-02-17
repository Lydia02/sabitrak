import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_service.dart';

class PasswordResetService {
  static final PasswordResetService _instance =
      PasswordResetService._internal();
  factory PasswordResetService() => _instance;
  PasswordResetService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  // Dedicated forgot-password template — separate from the sign-up verification template
  static const String _serviceId = 'service_7s6050a';
  static const String _templateId = 'template_72enyol';
  static const String _publicKey = 'WDc5SNXX3-rTF5u8J';

  String _generateOtp() {
    final random = Random.secure();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// Send 4-digit OTP and store it in Firestore under 'password_reset_codes'
  Future<void> sendOtp({required String email}) async {
    final otp = _generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    await _firebaseService.firestore
        .collection('password_reset_codes')
        .doc(email)
        .set({
      'code': otp,
      'email': email,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
      'used': false,
    });

    // Send via Cloud Function proxy (EmailJS blocks non-browser calls)
    final url = Uri.parse('https://us-central1-sabitrak-63dc2.cloudfunctions.net/sendEmail');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': email,
          'to_name': email.split('@').first,
          'verification_code': otp,
        },
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Email error (${response.statusCode}): ${response.body}');
    }
  }

  /// Verify the OTP — returns true and marks it used if valid
  Future<bool> verifyOtp({
    required String email,
    required String code,
  }) async {
    final doc = await _firebaseService.firestore
        .collection('password_reset_codes')
        .doc(email)
        .get();

    if (!doc.exists) return false;

    final data = doc.data()!;
    final storedCode = data['code'] as String;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    final used = data['used'] as bool? ?? false;

    if (used) return false;
    if (DateTime.now().isAfter(expiresAt)) return false;
    if (storedCode != code) return false;

    await _firebaseService.firestore
        .collection('password_reset_codes')
        .doc(email)
        .update({'used': true});

    return true;
  }

  /// Call Cloud Function via HTTP to update the user's password via Admin SDK
  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required String resetToken,
  }) async {
    final url = Uri.parse(
      'https://resetpassword-6vvfcstgua-uc.a.run.app',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'newPassword': newPassword,
        'resetToken': resetToken,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to reset password.';
      throw Exception(error);
    }
  }
}
