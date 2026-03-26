// Unit tests for Recipe and Ingredient models
//
// Tests cover:
//   - Ingredient constructor, fromMap, toMap round-trip
//   - Recipe constructor and toFirestore() serialisation
//   - Ingredient list serialisation inside Recipe.toFirestore()

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/models/recipe.dart';

Ingredient _makeIngredient({
  String name = 'Tomato',
  String quantity = '2',
  String unit = 'cups',
}) => Ingredient(name: name, quantity: quantity, unit: unit);

Recipe _makeRecipe() => Recipe(
  id: 'recipe-1',
  name: 'Jollof Rice',
  ingredients: [
    _makeIngredient(name: 'Rice', quantity: '2', unit: 'cups'),
    _makeIngredient(name: 'Tomato', quantity: '3', unit: 'pcs'),
  ],
  instructions: 'Step 1. Boil water.\nStep 2. Add rice.',
  prepTime: 30,
  servings: 4,
  category: 'Main',
  createdAt: DateTime(2024, 6, 1),
);

void main() {
  // ── Ingredient ─────────────────────────────────────────────────────────────

  group('Ingredient constructor', () {
    test('stores name, quantity, unit', () {
      final i = _makeIngredient();
      expect(i.name, 'Tomato');
      expect(i.quantity, '2');
      expect(i.unit, 'cups');
    });
  });

  group('Ingredient fromMap', () {
    test('parses all fields from map', () {
      final i = Ingredient.fromMap({
        'name': 'Onion',
        'quantity': '1',
        'unit': 'pcs',
      });
      expect(i.name, 'Onion');
      expect(i.quantity, '1');
      expect(i.unit, 'pcs');
    });

    test('defaults empty strings for missing keys', () {
      final i = Ingredient.fromMap({});
      expect(i.name, '');
      expect(i.quantity, '');
      expect(i.unit, '');
    });
  });

  group('Ingredient toMap', () {
    test('serialises all fields', () {
      final map = _makeIngredient().toMap();
      expect(map['name'], 'Tomato');
      expect(map['quantity'], '2');
      expect(map['unit'], 'cups');
    });

    test('fromMap → toMap round-trip', () {
      final original = {'name': 'Pepper', 'quantity': '0.5', 'unit': 'kg'};
      final i = Ingredient.fromMap(original);
      expect(i.toMap(), original);
    });
  });

  // ── Recipe ─────────────────────────────────────────────────────────────────

  group('Recipe constructor', () {
    test('stores all fields', () {
      final r = _makeRecipe();
      expect(r.id, 'recipe-1');
      expect(r.name, 'Jollof Rice');
      expect(r.ingredients.length, 2);
      expect(r.prepTime, 30);
      expect(r.servings, 4);
      expect(r.category, 'Main');
      expect(r.imageUrl, isNull);
    });

    test('imageUrl can be set', () {
      final r = Recipe(
        id: 'r2',
        name: 'Rice',
        ingredients: [],
        instructions: '',
        prepTime: 10,
        servings: 2,
        imageUrl: 'https://example.com/image.jpg',
        category: 'Side',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(r.imageUrl, 'https://example.com/image.jpg');
    });
  });

  group('Recipe toFirestore', () {
    test('serialises scalar fields correctly', () {
      final r = _makeRecipe();
      final map = r.toFirestore();
      expect(map['name'], 'Jollof Rice');
      expect(map['instructions'], 'Step 1. Boil water.\nStep 2. Add rice.');
      expect(map['prepTime'], 30);
      expect(map['servings'], 4);
      expect(map['category'], 'Main');
      expect(map['imageUrl'], isNull);
    });

    test('serialises createdAt as Timestamp', () {
      final map = _makeRecipe().toFirestore();
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), DateTime(2024, 6, 1));
    });

    test('serialises ingredients list', () {
      final map = _makeRecipe().toFirestore();
      final ingredientList = map['ingredients'] as List;
      expect(ingredientList.length, 2);
      expect(ingredientList[0]['name'], 'Rice');
      expect(ingredientList[1]['name'], 'Tomato');
    });

    test('ingredients in list have correct unit and quantity', () {
      final map = _makeRecipe().toFirestore();
      final ingredientList = map['ingredients'] as List;
      expect(ingredientList[0]['unit'], 'cups');
      expect(ingredientList[0]['quantity'], '2');
    });
  });
}
