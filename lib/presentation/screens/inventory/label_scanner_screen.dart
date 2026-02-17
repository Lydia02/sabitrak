import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../config/theme/app_theme.dart';
import 'manual_entry_screen.dart';

class LabelScannerScreen extends StatefulWidget {
  final String? prefilledBarcode;

  const LabelScannerScreen({super.key, this.prefilledBarcode});

  @override
  State<LabelScannerScreen> createState() => _LabelScannerScreenState();
}

class _LabelScannerScreenState extends State<LabelScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  String? _errorMessage;
  Widget? _pendingNavigation;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera available');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _captureAndRecognize() async {
    if (_isProcessing || _cameraController == null) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await _textRecognizer.processImage(inputImage);

      // Clean up temp file
      try {
        await File(image.path).delete();
      } catch (_) {}

      if (!mounted) return;

      if (recognized.text.isEmpty) {
        setState(() => _isProcessing = false);
        _showSnackBar('No text detected. Try again with better lighting.');
        return;
      }

      // Parse the OCR text to extract product info
      final parsed = _parseOcrText(recognized);
      _showParsedResult(parsed);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar('Error scanning label. Please try again.');
      }
    }
  }

  ParsedLabelInfo _parseOcrText(RecognizedText recognized) {
    String? productName;
    String? brand;
    String? quantity;
    String? category;
    final allText = recognized.text;
    final lines = allText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Filter blocks: discard junk text that's clearly not from a product label
    final blocks = List<TextBlock>.from(recognized.blocks);

    // Remove blocks with text that looks like file paths, URLs, or system text
    final junkPatterns = [
      RegExp(r'[/\\][A-Za-z]', caseSensitive: false), // file paths
      RegExp(r'https?://', caseSensitive: false),       // URLs
      RegExp(r'\.dart|\.js|\.py|\.txt|\.md', caseSensitive: false), // file extensions
      RegExp(r'Desktop|Documents|Users|project', caseSensitive: false), // OS paths
      RegExp(r'import |class |void |final |const ', caseSensitive: false), // code
    ];

    final filteredBlocks = blocks.where((block) {
      final text = block.text.trim();
      // Skip very short (1 char) or very long blocks (likely paragraphs from background)
      if (text.length < 2 || text.length > 200) return false;
      // Skip blocks that match junk patterns
      for (final pattern in junkPatterns) {
        if (pattern.hasMatch(text)) return false;
      }
      return true;
    }).toList();

    // Strategy: find the product name using text block font size (height relative to width)
    // The product name is typically the largest, most prominent text
    // Score blocks: prefer blocks that are short (1-4 words), have large font, and are near the top-center
    final scoredBlocks = <_ScoredBlock>[];
    for (final block in filteredBlocks) {
      final text = block.text.trim();
      final bbox = block.boundingBox;
      final area = bbox.width * bbox.height;
      // Estimated font size = bounding box height / number of lines in block
      final lineCount = block.lines.length.clamp(1, 100);
      final estimatedFontSize = bbox.height / lineCount;

      // Skip blocks that are just numbers (barcodes, registration numbers)
      if (RegExp(r'^[\d\s\-]+$').hasMatch(text)) continue;

      // Boost score for blocks with fewer words (product names are short)
      final wordCount = text.split(RegExp(r'\s+')).length;
      double score = estimatedFontSize * 2;
      if (wordCount <= 4) score *= 1.5;
      if (wordCount <= 2) score *= 1.3;
      // Slight area bonus
      score += area * 0.001;

      scoredBlocks.add(_ScoredBlock(text: text, score: score, block: block));
    }

    // Sort by score (highest = most likely product name)
    scoredBlocks.sort((a, b) => b.score.compareTo(a.score));

    if (scoredBlocks.isNotEmpty) {
      productName = scoredBlocks[0].text;
    }

    // For brand: look for common patterns first (e.g., "by BrandName", "Brand:" prefix)
    // Then fall back to 2nd highest scored block
    for (final line in lines) {
      final lower = line.toLowerCase().trim();
      // Common brand indicators on Nigerian/African labels
      if (lower.startsWith('by ') || lower.startsWith('brand:') || lower.startsWith('manufactured by') || lower.startsWith('produced by') || lower.startsWith('packed by')) {
        brand = line.replaceFirst(RegExp(r'^(by|brand:|manufactured by|produced by|packed by)\s*', caseSensitive: false), '').trim();
        break;
      }
    }
    // If no explicit brand pattern found, try 2nd scored block (only if different from name)
    if (brand == null && scoredBlocks.length > 1) {
      final candidate = scoredBlocks[1].text;
      if (candidate != productName) {
        brand = candidate;
      }
    }

    // Look for weight/quantity patterns in all text
    final weightPatterns = [
      RegExp(r'Net\s*(?:Weight|Wt|W)\.?\s*:?\s*(\d+\.?\d*)\s*(kg|g|ml|l)', caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*(grams|kilograms|litres|liters|millilitres|milliliters)', caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*(kg|g|ml|l|oz|lb|cl)\b', caseSensitive: false),
    ];

    for (final pattern in weightPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        if (match.groupCount >= 2) {
          quantity = '${match.group(1)}${match.group(2)}';
        } else {
          quantity = match.group(0);
        }
        break;
      }
    }

    // Try to detect category from common keywords in the filtered text only
    final lowerText = filteredBlocks.map((b) => b.text.toLowerCase()).join(' ');
    if (lowerText.contains('noodle') || lowerText.contains('pasta') || lowerText.contains('spaghetti') || lowerText.contains('rice') || lowerText.contains('bread')) {
      category = 'Grains';
    } else if (lowerText.contains('milk') || lowerText.contains('yogurt') || lowerText.contains('cheese') || lowerText.contains('butter') || lowerText.contains('cream')) {
      category = 'Dairy';
    } else if (lowerText.contains('juice') || lowerText.contains('drink') || lowerText.contains('water') || lowerText.contains('soda') || lowerText.contains('beverage')) {
      category = 'Beverages';
    } else if (lowerText.contains('biscuit') || lowerText.contains('cookie') || lowerText.contains('chocolate') || lowerText.contains('candy') || lowerText.contains('snack') || lowerText.contains('chip')) {
      category = 'Snacks';
    } else if (lowerText.contains('groundnut') || lowerText.contains('kuli') || lowerText.contains('chin chin') || lowerText.contains('plantain') || lowerText.contains('puff puff')) {
      category = 'Snacks';
    } else if (lowerText.contains('tomato') || lowerText.contains('pepper') || lowerText.contains('onion') || lowerText.contains('vegetable')) {
      category = 'Vegetables';
    } else if (lowerText.contains('fruit') || lowerText.contains('mango') || lowerText.contains('orange') || lowerText.contains('apple') || lowerText.contains('banana')) {
      category = 'Fruits';
    } else if (lowerText.contains('meat') || lowerText.contains('chicken') || lowerText.contains('beef') || lowerText.contains('fish') || lowerText.contains('sardine') || lowerText.contains('tuna')) {
      category = 'Meat & Fish';
    } else if (lowerText.contains('sauce') || lowerText.contains('spice') || lowerText.contains('seasoning') || lowerText.contains('pepper') || lowerText.contains('curry')) {
      category = 'Spices';
    } else if (lowerText.contains('canned') || lowerText.contains('tin') || lowerText.contains('preserved')) {
      category = 'Canned';
    } else if (lowerText.contains('frozen') || lowerText.contains('ice')) {
      category = 'Frozen';
    }

    return ParsedLabelInfo(
      productName: productName,
      brand: brand,
      quantity: quantity,
      category: category,
      rawLines: lines,
    );
  }

  void _showParsedResult(ParsedLabelInfo info) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    // Controllers for editable fields
    final nameController = TextEditingController(text: info.productName ?? '');
    final brandController = TextEditingController(text: info.brand ?? '');
    final quantityController = TextEditingController(text: info.quantity ?? '');
    String selectedCategory = info.category ?? 'Other';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtitleColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.document_scanner_outlined,
                    color: AppTheme.primaryGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Label Scanned!',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review and edit the detected info',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 20),

                // Editable fields
                _buildTextField('Product Name', nameController, textColor, subtitleColor, isDark),
                const SizedBox(height: 12),
                _buildTextField('Brand', brandController, textColor, subtitleColor, isDark),
                const SizedBox(height: 12),
                _buildTextField('Quantity', quantityController, textColor, subtitleColor, isDark),
                const SizedBox(height: 12),

                // Category dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppTheme.fieldBorderColor,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCategory,
                      dropdownColor: cardColor,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: textColor,
                      ),
                      items: const [
                        'Fruits', 'Vegetables', 'Dairy', 'Meat & Fish',
                        'Grains', 'Canned', 'Spices', 'Beverages',
                        'Snacks', 'Frozen', 'Other',
                      ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setSheetState(() => selectedCategory = v!),
                    ),
                  ),
                ),

                // Show raw OCR text for reference
                if (info.rawLines.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: Text(
                      'Raw OCR Text (${info.rawLines.length} lines)',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.grey.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          info.rawLines.join('\n'),
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: subtitleColor,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // Add to Inventory button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a product name')),
                        );
                        return;
                      }
                      _pendingNavigation = ManualEntryScreen(
                        prefilledName: name,
                        prefilledCategory: selectedCategory,
                        prefilledBarcode: widget.prefilledBarcode,
                      );
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add to Inventory',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Retake button
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() => _isProcessing = false);
                  },
                  child: Text(
                    'Scan Again',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (!mounted) return;
      final nav = _pendingNavigation;
      _pendingNavigation = null;
      setState(() => _isProcessing = false);
      if (nav != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => nav),
        );
      }
    });
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color textColor,
    Color subtitleColor,
    bool isDark,
  ) {
    return TextField(
      controller: controller,
      style: TextStyle(fontFamily: 'Roboto', fontSize: 14, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          color: subtitleColor,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppTheme.fieldBorderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppTheme.fieldBorderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                  const Spacer(),
                  // Flash toggle
                  if (_cameraController != null)
                    IconButton(
                      onPressed: () async {
                        try {
                          await _cameraController!.setFlashMode(
                            _cameraController!.value.flashMode == FlashMode.torch
                                ? FlashMode.off
                                : FlashMode.torch,
                          );
                          setState(() {});
                        } catch (_) {}
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _cameraController?.value.flashMode == FlashMode.torch
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom instructions + capture button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.white70,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Point at the product label',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Make sure the text is clear and well-lit',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Capture button
                  GestureDetector(
                    onTap: _isProcessing ? null : _captureAndRecognize,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: _isProcessing
                            ? Colors.grey
                            : AppTheme.primaryGreen,
                      ),
                      child: _isProcessing
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoredBlock {
  final String text;
  final double score;
  final TextBlock block;
  const _ScoredBlock({required this.text, required this.score, required this.block});
}

class ParsedLabelInfo {
  final String? productName;
  final String? brand;
  final String? quantity;
  final String? category;
  final List<String> rawLines;

  const ParsedLabelInfo({
    this.productName,
    this.brand,
    this.quantity,
    this.category,
    required this.rawLines,
  });
}
