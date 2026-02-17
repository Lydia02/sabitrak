import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// GS1 country prefix detection for African and common barcodes
class BarcodeCountryInfo {
  final String country;
  final String flag;
  final String prefix;

  const BarcodeCountryInfo({
    required this.country,
    required this.flag,
    required this.prefix,
  });

  /// Detect country of origin from GS1 barcode prefix
  static BarcodeCountryInfo? fromBarcode(String barcode) {
    if (barcode.length < 3) return null;

    // Try 3-digit prefix first, then 2-digit
    final p3 = barcode.substring(0, 3);
    final p2 = barcode.substring(0, 2);

    // African countries
    const africanPrefixes = <String, List<String>>{
      '600': ['South Africa', '\u{1F1FF}\u{1F1E6}'],
      '601': ['South Africa', '\u{1F1FF}\u{1F1E6}'],
      '603': ['Ghana', '\u{1F1EC}\u{1F1ED}'],
      '608': ['Bahrain', '\u{1F1E7}\u{1F1ED}'],
      '609': ['Mauritius', '\u{1F1F2}\u{1F1FA}'],
      '611': ['Morocco', '\u{1F1F2}\u{1F1E6}'],
      '613': ['Algeria', '\u{1F1E9}\u{1F1FF}'],
      '615': ['Nigeria', '\u{1F1F3}\u{1F1EC}'],
      '616': ['Kenya', '\u{1F1F0}\u{1F1EA}'],
      '618': ["C\u00f4te d'Ivoire", '\u{1F1E8}\u{1F1EE}'],
      '619': ['Tunisia', '\u{1F1F9}\u{1F1F3}'],
      '621': ['Egypt', '\u{1F1EA}\u{1F1EC}'],
      '622': ['Egypt', '\u{1F1EA}\u{1F1EC}'],
      '624': ['Libya', '\u{1F1F1}\u{1F1FE}'],
      '625': ['Jordan', '\u{1F1EF}\u{1F1F4}'],
      '626': ['Iran', '\u{1F1EE}\u{1F1F7}'],
      '627': ['Kuwait', '\u{1F1F0}\u{1F1FC}'],
      '628': ['Saudi Arabia', '\u{1F1F8}\u{1F1E6}'],
      '629': ['UAE', '\u{1F1E6}\u{1F1EA}'],
    };

    // Common international prefixes
    const internationalPrefixes = <String, List<String>>{
      '00': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '01': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '02': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '03': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '04': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '05': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '06': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '07': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '08': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '09': ['USA / Canada', '\u{1F1FA}\u{1F1F8}'],
      '30': ['France', '\u{1F1EB}\u{1F1F7}'],
      '31': ['France', '\u{1F1EB}\u{1F1F7}'],
      '32': ['France', '\u{1F1EB}\u{1F1F7}'],
      '33': ['France', '\u{1F1EB}\u{1F1F7}'],
      '34': ['France', '\u{1F1EB}\u{1F1F7}'],
      '35': ['France', '\u{1F1EB}\u{1F1F7}'],
      '36': ['France', '\u{1F1EB}\u{1F1F7}'],
      '37': ['France', '\u{1F1EB}\u{1F1F7}'],
      '40': ['Germany', '\u{1F1E9}\u{1F1EA}'],
      '41': ['Germany', '\u{1F1E9}\u{1F1EA}'],
      '42': ['Germany', '\u{1F1E9}\u{1F1EA}'],
      '43': ['Germany', '\u{1F1E9}\u{1F1EA}'],
      '44': ['Germany', '\u{1F1E9}\u{1F1EA}'],
      '45': ['Japan', '\u{1F1EF}\u{1F1F5}'],
      '49': ['Japan', '\u{1F1EF}\u{1F1F5}'],
      '46': ['Russia', '\u{1F1F7}\u{1F1FA}'],
      '47': ['Taiwan', '\u{1F1F9}\u{1F1FC}'],
      '48': ['Philippines', '\u{1F1F5}\u{1F1ED}'],
      '50': ['United Kingdom', '\u{1F1EC}\u{1F1E7}'],
      '52': ['Greece', '\u{1F1EC}\u{1F1F7}'],
      '53': ['Ireland', '\u{1F1EE}\u{1F1EA}'],
      '54': ['Belgium', '\u{1F1E7}\u{1F1EA}'],
      '57': ['Denmark', '\u{1F1E9}\u{1F1F0}'],
      '64': ['Finland', '\u{1F1EB}\u{1F1EE}'],
      '69': ['China', '\u{1F1E8}\u{1F1F3}'],
      '73': ['Sweden', '\u{1F1F8}\u{1F1EA}'],
      '74': ['Central America', '\u{1F30E}'],
      '75': ['Mexico', '\u{1F1F2}\u{1F1FD}'],
      '76': ['Switzerland', '\u{1F1E8}\u{1F1ED}'],
      '77': ['Colombia', '\u{1F1E8}\u{1F1F4}'],
      '78': ['Argentina', '\u{1F1E6}\u{1F1F7}'],
      '79': ['Brazil', '\u{1F1E7}\u{1F1F7}'],
      '80': ['Italy', '\u{1F1EE}\u{1F1F9}'],
      '84': ['Spain', '\u{1F1EA}\u{1F1F8}'],
      '85': ['Cuba', '\u{1F1E8}\u{1F1FA}'],
      '86': ['Turkey', '\u{1F1F9}\u{1F1F7}'],
      '87': ['Netherlands', '\u{1F1F3}\u{1F1F1}'],
      '88': ['South Korea', '\u{1F1F0}\u{1F1F7}'],
      '89': ['India', '\u{1F1EE}\u{1F1F3}'],
      '90': ['Austria', '\u{1F1E6}\u{1F1F9}'],
      '93': ['Australia', '\u{1F1E6}\u{1F1FA}'],
      '94': ['New Zealand', '\u{1F1F3}\u{1F1FF}'],
    };

    // Check 3-digit African prefixes first
    if (africanPrefixes.containsKey(p3)) {
      final info = africanPrefixes[p3]!;
      return BarcodeCountryInfo(country: info[0], flag: info[1], prefix: p3);
    }

    // Check 2-digit international prefixes
    if (internationalPrefixes.containsKey(p2)) {
      final info = internationalPrefixes[p2]!;
      return BarcodeCountryInfo(country: info[0], flag: info[1], prefix: p2);
    }

    return null;
  }
}

class ScannedProduct {
  final String barcode;
  final String name;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final String? quantity;
  final String source;

  const ScannedProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.category,
    this.imageUrl,
    this.quantity,
    this.source = 'openfoodfacts',
  });

  /// Map Open Food Facts categories to app categories
  String get appCategory {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('fruit')) return 'Fruits';
    if (cat.contains('vegetable') || cat.contains('legume')) return 'Vegetables';
    if (cat.contains('dairy') || cat.contains('milk') || cat.contains('cheese') || cat.contains('yogurt')) return 'Dairy';
    if (cat.contains('meat') || cat.contains('fish') || cat.contains('poultry') || cat.contains('seafood')) return 'Meat & Fish';
    if (cat.contains('grain') || cat.contains('cereal') || cat.contains('bread') || cat.contains('pasta') || cat.contains('rice')) return 'Grains';
    if (cat.contains('canned') || cat.contains('preserved')) return 'Canned';
    if (cat.contains('spice') || cat.contains('sauce') || cat.contains('condiment') || cat.contains('seasoning')) return 'Spices';
    if (cat.contains('beverage') || cat.contains('drink') || cat.contains('juice') || cat.contains('water') || cat.contains('soda')) return 'Beverages';
    if (cat.contains('snack') || cat.contains('chip') || cat.contains('biscuit') || cat.contains('cookie') || cat.contains('chocolate') || cat.contains('candy') || cat.contains('sweet')) return 'Snacks';
    if (cat.contains('frozen')) return 'Frozen';
    return 'Other';
  }

  /// Display name combining brand + name
  String get displayName {
    if (brand != null && brand!.isNotEmpty && !name.toLowerCase().contains(brand!.toLowerCase())) {
      return '$brand $name';
    }
    return name;
  }
}

/// Result combining product info with country detection
class BarcodeLookupResult {
  final ScannedProduct? product;
  final BarcodeCountryInfo? countryInfo;
  final String barcode;

  const BarcodeLookupResult({
    this.product,
    this.countryInfo,
    required this.barcode,
  });
}

class OpenFoodFactsService {
  static const String _offBaseUrl = 'https://world.openfoodfacts.org/api/v2/product';
  static const String _goUpcBaseUrl = 'https://go-upc.com/api/v1/code';
  static const String _upcitemdbBaseUrl = 'https://api.upcitemdb.com/prod/trial/lookup';
  static const Duration _timeout = Duration(seconds: 10);

  final String? _goUpcApiKey;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  OpenFoodFactsService({String? goUpcApiKey}) : _goUpcApiKey = goUpcApiKey;

  /// Multi-source lookup chain:
  /// 1. Community DB (Firebase) -> 2. Open Food Facts -> 3. Go-UPC -> 4. UPCitemdb
  Future<BarcodeLookupResult> lookupBarcode(String barcode) async {
    final countryInfo = BarcodeCountryInfo.fromBarcode(barcode);

    // 1. Try Community Database first (fastest, most relevant for Africa)
    final communityProduct = await _getFromCommunityDB(barcode);
    if (communityProduct != null) {
      return BarcodeLookupResult(
        product: communityProduct,
        countryInfo: countryInfo,
        barcode: barcode,
      );
    }

    // 2. Try Open Food Facts
    final offProduct = await _getFromOpenFoodFacts(barcode);
    if (offProduct != null) {
      return BarcodeLookupResult(
        product: offProduct,
        countryInfo: countryInfo,
        barcode: barcode,
      );
    }

    // 3. Try Go-UPC as fallback
    if (_goUpcApiKey != null) {
      final goUpcProduct = await _getFromGoUpc(barcode);
      if (goUpcProduct != null) {
        return BarcodeLookupResult(
          product: goUpcProduct,
          countryInfo: countryInfo,
          barcode: barcode,
        );
      }
    }

    // 4. Try UPCitemdb as last resort
    final upcProduct = await _getFromUpcitemdb(barcode);
    if (upcProduct != null) {
      return BarcodeLookupResult(
        product: upcProduct,
        countryInfo: countryInfo,
        barcode: barcode,
      );
    }

    // No product found, but still return country info
    return BarcodeLookupResult(
      countryInfo: countryInfo,
      barcode: barcode,
    );
  }

  /// Save a product to the community database for other users
  Future<void> saveToCommunitDB({
    required String barcode,
    required String name,
    String? brand,
    String? category,
    String? imageUrl,
    String? quantity,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final docRef = _firestore.collection('community_products').doc(barcode);
    final existing = await docRef.get();

    if (existing.exists) {
      // Product already exists — increment confirmation count
      await docRef.update({
        'confirmedCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // New product — create entry
      await docRef.set({
        'barcode': barcode,
        'name': name,
        'brand': brand ?? '',
        'category': category ?? 'Other',
        'imageUrl': imageUrl ?? '',
        'quantity': quantity ?? '',
        'contributedBy': user?.uid ?? 'anonymous',
        'confirmedCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get community product count for stats
  Future<int> getCommunityProductCount() async {
    try {
      final snapshot = await _firestore
          .collection('community_products')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Legacy method for backwards compatibility
  Future<ScannedProduct?> getProduct(String barcode) async {
    final result = await lookupBarcode(barcode);
    return result.product;
  }

  /// 1. Community Database lookup (Firebase Firestore)
  Future<ScannedProduct?> _getFromCommunityDB(String barcode) async {
    try {
      final doc = await _firestore
          .collection('community_products')
          .doc(barcode)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final name = (data['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      return ScannedProduct(
        barcode: barcode,
        name: name,
        brand: (data['brand'] as String?)?.trim(),
        category: (data['category'] as String?)?.trim(),
        imageUrl: (data['imageUrl'] as String?)?.trim(),
        quantity: (data['quantity'] as String?)?.trim(),
        source: 'community',
      );
    } catch (_) {
      return null;
    }
  }

  /// 2. Open Food Facts lookup
  Future<ScannedProduct?> _getFromOpenFoodFacts(String barcode) async {
    try {
      final url = Uri.parse('$_offBaseUrl/$barcode.json');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SabiTrak/1.0 (Flutter; contact@sabitrak.com)',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name = (product['product_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      return ScannedProduct(
        barcode: barcode,
        name: name,
        brand: (product['brands'] as String?)?.trim(),
        category: (product['categories'] as String?)?.trim(),
        imageUrl: product['image_front_url'] as String?,
        quantity: (product['quantity'] as String?)?.trim(),
        source: 'openfoodfacts',
      );
    } catch (_) {
      return null;
    }
  }

  /// 3. Go-UPC fallback lookup
  Future<ScannedProduct?> _getFromGoUpc(String barcode) async {
    try {
      final url = Uri.parse('$_goUpcBaseUrl/$barcode');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_goUpcApiKey',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name = (product['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      return ScannedProduct(
        barcode: barcode,
        name: name,
        brand: (product['brand'] as String?)?.trim(),
        category: (product['category'] as String?)?.trim(),
        imageUrl: (product['imageUrl'] as String?)?.trim(),
        source: 'goupc',
      );
    } catch (_) {
      return null;
    }
  }

  /// 4. UPCitemdb fallback lookup (100 free lookups/day, no API key needed)
  Future<ScannedProduct?> _getFromUpcitemdb(String barcode) async {
    try {
      final url = Uri.parse('$_upcitemdbBaseUrl?upc=$barcode');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'SabiTrak/1.0',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['code'] != 'OK') return null;

      final items = data['items'] as List?;
      if (items == null || items.isEmpty) return null;

      final item = items[0] as Map<String, dynamic>;
      final name = (item['title'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      // Get image from images array
      String? imageUrl;
      final images = item['images'] as List?;
      if (images != null && images.isNotEmpty) {
        imageUrl = images[0] as String?;
      }

      return ScannedProduct(
        barcode: barcode,
        name: name,
        brand: (item['brand'] as String?)?.trim(),
        category: (item['category'] as String?)?.trim(),
        imageUrl: imageUrl,
        source: 'upcitemdb',
      );
    } catch (_) {
      return null;
    }
  }
}
