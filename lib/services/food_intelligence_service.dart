/// Smart food intelligence — auto-suggests category, storage location,
/// and shelf-life (days) from any food name.
///
/// Covers: African staples, tropical produce, universal pantry items,
/// dairy, meats, fish/seafood, grains, legumes, spices, beverages,
/// packaged goods, frozen foods, baked items, condiments & sauces.
///
/// Algorithm:
///   1. Exact key match (normalised lowercase)
///   2. Token-starts-with match on each word in the query
///   3. Token-contains match
///   4. Keyword pattern match (broadest)
///   5. Category default fallback
class FoodIntelligenceService {
  static FoodIntelligenceService? _instance;
  FoodIntelligenceService._();
  factory FoodIntelligenceService() =>
      _instance ??= FoodIntelligenceService._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a [FoodSuggestion] for the given food name.
  /// Never throws — always returns a result (may be a category default).
  FoodSuggestion suggest(String foodName) {
    if (foodName.trim().isEmpty) {
      return const FoodSuggestion(
        category: 'Other',
        storageLocation: 'Cupboard',
        shelfLifeDays: 14,
        tip: '',
        isGuessed: false,
      );
    }

    final q = _normalise(foodName);

    // 1. Exact match
    final exact = _db[q];
    if (exact != null) return exact;

    // 2. Token starts-with match (longest matching token wins)
    final tokens = q.split(RegExp(r'\s+'));
    FoodSuggestion? best;
    int bestLen = 0;
    for (final token in tokens) {
      if (token.length < 3) continue;
      for (final key in _db.keys) {
        if (key.startsWith(token) && token.length > bestLen) {
          best = _db[key];
          bestLen = token.length;
        }
      }
    }
    if (best != null) return best;

    // 3. Token-contains match
    for (final token in tokens) {
      if (token.length < 3) continue;
      for (final entry in _db.entries) {
        if (entry.key.contains(token)) return entry.value;
      }
    }

    // 4. Keyword pattern match
    final pattern = _matchPattern(q);
    if (pattern != null) return pattern;

    // 5. Fallback to category default
    return _categoryDefault(q);
  }

  // ── Pattern matching ───────────────────────────────────────────────────────

  static FoodSuggestion? _matchPattern(String q) {
    // Frozen anything
    if (q.contains('frozen') || q.startsWith('ice ')) {
      return _s('Frozen', 'Freezer', 90, 'Frozen foods keep 2–3 months. Check packaging for best-by date.');
    }
    // Canned / tinned
    if (q.contains('canned') || q.contains('tinned') || q.startsWith('can of') || q.contains(' tin')) {
      return _s('Canned', 'Cupboard', 730, 'Store in a cool dry cupboard. Refrigerate after opening.');
    }
    // Juice
    if (q.contains('juice')) {
      return _s('Beverages', 'Fridge', 7, 'Refrigerate after opening. Consume within 7 days.');
    }
    // Sauce / gravy / soup (packaged)
    if (q.contains('sauce') && !q.contains('hot sauce')) {
      return _s('Other', 'Cupboard', 365, 'Sealed sauces keep 1 year. Refrigerate after opening.');
    }
    // Soup
    if (q.contains('soup') && !q.contains('dry')) {
      return _s('Other', 'Fridge', 4, 'Refrigerate cooked soup. Consume within 4 days or freeze.');
    }
    // Stew / curry (cooked)
    if (q.contains('stew') || q.contains('curry')) {
      return _s('Other', 'Fridge', 4, 'Cool and refrigerate. Best within 4 days or freeze up to 3 months.');
    }
    // Powder / flour / mix
    if (q.contains('powder') || q.contains('flour') || q.contains('mix')) {
      return _s('Grains', 'Cupboard', 180, 'Store in airtight container in cool dry place.');
    }
    // Oil
    if (q.contains('oil')) {
      return _s('Other', 'Cupboard', 365, 'Store oil in a cool, dark cupboard away from heat.');
    }
    // Dried
    if (q.contains('dried') || q.contains('dry ')) {
      return _s('Spices', 'Cupboard', 365, 'Dried foods keep 6–12 months in airtight containers.');
    }
    // Smoked
    if (q.contains('smoked')) {
      return _s('Meat & Fish', 'Fridge', 14, 'Refrigerate smoked items. Keeps 2 weeks.');
    }
    // Drink / beverage
    if (q.contains('drink') || q.contains('water') || q.contains('tea') || q.contains('coffee')) {
      return _s('Beverages', 'Cupboard', 365, 'Store sealed beverages in a cool place.');
    }
    // Biscuit / cookie / crisp / chip
    if (q.contains('biscuit') || q.contains('cookie') || q.contains('crisp') || q.contains('chip')) {
      return _s('Snacks', 'Cupboard', 60, 'Store in airtight container. Keep dry.');
    }
    // Bread / roll / bun
    if (q.contains('bread') || q.contains('roll') || q.contains('bun') || q.contains('loaf')) {
      return _s('Other', 'Counter', 5, 'Keep at room temperature or freeze for longer shelf life.');
    }
    // Cake / pastry
    if (q.contains('cake') || q.contains('pastry') || q.contains('pie')) {
      return _s('Snacks', 'Counter', 4, 'Store at room temperature for 2–4 days or refrigerate.');
    }
    // Cooked rice / cooked food
    if (q.startsWith('cooked ') || q.contains('leftover')) {
      return _s('Other', 'Fridge', 3, 'Cool within 2 hours, refrigerate. Consume within 3 days.');
    }
    // Cheese
    if (q.contains('cheese')) {
      return _s('Dairy', 'Fridge', 30, 'Keep wrapped in fridge. Hard cheese lasts longer than soft.');
    }
    // Milk
    if (q.contains('milk')) {
      return _s('Dairy', 'Fridge', 7, 'Always refrigerate milk. Consume by best-before date.');
    }
    // Yoghurt
    if (q.contains('yoghurt') || q.contains('yogurt')) {
      return _s('Dairy', 'Fridge', 10, 'Keep refrigerated. Consume within 10 days of opening.');
    }
    // Egg
    if (q.contains('egg')) {
      return _s('Dairy', 'Counter', 21, 'Eggs keep 3 weeks at room temperature, 5 weeks if refrigerated.');
    }
    // Butter / margarine
    if (q.contains('butter') || q.contains('margarine')) {
      return _s('Dairy', 'Fridge', 30, 'Refrigerate. Can also be kept on counter in a butter dish for 1–2 weeks.');
    }
    // Chicken / poultry
    if (q.contains('chicken') || q.contains('turkey') || q.contains('duck') || q.contains('poultry')) {
      return _s('Meat & Fish', 'Fridge', 2, 'Keep in coldest part of fridge. Cook within 2 days or freeze.');
    }
    // Beef / pork / lamb / meat
    if (q.contains('beef') || q.contains('pork') || q.contains('lamb') || q.contains('meat') || q.contains('mince') || q.contains('goat')) {
      return _s('Meat & Fish', 'Fridge', 3, 'Refrigerate raw meat. Consume within 3 days or freeze.');
    }
    // Fish / seafood
    if (q.contains('fish') || q.contains('prawn') || q.contains('shrimp') || q.contains('seafood') || q.contains('tilapia') || q.contains('catfish') || q.contains('salmon') || q.contains('tuna')) {
      return _s('Meat & Fish', 'Fridge', 2, 'Fresh fish is highly perishable. Cook within 1–2 days or freeze.');
    }
    // Beans / lentils / legumes (dried)
    if (q.contains('beans') || q.contains('lentil') || q.contains('pea') || q.contains('cowpea')) {
      return _s('Grains', 'Cupboard', 365, 'Dried legumes last 1 year in airtight container.');
    }
    // Rice / grain
    if (q.contains('rice') || q.contains('grain') || q.contains('sorghum') || q.contains('millet') || q.contains('oat')) {
      return _s('Grains', 'Cupboard', 365, 'Keep in sealed container away from moisture.');
    }
    // Pasta / noodle
    if (q.contains('pasta') || q.contains('noodle') || q.contains('spaghetti') || q.contains('macaroni')) {
      return _s('Grains', 'Cupboard', 730, 'Dried pasta keeps 2 years in a cool dry cupboard.');
    }
    // Tomato
    if (q.contains('tomato')) {
      return _s('Vegetables', 'Counter', 7, 'Whole tomatoes are best stored at room temperature. Refrigerate only if cut.');
    }
    // Pepper / hot pepper
    if (q.contains('pepper') && !q.contains('peppercorn')) {
      return _s('Vegetables', 'Fridge', 14, 'Fresh peppers last 1–2 weeks in the fridge.');
    }
    // Onion / shallot
    if (q.contains('onion') || q.contains('shallot')) {
      return _s('Vegetables', 'Counter', 30, 'Store whole onions in a cool, dry, dark place.');
    }
    // Garlic / ginger
    if (q.contains('garlic') || q.contains('ginger')) {
      return _s('Spices', 'Counter', 30, 'Store in a cool dry place. Refrigerate peeled/cut pieces.');
    }
    // Fruit keywords
    if (q.contains('fruit') || q.contains('berry') || q.contains('melon')) {
      return _s('Fruits', 'Counter', 5, 'Store at room temperature until ripe, then refrigerate.');
    }
    // Leafy greens / vegetables
    if (q.contains('leaf') || q.contains('leaves') || q.contains('green') || q.contains('spinach') || q.contains('lettuce') || q.contains('salad')) {
      return _s('Vegetables', 'Fridge', 5, 'Store in fridge in a breathable bag. Use quickly.');
    }
    // Spice / seasoning
    if (q.contains('spice') || q.contains('seasoning') || q.contains('herb')) {
      return _s('Spices', 'Cupboard', 365, 'Store in airtight containers away from heat and light.');
    }
    // Snack / crisp
    if (q.contains('snack') || q.contains('cracker')) {
      return _s('Snacks', 'Cupboard', 90, 'Keep sealed in a cool dry place.');
    }

    return null;
  }

  // ── Category fallback ──────────────────────────────────────────────────────

  static FoodSuggestion _categoryDefault(String q) {
    // Generic heuristic from first word
    return _s('Other', 'Cupboard', 14, 'Check packaging for storage instructions.');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _normalise(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static FoodSuggestion _s(
    String category,
    String storage,
    int days,
    String tip,
  ) =>
      FoodSuggestion(
        category: category,
        storageLocation: storage,
        shelfLifeDays: days,
        tip: tip,
        isGuessed: true,
      );

  // ── Comprehensive food database ────────────────────────────────────────────
  // Key: normalised food name  →  FoodSuggestion

  static final Map<String, FoodSuggestion> _db = {
    // ── AFRICAN STAPLES ───────────────────────────────────────────────────────
    'jollof rice': _s('Grains', 'Fridge', 3, 'Refrigerate cooked jollof. Reheat thoroughly before eating.'),
    'fried rice': _s('Grains', 'Fridge', 3, 'Refrigerate cooked fried rice. Reheat thoroughly.'),
    'egusi': _s('Grains', 'Cupboard', 180, 'Dried egusi keeps 4–6 months in airtight container.'),
    'egusi soup': _s('Other', 'Fridge', 4, 'Refrigerate cooked soup. Consume within 4 days or freeze.'),
    'ogbono': _s('Grains', 'Cupboard', 180, 'Dried ogbono keeps up to 6 months away from moisture.'),
    'ogbono soup': _s('Other', 'Fridge', 4, 'Refrigerate and consume within 4 days.'),
    'banga soup': _s('Other', 'Fridge', 4, 'Palm nut soup is rich — refrigerate and use within 4 days.'),
    'okro soup': _s('Other', 'Fridge', 3, 'Refrigerate. Okra soups thicken quickly; best eaten within 3 days.'),
    'okra soup': _s('Other', 'Fridge', 3, 'Refrigerate. Consume within 3 days.'),
    'efo riro': _s('Other', 'Fridge', 3, 'Vegetable soups spoil quickly; refrigerate and use within 3 days.'),
    'edikaikong': _s('Other', 'Fridge', 3, 'Refrigerate. Consume within 3 days.'),
    'afang soup': _s('Other', 'Fridge', 3, 'Refrigerate and consume within 3 days.'),
    'ofe onugbu': _s('Other', 'Fridge', 3, 'Bitter leaf soup — refrigerate and consume within 3 days.'),
    'oha soup': _s('Other', 'Fridge', 3, 'Refrigerate. Consume within 3 days.'),
    'pepper soup': _s('Other', 'Fridge', 3, 'Refrigerate cooked pepper soup. Consume within 3 days.'),
    'moi moi': _s('Other', 'Fridge', 3, 'Refrigerate cooked moi moi. Best eaten within 3 days.'),
    'akara': _s('Other', 'Counter', 1, 'Best eaten fresh. Store at room temperature for max 1 day.'),
    'suya': _s('Meat & Fish', 'Fridge', 2, 'Refrigerate suya. Reheat before eating. Best within 2 days.'),
    'kilishi': _s('Meat & Fish', 'Cupboard', 30, 'Keep in cool dry place or refrigerate. Lasts up to a month.'),
    'ponmo': _s('Meat & Fish', 'Fridge', 3, 'Refrigerate cooked ponmo. Use within 3 days.'),
    'stockfish': _s('Meat & Fish', 'Cupboard', 365, 'Very long shelf life in cool dry storage. Rehydrate before use.'),
    'dried fish': _s('Meat & Fish', 'Cupboard', 90, 'Store in airtight container in cool dry place. Up to 3 months.'),
    'smoked fish': _s('Meat & Fish', 'Fridge', 14, 'Refrigerate smoked fish. Consume within 2 weeks.'),
    'crayfish': _s('Spices', 'Cupboard', 90, 'Keep dried crayfish in airtight container away from moisture.'),
    'ogi': _s('Grains', 'Fridge', 5, 'Prepared ogi/pap keeps 5 days refrigerated. Dry ogi powder lasts 3 months.'),
    'akamu': _s('Grains', 'Fridge', 5, 'Same as ogi/pap. Refrigerate and use within 5 days.'),
    'pap': _s('Grains', 'Fridge', 5, 'Refrigerate prepared pap. Consume within 5 days.'),
    'garri': _s('Grains', 'Cupboard', 180, 'Store in a dry airtight container. Keeps 4–6 months.'),
    'eba': _s('Grains', 'Counter', 1, 'Eba is best eaten immediately. Do not refrigerate.'),
    'fufu': _s('Grains', 'Counter', 1, 'Eat immediately. Can refrigerate up to 1 day but best fresh.'),
    'pounded yam': _s('Grains', 'Counter', 1, 'Best eaten fresh. Refrigerate if needed, use within 1 day.'),
    'amala': _s('Grains', 'Counter', 1, 'Best consumed immediately after preparation.'),
    'tuwo shinkafa': _s('Grains', 'Counter', 1, 'Serve and eat immediately.'),
    'tuwo masara': _s('Grains', 'Counter', 1, 'Serve and eat immediately.'),
    'semovita': _s('Grains', 'Cupboard', 180, 'Store sealed in cool dry place. Lasts 6 months.'),
    'wheat meal': _s('Grains', 'Cupboard', 180, 'Store in airtight container.'),
    'oatmeal': _s('Grains', 'Cupboard', 365, 'Keep in sealed container. Lasts 1 year.'),
    'yam': _s('Vegetables', 'Counter', 30, 'Store whole yam in a cool, dark, well-ventilated place. Up to 1 month.'),
    'yam flour': _s('Grains', 'Cupboard', 180, 'Store in airtight container in cool place.'),
    'cassava': _s('Vegetables', 'Counter', 5, 'Fresh cassava must be used quickly. Peeled pieces refrigerate 3–5 days.'),
    'cocoyam': _s('Vegetables', 'Counter', 21, 'Store in cool dry place like yam. Up to 3 weeks.'),
    'taro': _s('Vegetables', 'Counter', 21, 'Store in cool dry ventilated place. Up to 3 weeks.'),
    'plantain': _s('Fruits', 'Counter', 7, 'Keep at room temperature to ripen. Refrigerate once very ripe.'),
    'unripe plantain': _s('Fruits', 'Counter', 10, 'Leave at room temperature to ripen.'),
    'ripe plantain': _s('Fruits', 'Fridge', 3, 'Refrigerate ripe plantains to slow further ripening.'),
    'palm oil': _s('Other', 'Cupboard', 365, 'Store in sealed container in cool dark place. Keeps 1 year.'),
    'groundnut oil': _s('Other', 'Cupboard', 365, 'Keep in cool dark place, away from heat. Lasts 1 year.'),
    'coconut oil': _s('Other', 'Cupboard', 730, 'Very stable oil — keeps 2 years at room temperature.'),
    'vegetable oil': _s('Other', 'Cupboard', 365, 'Keep in cool dark place. Lasts 1 year sealed.'),
    'locust beans': _s('Spices', 'Cupboard', 180, 'Dried dawadawa/iru keeps 6 months in airtight container.'),
    'dawadawa': _s('Spices', 'Cupboard', 180, 'Store dried in airtight container, away from moisture.'),
    'iru': _s('Spices', 'Cupboard', 90, 'Fermented locust beans — refrigerate or freeze for longer storage.'),
    'ogiri': _s('Spices', 'Fridge', 30, 'Wrapped ogiri can be refrigerated for up to 1 month.'),
    'ugba': _s('Other', 'Fridge', 5, 'African oil bean — refrigerate and use within 5 days.'),
    'ukpaka': _s('Other', 'Fridge', 5, 'Fermented oil bean seed — refrigerate. Use within 5 days.'),
    'uziza leaf': _s('Vegetables', 'Fridge', 5, 'Wrap in damp paper and refrigerate. Use within 5 days.'),
    'bitter leaf': _s('Vegetables', 'Fridge', 5, 'Wash, dry and refrigerate. Use within 5 days.'),
    'scent leaf': _s('Vegetables', 'Fridge', 5, 'Wrap loosely and refrigerate. Use within 5 days.'),
    'ugu leaf': _s('Vegetables', 'Fridge', 5, 'Refrigerate and use within 5 days.'),
    'fluted pumpkin': _s('Vegetables', 'Fridge', 5, 'Refrigerate pumpkin leaves. Use within 5 days.'),
    'african spinach': _s('Vegetables', 'Fridge', 5, 'Efo — refrigerate and use within 5 days.'),
    'waterleaf': _s('Vegetables', 'Fridge', 3, 'Very perishable. Use within 3 days.'),
    'nchuanwu': _s('Vegetables', 'Fridge', 5, 'Wrap and refrigerate. Use within 5 days.'),
    'tiger nut': _s('Snacks', 'Counter', 30, 'Dried tiger nuts keep 1 month at room temperature.'),
    'zobo': _s('Beverages', 'Fridge', 7, 'Prepared zobo drink keeps 1 week refrigerated.'),
    'hibiscus': _s('Spices', 'Cupboard', 180, 'Dried hibiscus keeps 6 months in airtight container.'),
    'soybeans': _s('Grains', 'Cupboard', 365, 'Dried soybeans keep 1 year in sealed container.'),
    'groundnut': _s('Snacks', 'Cupboard', 90, 'Keep in cool dry place. Up to 3 months.'),
    'peanut': _s('Snacks', 'Cupboard', 90, 'Roasted peanuts last 3 months sealed in cool dry place.'),
    'peanut butter': _s('Other', 'Cupboard', 90, 'Homemade peanut butter — refrigerate. Commercial: cupboard 3 months.'),
    'suya spice': _s('Spices', 'Cupboard', 180, 'Dry spice blend lasts 6 months in airtight container.'),
    'cameroon pepper': _s('Spices', 'Cupboard', 365, 'Keep in airtight container. Lasts 1 year.'),
    'tatashe': _s('Vegetables', 'Fridge', 10, 'Red bell pepper — refrigerate. Lasts up to 10 days.'),
    'scotch bonnet': _s('Vegetables', 'Fridge', 14, 'Keep in fridge for up to 2 weeks.'),
    'atarodo': _s('Vegetables', 'Fridge', 14, 'Refrigerate fresh habanero. Lasts 2 weeks.'),
    'tomato paste': _s('Canned', 'Cupboard', 730, 'Sealed — keep in cupboard. Refrigerate after opening, use within 5 days.'),
    'tomato puree': _s('Canned', 'Cupboard', 730, 'Refrigerate after opening. Use within 5 days.'),
    'plantain chips': _s('Snacks', 'Cupboard', 60, 'Keep sealed in cool dry place. Up to 2 months.'),
    'chin chin': _s('Snacks', 'Cupboard', 21, 'Keep in airtight container at room temperature. Up to 3 weeks.'),
    'puff puff': _s('Snacks', 'Counter', 2, 'Best eaten fresh. Room temperature for max 2 days.'),
    'agege bread': _s('Other', 'Counter', 3, 'Keep at room temperature. Eat within 3 days.'),
    'masa': _s('Other', 'Counter', 1, 'Best eaten same day.'),
    'kilshi': _s('Meat & Fish', 'Cupboard', 30, 'Dried spiced meat — keep in cool dry place up to 1 month.'),
    'bole': _s('Other', 'Counter', 1, 'Eat roasted plantain/yam fresh.'),
    'ofada rice': _s('Grains', 'Cupboard', 365, 'Uncooked ofada rice — airtight container, cool dry place.'),

    // ── COMMON VEGETABLES ─────────────────────────────────────────────────────
    'tomato': _s('Vegetables', 'Counter', 7, 'Keep whole tomatoes at room temperature. Refrigerate only once cut.'),
    'tomatoes': _s('Vegetables', 'Counter', 7, 'Store at room temperature. Refrigerate once ripe to extend 5 more days.'),
    'onion': _s('Vegetables', 'Counter', 30, 'Store in cool, dark, dry ventilated area. Avoid plastic bags.'),
    'onions': _s('Vegetables', 'Counter', 30, 'Keep in a mesh bag in cool dark place.'),
    'garlic': _s('Spices', 'Counter', 30, 'Keep whole bulbs at room temperature. Refrigerate peeled cloves.'),
    'ginger': _s('Spices', 'Counter', 30, 'Fresh ginger — wrap and refrigerate for up to 4 weeks.'),
    'carrot': _s('Vegetables', 'Fridge', 21, 'Remove tops and refrigerate. Keeps up to 3 weeks.'),
    'carrots': _s('Vegetables', 'Fridge', 21, 'Refrigerate in breathable bag. Up to 3 weeks.'),
    'potato': _s('Vegetables', 'Counter', 21, 'Keep in cool dark dry place. Avoid fridge (sweetens starch).'),
    'potatoes': _s('Vegetables', 'Counter', 21, 'Dark, cool, ventilated place. Never refrigerate raw.'),
    'sweet potato': _s('Vegetables', 'Counter', 30, 'Store in cool dark dry place. Keeps up to 1 month.'),
    'sweet potatoes': _s('Vegetables', 'Counter', 30, 'Keep in cool dry ventilated spot.'),
    'cucumber': _s('Vegetables', 'Fridge', 7, 'Refrigerate in crisper drawer. Best within 1 week.'),
    'cabbage': _s('Vegetables', 'Fridge', 14, 'Keeps 2 weeks in fridge. Remove outer leaves before storing.'),
    'lettuce': _s('Vegetables', 'Fridge', 7, 'Wrap in damp cloth in fridge. 7–10 days.'),
    'spinach': _s('Vegetables', 'Fridge', 5, 'Refrigerate in loosely closed bag. Best within 5 days.'),
    'okra': _s('Vegetables', 'Fridge', 4, 'Store in fridge in perforated bag. Use within 4 days.'),
    'okra fresh': _s('Vegetables', 'Fridge', 4, 'Use within 4 days of purchase.'),
    'mushroom': _s('Vegetables', 'Fridge', 7, 'Refrigerate in paper bag. Keeps 1 week.'),
    'mushrooms': _s('Vegetables', 'Fridge', 7, 'Store in fridge in paper bag.'),
    'pepper': _s('Vegetables', 'Fridge', 14, 'Refrigerate fresh peppers. Lasts 1–2 weeks.'),
    'bell pepper': _s('Vegetables', 'Fridge', 14, 'Refrigerate whole. 10–14 days.'),
    'broccoli': _s('Vegetables', 'Fridge', 7, 'Refrigerate unwashed. Use within 7 days.'),
    'cauliflower': _s('Vegetables', 'Fridge', 7, 'Wrap in damp towel in fridge. Up to 1 week.'),
    'corn': _s('Vegetables', 'Fridge', 3, 'Best refrigerated in husk. Cook within 3 days for sweetness.'),
    'maize': _s('Grains', 'Cupboard', 365, 'Dried maize keeps 1 year in cool dry place.'),
    'pumpkin': _s('Vegetables', 'Counter', 60, 'Whole pumpkin keeps 2 months in cool dry spot.'),
    'courgette': _s('Vegetables', 'Fridge', 10, 'Refrigerate. Use within 10 days.'),
    'zucchini': _s('Vegetables', 'Fridge', 10, 'Refrigerate. Best within 10 days.'),
    'eggplant': _s('Vegetables', 'Fridge', 7, 'Keep in fridge. Best within 1 week.'),
    'aubergine': _s('Vegetables', 'Fridge', 7, 'Refrigerate and use within 7 days.'),

    // ── FRUITS ────────────────────────────────────────────────────────────────
    'mango': _s('Fruits', 'Counter', 5, 'Ripen at room temperature. Refrigerate once ripe — extends 5 more days.'),
    'mangoes': _s('Fruits', 'Counter', 5, 'Let ripen at room temperature. Refrigerate once ripe.'),
    'banana': _s('Fruits', 'Counter', 5, 'Keep at room temperature. Refrigerate once ripe to slow browning.'),
    'bananas': _s('Fruits', 'Counter', 5, 'Room temperature for ripening; fridge to extend shelf life.'),
    'orange': _s('Fruits', 'Counter', 14, 'Room temperature for 2 weeks, fridge for up to 4 weeks.'),
    'oranges': _s('Fruits', 'Counter', 14, 'Store at room temperature or in fridge.'),
    'apple': _s('Fruits', 'Fridge', 30, 'Best stored in fridge. Keeps up to 1 month in crisper.'),
    'apples': _s('Fruits', 'Fridge', 30, 'Refrigerate in crisper drawer. Up to 4 weeks.'),
    'pawpaw': _s('Fruits', 'Counter', 5, 'Ripen at room temperature. Refrigerate once ripe.'),
    'papaya': _s('Fruits', 'Counter', 5, 'Room temperature to ripen; fridge once ripe for 5 more days.'),
    'pineapple': _s('Fruits', 'Counter', 3, 'Ripen at room temperature. Once ripe, refrigerate for up to 4 days.'),
    'watermelon': _s('Fruits', 'Counter', 14, 'Whole: room temperature for 2 weeks. Cut: fridge, 3–5 days.'),
    'avocado': _s('Fruits', 'Counter', 4, 'Ripen at room temperature. Refrigerate once ripe to slow softening.'),
    'avocados': _s('Fruits', 'Counter', 4, 'Room temperature until ripe, then fridge.'),
    'strawberry': _s('Fruits', 'Fridge', 5, 'Refrigerate unwashed. Use within 5 days.'),
    'strawberries': _s('Fruits', 'Fridge', 5, 'Keep refrigerated. Best within 5 days.'),
    'grape': _s('Fruits', 'Fridge', 10, 'Keep refrigerated. Up to 10 days.'),
    'grapes': _s('Fruits', 'Fridge', 10, 'Refrigerate. Stays fresh up to 10 days.'),
    'lemon': _s('Fruits', 'Counter', 14, 'Room temperature for 2 weeks, fridge for 4 weeks.'),
    'lemons': _s('Fruits', 'Counter', 14, 'Counter or fridge.'),
    'lime': _s('Fruits', 'Counter', 14, 'Room temperature for 1–2 weeks; fridge up to 4 weeks.'),
    'limes': _s('Fruits', 'Counter', 14, 'Store at room temperature.'),
    'coconut': _s('Fruits', 'Counter', 30, 'Whole coconuts keep 1 month on counter. Opened coconut: fridge, 5 days.'),
    'guava': _s('Fruits', 'Counter', 5, 'Ripen at room temperature. Refrigerate when ripe.'),
    'peach': _s('Fruits', 'Counter', 4, 'Ripen at room temperature. Refrigerate once ripe.'),
    'pear': _s('Fruits', 'Counter', 4, 'Ripen at room temperature; refrigerate once ripe.'),
    'plum': _s('Fruits', 'Fridge', 5, 'Ripen on counter then refrigerate.'),
    'cherry': _s('Fruits', 'Fridge', 7, 'Refrigerate and use within 1 week.'),
    'kiwi': _s('Fruits', 'Counter', 7, 'Room temperature until ripe, then fridge.'),
    'passion fruit': _s('Fruits', 'Counter', 7, 'Room temperature — wrinkles when fully ripe.'),
    'tamarind': _s('Fruits', 'Cupboard', 90, 'Dried tamarind keeps 3 months in airtight container.'),

    // ── DAIRY ─────────────────────────────────────────────────────────────────
    'milk': _s('Dairy', 'Fridge', 7, 'Always refrigerate. Consume within 7 days of opening.'),
    'fresh milk': _s('Dairy', 'Fridge', 7, 'Refrigerate immediately. Use within 7 days.'),
    'uht milk': _s('Dairy', 'Cupboard', 180, 'Store in cupboard until opened. Refrigerate after opening; use within 7 days.'),
    'evaporated milk': _s('Dairy', 'Cupboard', 730, 'Sealed tin: 2 years in cupboard. After opening: fridge, 5 days.'),
    'condensed milk': _s('Dairy', 'Cupboard', 730, 'Sealed: 2 years. Opened: transfer to container, fridge, 2 weeks.'),
    'powdered milk': _s('Dairy', 'Cupboard', 365, 'Sealed powder lasts 1 year. Once opened, use within 3 months.'),
    'yoghurt': _s('Dairy', 'Fridge', 14, 'Refrigerate. Sealed lasts until best-before; opened 7 days.'),
    'yogurt': _s('Dairy', 'Fridge', 14, 'Refrigerate. Consume within 14 days.'),
    'cheese': _s('Dairy', 'Fridge', 30, 'Wrap tightly and refrigerate. Hard cheese 3–4 weeks; soft cheese 1–2 weeks.'),
    'cheddar': _s('Dairy', 'Fridge', 30, 'Hard cheese — keeps 3–4 weeks wrapped in fridge.'),
    'mozzarella': _s('Dairy', 'Fridge', 5, 'Soft cheese — use within 5 days of opening.'),
    'soft cheese': _s('Dairy', 'Fridge', 7, 'Soft cheeses are perishable. Use within 7 days.'),
    'butter': _s('Dairy', 'Fridge', 30, 'Refrigerate. Can be kept in butter dish at room temperature 1–2 weeks.'),
    'margarine': _s('Dairy', 'Fridge', 30, 'Refrigerate. Keeps 1 month after opening.'),
    'cream': _s('Dairy', 'Fridge', 7, 'Refrigerate immediately. Use within 7 days of opening.'),
    'sour cream': _s('Dairy', 'Fridge', 14, 'Keep refrigerated. 2 weeks from opening.'),
    'egg': _s('Dairy', 'Counter', 21, 'Keep at room temperature up to 3 weeks; fridge extends to 5 weeks.'),
    'eggs': _s('Dairy', 'Counter', 21, 'Room temperature 3 weeks; refrigerator 5 weeks.'),
    'ice cream': _s('Frozen', 'Freezer', 60, 'Keep in freezer. Opened container best within 2 months.'),

    // ── MEAT ──────────────────────────────────────────────────────────────────
    'chicken': _s('Meat & Fish', 'Fridge', 2, 'Raw chicken — cook within 2 days or freeze for up to 9 months.'),
    'chicken breast': _s('Meat & Fish', 'Fridge', 2, 'Refrigerate and cook within 2 days.'),
    'chicken thigh': _s('Meat & Fish', 'Fridge', 2, 'Refrigerate and cook within 2 days.'),
    'chicken wings': _s('Meat & Fish', 'Fridge', 2, 'Raw: fridge 2 days; frozen: 9 months.'),
    'whole chicken': _s('Meat & Fish', 'Fridge', 2, 'Raw: fridge 2 days; freeze if not cooking soon.'),
    'turkey': _s('Meat & Fish', 'Fridge', 2, 'Raw: fridge 2 days or freeze.'),
    'beef': _s('Meat & Fish', 'Fridge', 3, 'Refrigerate raw beef. Cook within 3–5 days. Freeze for longer storage.'),
    'beef mince': _s('Meat & Fish', 'Fridge', 2, 'Ground beef — cook or freeze within 2 days.'),
    'minced beef': _s('Meat & Fish', 'Fridge', 2, 'Cook or freeze within 2 days of purchase.'),
    'steak': _s('Meat & Fish', 'Fridge', 3, 'Refrigerate and cook within 3 days.'),
    'pork': _s('Meat & Fish', 'Fridge', 3, 'Refrigerate and cook within 3 days.'),
    'bacon': _s('Meat & Fish', 'Fridge', 7, 'Sealed bacon: 1 week in fridge. Freeze for longer storage.'),
    'sausage': _s('Meat & Fish', 'Fridge', 3, 'Raw sausages: fridge 3 days. Cooked: 4 days.'),
    'sausages': _s('Meat & Fish', 'Fridge', 3, 'Keep refrigerated. Cook within 3 days.'),
    'lamb': _s('Meat & Fish', 'Fridge', 3, 'Refrigerate and cook within 3 days.'),
    'goat meat': _s('Meat & Fish', 'Fridge', 3, 'Raw goat meat — fridge 3 days, freeze for longer.'),
    'goat': _s('Meat & Fish', 'Fridge', 3, 'Refrigerate and cook within 3 days.'),
    'liver': _s('Meat & Fish', 'Fridge', 2, 'Organ meats are very perishable. Cook within 2 days.'),
    'gizzard': _s('Meat & Fish', 'Fridge', 2, 'Cook within 2 days of purchase.'),
    'offal': _s('Meat & Fish', 'Fridge', 1, 'Very perishable. Cook within 1 day.'),
    'ham': _s('Meat & Fish', 'Fridge', 7, 'Opened sliced ham: 1 week in fridge.'),
    'cooked chicken': _s('Meat & Fish', 'Fridge', 4, 'Store cooked chicken in fridge. Consume within 4 days.'),

    // ── FISH & SEAFOOD ────────────────────────────────────────────────────────
    'fish': _s('Meat & Fish', 'Fridge', 2, 'Fresh fish is very perishable. Cook within 1–2 days or freeze.'),
    'fresh fish': _s('Meat & Fish', 'Fridge', 2, 'Use within 2 days. Freeze if not eating soon.'),
    'tilapia': _s('Meat & Fish', 'Fridge', 2, 'Fresh tilapia — cook within 2 days of purchase.'),
    'catfish': _s('Meat & Fish', 'Fridge', 2, 'Cook within 2 days.'),
    'croaker': _s('Meat & Fish', 'Fridge', 2, 'Cook within 2 days.'),
    'mackerel': _s('Meat & Fish', 'Fridge', 2, 'Fresh mackerel — very perishable. Cook within 2 days.'),
    'salmon': _s('Meat & Fish', 'Fridge', 2, 'Raw salmon: cook within 2 days or freeze.'),
    'tuna': _s('Meat & Fish', 'Fridge', 2, 'Fresh tuna: cook within 2 days.'),
    'canned tuna': _s('Canned', 'Cupboard', 1460, 'Canned tuna: 4 years unopened. Opened: fridge, 3 days.'),
    'sardines': _s('Canned', 'Cupboard', 1460, 'Canned: 4 years. Opened: fridge, 3 days.'),
    'shrimp': _s('Meat & Fish', 'Fridge', 2, 'Raw shrimp very perishable. Cook within 2 days or freeze.'),
    'prawn': _s('Meat & Fish', 'Fridge', 2, 'Cook within 2 days of purchase.'),
    'prawns': _s('Meat & Fish', 'Fridge', 2, 'Raw prawns: cook within 2 days or freeze.'),
    'frozen fish': _s('Frozen', 'Freezer', 180, 'Keep in freezer. Use within 6 months.'),
    'frozen shrimp': _s('Frozen', 'Freezer', 180, 'Keep frozen. 6 months in freezer.'),

    // ── GRAINS & CEREALS ──────────────────────────────────────────────────────
    'rice': _s('Grains', 'Cupboard', 730, 'White rice keeps 2 years in airtight container.'),
    'white rice': _s('Grains', 'Cupboard', 730, 'Store sealed in cool dry place. Up to 2 years.'),
    'brown rice': _s('Grains', 'Cupboard', 180, 'Brown rice has oils that go rancid — keep 6 months.'),
    'basmati rice': _s('Grains', 'Cupboard', 730, 'Basmati keeps well. Store sealed, 2 years.'),
    'parboiled rice': _s('Grains', 'Cupboard', 730, 'Store in airtight container. 2 years.'),
    'flour': _s('Grains', 'Cupboard', 180, 'Store in airtight container in cool dry place. 6 months.'),
    'wheat flour': _s('Grains', 'Cupboard', 180, 'Airtight container, cool and dry. Up to 6 months.'),
    'cornmeal': _s('Grains', 'Cupboard', 180, 'Store sealed in cool dry place. 6 months.'),
    'semolina': _s('Grains', 'Cupboard', 180, 'Keep in airtight container. 6 months.'),
    'oats': _s('Grains', 'Cupboard', 365, 'Rolled or quick oats keep 1 year sealed.'),
    'rolled oats': _s('Grains', 'Cupboard', 365, 'Airtight container, cool and dry.'),
    'pasta': _s('Grains', 'Cupboard', 730, 'Dried pasta keeps 2 years. No special storage needed.'),
    'spaghetti': _s('Grains', 'Cupboard', 730, 'Dried pasta — 2 years in cupboard.'),
    'noodles': _s('Grains', 'Cupboard', 730, 'Dried noodles — keep in cool dry cupboard, 2 years.'),
    'instant noodles': _s('Grains', 'Cupboard', 365, 'Keep in cool dry place. Check best-before date.'),
    'indomie': _s('Grains', 'Cupboard', 365, 'Store in dry place. Lasts up to 1 year.'),
    'bread': _s('Other', 'Counter', 5, 'Keep at room temperature in sealed bag. Freeze for longer storage.'),
    'cornflakes': _s('Grains', 'Cupboard', 365, 'Keep sealed in dry cupboard.'),
    'cereal': _s('Grains', 'Cupboard', 365, 'Store in cool dry place.'),

    // ── LEGUMES ───────────────────────────────────────────────────────────────
    'beans': _s('Grains', 'Cupboard', 365, 'Dried beans keep 1 year. Cooked beans: fridge 5 days.'),
    'black eyed beans': _s('Grains', 'Cupboard', 365, 'Dried cowpeas — 1 year in airtight container.'),
    'cowpeas': _s('Grains', 'Cupboard', 365, 'Store dried in sealed container.'),
    'lentils': _s('Grains', 'Cupboard', 730, 'Dried lentils keep up to 2 years.'),
    'chickpeas': _s('Grains', 'Cupboard', 730, 'Dried: 2 years. Canned: 2 years sealed, fridge 5 days opened.'),
    'kidney beans': _s('Grains', 'Cupboard', 730, 'Dried: 2 years. Canned: see label; opened: fridge 5 days.'),
    'soya beans': _s('Grains', 'Cupboard', 365, 'Dried soybeans — 1 year in cool dry place.'),

    // ── SPICES & SEASONINGS ───────────────────────────────────────────────────
    'salt': _s('Spices', 'Cupboard', 9999, 'Salt lasts indefinitely. Keep dry.'),
    'sugar': _s('Other', 'Cupboard', 9999, 'Sugar lasts indefinitely if kept dry.'),
    'curry powder': _s('Spices', 'Cupboard', 365, 'Ground spices best within 1 year. Keep sealed away from heat.'),
    'thyme': _s('Spices', 'Cupboard', 365, 'Dried thyme keeps 1–3 years in airtight container.'),
    'bay leaf': _s('Spices', 'Cupboard', 365, 'Whole dried bay leaves — 1–3 years.'),
    'bay leaves': _s('Spices', 'Cupboard', 365, 'Store in airtight container, away from light.'),
    'black pepper': _s('Spices', 'Cupboard', 365, 'Ground black pepper keeps 1 year; whole peppercorns 3 years.'),
    'peppercorn': _s('Spices', 'Cupboard', 1095, 'Whole peppercorns keep 3 years in sealed container.'),
    'cinnamon': _s('Spices', 'Cupboard', 730, 'Ground cinnamon: 2 years. Sticks: 3 years.'),
    'nutmeg': _s('Spices', 'Cupboard', 730, 'Ground: 2 years. Whole nutmeg: 4 years.'),
    'turmeric': _s('Spices', 'Cupboard', 730, 'Ground turmeric keeps 2–3 years sealed.'),
    'paprika': _s('Spices', 'Cupboard', 365, 'Keeps best within 1 year. Store away from heat.'),
    'chilli powder': _s('Spices', 'Cupboard', 365, 'Keep in airtight container. Best within 1 year.'),
    'cumin': _s('Spices', 'Cupboard', 730, 'Ground cumin: 2 years. Whole: 4 years.'),
    'coriander': _s('Spices', 'Cupboard', 730, 'Ground: 2 years. Seeds: 4 years.'),
    'mixed spice': _s('Spices', 'Cupboard', 365, 'Use within 1 year for best flavour.'),
    'seasoning cube': _s('Spices', 'Cupboard', 365, 'Maggi/Knorr cubes — keep dry, up to 1 year.'),
    'maggi': _s('Spices', 'Cupboard', 365, 'Store in dry place. Up to 1 year.'),
    'knorr': _s('Spices', 'Cupboard', 365, 'Seasoning cubes — store dry.'),
    'bouillon': _s('Spices', 'Cupboard', 365, 'Keep in cool dry cupboard.'),
    'vinegar': _s('Other', 'Cupboard', 9999, 'Vinegar lasts indefinitely. Keep in cool dark place.'),

    // ── CONDIMENTS & SAUCES ───────────────────────────────────────────────────
    'ketchup': _s('Other', 'Cupboard', 365, 'Sealed: 1 year in cupboard. Opened: fridge, 6 months.'),
    'tomato ketchup': _s('Other', 'Cupboard', 365, 'Sealed: 1 year. Opened: refrigerate.'),
    'mayonnaise': _s('Other', 'Fridge', 60, 'Commercial mayo: unopened 3 months cool cupboard. Opened: fridge, 2 months.'),
    'mayo': _s('Other', 'Fridge', 60, 'Keep refrigerated after opening.'),
    'mustard': _s('Other', 'Fridge', 365, 'Keeps 1 year refrigerated after opening.'),
    'soy sauce': _s('Other', 'Cupboard', 730, 'Sealed soy sauce, 2 years. Opened: fridge or cupboard, 6 months.'),
    'hot sauce': _s('Other', 'Cupboard', 365, 'Sealed: 1 year. Opened: refrigerate for 6 months.'),
    'worcestershire': _s('Other', 'Cupboard', 365, 'Keeps 1 year sealed; refrigerate once opened.'),
    'honey': _s('Other', 'Cupboard', 9999, 'Pure honey never spoils. Keep in airtight container.'),
    'jam': _s('Other', 'Cupboard', 365, 'Sealed: 1 year. Opened: fridge, 3 months.'),
    'nutella': _s('Other', 'Cupboard', 365, 'Keep in cool dry place. Best before date on jar.'),
    'peanut butter powder': _s('Other', 'Cupboard', 365, 'Powdered form: 1 year in cool dry place.'),
    'olive oil': _s('Other', 'Cupboard', 730, 'Keep in dark cool cupboard. Lasts 2 years sealed.'),
    'chilli sauce': _s('Other', 'Fridge', 90, 'Refrigerate after opening. 3 months.'),
    'oyster sauce': _s('Other', 'Fridge', 90, 'Refrigerate after opening.'),
    'fish sauce': _s('Other', 'Cupboard', 365, 'Opened fish sauce keeps 1 year.'),
    'jerk sauce': _s('Other', 'Fridge', 90, 'Refrigerate. 3 months.'),

    // ── BEVERAGES ─────────────────────────────────────────────────────────────
    'water': _s('Beverages', 'Cupboard', 9999, 'Sealed bottled water lasts indefinitely. Keep away from sunlight.'),
    'juice': _s('Beverages', 'Fridge', 7, 'Fresh/opened juice — refrigerate and use within 7 days.'),
    'orange juice': _s('Beverages', 'Fridge', 7, 'Refrigerate. Use within 7 days of opening.'),
    'soft drink': _s('Beverages', 'Cupboard', 365, 'Sealed cans/bottles: 1 year. Opened: fridge, 2 days.'),
    'soda': _s('Beverages', 'Cupboard', 365, 'Sealed: 1 year. Opened: refrigerate.'),
    'tea': _s('Beverages', 'Cupboard', 365, 'Dry tea bags/leaves — 1 year in sealed container.'),
    'coffee': _s('Beverages', 'Cupboard', 180, 'Ground coffee: 3–6 months sealed. Beans: 6 months.'),
    'instant coffee': _s('Beverages', 'Cupboard', 730, 'Instant coffee powder: 2 years if kept dry.'),
    'milo': _s('Beverages', 'Cupboard', 365, 'Keep dry and sealed. Up to 1 year.'),
    'ovaltine': _s('Beverages', 'Cupboard', 365, 'Store in cool dry place.'),
    'cocoa powder': _s('Beverages', 'Cupboard', 365, 'Sealed: 1 year. Keep dry.'),
    'wine': _s('Beverages', 'Cupboard', 365, 'Sealed: store in cool dark place up to 1 year. Opened: fridge 5 days.'),
    'beer': _s('Beverages', 'Cupboard', 180, 'Keeps 6 months sealed in cool dark place.'),
    'palm wine': _s('Beverages', 'Fridge', 2, 'Fresh palm wine is very perishable. Consume within 2 days.'),

    // ── CANNED / PACKAGED ─────────────────────────────────────────────────────
    'corned beef': _s('Canned', 'Cupboard', 1460, 'Canned: 4 years. Opened: fridge, 3 days.'),
    'baked beans': _s('Canned', 'Cupboard', 1095, 'Canned: 3 years. Opened: fridge, 5 days.'),
    'canned tomatoes': _s('Canned', 'Cupboard', 730, '2 years sealed. Opened: fridge in container, 5 days.'),
    'canned fish': _s('Canned', 'Cupboard', 1460, '4 years sealed. Opened: fridge, 3 days.'),
    'canned beans': _s('Canned', 'Cupboard', 1095, 'Sealed: 3 years. Opened: fridge, 5 days.'),
    'coconut milk': _s('Canned', 'Cupboard', 730, 'Sealed: 2 years. Opened: fridge in container, 4 days.'),
    'coconut cream': _s('Canned', 'Cupboard', 730, 'Sealed: 2 years. Opened: fridge, 4 days.'),

    // ── BAKED GOODS / SNACKS ──────────────────────────────────────────────────
    'biscuits': _s('Snacks', 'Cupboard', 60, 'Keep sealed in dry cupboard. Up to 2 months.'),
    'crackers': _s('Snacks', 'Cupboard', 60, 'Keep in airtight container.'),
    'cookies': _s('Snacks', 'Cupboard', 14, 'Room temperature in airtight jar. 2 weeks.'),
    'cake': _s('Snacks', 'Counter', 4, 'Room temperature: 4 days. Refrigerate if cream-frosted.'),
    'donut': _s('Snacks', 'Counter', 2, 'Best within 2 days at room temperature.'),
    'doughnut': _s('Snacks', 'Counter', 2, 'Eat within 2 days.'),
    'chips': _s('Snacks', 'Cupboard', 60, 'Keep sealed. Up to 2 months after opening.'),
    'popcorn': _s('Snacks', 'Cupboard', 30, 'Sealed bag: up to 1 month. Popped: airtight, 1 week.'),
    'chocolate': _s('Snacks', 'Cupboard', 365, 'Keep in cool dark place. Avoid fridge (condensation). 1 year.'),

    // ── FROZEN FOODS ──────────────────────────────────────────────────────────
    'frozen chicken': _s('Frozen', 'Freezer', 270, 'Frozen chicken keeps 9 months.'),
    'frozen beef': _s('Frozen', 'Freezer', 120, 'Frozen beef: 4 months.'),
    'frozen vegetables': _s('Frozen', 'Freezer', 365, 'Frozen veg keeps 12 months.'),
    'frozen fries': _s('Frozen', 'Freezer', 180, 'Keep in freezer. 6 months.'),
    'frozen peas': _s('Frozen', 'Freezer', 365, '12 months in freezer.'),
  };
}

// ── Data model ─────────────────────────────────────────────────────────────────

class FoodSuggestion {
  final String category;
  final String storageLocation;
  final int shelfLifeDays;
  final String tip;
  final bool isGuessed;

  const FoodSuggestion({
    required this.category,
    required this.storageLocation,
    required this.shelfLifeDays,
    required this.tip,
    required this.isGuessed,
  });

  /// Human-readable shelf life e.g. "3 days", "2 weeks", "6 months"
  String get shelfLifeLabel {
    if (shelfLifeDays >= 9999) return 'Indefinite';
    if (shelfLifeDays >= 365) {
      final years = shelfLifeDays ~/ 365;
      return '$years yr${years > 1 ? 's' : ''}';
    }
    if (shelfLifeDays >= 30) {
      final months = shelfLifeDays ~/ 30;
      return '$months mo${months > 1 ? 's' : ''}';
    }
    if (shelfLifeDays >= 7) {
      final weeks = shelfLifeDays ~/ 7;
      return '$weeks wk${weeks > 1 ? 's' : ''}';
    }
    return '$shelfLifeDays day${shelfLifeDays > 1 ? 's' : ''}';
  }
}
