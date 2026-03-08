import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/food_item.dart';

/// Thin Hive wrapper that stores FoodItem data as plain Maps.
/// No code-generation needed — we serialise/deserialise manually.
class LocalCacheService {
  static const String _foodBox = 'food_items_cache';
  static const String _profileBox = 'user_profile_cache';

  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  /// Call once in main() before runApp.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(_foodBox);
    await Hive.openBox<String>(_profileBox);
  }

  Box<Map> get _box => Hive.box<Map>(_foodBox);
  Box<String> get _profileBox2 => Hive.box<String>(_profileBox);

  // ── Write ──────────────────────────────────────────────────────────────

  /// Replace the cached inventory for one household.
  Future<void> saveFoodItems(String householdId, List<FoodItem> items) async {
    final maps = {for (final item in items) item.id: _toMap(item)};
    // Clear old entries for this household first
    final keysToDelete =
        _box.keys
            .where((k) => k.toString().startsWith('${householdId}_'))
            .toList();
    await _box.deleteAll(keysToDelete);

    // Write each item with a compound key: <householdId>_<itemId>
    for (final entry in maps.entries) {
      await _box.put('${householdId}_${entry.key}', entry.value);
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────

  /// Returns cached items for a household (empty list if nothing cached).
  List<FoodItem> getCachedFoodItems(String householdId) {
    final prefix = '${householdId}_';
    final items = <FoodItem>[];
    for (final key in _box.keys) {
      if (key.toString().startsWith(prefix)) {
        final raw = _box.get(key);
        if (raw != null) {
          try {
            items.add(_fromMap(Map<String, dynamic>.from(raw)));
          } catch (_) {
            // Skip malformed entries
          }
        }
      }
    }
    // Sort by expiry date ascending (same as Firestore query)
    items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return items;
  }

  // ── User profile ───────────────────────────────────────────────────────

  /// Persist the signed-in user's profile so we can restore the session offline.
  Future<void> saveUserProfile({
    required String uid,
    required String displayName,
    required String householdId,
  }) async {
    await _profileBox2.put('uid', uid);
    await _profileBox2.put('displayName', displayName);
    await _profileBox2.put('householdId', householdId);
  }

  /// Returns null if no profile has ever been cached.
  Map<String, String>? getCachedUserProfile() {
    final uid = _profileBox2.get('uid');
    if (uid == null) return null;
    return {
      'uid': uid,
      'displayName': _profileBox2.get('displayName') ?? '',
      'householdId': _profileBox2.get('householdId') ?? '',
    };
  }

  Future<void> clearUserProfile() async {
    await _profileBox2.deleteAll(['uid', 'displayName', 'householdId']);
  }

  // ── Clear ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _box.clear();
    await _profileBox2.clear();
  }

  // ── Serialisation ──────────────────────────────────────────────────────

  Map<String, dynamic> _toMap(FoodItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'barcode': item.barcode,
      'category': item.category,
      'quantity': item.quantity,
      'unit': item.unit,
      'purchaseDate': item.purchaseDate.millisecondsSinceEpoch,
      'expiryDate': item.expiryDate.millisecondsSinceEpoch,
      'storageLocation': item.storageLocation,
      'imageUrl': item.imageUrl,
      'householdId': item.householdId,
      'addedBy': item.addedBy,
      'createdAt': item.createdAt.millisecondsSinceEpoch,
      'itemType': item.itemType.name,
    };
  }

  FoodItem _fromMap(Map<String, dynamic> m) {
    final typeStr = m['itemType'] as String? ?? 'ingredient';
    final itemType = ItemType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ItemType.ingredient,
    );
    return FoodItem(
      id: m['id'] as String,
      name: m['name'] as String? ?? '',
      barcode: m['barcode'] as String? ?? '',
      category: m['category'] as String? ?? '',
      quantity: m['quantity'] as int? ?? 0,
      unit: m['unit'] as String? ?? '',
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(
        m['purchaseDate'] as int,
      ),
      expiryDate: DateTime.fromMillisecondsSinceEpoch(m['expiryDate'] as int),
      storageLocation: m['storageLocation'] as String? ?? '',
      imageUrl: m['imageUrl'] as String?,
      householdId: m['householdId'] as String? ?? '',
      addedBy: m['addedBy'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      itemType: itemType,
    );
  }
}
