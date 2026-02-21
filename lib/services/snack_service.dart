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
  };

  /// Returns snack suggestions for pantry items that are in snack-like categories
  /// or have a barcode (scanned products).
  Future<List<SnackSuggestion>> getSuggestions(
      List<FoodItem> pantryItems) async {
    // Filter to snack-category or barcoded items
    final snackItems = pantryItems
        .where((item) =>
            _snackCategories.contains(item.category.toLowerCase()) ||
            item.barcode.isNotEmpty)
        .toList();

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

    if (n.contains('pringles') || n.contains('chips') || n.contains('crisp') || c.contains('chips')) {
      return 'Enjoy with a cold drink or dip';
    }
    if (n.contains('biscuit') || n.contains('cookie') || c.contains('biscuit') || c.contains('cookie')) {
      return 'Great with tea, coffee, or milk';
    }
    if (n.contains('chocolate') || c.contains('chocolate')) {
      return 'Melt over ice cream or enjoy as-is';
    }
    if (n.contains('juice') || n.contains('drink') || c.contains('beverage') || c.contains('juice')) {
      return 'Serve chilled with a snack';
    }
    if (n.contains('nut') || n.contains('groundnut') || n.contains('peanut') || c.contains('nut')) {
      return 'Add to salads or enjoy as a protein snack';
    }
    if (n.contains('yogurt') || n.contains('yoghurt') || c.contains('yogurt')) {
      return 'Top with honey or fruit for a quick snack';
    }
    if (n.contains('bread') || c.contains('bread')) {
      return 'Toast and top with butter, egg, or avocado';
    }
    if (n.contains('noodle') || n.contains('indomie') || n.contains('pasta') || c.contains('noodle')) {
      return 'Quick 5-min meal: boil and season to taste';
    }
    if (n.contains('sardine') || n.contains('tuna') || c.contains('fish')) {
      return 'Serve on crackers or toast for a quick meal';
    }
    if (n.contains('corn') || n.contains('popcorn')) {
      return 'Pop or enjoy as a crunchy snack';
    }
    return 'Ready to eat — a quick and easy snack';
  }

  String _emojiFor(String name, String offCategory) {
    final n = name.toLowerCase();
    final c = offCategory.toLowerCase();

    if (n.contains('pringles') || n.contains('chips') || n.contains('crisp') || c.contains('chips')) return '🥔';
    if (n.contains('chocolate') || c.contains('chocolate')) return '🍫';
    if (n.contains('biscuit') || n.contains('cookie') || c.contains('biscuit')) return '🍪';
    if (n.contains('juice') || n.contains('drink') || c.contains('juice')) return '🥤';
    if (n.contains('nut') || n.contains('peanut') || c.contains('nut')) return '🥜';
    if (n.contains('yogurt') || n.contains('yoghurt')) return '🥛';
    if (n.contains('bread') || c.contains('bread')) return '🍞';
    if (n.contains('noodle') || n.contains('indomie') || c.contains('noodle')) return '🍜';
    if (n.contains('sardine') || n.contains('tuna') || c.contains('fish')) return '🐟';
    if (n.contains('popcorn') || n.contains('corn')) return '🍿';
    return '🍽️';
  }
}
