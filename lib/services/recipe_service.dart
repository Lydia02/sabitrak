import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/food_item.dart';
import '../data/models/matched_recipe.dart';

/// Combines two recipe sources:
///   1. TheMealDB  — broad international + some African coverage (free, no key)
///   2. African Food Database — 358+ African dishes (Lydia02/african-food-database)
///
/// Both run in parallel. Results are merged, deduped by name, and ranked by:
///   score = (expiryBonus × 0.45) + (matchRatio × 0.40) + (prepBonus × 0.15)
class RecipeService {
  static const String _mealDbBase = 'https://www.themealdb.com/api/json/v1/1';
  static const String _africanBase =
      'https://african-food-database-production.up.railway.app';

  static const int _maxDetailFetches = 20;
  static const int _minMatchedIngredients = 1;

  // ────────────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ────────────────────────────────────────────────────────────────────────────

  Future<RecipeRecommendationResult> getRecommendations(
      List<FoodItem> pantryItems) async {
    if (pantryItems.isEmpty) {
      return const RecipeRecommendationResult(expiring: [], quickMatch: []);
    }

    final allItems = pantryItems
        .where((item) => !item.isExpired && item.name.trim().isNotEmpty)
        .toList();
    final expiringItems =
        allItems.where((item) => item.isExpiringSoon).toList();

    // Run both APIs in parallel
    final results = await Future.wait([
      _getMealDbMatches(allItems, expiringItems),
      _getAfricanDbMatches(allItems, expiringItems),
    ]);

    final mealDbMatched = results[0] as List<MatchedRecipe>;
    final africanMatched = results[1] as List<MatchedRecipe>;

    // Merge: African DB first (priority), then TheMealDB, dedup by name
    final seen = <String>{};
    final merged = <MatchedRecipe>[];
    for (final r in [...africanMatched, ...mealDbMatched]) {
      final key = r.name.toLowerCase().trim();
      if (seen.add(key)) merged.add(r);
    }
    merged.sort((a, b) => b.score.compareTo(a.score));

    final expiringList =
        merged.where((r) => r.usesExpiringItem).take(10).toList();
    final quickMatchList = merged.take(15).toList();

    return RecipeRecommendationResult(
      expiring: expiringList,
      quickMatch: quickMatchList,
    );
  }

  /// Search by keyword — queries both APIs and merges results.
  Future<List<MatchedRecipe>> searchRecipes(
      String query, List<FoodItem> pantryItems) async {
    if (query.trim().isEmpty) return [];

    final allItems = pantryItems.where((item) => !item.isExpired).toList();
    final expiringItems =
        allItems.where((item) => item.isExpiringSoon).toList();

    final results = await Future.wait([
      _searchMealDb(query, allItems, expiringItems),
      _searchAfricanDb(query, allItems, expiringItems),
    ]);

    final seen = <String>{};
    final merged = <MatchedRecipe>[];
    // African results first in search too
    for (final r in [...results[1], ...results[0]]) {
      if (seen.add(r.name.toLowerCase().trim())) merged.add(r);
    }
    merged.sort((a, b) => b.score.compareTo(a.score));
    return merged.take(20).toList();
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  THEMEALDB
  // ────────────────────────────────────────────────────────────────────────────

  Future<List<MatchedRecipe>> _getMealDbMatches(
      List<FoodItem> allItems, List<FoodItem> expiringItems) async {
    try {
      final mealScoreMap = await _buildMealScoreMap(allItems, expiringItems);
      if (mealScoreMap.isEmpty) return [];

      final sortedIds = mealScoreMap.entries
          .where((e) => e.value.rawMatchCount >= _minMatchedIngredients)
          .toList()
        ..sort(
            (a, b) => b.value.rawMatchCount.compareTo(a.value.rawMatchCount));

      final topIds =
          sortedIds.take(_maxDetailFetches).map((e) => e.key).toList();
      final details = await _fetchMealDetails(topIds);

      return details
          .map((meal) => _scoreRecipeFromMealDb(
              meal, mealScoreMap[meal['idMeal']]!, allItems, expiringItems))
          .where((r) => r != null)
          .cast<MatchedRecipe>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MatchedRecipe>> _searchMealDb(String query,
      List<FoodItem> allItems, List<FoodItem> expiringItems) async {
    try {
      final uri = Uri.parse(
          '$_mealDbBase/search.php?s=${Uri.encodeComponent(query.trim())}');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final meals =
          (data['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      return meals
          .map((meal) => _scoreRecipeFromMealDb(
              meal,
              _MealScore(rawMatchCount: 1, expiryMatchCount: 0),
              allItems,
              expiringItems))
          .where((r) => r != null)
          .cast<MatchedRecipe>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, _MealScore>> _buildMealScoreMap(
      List<FoodItem> allItems, List<FoodItem> expiringItems) async {
    final Map<String, _MealScore> scores = {};

    final futures = allItems.map((item) async {
      final isExpiring = expiringItems
          .any((e) => e.name.toLowerCase() == item.name.toLowerCase());
      final keywords = _ingredientKeywords(item.name);

      List<Map<String, dynamic>> meals = [];
      for (final kw in keywords) {
        meals = await _filterByIngredient(kw);
        if (meals.isNotEmpty) break;
      }

      for (final meal in meals) {
        final id = meal['idMeal'] as String;
        scores.update(
          id,
          (s) => _MealScore(
            rawMatchCount: s.rawMatchCount + 1,
            expiryMatchCount: s.expiryMatchCount + (isExpiring ? 1 : 0),
          ),
          ifAbsent: () => _MealScore(
            rawMatchCount: 1,
            expiryMatchCount: isExpiring ? 1 : 0,
          ),
        );
      }
    });

    await Future.wait(futures);
    return scores;
  }

  Future<List<Map<String, dynamic>>> _filterByIngredient(
      String ingredient) async {
    try {
      final uri = Uri.parse(
          '$_mealDbBase/filter.php?i=${Uri.encodeComponent(ingredient)}');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMealDetails(
      List<String> ids) async {
    final futures = ids.map((id) async {
      try {
        final uri = Uri.parse('$_mealDbBase/lookup.php?i=$id');
        final response =
            await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return null;
        final data = json.decode(response.body) as Map<String, dynamic>;
        final meals =
            (data['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return meals.isNotEmpty ? meals.first : null;
      } catch (_) {
        return null;
      }
    });
    final results = await Future.wait(futures);
    return results.whereType<Map<String, dynamic>>().toList();
  }

  MatchedRecipe? _scoreRecipeFromMealDb(
    Map<String, dynamic> meal,
    _MealScore mealScore,
    List<FoodItem> allPantry,
    List<FoodItem> expiringPantry,
  ) {
    final ingredients = _extractMealDbIngredients(meal);
    if (ingredients.isEmpty) return null;

    final matchedNames = <String>[];
    final expiringMatchedNames = <String>[];

    for (final ingredient in ingredients) {
      final pantryMatch = allPantry.firstWhere(
        (item) => _ingredientMatches(item.name, ingredient.name),
        orElse: () => _noMatch,
      );
      if (pantryMatch.id.isNotEmpty) {
        matchedNames.add(ingredient.name);
        if (expiringPantry.any((e) => e.id == pantryMatch.id)) {
          expiringMatchedNames.add(ingredient.name);
        }
      }
    }

    final matchRatio =
        ingredients.isEmpty ? 0.0 : matchedNames.length / ingredients.length;
    final expiryBonus = ingredients.isEmpty
        ? 0.0
        : expiringMatchedNames.length / ingredients.length;

    final instructions = (meal['strInstructions'] as String?) ?? '';
    final stepCount =
        instructions.split('\r\n').where((s) => s.trim().isNotEmpty).length;
    final prepBonus = stepCount <= 5
        ? 1.0
        : stepCount <= 10
            ? 0.6
            : 0.3;

    final score =
        (expiryBonus * 0.45) + (matchRatio * 0.40) + (prepBonus * 0.15);

    return MatchedRecipe(
      id: 'mdb_${meal['idMeal'] ?? ''}',
      name: meal['strMeal'] as String? ?? '',
      thumbnailUrl: meal['strMealThumb'] as String? ?? '',
      category: meal['strCategory'] as String? ?? '',
      area: meal['strArea'] as String? ?? '',
      instructions: instructions,
      youtubeUrl: meal['strYoutube'] as String? ?? '',
      ingredients: ingredients,
      matchedPantryItems: matchedNames,
      expiringMatchedItems: expiringMatchedNames,
      matchRatio: matchRatio,
      score: score,
    );
  }

  List<RecipeIngredient> _extractMealDbIngredients(
      Map<String, dynamic> meal) {
    final result = <RecipeIngredient>[];
    for (int i = 1; i <= 20; i++) {
      final name = (meal['strIngredient$i'] as String?)?.trim() ?? '';
      final measure = (meal['strMeasure$i'] as String?)?.trim() ?? '';
      if (name.isNotEmpty) {
        result.add(RecipeIngredient(name: name, measure: measure));
      }
    }
    return result;
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  AFRICAN FOOD DATABASE
  // ────────────────────────────────────────────────────────────────────────────

  Future<List<MatchedRecipe>> _getAfricanDbMatches(
      List<FoodItem> allItems, List<FoodItem> expiringItems) async {
    try {
      // Use each pantry item name as a search query against /api/search?q=
      // Deduplicate keywords, cap at 8 parallel calls
      final keywords = allItems
          .map((item) => _ingredientKeywords(item.name).first)
          .toSet()
          .take(8)
          .toList();

      final futures = keywords.map((kw) => _africanSearch(kw));
      final batchResults = await Future.wait(futures);

      // Tally how many pantry items each food ID appears for
      final Map<String, _AfricanFoodEntry> foodMap = {};
      for (int ki = 0; ki < keywords.length; ki++) {
        final kw = keywords[ki];
        final foods = batchResults[ki];

        // Find the original pantry item this keyword came from
        final pantryItem = allItems.firstWhere(
          (item) => _ingredientKeywords(item.name).first == kw,
          orElse: () => _noMatch,
        );
        final isExpiring = expiringItems.any((e) => e.id == pantryItem.id);

        for (final food in foods) {
          final id = (food['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          foodMap[id] = _AfricanFoodEntry(
            food: food,
            matchCount: (foodMap[id]?.matchCount ?? 0) + 1,
            expiryCount: (foodMap[id]?.expiryCount ?? 0) + (isExpiring ? 1 : 0),
          );
        }
      }

      if (foodMap.isEmpty) return [];

      return foodMap.values
          .map((entry) => _scoreRecipeFromAfricanDb(
              entry.food, entry.matchCount, entry.expiryCount,
              allItems, expiringItems))
          .where((r) => r != null)
          .cast<MatchedRecipe>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MatchedRecipe>> _searchAfricanDb(String query,
      List<FoodItem> allItems, List<FoodItem> expiringItems) async {
    try {
      final foods = await _africanSearch(query.trim(), limit: 15);
      return foods
          .map((food) =>
              _scoreRecipeFromAfricanDb(food, 1, 0, allItems, expiringItems))
          .where((r) => r != null)
          .cast<MatchedRecipe>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// GET /api/search?q={query}&limit={limit}
  /// Response: { success, data: { results: [...] } }
  Future<List<Map<String, dynamic>>> _africanSearch(String keyword,
      {int limit = 10}) async {
    try {
      final uri = Uri.parse(
          '$_africanBase/api/search?q=${Uri.encodeComponent(keyword)}&limit=$limit');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final body = json.decode(response.body) as Map<String, dynamic>;
      // Structure: { success: true, data: { results: [...] } }
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        final results = data['results'];
        if (results is List) return results.cast<Map<String, dynamic>>();
        // Fallback: data might be { foods: [...] }
        final foods = data['foods'];
        if (foods is List) return foods.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  MatchedRecipe? _scoreRecipeFromAfricanDb(
    Map<String, dynamic> food,
    int rawMatchCount,
    int expiryMatchCount,
    List<FoodItem> allPantry,
    List<FoodItem> expiringPantry,
  ) {
    final name = (food['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;

    // ingredients is List<String> like "3 cups palm oil", "2 unripe plantains"
    final rawIngredients = food['ingredients'];
    final ingredientRaw = <String>[];
    if (rawIngredients is List) {
      for (final ing in rawIngredients) {
        final s = ing.toString().trim();
        if (s.isNotEmpty) ingredientRaw.add(s);
      }
    }
    if (ingredientRaw.isEmpty) return null;

    // Extract the food noun from each ingredient string (strip quantity/unit prefix)
    final ingredientNames =
        ingredientRaw.map(_extractFoodNoun).toList();

    final ingredients = List.generate(
      ingredientRaw.length,
      (i) => RecipeIngredient(name: ingredientNames[i], measure: ''),
    );

    // Match against pantry
    final matchedNames = <String>[];
    final expiringMatchedNames = <String>[];
    for (final ing in ingredientNames) {
      final pantryMatch = allPantry.firstWhere(
        (item) => _ingredientMatches(item.name, ing),
        orElse: () => _noMatch,
      );
      if (pantryMatch.id.isNotEmpty) {
        matchedNames.add(ing);
        if (expiringPantry.any((e) => e.id == pantryMatch.id)) {
          expiringMatchedNames.add(ing);
        }
      }
    }

    final matchRatio =
        ingredientNames.isEmpty ? 0.0 : matchedNames.length / ingredientNames.length;
    final expiryBonus = ingredientNames.isEmpty
        ? 0.0
        : expiringMatchedNames.length / ingredientNames.length;

    // Build instructions string from array
    final rawInstructions = food['instructions'];
    String instructionsStr = '';
    if (rawInstructions is List) {
      instructionsStr = rawInstructions.join('\n');
    } else if (rawInstructions is String) {
      instructionsStr = rawInstructions;
    }

    final stepCount =
        instructionsStr.split('\n').where((s) => s.trim().isNotEmpty).length;
    final prepBonus = stepCount <= 5
        ? 1.0
        : stepCount <= 10
            ? 0.6
            : 0.3;

    final score =
        (expiryBonus * 0.45) + (matchRatio * 0.40) + (prepBonus * 0.15);

    final prepTime = food['prepTime'] as int? ?? 0;
    final cookTime = food['cookTime'] as int? ?? 0;
    final totalMin = prepTime + cookTime;
    final prepTimeStr = totalMin > 0
        ? '$totalMin min'
        : instructionsStr.isNotEmpty
            ? null
            : null;

    final countryName = (food['countryName'] as String?) ?? '';
    final area = countryName.isNotEmpty ? countryName : 'African';

    return MatchedRecipe(
      id: 'afd_${food['id'] ?? food['_id'] ?? name.hashCode}',
      name: name,
      thumbnailUrl: (food['imageUrl'] as String?) ?? '',
      category: (food['categories'] is List && (food['categories'] as List).isNotEmpty)
          ? (food['categories'] as List).first.toString()
          : 'African',
      area: area,
      instructions: instructionsStr,
      youtubeUrl: '',
      ingredients: ingredients,
      matchedPantryItems: matchedNames,
      expiringMatchedItems: expiringMatchedNames,
      matchRatio: matchRatio,
      score: score,
      prepTimeOverride: prepTimeStr,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  SHARED HELPERS
  // ────────────────────────────────────────────────────────────────────────────

  /// Extracts the food noun from an African DB ingredient string like
  /// "3 cups dried abacha" → "abacha", "1/2 cup palm oil" → "palm oil",
  /// "2 unripe plantains" → "plantains"
  String _extractFoodNoun(String raw) {
    // Remove leading quantity: digits, fractions (1/2), decimals
    var s = raw
        .replaceAll(RegExp(r'^[\d/\.\s]+'), '')
        .trim();
    // Remove common unit words at start
    const units = [
      'cups', 'cup', 'tablespoons', 'tablespoon', 'tbsp', 'teaspoons',
      'teaspoon', 'tsp', 'kg', 'g', 'ml', 'litres', 'litre', 'liter',
      'pieces', 'piece', 'pcs', 'packs', 'pack', 'bunch', 'cloves', 'clove',
      'cans', 'can', 'bottles', 'bottle', 'large', 'medium', 'small',
      'fresh', 'dried', 'ground', 'sliced', 'chopped', 'diced', 'unripe',
      'ripe', 'cooked', 'raw', 'whole', 'halved', 'cubed', 'grated',
    ];
    for (final unit in units) {
      if (s.toLowerCase().startsWith('$unit ')) {
        s = s.substring(unit.length).trim();
      }
    }
    return s.isNotEmpty ? s : raw;
  }

  bool _ingredientMatches(String pantryName, String ingredientName) {
    final p = pantryName.toLowerCase().trim();
    final i = ingredientName.toLowerCase().trim();
    if (p.contains(i) || i.contains(p)) return true;
    final pantryWords = p.split(RegExp(r'[\s,]+'));
    final ingWords = i.split(RegExp(r'[\s,]+'));
    return pantryWords.any((w) => w.length > 2 && ingWords.contains(w));
  }

  List<String> _ingredientKeywords(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'^\d+[\s]*(g|kg|ml|l|oz|lb|pcs|pack)?\s*',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'[,.].*'), '')
        .trim()
        .toLowerCase();

    final keywords = <String>[];
    if (cleaned.isNotEmpty) keywords.add(cleaned);

    final words = cleaned
        .split(RegExp(r'[\s]+'))
        .where((w) => w.length > 2)
        .toList();
    for (final w in words) {
      if (!keywords.contains(w)) keywords.add(w);
    }
    return keywords.isEmpty ? [name.toLowerCase().trim()] : keywords;
  }

  static final FoodItem _noMatch = FoodItem(
    id: '',
    name: '',
    barcode: '',
    category: '',
    quantity: 0,
    unit: '',
    purchaseDate: DateTime(2000),
    expiryDate: DateTime(2000),
    storageLocation: '',
    householdId: '',
    addedBy: '',
    createdAt: DateTime(2000),
  );
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _MealScore {
  final int rawMatchCount;
  final int expiryMatchCount;
  const _MealScore(
      {required this.rawMatchCount, required this.expiryMatchCount});
}

class _AfricanFoodEntry {
  final Map<String, dynamic> food;
  final int matchCount;
  final int expiryCount;
  const _AfricanFoodEntry(
      {required this.food,
      required this.matchCount,
      required this.expiryCount});
}

// ── Result container ──────────────────────────────────────────────────────────

class RecipeRecommendationResult {
  final List<MatchedRecipe> expiring;
  final List<MatchedRecipe> quickMatch;

  const RecipeRecommendationResult({
    required this.expiring,
    required this.quickMatch,
  });

  bool get isEmpty => expiring.isEmpty && quickMatch.isEmpty;
}
