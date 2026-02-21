/// A recipe from TheMealDB or African Food Database, enriched with pantry-matching metadata.
class MatchedRecipe {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String category;
  final String area;
  final String instructions;
  final String youtubeUrl;
  final List<RecipeIngredient> ingredients;
  final List<String> matchedPantryItems;
  final List<String> expiringMatchedItems;
  final double matchRatio;
  final double score;

  /// Optional actual prep time string from African DB (e.g. "35 min").
  /// When set, overrides the heuristic estimatedPrepTime.
  final String? prepTimeOverride;

  const MatchedRecipe({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.category,
    required this.area,
    required this.instructions,
    required this.youtubeUrl,
    required this.ingredients,
    required this.matchedPantryItems,
    required this.expiringMatchedItems,
    required this.matchRatio,
    required this.score,
    this.prepTimeOverride,
  });

  /// How many ingredients the user already has.
  int get matchedCount => matchedPantryItems.length;

  /// Whether at least one expiring pantry item is used in this recipe.
  bool get usesExpiringItem => expiringMatchedItems.isNotEmpty;

  /// Match percentage string for UI display.
  String get matchPercent => '${(matchRatio * 100).round()}%';

  /// Prep time — uses actual time from African DB if available, otherwise heuristic.
  String get estimatedPrepTime {
    if (prepTimeOverride != null && prepTimeOverride!.isNotEmpty) {
      return prepTimeOverride!;
    }
    final steps = instructions
        .split(RegExp(r'\r\n|\n'))
        .where((s) => s.trim().isNotEmpty)
        .length;
    if (steps <= 4) return '10–15 min';
    if (steps <= 8) return '20–30 min';
    if (steps <= 14) return '30–45 min';
    return '45+ min';
  }
}

class RecipeIngredient {
  final String name;
  final String measure;

  const RecipeIngredient({required this.name, required this.measure});
}
