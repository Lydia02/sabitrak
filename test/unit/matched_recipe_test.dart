// Unit tests for MatchedRecipe and RecipeIngredient models
//
// Tests cover:
//   - Constructor and field assignment
//   - matchedCount computed property
//   - usesExpiringItem computed property
//   - matchPercent computed property
//   - estimatedPrepTime with prepTimeOverride
//   - estimatedPrepTime heuristic based on instruction step count

import 'package:flutter_test/flutter_test.dart';
import 'package:sabitrak/data/models/matched_recipe.dart';

MatchedRecipe _makeRecipe({
  String instructions = '',
  List<String> matchedPantryItems = const [],
  List<String> expiringMatchedItems = const [],
  double matchRatio = 0.5,
  double score = 0.6,
  String? prepTimeOverride,
}) {
  return MatchedRecipe(
    id: 'r-1',
    name: 'Test Recipe',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    category: 'Main',
    area: 'Nigerian',
    instructions: instructions,
    youtubeUrl: '',
    ingredients: const [],
    matchedPantryItems: matchedPantryItems,
    expiringMatchedItems: expiringMatchedItems,
    matchRatio: matchRatio,
    score: score,
    prepTimeOverride: prepTimeOverride,
  );
}

void main() {
  // ── RecipeIngredient ────────────────────────────────────────────────────────

  group('RecipeIngredient', () {
    test('stores name and measure', () {
      const ri = RecipeIngredient(name: 'Rice', measure: '2 cups');
      expect(ri.name, 'Rice');
      expect(ri.measure, '2 cups');
    });
  });

  // ── MatchedRecipe constructor ───────────────────────────────────────────────

  group('MatchedRecipe constructor', () {
    test('stores all required fields', () {
      final r = _makeRecipe(matchRatio: 0.75, score: 0.9);
      expect(r.id, 'r-1');
      expect(r.name, 'Test Recipe');
      expect(r.matchRatio, 0.75);
      expect(r.score, 0.9);
    });

    test('prepTimeOverride defaults to null', () {
      expect(_makeRecipe().prepTimeOverride, isNull);
    });
  });

  // ── matchedCount ────────────────────────────────────────────────────────────

  group('matchedCount', () {
    test('returns 0 when no matched items', () {
      expect(_makeRecipe().matchedCount, 0);
    });

    test('returns correct count for matched items', () {
      final r = _makeRecipe(matchedPantryItems: ['Rice', 'Tomato', 'Onion']);
      expect(r.matchedCount, 3);
    });
  });

  // ── usesExpiringItem ────────────────────────────────────────────────────────

  group('usesExpiringItem', () {
    test('false when no expiring items', () {
      expect(_makeRecipe().usesExpiringItem, isFalse);
    });

    test('true when at least one expiring item present', () {
      final r = _makeRecipe(expiringMatchedItems: ['Milk']);
      expect(r.usesExpiringItem, isTrue);
    });
  });

  // ── matchPercent ────────────────────────────────────────────────────────────

  group('matchPercent', () {
    test('100% for ratio 1.0', () {
      expect(_makeRecipe(matchRatio: 1.0).matchPercent, '100%');
    });

    test('0% for ratio 0.0', () {
      expect(_makeRecipe(matchRatio: 0.0).matchPercent, '0%');
    });

    test('75% for ratio 0.75', () {
      expect(_makeRecipe(matchRatio: 0.75).matchPercent, '75%');
    });

    test('rounds correctly — 0.666 → 67%', () {
      expect(_makeRecipe(matchRatio: 0.666).matchPercent, '67%');
    });
  });

  // ── estimatedPrepTime with override ────────────────────────────────────────

  group('estimatedPrepTime with prepTimeOverride', () {
    test('returns override string when set and non-empty', () {
      final r = _makeRecipe(prepTimeOverride: '35 min');
      expect(r.estimatedPrepTime, '35 min');
    });

    test('ignores empty string override and uses heuristic', () {
      final r = _makeRecipe(
        instructions: 'Step 1\nStep 2\nStep 3',
        prepTimeOverride: '',
      );
      expect(r.estimatedPrepTime, '10–15 min');
    });
  });

  // ── estimatedPrepTime heuristic ─────────────────────────────────────────────

  group('estimatedPrepTime heuristic', () {
    String buildInstructions(int steps) =>
        List.generate(steps, (i) => 'Step ${i + 1}.').join('\n');

    test('returns 10–15 min for ≤4 steps', () {
      expect(
        _makeRecipe(instructions: buildInstructions(4)).estimatedPrepTime,
        '10–15 min',
      );
    });

    test('returns 10–15 min for 1 step', () {
      expect(
        _makeRecipe(instructions: buildInstructions(1)).estimatedPrepTime,
        '10–15 min',
      );
    });

    test('returns 20–30 min for 5–8 steps', () {
      expect(
        _makeRecipe(instructions: buildInstructions(5)).estimatedPrepTime,
        '20–30 min',
      );
      expect(
        _makeRecipe(instructions: buildInstructions(8)).estimatedPrepTime,
        '20–30 min',
      );
    });

    test('returns 30–45 min for 9–14 steps', () {
      expect(
        _makeRecipe(instructions: buildInstructions(9)).estimatedPrepTime,
        '30–45 min',
      );
      expect(
        _makeRecipe(instructions: buildInstructions(14)).estimatedPrepTime,
        '30–45 min',
      );
    });

    test('returns 45+ min for 15+ steps', () {
      expect(
        _makeRecipe(instructions: buildInstructions(15)).estimatedPrepTime,
        '45+ min',
      );
      expect(
        _makeRecipe(instructions: buildInstructions(20)).estimatedPrepTime,
        '45+ min',
      );
    });

    test('empty instructions returns 10–15 min', () {
      expect(_makeRecipe(instructions: '').estimatedPrepTime, '10–15 min');
    });

    test('blank lines are ignored in step count', () {
      // 3 real steps + 2 blank lines = still 3 steps → 10–15 min
      final r = _makeRecipe(instructions: 'Step 1.\n\nStep 2.\n\nStep 3.');
      expect(r.estimatedPrepTime, '10–15 min');
    });
  });
}
