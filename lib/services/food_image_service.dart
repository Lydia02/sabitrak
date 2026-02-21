import 'dart:convert';
import 'package:http/http.dart' as http;

/// Finds a food image URL for a given ingredient/product name.
///
/// Sources tried in order (all free, no API key):
///   1. Open Food Facts name search  — great for packaged goods
///   2. TheMealDB ingredient thumbnail — good for raw ingredients
///
/// Returns null if nothing found — callers should fall back to category icon.
class FoodImageService {
  static const String _offSearch =
      'https://world.openfoodfacts.org/cgi/search.pl';
  static const String _mealDbIngredient =
      'https://www.themealdb.com/images/ingredients';

  /// Try to find an image URL for [foodName].
  /// Always returns quickly — timeouts are short and errors are swallowed.
  static Future<String?> findImageUrl(String foodName) async {
    final name = foodName.trim();
    if (name.isEmpty) return null;

    // 1. Open Food Facts name search (best for packaged items like Indomie, Pringles)
    final offUrl = await _searchOff(name);
    if (offUrl != null) return offUrl;

    // 2. TheMealDB ingredient image (best for raw produce like chicken, rice, yam)
    final mdbUrl = _mealDbIngredientUrl(name);
    final exists = await _urlExists(mdbUrl);
    if (exists) return mdbUrl;

    return null;
  }

  // ── Open Food Facts ──────────────────────────────────────────────────────────

  static Future<String?> _searchOff(String name) async {
    try {
      final uri = Uri.parse(_offSearch).replace(queryParameters: {
        'search_terms': name,
        'json': '1',
        'page_size': '3',
        'fields': 'product_name,image_front_url',
      });
      final response = await http
          .get(uri,
              headers: {'User-Agent': 'SabiTrak/1.0 (pantry management app)'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final products =
          (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      for (final p in products) {
        final imgUrl = p['image_front_url'] as String?;
        if (imgUrl != null && imgUrl.isNotEmpty) return imgUrl;
      }
    } catch (_) {}
    return null;
  }

  // ── TheMealDB ingredient thumbnail ──────────────────────────────────────────

  /// TheMealDB hosts ingredient images at a predictable URL:
  /// https://www.themealdb.com/images/ingredients/{Ingredient}-Small.png
  static String _mealDbIngredientUrl(String name) {
    // Capitalise first letter of each word, replace spaces with hyphens
    final formatted = name
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join('%20');
    return '$_mealDbIngredient/$formatted-Small.png';
  }

  /// HEAD request to check if a URL actually returns an image (not 404).
  static Future<bool> _urlExists(String url) async {
    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
