import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase instances
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // Collections
  CollectionReference get users => firestore.collection('users');
  CollectionReference get households => firestore.collection('households');
  CollectionReference get foodItems => firestore.collection('food_items');
  CollectionReference get recipes => firestore.collection('recipes');

  // Get current user
  User? get currentUser => auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;
}
