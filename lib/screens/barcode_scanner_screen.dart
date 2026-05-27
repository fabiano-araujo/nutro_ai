import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../i18n/app_localizations_extension.dart';
import '../theme/app_theme.dart';
import '../utils/product_barcode_utils.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  static const int _requiredConsistentReads = 2;
  static const Duration _candidateResetInterval = Duration(seconds: 2);

  late final MobileScannerController _controller;
  bool _hasReturnedBarcode = false;
  String? _lastBarcode;
  DateTime? _candidateWindowStartedAt;
  final Map<String, int> _candidateReadCounts = {};

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      cameraResolution: const Size(1280, 720),
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 150,
      autoZoom: true,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
  }

  @override
  Future<void> dispose() async {
    await _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasReturnedBarcode || capture.barcodes.isEmpty || !mounted) return;

    for (final barcode in capture.barcodes) {
      final normalizedBarcode = _normalizeDetectedBarcode(barcode);
      if (normalizedBarcode == null) continue;

      final count = _recordCandidateRead(normalizedBarcode);
      setState(() {
        _lastBarcode = '$normalizedBarcode ($count/$_requiredConsistentReads)';
      });

      if (count >= _requiredConsistentReads) {
        _hasReturnedBarcode = true;
        Navigator.of(context).pop(normalizedBarcode);
        return;
      }
    }
  }

  int _recordCandidateRead(String barcode) {
    final now = DateTime.now();
    final shouldReset = _candidateWindowStartedAt == null ||
        now.difference(_candidateWindowStartedAt!) > _candidateResetInterval;

    if (shouldReset) {
      _candidateReadCounts.clear();
      _candidateWindowStartedAt = now;
    }

    final count = (_candidateReadCounts[barcode] ?? 0) + 1;
    _candidateReadCounts[barcode] = count;
    return count;
  }

  String? _normalizeDetectedBarcode(Barcode barcode) {
    final rawValue = barcode.rawValue ?? barcode.displayValue;
    final digits =
        rawValue == null ? null : ProductBarcodeUtils.digitsOnly(rawValue);
    if (digits == null || digits.isEmpty) return null;

    switch (barcode.format) {
      case BarcodeFormat.ean13:
        return ProductBarcodeUtils.normalizeEan13Digits(digits);
      case BarcodeFormat.ean8:
        return ProductBarcodeUtils.normalizeEan8Digits(digits);
      case BarcodeFormat.upcA:
        return ProductBarcodeUtils.normalizeUpcADigits(digits);
      case BarcodeFormat.upcE:
        return ProductBarcodeUtils.normalizeUpcEDigits(digits);
      default:
        return null;
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
  }

  Future<void> _switchCamera() async {
    await _controller.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scanWidth = constraints.maxWidth * 0.82;
            final scanHeight = scanWidth * 0.58;
            final scanWindow = Rect.fromCenter(
              center: Offset(
                constraints.maxWidth / 2,
                constraints.maxHeight * 0.45,
              ),
              width: scanWidth,
              height: scanHeight,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: MobileScanner(
                    controller: _controller,
                    scanWindow: scanWindow,
                    fit: BoxFit.cover,
                    onDetect: _handleBarcode,
                    errorBuilder: (context, error) =>
                        _ScannerError(error: error),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScannerOverlayPainter(scanWindow: scanWindow),
                  ),
                ),
                Positioned(
                  left: scanWindow.left,
                  top: scanWindow.top,
                  width: scanWindow.width,
                  height: scanWindow.height,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 8,
                  child: _ScannerHeader(
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: scanWindow.bottom + 24,
                  child: Column(
                    children: [
                      Text(
                        context.tr.translate('barcode_scanner_hint'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      if (_lastBarcode != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _lastBarcode!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ScannerCircleButton(
                        icon: Icons.flashlight_on,
                        tooltip: context.tr.translate('scanner_flash'),
                        onPressed: _toggleTorch,
                      ),
                      const SizedBox(width: 18),
                      _ScannerCircleButton(
                        icon: Icons.cameraswitch,
                        tooltip: context.tr.translate('scanner_switch_camera'),
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScannerHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _ScannerHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              context.tr.translate('barcode_scanner_title'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ScannerCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ScannerCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  final MobileScannerException error;

  const _ScannerError({required this.error});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                context.tr.translate('barcode_scanner_camera_error'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.errorCode.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  _ScannerOverlayPainter({required this.scanWindow});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()..addRect(Offset.zero & size);
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(18)),
      );
    final path = Path.combine(
      PathOperation.difference,
      overlayPath,
      cutoutPath,
    );

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}
