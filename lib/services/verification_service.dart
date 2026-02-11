import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_service.dart';

class VerificationService {
  static final VerificationService _instance = VerificationService._internal();
  factory VerificationService() => _instance;
  VerificationService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  // EmailJS credentials
  static const String _serviceId = 'service_7s6050a';
  static const String _templateId = 'template_uayk1ab';
  static const String _publicKey = 'WDc5SNXX3-rTF5u8J';

  /// Generate a random 4-digit code
  String _generateCode() {
    final random = Random.secure();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// Send verification code to the user's email
  Future<void> sendVerificationCode({
    required String email,
    required String firstName,
  }) async {
    final code = _generateCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    // Store code in Firestore
    await _firebaseService.firestore
        .collection('verification_codes')
        .doc(email)
        .set({
      'code': code,
      'email': email,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
      'verified': false,
    });

    // Send email via EmailJS
    await _sendEmailViaEmailJS(
      toEmail: email,
      toName: firstName,
      verificationCode: code,
    );
  }

  /// Send email using EmailJS REST API
  Future<void> _sendEmailViaEmailJS({
    required String toEmail,
    required String toName,
    required String verificationCode,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': toEmail,
          'to_name': toName,
          'verification_code': verificationCode,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send verification email (${response.statusCode}): ${response.body}');
    }
  }

  /// Verify the code entered by the user
  Future<bool> verifyCode({
    required String email,
    required String code,
  }) async {
    final doc = await _firebaseService.firestore
        .collection('verification_codes')
        .doc(email)
        .get();

    if (!doc.exists) return false;

    final data = doc.data()!;
    final storedCode = data['code'] as String;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    final verified = data['verified'] as bool? ?? false;

    if (verified) return false; // Already used
    if (DateTime.now().isAfter(expiresAt)) return false; // Expired
    if (storedCode != code) return false; // Wrong code

    // Mark as verified
    await _firebaseService.firestore
        .collection('verification_codes')
        .doc(email)
        .update({'verified': true});

    return true;
  }

  /// Check if EmailJS credentials are configured
  bool get isConfigured =>
      _serviceId != 'YOUR_SERVICE_ID' &&
      _templateId != 'YOUR_TEMPLATE_ID' &&
      _publicKey != 'YOUR_PUBLIC_KEY';
}
