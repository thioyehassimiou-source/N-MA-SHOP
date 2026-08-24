import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dialog de scan code-barres via la caméra.
/// Retourne le code scanné (String) ou null si l'utilisateur ferme.
class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const BarcodeScannerDialog(),
    );
  }

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _detected = true);
    final code = barcode!.rawValue!;

    // Court délai pour montrer le feedback visuel
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.of(context).pop(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 400,
        height: 480,
        child: Column(
          children: [
            // ─── En-tête ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandNavy, Color(0xFF1A3060)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scanner un code-barres',
                          style: AppTypography.labelMd
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          'Pointez la caméra vers le code EAN/QR',
                          style: AppTypography.bodySm.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            // ─── Viewfinder caméra ────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),

                  // Overlay viseur
                  _ScannerOverlay(detected: _detected),

                  // Bouton torche
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: IconButton.filled(
                      onPressed: () => _controller.toggleTorch(),
                      icon: const Icon(Icons.flashlight_on_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Pied ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _detected
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Code détecté !',
                            style: AppTypography.labelMd
                                .copyWith(color: Colors.green)),
                      ],
                    )
                  : Text(
                      'Ou saisissez manuellement la référence produit',
                      style: AppTypography.bodySm.copyWith(
                          color: Colors.grey, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Overlay viseur animé ─────────────────────────────────────────────────────

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.detected});

  final bool detected;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(detected: detected),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.detected});

  final bool detected;

  @override
  void paint(Canvas canvas, Size size) {
    const cutW = 240.0;
    const cutH = 160.0;
    final cutX = (size.width - cutW) / 2;
    final cutY = (size.height - cutH) / 2;
    final cutRect = Rect.fromLTWH(cutX, cutY, cutW, cutH);

    // Fond semi-transparent sauf dans la zone de scan
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutRect, const Radius.circular(12)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPath, holePath),
      bgPaint,
    );

    // Coins du viseur
    final cornerPaint = Paint()
      ..color = detected ? Colors.greenAccent : const Color(0xFFE85D04)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cLen = 22.0;
    const r = 12.0;

    void drawCorner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y + dy * r), Offset(x, y + dy * cLen), cornerPaint);
      canvas.drawLine(Offset(x + dx * r, y), Offset(x + dx * cLen, y), cornerPaint);
      // Small arc
      final arcRect = Rect.fromLTWH(
        x + (dx < 0 ? -r : 0), y + (dy < 0 ? -r : 0), r, r,
      );
      canvas.drawArc(arcRect, dx < 0 ? 0 : 3.14, 1.57 * dx * dy.sign, false, cornerPaint);
    }

    drawCorner(cutRect.left, cutRect.top, 1, 1);
    drawCorner(cutRect.right, cutRect.top, -1, 1);
    drawCorner(cutRect.left, cutRect.bottom, 1, -1);
    drawCorner(cutRect.right, cutRect.bottom, -1, -1);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.detected != detected;
}
