import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String name;
  final List<Ingredient> ingredients;
  final String instructions;
  final int prepTime;
  final int servings;
  final String? imageUrl;
  final String category;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
    required this.prepTime,
    required this.servings,
    this.imageUrl,
    required this.category,
    required this.createdAt,
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      name: data['name'] ?? '',
      ingredients: (data['ingredients'] as List)
          .map((i) => Ingredient.fromMap(i))
          .toList(),
      instructions: data['instructions'] ?? '',
      prepTime: data['prepTime'] ?? 0,
      servings: data['servings'] ?? 0,
      imageUrl: data['imageUrl'],
      category: data['category'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions,
      'prepTime': prepTime,
      'servings': servings,
      'imageUrl': imageUrl,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Ingredient {
  final String name;
  final String quantity;
  final String unit;

  Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? '',
      unit: map['unit'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }
}
