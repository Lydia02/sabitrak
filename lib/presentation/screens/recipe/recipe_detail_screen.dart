import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/matched_recipe.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/firebase_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final MatchedRecipe recipe;
  final List<FoodItem> pantryItems;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.pantryItems = const [],
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _usingRecipe = false;
  final InventoryRepository _inventoryRepo = InventoryRepository();

  // Find pantry items that match a recipe ingredient
  List<FoodItem> _matchingPantryItems(String ingredientName) {
    final ingLower = ingredientName.toLowerCase().trim();
    return widget.pantryItems.where((item) {
      final p = item.name.toLowerCase().trim();
      if (p.contains(ingLower) || ingLower.contains(p)) return true;
      final pWords = p.split(RegExp(r'[\s,]+'));
      final iWords = ingLower.split(RegExp(r'[\s,]+'));
      return pWords.any((w) => w.length > 2 && iWords.contains(w));
    }).toList();
  }

  // Parse quantity from a measure string like "2 cups" → 2.0, "1/2" → 0.5
  double _quantityFromMeasure(String measure) {
    final lower = measure.toLowerCase().trim();
    // Try to find a leading number or fraction
    final match = RegExp(r'^([\d]+)\s*/\s*([\d]+)').firstMatch(lower);
    if (match != null) {
      return double.parse(match.group(1)!) / double.parse(match.group(2)!);
    }
    final decMatch = RegExp(r'^([\d]*\.?[\d]+)').firstMatch(lower);
    if (decMatch != null) return double.parse(decMatch.group(1)!);
    // Unicode fractions
    if (lower.startsWith('½')) return 0.5;
    if (lower.startsWith('¼')) return 0.25;
    if (lower.startsWith('¾')) return 0.75;
    if (lower.startsWith('⅓')) return 1 / 3;
    if (lower.startsWith('⅔')) return 2 / 3;
    return 1.0;
  }

  // Extract the unit from a measure string like "2 cups" → "cups"
  String _unitFromMeasure(String measure) {
    var lower = measure.toLowerCase().trim();
    lower = lower.replaceFirst(RegExp(r'^[\d\s./½¼¾⅓⅔⅛⅜⅝⅞]+'), '').trim();
    if (lower.isEmpty) return '';
    return lower.split(RegExp(r'\s+')).first;
  }

  // Convert recipeQty in recipeUnit → pantryUnit. Returns null if no conversion known.
  double? _convertToPantryUnit(
    double recipeQty,
    String recipeUnit,
    String pantryUnit,
  ) {
    final r = recipeUnit.toLowerCase().trim();
    final p = pantryUnit.toLowerCase().trim();
    if (r == p) return recipeQty;

    // Convert everything to grams first, then to pantry unit
    // Volume→weight conversions use a generic density (~200g per cup for grains/powders)
    const toGrams = <String, double>{
      'kg': 1000, 'g': 1, 'gram': 1, 'grams': 1,
      'oz': 28.35, 'lb': 453.6, 'lbs': 453.6,
      // Volume units — approximate using water density (ml≈g), good enough for pantry
      'ml': 1,
      'l': 1000,
      'litre': 1000,
      'litres': 1000,
      'liter': 1000,
      'liters': 1000,
      'cup': 240, 'cups': 240,
      'tbsp': 15, 'tablespoon': 15, 'tablespoons': 15,
      'tsp': 5, 'teaspoon': 5, 'teaspoons': 5,
    };

    final rGrams = toGrams[r];
    final pGrams = toGrams[p];
    if (rGrams == null || pGrams == null) return null;

    return (recipeQty * rGrams) / pGrams;
  }

  Future<void> _onUseRecipe() async {
    // Build list of (pantryItem, deductAmount) pairs
    final toDeduct = <({FoodItem item, int amount, String fromMeasure})>[];

    for (final ing in widget.recipe.matchedPantryItems) {
      final matches = _matchingPantryItems(ing);
      if (matches.isEmpty) continue;
      final pantryItem = matches.first;

      // Find the matching recipe ingredient
      final ingLower = ing.toLowerCase().trim();
      RecipeIngredient? recipeIng;
      for (final ri in widget.recipe.ingredients) {
        final riLower = ri.name.toLowerCase().trim();
        final pantryLower = pantryItem.name.toLowerCase().trim();
        if (riLower.contains(ingLower) ||
            ingLower.contains(riLower) ||
            riLower.contains(pantryLower) ||
            pantryLower.contains(riLower)) {
          recipeIng = ri;
          break;
        }
      }

      int deductAmount;
      String fromMeasure;

      if (recipeIng != null && recipeIng.measure.trim().isNotEmpty) {
        final recipeQty = _quantityFromMeasure(recipeIng.measure);
        final recipeUnit = _unitFromMeasure(recipeIng.measure);
        final converted = _convertToPantryUnit(
          recipeQty,
          recipeUnit,
          pantryItem.unit,
        );
        if (converted != null) {
          // Round up — always deduct at least 1
          deductAmount = converted.ceil().clamp(1, pantryItem.quantity);
          fromMeasure = recipeIng.measure;
        } else {
          // Units completely incompatible (e.g. cups → pcs) — deduct 1
          deductAmount = 1;
          fromMeasure = recipeIng.measure;
        }
      } else {
        deductAmount = 1;
        fromMeasure = '';
      }

      toDeduct.add((
        item: pantryItem,
        amount: deductAmount,
        fromMeasure: fromMeasure,
      ));
    }

    if (toDeduct.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pantry items to deduct for this recipe.'),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
        final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
        final subtitleColor =
            isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.restaurant,
                color: AppTheme.primaryGreen,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Use This Recipe?',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The following will be deducted from your pantry:',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...toDeduct.map((entry) {
                  final newQty = entry.item.quantity - entry.amount;
                  final measureNote =
                      entry.fromMeasure.isNotEmpty
                          ? ' (recipe: ${entry.fromMeasure})'
                          : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.remove_circle_outline,
                          color: Color(0xFFE65100),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${entry.item.name}: ${entry.item.quantity} ${entry.item.unit} → ${newQty < 0 ? 0 : newQty} ${entry.item.unit}$measureNote',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (toDeduct.any((e) => e.item.quantity - e.amount <= 0)) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Items reaching 0 will be removed from your pantry.',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(fontFamily: 'Roboto', color: subtitleColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Yes, I used it',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _usingRecipe = true);

    try {
      // Load household ID
      final uid = FirebaseService().currentUser?.uid;
      if (uid == null) return;

      for (final entry in toDeduct) {
        final newQty = entry.item.quantity - entry.amount;
        if (newQty <= 0) {
          await _inventoryRepo.deleteFoodItem(entry.item.id);
        } else {
          await _inventoryRepo.updateFoodItem(entry.item.id, {
            'quantity': newQty,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Pantry updated! Enjoy your meal.',
                style: TextStyle(fontFamily: 'Roboto'),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update pantry: $e')));
    } finally {
      if (mounted) setState(() => _usingRecipe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor =
        isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.backgroundColor;

    final steps =
        recipe.instructions
            .split(RegExp(r'\r\n|\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // ── Hero image app bar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: isDark ? AppTheme.darkCard : AppTheme.primaryGreen,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background:
                  recipe.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: recipe.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder:
                            (_, __) => Container(
                              color:
                                  isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFE8D5B7),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryGreen,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        errorWidget:
                            (_, __, ___) => Container(
                              color:
                                  isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFE8D5B7),
                              child: Icon(
                                Icons.restaurant,
                                size: 64,
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                      )
                      : Container(
                        color:
                            isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFE8D5B7),
                        child: Icon(
                          Icons.restaurant,
                          size: 64,
                          color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                        ),
                      ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title + meta ──────────────────────────────────────────
                  Text(
                    recipe.name,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MetaChip(
                        icon: Icons.schedule,
                        label: recipe.estimatedPrepTime,
                        color: subtitleColor,
                      ),
                      const SizedBox(width: 12),
                      if (recipe.area.isNotEmpty)
                        _MetaChip(
                          icon: Icons.flag_outlined,
                          label: recipe.area,
                          color: subtitleColor,
                        ),
                      if (recipe.area.isNotEmpty) const SizedBox(width: 12),
                      _MetaChip(
                        icon: Icons.category_outlined,
                        label: recipe.category,
                        color: subtitleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Match badge ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.eco,
                          color: AppTheme.primaryGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'You have ${recipe.matchedCount} of ${recipe.ingredients.length} ingredients — ${recipe.matchPercent} match',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (recipe.usesExpiringItem) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFE65100),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Uses expiring: ${recipe.expiringMatchedItems.join(', ')}',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Ingredients ───────────────────────────────────────────
                  Text(
                    'Ingredients',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recipe.ingredients.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : Colors.black.withValues(alpha: 0.05),
                          ),
                      itemBuilder: (_, i) {
                        final ing = recipe.ingredients[i];
                        final inPantry = recipe.matchedPantryItems.any(
                          (m) => m.toLowerCase() == ing.name.toLowerCase(),
                        );
                        final isExpiring = recipe.expiringMatchedItems.any(
                          (e) => e.toLowerCase() == ing.name.toLowerCase(),
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Status dot
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color:
                                      isExpiring
                                          ? const Color(
                                            0xFFE65100,
                                          ).withValues(alpha: 0.12)
                                          : inPantry
                                          ? AppTheme.primaryGreen.withValues(
                                            alpha: 0.12,
                                          )
                                          : subtitleColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isExpiring
                                      ? Icons.warning_amber_rounded
                                      : inPantry
                                      ? Icons.check
                                      : Icons.add,
                                  size: 16,
                                  color:
                                      isExpiring
                                          ? const Color(0xFFE65100)
                                          : inPantry
                                          ? AppTheme.primaryGreen
                                          : subtitleColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ing.name,
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: inPantry ? textColor : subtitleColor,
                                  ),
                                ),
                              ),
                              Text(
                                ing.measure,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
                  // Legend
                  Row(
                    children: [
                      const _LegendItem(
                        color: AppTheme.primaryGreen,
                        label: 'In your pantry',
                      ),
                      const SizedBox(width: 16),
                      const _LegendItem(
                        color: Color(0xFFE65100),
                        label: 'Expiring soon',
                      ),
                      const SizedBox(width: 16),
                      _LegendItem(color: subtitleColor, label: 'Need to buy'),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Instructions ──────────────────────────────────────────
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...steps.asMap().entries.map((entry) {
                    final stepNum = entry.key + 1;
                    final stepText = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$stepNum',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stepText,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                height: 1.55,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // ── Use This Recipe button ────────────────────────────────
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _usingRecipe ? null : _onUseRecipe,
                      icon:
                          _usingRecipe
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(
                                Icons.check_circle_outline,
                                size: 20,
                                color: Colors.white,
                              ),
                      label: Text(
                        _usingRecipe
                            ? 'Updating pantry…'
                            : 'I Used This Recipe',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  // ── YouTube link ──────────────────────────────────────────
                  if (recipe.youtubeUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(recipe.youtubeUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Watch on YouTube',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 13, color: color),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 11, color: color),
        ),
      ],
    );
  }
}
