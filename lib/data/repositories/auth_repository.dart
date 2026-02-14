import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/firebase_service.dart';
import '../models/registration_data.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseService _firebaseService = FirebaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _firebaseService.currentUser;

  Future<User> registerWithEmailAndPassword(RegistrationData data) async {
    final UserCredential credential =
        await _firebaseService.auth.createUserWithEmailAndPassword(
      email: data.email,
      password: data.password,
    );

    final User user = credential.user!;

    await user.updateDisplayName('${data.firstName} ${data.lastName}');

    await _saveUserToFirestore(
      uid: user.uid,
      firstName: data.firstName,
      lastName: data.lastName,
      email: data.email,
      occupation: data.occupation,
      country: data.country,
    );

    return user;
  }

  Future<({User user, bool isNewUser})> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    }
    return _signInWithGoogleNative();
  }

  Future<({User user, bool isNewUser})> _signInWithGoogleWeb() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    final UserCredential userCredential =
        await _firebaseService.auth.signInWithPopup(googleProvider);

    final bool isNewUser =
        userCredential.additionalUserInfo?.isNewUser ?? false;

    return (user: userCredential.user!, isNewUser: isNewUser);
  }

  Future<({User user, bool isNewUser})> _signInWithGoogleNative() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google Sign-In was cancelled');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await _firebaseService.auth.signInWithCredential(credential);

    final bool isNewUser =
        userCredential.additionalUserInfo?.isNewUser ?? false;

    return (user: userCredential.user!, isNewUser: isNewUser);
  }

  Future<void> saveGoogleUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String occupation,
    required String country,
    String? photoUrl,
  }) async {
    await _saveUserToFirestore(
      uid: uid,
      firstName: firstName,
      lastName: lastName,
      email: email,
      occupation: occupation,
      country: country,
      photoUrl: photoUrl,
    );
  }

  Future<User> signInWithEmailAndPassword(String email, String password) async {
    final UserCredential credential =
        await _firebaseService.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseService.auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseService.auth.signOut();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseService.currentUser;
    if (user == null) throw Exception('No user logged in');
    if (user.email == null) throw Exception('No email associated with account');

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<bool> userProfileExists(String uid) async {
    final doc = await _firebaseService.users.doc(uid).get();
    return doc.exists;
  }

  Future<void> _saveUserToFirestore({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String occupation,
    required String country,
    String? photoUrl,
  }) async {
    final userModel = UserModel(
      id: uid,
      firstName: firstName,
      lastName: lastName,
      email: email,
      occupation: occupation,
      country: country,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
    );

    await _firebaseService.users.doc(uid).set(userModel.toFirestore());
  }
}
