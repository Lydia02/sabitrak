import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/food_item.dart';

/// A snack suggestion generated from Open Food Facts product data.
class SnackSuggestion {
  final String itemName;
  final String productName;
  final String? imageUrl;
  final String category;
  final String servingSuggestion;
  final String emoji;

  const SnackSuggestion({
    required this.itemName,
    required this.productName,
    this.imageUrl,
    required this.category,
    required this.servingSuggestion,
    required this.emoji,
  });
}

/// Queries Open Food Facts for snack/beverage/packaged items in the pantry
/// and returns serving suggestions.
class SnackService {
  static const String _base = 'https://world.openfoodfacts.org';

  static const Set<String> _snackCategories = {
    'snacks',
    'beverages',
    'other',
    'canned',
    'cereals',
    'breakfast',
    'bread',
    'bakery',
    'dairy',
    'eggs',
    'condiments',
    'spreads',
  };

  /// Name keywords that qualify any item as a quick/no-cook item regardless of category.
  static const List<String> _quickKeywords = [
    'cereal', 'cornflakes', 'oats', 'granola', 'muesli',
    'bread', 'toast', 'biscuit', 'cracker', 'wafer',
    'noodle', 'indomie', 'instant', 'maggi', 'cup noodle',
    'egg', 'boiled egg',
    'yogurt', 'yoghurt', 'milk', 'cheese',
    'peanut butter', 'jam', 'honey', 'spread', 'margarine', 'butter',
    'juice', 'drink', 'water', 'milo', 'ovaltine', 'bournvita',
    'banana', 'apple', 'orange', 'fruit',
    'chocolate', 'candy', 'sweet', 'candy bar',
    'chips', 'crisps', 'popcorn', 'pringles',
    'nuts', 'peanut', 'groundnut', 'cashew', 'almond',
    'sardine', 'tuna', 'corned beef',
    'plantain chips', 'gari', 'garri',
  ];

  /// Returns snack/quick-eat suggestions for pantry items that are in snack-like
  /// categories, have a barcode, or match quick-eat keywords — no cooking required.
  Future<List<SnackSuggestion>> getSuggestions(
      List<FoodItem> pantryItems) async {
    // Filter: snack-category OR barcoded OR name matches a quick keyword
    final snackItems = pantryItems.where((item) {
      final cat = item.category.toLowerCase();
      final name = item.name.toLowerCase();
      if (_snackCategories.contains(cat)) return true;
      if (item.barcode.isNotEmpty) return true;
      return _quickKeywords.any((kw) => name.contains(kw));
    }).toList();

    if (snackItems.isEmpty) return [];

    final suggestions = <SnackSuggestion>[];
    final seen = <String>{};

    final futures = snackItems.map((item) => _fetchSuggestion(item));
    final results = await Future.wait(futures);

    for (final s in results) {
      if (s != null && !seen.contains(s.itemName.toLowerCase())) {
        seen.add(s.itemName.toLowerCase());
        suggestions.add(s);
      }
    }

    return suggestions;
  }

  Future<SnackSuggestion?> _fetchSuggestion(FoodItem item) async {
    try {
      Map<String, dynamic>? product;

      // Try barcode lookup first (most accurate)
      if (item.barcode.isNotEmpty) {
        product = await _lookupByBarcode(item.barcode);
      }

      // Fall back to name search
      if (product == null) {
        product = await _searchByName(item.name);
      }

      if (product == null) {
        // Return a generic suggestion based on category
        return _genericSuggestion(item);
      }

      final productName = (product['product_name'] as String?)?.trim() ??
          (product['product_name_en'] as String?)?.trim() ??
          item.name;

      final imageUrl = product['image_front_url'] as String? ??
          product['image_url'] as String?;

      final offCategory =
          (product['categories'] as String? ?? '').toLowerCase();

      return SnackSuggestion(
        itemName: item.name,
        productName: productName.isNotEmpty ? productName : item.name,
        imageUrl: imageUrl,
        category: item.category,
        servingSuggestion: _servingSuggestionFor(item.name, offCategory),
        emoji: _emojiFor(item.name, offCategory),
      );
    } catch (_) {
      return _genericSuggestion(item);
    }
  }

  Future<Map<String, dynamic>?> _lookupByBarcode(String barcode) async {
    try {
      final uri =
          Uri.parse('$_base/api/v0/product/$barcode.json?fields=product_name,product_name_en,image_front_url,image_url,categories');
      final response = await http.get(uri,
          headers: {'User-Agent': 'SabiTrak/1.0 (pantry management app)'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if ((data['status'] as int? ?? 0) != 1) return null;
      return data['product'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _searchByName(String name) async {
    try {
      final query = Uri.encodeComponent(name.trim());
      final uri = Uri.parse(
          '$_base/cgi/search.pl?search_terms=$query&json=1&page_size=1&fields=product_name,product_name_en,image_front_url,image_url,categories');
      final response = await http.get(uri,
          headers: {'User-Agent': 'SabiTrak/1.0 (pantry management app)'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final products =
          (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return products.isNotEmpty ? products.first : null;
    } catch (_) {
      return null;
    }
  }

  SnackSuggestion _genericSuggestion(FoodItem item) {
    return SnackSuggestion(
      itemName: item.name,
      productName: item.name,
      imageUrl: null,
      category: item.category,
      servingSuggestion: _servingSuggestionFor(item.name, ''),
      emoji: _emojiFor(item.name, ''),
    );
  }

  String _servingSuggestionFor(String name, String offCategory) {
    final n = name.toLowerCase();
    final c = offCategory.toLowerCase();

    // Cereals & breakfast
    if (n.contains('cornflakes') || n.contains('corn flakes')) return 'Pour into a bowl, add cold milk — done in 1 min';
    if (n.contains('cereal') || n.contains('granola') || n.contains('muesli') || c.contains('cereal')) return 'Add milk or yogurt for a quick no-cook breakfast';
    if (n.contains('oat') || n.contains('oatmeal') || n.contains('quaker')) return 'Add hot water or milk and stir — ready in 3 min';
    if (n.contains('milo') || n.contains('ovaltine') || n.contains('bournvita') || n.contains('horlicks')) return 'Mix with hot or cold milk for an instant energy drink';

    // Bread & spreads
    if (n.contains('bread') || c.contains('bread') || c.contains('bakery')) return 'Toast and spread with butter, jam, or peanut butter';
    if (n.contains('peanut butter') || n.contains('jam') || n.contains('jelly') || n.contains('spread')) return 'Spread on bread or crackers for a quick bite';
    if (n.contains('margarine') || n.contains('butter')) return 'Spread on toast or warm bread — ready instantly';

    // Eggs
    if (n.contains('egg')) return 'Boil, fry, or microwave in under 5 min';

    // Instant noodles
    if (n.contains('indomie') || n.contains('instant noodle') || n.contains('cup noodle') || n.contains('maggi noodle')) return 'Boil for 3 min, add seasoning — fastest hot meal ever';
    if (n.contains('noodle') || c.contains('noodle')) return 'Quick 5-min meal: boil and season to taste';

    // Dairy
    if (n.contains('yogurt') || n.contains('yoghurt') || c.contains('yogurt')) return 'Top with honey or granola for a quick snack';
    if (n.contains('milk') || c.contains('dairy')) return 'Drink cold or mix with cereal';
    if (n.contains('cheese')) return 'Slice onto crackers or bread — no cooking needed';

    // Chips & crisps
    if (n.contains('pringles') || n.contains('chips') || n.contains('crisp') || c.contains('chips')) return 'Enjoy with a cold drink or dip';

    // Biscuits & cookies
    if (n.contains('biscuit') || n.contains('cookie') || n.contains('cracker') || c.contains('biscuit') || c.contains('cookie')) return 'Great with tea, coffee, or milk';

    // Chocolate & sweets
    if (n.contains('chocolate') || c.contains('chocolate')) return 'Eat as-is or melt over ice cream';

    // Drinks
    if (n.contains('juice') || n.contains('drink') || c.contains('beverage') || c.contains('juice')) return 'Serve chilled — no prep needed';

    // Nuts
    if (n.contains('cashew') || n.contains('almond') || n.contains('groundnut') || n.contains('peanut') || c.contains('nut')) return 'Grab a handful — great protein snack on the go';

    // Canned fish
    if (n.contains('sardine') || n.contains('tuna') || n.contains('corned beef') || c.contains('fish')) return 'Serve on crackers or toast — open and eat';

    // African quick bites
    if (n.contains('garri') || n.contains('gari')) return 'Soak in cold water with sugar and groundnuts for a quick snack';
    if (n.contains('plantain chip') || n.contains('chin chin')) return 'Ready to eat straight from the pack';

    // Fruits
    if (n.contains('banana') || n.contains('apple') || n.contains('orange') || n.contains('mango')) return 'Rinse and enjoy as-is — nature\'s fastest snack';

    // Popcorn & corn
    if (n.contains('popcorn') || n.contains('corn')) return 'Pop or enjoy as a crunchy snack';

    return 'Ready to eat — no cooking required';
  }

  String _emojiFor(String name, String offCategory) {
    final n = name.toLowerCase();
    final c = offCategory.toLowerCase();

    if (n.contains('cornflakes') || n.contains('cereal') || n.contains('granola') || n.contains('muesli') || c.contains('cereal')) return '🥣';
    if (n.contains('oat') || n.contains('oatmeal')) return '🥣';
    if (n.contains('milo') || n.contains('ovaltine') || n.contains('bournvita')) return '☕';
    if (n.contains('bread') || c.contains('bread') || c.contains('bakery')) return '🍞';
    if (n.contains('peanut butter')) return '🥜';
    if (n.contains('jam') || n.contains('jelly') || n.contains('honey')) return '🍯';
    if (n.contains('egg')) return '🥚';
    if (n.contains('indomie') || n.contains('instant noodle') || n.contains('noodle') || c.contains('noodle')) return '🍜';
    if (n.contains('cheese')) return '🧀';
    if (n.contains('yogurt') || n.contains('yoghurt') || n.contains('milk') || c.contains('dairy')) return '🥛';
    if (n.contains('pringles') || n.contains('chips') || n.contains('crisp') || c.contains('chips')) return '🥔';
    if (n.contains('chocolate') || c.contains('chocolate')) return '🍫';
    if (n.contains('biscuit') || n.contains('cookie') || n.contains('cracker') || c.contains('biscuit')) return '🍪';
    if (n.contains('juice') || n.contains('drink') || c.contains('juice')) return '🥤';
    if (n.contains('cashew') || n.contains('almond') || n.contains('peanut') || n.contains('groundnut') || c.contains('nut')) return '🥜';
    if (n.contains('sardine') || n.contains('tuna') || n.contains('corned beef') || c.contains('fish')) return '🐟';
    if (n.contains('popcorn') || n.contains('corn')) return '🍿';
    if (n.contains('banana')) return '🍌';
    if (n.contains('apple')) return '🍎';
    if (n.contains('orange')) return '🍊';
    if (n.contains('garri') || n.contains('gari')) return '🥣';
    if (n.contains('plantain chip') || n.contains('chin chin')) return '🍟';
    return '⚡';
  }
}
