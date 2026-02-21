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

    // African DB is primary — run it first
    final africanMatched =
        await _getAfricanDbMatches(allItems, expiringItems);

    // Only query MealDB when African DB returned fewer than 6 results
    List<MatchedRecipe> mealDbMatched = [];
    if (africanMatched.length < 6) {
      mealDbMatched = await _getMealDbMatches(allItems, expiringItems);
    }

    // Merge: African first, then MealDB, dedup by normalised name
    final seen = <String>{};
    final merged = <MatchedRecipe>[];
    for (final r in [...africanMatched, ...mealDbMatched]) {
      final key = _normaliseName(r.name);
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

  /// Search by keyword — African DB is authoritative.
  /// MealDB is only consulted when African DB returns zero matches.
  Future<List<MatchedRecipe>> searchRecipes(
      String query, List<FoodItem> pantryItems) async {
    if (query.trim().isEmpty) return [];

    final allItems = pantryItems.where((item) => !item.isExpired).toList();
    final expiringItems =
        allItems.where((item) => item.isExpiringSoon).toList();

    // 1. Try African DB first
    final africanResults =
        await _searchAfricanDb(query, allItems, expiringItems);

    if (africanResults.isNotEmpty) {
      final sorted = List<MatchedRecipe>.from(africanResults)
        ..sort((a, b) => b.score.compareTo(a.score));
      return sorted.take(20).toList();
    }

    // 2. African DB found nothing → fall back to MealDB
    final mealResults =
        await _searchMealDb(query, allItems, expiringItems);
    mealResults.sort((a, b) => b.score.compareTo(a.score));
    return mealResults.take(20).toList();
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
              const _MealScore(rawMatchCount: 1, expiryMatchCount: 0),
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

    // MealDB results get no African bonus
    final score =
        (expiryBonus * 0.40) + (matchRatio * 0.30) + (prepBonus * 0.10);

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
      // Use each unique pantry item keyword — cap at 10 parallel calls
      final keywords = allItems
          .map((item) => _ingredientKeywords(item.name).first)
          .toSet()
          .take(10)
          .toList();

      final futures = keywords.map((kw) => _africanSearchAll(kw));
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
          final id = ((food['id'] as String?) ??
                  (food['_id'] as String?) ??
                  (food['name'] as String? ?? ''))
              .toLowerCase();
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
      final foods = await _africanSearchAll(query.trim(), limit: 20);
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

  /// Tries both search strategies and deduplicates results.
  ///   1. GET /api/search?q={keyword}       (fuzzy search)
  ///   2. GET /api/foods?search={keyword}    (keyword filter)
  Future<List<Map<String, dynamic>>> _africanSearchAll(String keyword,
      {int limit = 15}) async {
    final results = await Future.wait([
      _africanFuzzySearch(keyword, limit: limit),
      _africanFoodSearch(keyword, limit: limit),
    ]);

    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final list in results) {
      for (final food in list) {
        final key = ((food['id'] as String?) ??
                (food['_id'] as String?) ??
                (food['name'] as String? ?? ''))
            .toLowerCase();
        if (key.isNotEmpty && seen.add(key)) merged.add(food);
      }
    }
    return merged;
  }

  /// GET /api/search?q={query}&limit={limit}
  /// Response per docs: { success: true, data: { items: [...], totalMatches: N } }
  Future<List<Map<String, dynamic>>> _africanFuzzySearch(String keyword,
      {int limit = 15}) async {
    try {
      final uri = Uri.parse(
          '$_africanBase/api/search?q=${Uri.encodeComponent(keyword)}&limit=$limit');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final body = json.decode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) return [];
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        // Primary key per API documentation
        final items = data['items'];
        if (items is List && items.isNotEmpty) {
          return items.cast<Map<String, dynamic>>();
        }
        // Legacy fallback keys
        for (final key in ['results', 'foods', 'recipes']) {
          final v = data[key];
          if (v is List && v.isNotEmpty) {
            return v.cast<Map<String, dynamic>>();
          }
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/foods?search={keyword}&limit={limit}
  /// Response: { success: true, data: { items: [...] } }
  Future<List<Map<String, dynamic>>> _africanFoodSearch(String keyword,
      {int limit = 15}) async {
    try {
      final uri = Uri.parse(
          '$_africanBase/api/foods?search=${Uri.encodeComponent(keyword)}&limit=$limit');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final body = json.decode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) return [];
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        final items = data['items'];
        if (items is List && items.isNotEmpty) {
          return items.cast<Map<String, dynamic>>();
        }
        for (final key in ['foods', 'results']) {
          final v = data[key];
          if (v is List && v.isNotEmpty) {
            return v.cast<Map<String, dynamic>>();
          }
        }
      }
      if (data is List) return data.cast<Map<String, dynamic>>();
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

    // ingredients: List<Map {name,quantity,unit}> OR List<String>
    final rawIngredients = food['ingredients'];
    final ingredients = <RecipeIngredient>[];
    if (rawIngredients is List) {
      for (final ing in rawIngredients) {
        if (ing is Map<String, dynamic>) {
          final n = (ing['name'] as String?)?.trim() ?? '';
          final q = (ing['quantity'] as String?)?.trim() ?? '';
          final u = (ing['unit'] as String?)?.trim() ?? '';
          if (n.isNotEmpty) {
            final measure =
                [q, u].where((s) => s.isNotEmpty).join(' ').trim();
            ingredients.add(RecipeIngredient(name: n, measure: measure));
          }
        } else {
          final s = ing.toString().trim();
          if (s.isNotEmpty) {
            ingredients
                .add(RecipeIngredient(name: _extractFoodNoun(s), measure: ''));
          }
        }
      }
    }
    // Don't drop recipes with no parsed ingredients — use the dish name itself
    final effectiveIngredients = ingredients.isNotEmpty
        ? ingredients
        : [RecipeIngredient(name: name, measure: '')];

    // Match against pantry
    final matchedNames = <String>[];
    final expiringMatchedNames = <String>[];
    for (final ing in effectiveIngredients) {
      final pantryMatch = allPantry.firstWhere(
        (item) => _ingredientMatches(item.name, ing.name),
        orElse: () => _noMatch,
      );
      if (pantryMatch.id.isNotEmpty) {
        matchedNames.add(ing.name);
        if (expiringPantry.any((e) => e.id == pantryMatch.id)) {
          expiringMatchedNames.add(ing.name);
        }
      }
    }

    final matchRatio = effectiveIngredients.isEmpty
        ? 0.0
        : matchedNames.length / effectiveIngredients.length;
    final expiryBonus = effectiveIngredients.isEmpty
        ? 0.0
        : expiringMatchedNames.length / effectiveIngredients.length;

    // Build instructions string — handles List<Map {step,description}> or List<String>
    final rawInstructions = food['instructions'];
    String instructionsStr = '';
    if (rawInstructions is List) {
      instructionsStr = rawInstructions
          .asMap()
          .entries
          .map((e) {
            final val = e.value;
            if (val is Map<String, dynamic>) {
              final step = val['step'] ?? (e.key + 1);
              final desc =
                  val['description'] ?? val['text'] ?? val['instruction'] ?? '';
              return 'Step $step: $desc';
            }
            return val.toString();
          })
          .join('\n');
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

    // African DB results always get a base score bonus (0.20)
    // so they rank above MealDB results with similar pantry matches
    const double africanBonus = 1.0;
    final score = (africanBonus * 0.20) +
        (expiryBonus * 0.40) +
        (matchRatio * 0.30) +
        (prepBonus * 0.10);

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

    final categories = food['categories'];
    final category = (categories is List && categories.isNotEmpty)
        ? categories.first.toString()
        : 'African';

    return MatchedRecipe(
      id: 'afd_${food['id'] ?? food['_id'] ?? name.hashCode}',
      name: name,
      thumbnailUrl: (food['imageUrl'] as String?) ?? '',
      category: category,
      area: area,
      instructions: instructionsStr,
      youtubeUrl: '',
      ingredients: effectiveIngredients,
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

  /// Normalise a recipe name for deduplication.
  String _normaliseName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();

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
      'heaped', 'level', 'pinch', 'handful', 'sprigs', 'sprig',
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
