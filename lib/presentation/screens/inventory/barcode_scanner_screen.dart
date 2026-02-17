import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../config/theme/app_theme.dart';
import '../../../services/open_food_facts_service.dart';
import 'label_scanner_screen.dart';
import 'manual_entry_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final OpenFoodFactsService _service = OpenFoodFactsService();

  bool _isProcessing = false;
  String? _lastScannedCode;
  Widget? _pendingNavigation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'community':
        return 'Source: SabiTrak Community';
      case 'openfoodfacts':
        return 'Source: Open Food Facts';
      case 'goupc':
        return 'Source: Go-UPC';
      case 'upcitemdb':
        return 'Source: UPCitemdb';
      default:
        return 'Source: $source';
    }
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    if (_isProcessing || barcode == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = barcode;
    });

    final result = await _service.lookupBarcode(barcode);

    if (!mounted) return;

    if (result.product != null) {
      _showProductFound(result);
    } else {
      _showProductNotFound(result);
    }
  }

  void _showProductFound(BarcodeLookupResult result) {
    final product = result.product!;
    final countryInfo = result.countryInfo;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subtitleColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Success icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.primaryGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Product Found!',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),

            // Product info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppTheme.primaryGreen.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : AppTheme.fieldBorderColor,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: product.imageUrl != null
                        ? Image.network(
                            product.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.displayName,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product.brand != null && product.brand!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.brand!,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildChip(product.appCategory, AppTheme.primaryGreen),
                            if (countryInfo != null)
                              _buildChip(
                                '${countryInfo.flag} ${countryInfo.country}',
                                Colors.blue.shade700,
                              ),
                            if (product.quantity != null && product.quantity!.isNotEmpty)
                              Text(
                                product.quantity!,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 11,
                                  color: subtitleColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Data source badge
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _sourceLabel(product.source),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10,
                  color: subtitleColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Add to Inventory button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Save to community DB for future users
                  _service.saveToCommunitDB(
                    barcode: product.barcode,
                    name: product.displayName,
                    brand: product.brand,
                    category: product.appCategory,
                    imageUrl: product.imageUrl,
                    quantity: product.quantity,
                  );

                  _pendingNavigation = ManualEntryScreen(
                    prefilledName: product.displayName,
                    prefilledCategory: product.appCategory,
                    prefilledBarcode: product.barcode,
                    prefilledImageUrl: product.imageUrl,
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

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
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
    ).whenComplete(() {
      if (!mounted) return;
      final nav = _pendingNavigation;
      _pendingNavigation = null;
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
      if (nav != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => nav),
        );
      }
    });
  }

  void _showProductNotFound(BarcodeLookupResult result) {
    final countryInfo = result.countryInfo;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subtitleColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                color: Colors.orange.shade700,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Product Not Found',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),

            // Country info
            if (countryInfo != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      countryInfo.flag,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registered in ${countryInfo.country}',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'GS1 Prefix: ${countryInfo.prefix}',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Barcode display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Barcode: ${result.barcode}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Camera label scan prompt
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppTheme.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Take a photo of the label',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Point your camera at the product packaging and we\'ll read the name, brand & details automatically',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: subtitleColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scan Label button (OCR) - primary action
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  _pendingNavigation = LabelScannerScreen(
                    prefilledBarcode: result.barcode,
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text(
                  'Scan Product Label',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Add Manually button - secondary action
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  _pendingNavigation = ManualEntryScreen(
                    prefilledBarcode: result.barcode,
                  );
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Enter Manually Instead',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
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
    ).whenComplete(() {
      if (!mounted) return;
      final nav = _pendingNavigation;
      _pendingNavigation = null;
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
      if (nav != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => nav),
        );
      }
    });
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.fastfood_outlined,
        color: AppTheme.primaryGreen,
        size: 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : Colors.white;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                _onBarcodeDetected(barcodes.first.rawValue!);
              }
            },
          ),

          // Overlay
          _buildOverlay(textColor),

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
                  IconButton(
                    onPressed: () => _controller.toggleTorch(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: ValueListenableBuilder<TorchState>(
                        valueListenable: _controller.torchState,
                        builder: (_, state, __) => Icon(
                          state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (_isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryGreen),
                    SizedBox(height: 16),
                    Text(
                      'Searching 4 databases...',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white,
                        fontSize: 14,
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

  Widget _buildOverlay(Color textColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final cutoutLeft = (screenW - scanAreaSize) / 2;
        final cutoutTop = (screenH - scanAreaSize) / 2 - 40;

        return Stack(
          children: [
            // Dark overlay with transparent cutout using ClipPath
            CustomPaint(
              size: Size(screenW, screenH),
              painter: _ScanOverlayPainter(
                cutoutRect: RRect.fromRectAndRadius(
                  Rect.fromLTWH(cutoutLeft, cutoutTop, scanAreaSize, scanAreaSize),
                  const Radius.circular(20),
                ),
                overlayColor: Colors.black.withValues(alpha: 0.55),
              ),
            ),

            Center(
              child: Transform.translate(
                offset: const Offset(0, -40),
                child: SizedBox(
                  width: scanAreaSize,
                  height: scanAreaSize,
                  child: CustomPaint(
                    painter: _CornerBracketPainter(),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white70, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'Point camera at a barcode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Searches Community DB + Open Food Facts + Go-UPC + UPCitemdb',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final RRect cutoutRect;
  final Color overlayColor;

  _ScanOverlayPainter({required this.cutoutRect, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    // Draw overlay with cutout by using Path.combine to subtract the rounded rect
    final overlayPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(cutoutRect);
    final combinedPath = Path.combine(PathOperation.difference, overlayPath, cutoutPath);
    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      cutoutRect != oldDelegate.cutoutRect || overlayColor != oldDelegate.overlayColor;
}

class _CornerBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 30.0;
    const r = 12.0;

    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, len),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - r)
        ..quadraticBezierTo(0, size.height, r, size.height)
        ..lineTo(len, size.height),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - r, size.height)
        ..quadraticBezierTo(size.width, size.height, size.width, size.height - r)
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
