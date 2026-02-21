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
  /// Send verification code to the user's email.
  ///
  /// Guards against duplicate sends: if a code was already sent for this email
  /// within the last 60 seconds and hasn't been verified yet, the existing code
  /// is reused — no overwrite, no duplicate email that invalidates prior codes.
  Future<void> sendVerificationCode({
    required String email,
    required String firstName,
  }) async {
    final docRef = _firebaseService.firestore
        .collection('verification_codes')
        .doc(email);

    // Check for a recently-sent, unverified code (cooldown: 60 s)
    final existing = await docRef.get();
    if (existing.exists) {
      final data = existing.data()!;
      final alreadyVerified = data['verified'] as bool? ?? false;
      final createdAt = data['createdAt'];
      if (!alreadyVerified && createdAt is Timestamp) {
        final secondsAgo =
            DateTime.now().difference(createdAt.toDate()).inSeconds;
        if (secondsAgo < 60) {
          // Fresh unverified code exists — resend the same code without overwriting
          await _sendEmailViaEmailJS(
            toEmail: email,
            toName: firstName,
            verificationCode: data['code'] as String,
          );
          return;
        }
      }
    }

    // Generate and store a new code
    final code = _generateCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    await docRef.set({
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

  /// Send email via Cloud Function proxy (EmailJS blocks non-browser calls)
  Future<void> _sendEmailViaEmailJS({
    required String toEmail,
    required String toName,
    required String verificationCode,
  }) async {
    final url = Uri.parse('https://us-central1-sabitrak-63dc2.cloudfunctions.net/sendEmail');

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
