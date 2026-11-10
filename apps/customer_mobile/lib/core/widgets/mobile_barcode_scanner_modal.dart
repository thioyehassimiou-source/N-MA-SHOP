import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';

/// Modal de scan de code-barres par caméra smartphone optimisé pour boutiquier.
///
/// Fonctionne 100% hors-ligne avec [MobileScanner].
/// Retourne la chaîne scannée ou null en cas d'annulation.
class MobileBarcodeScannerModal extends StatefulWidget {
  final String title;
  final String hintText;

  const MobileBarcodeScannerModal({
    super.key,
    this.title = 'Scanner Code-barres',
    this.hintText = 'Placez le code-barres du produit dans le cadre',
  });

  /// Ouvre le scanner sous forme de modal plein écran interactif.
  static Future<String?> show(
    BuildContext context, {
    String title = 'Scanner Code-barres',
    String hintText = 'Placez le code-barres du produit dans le cadre',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.black,
      builder: (_) => MobileBarcodeScannerModal(
        title: title,
        hintText: hintText,
      ),
    );
  }

  @override
  State<MobileBarcodeScannerModal> createState() => _MobileBarcodeScannerModalState();
}

class _MobileBarcodeScannerModalState extends State<MobileBarcodeScannerModal>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _scanLineAnimation;

  bool _isDetected = false;
  bool _isTorchOn = false;
  bool _showManualInput = false;
  final TextEditingController _manualInputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.qrCode,
      ],
      returnImage: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _manualInputCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isDetected) return;
    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue?.trim();

    if (code != null && code.isNotEmpty) {
      _triggerSuccess(code);
    }
  }

  void _triggerSuccess(String code) {
    if (_isDetected || !mounted) return;
    setState(() => _isDetected = true);

    SystemSound.play(SystemSoundType.click);
    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        Navigator.of(context).pop(code);
      }
    });
  }

  void _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  void _switchCamera() async {
    await _controller.switchCamera();
  }

  void _submitManual() {
    final code = _manualInputCtrl.text.trim();
    if (code.isNotEmpty) {
      _triggerSuccess(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = (size.width * 0.75).clamp(240.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Vue Caméra MobileScanner
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 48),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Accès Caméra Requis',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Activez la caméra dans les paramètres pour scanner vos codes-barres directement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _showManualInput = true),
                          icon: const Icon(Icons.keyboard_rounded),
                          label: const Text('Saisir le code manuellement'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 2. Masque sombre semi-transparent autour du viseur
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.65),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: boxSize,
                      height: boxSize * 0.75,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Cadre & Animation du Viseur (Reticle)
            Center(
              child: SizedBox(
                width: boxSize,
                height: boxSize * 0.75,
                child: Stack(
                  children: [
                    // Bordures du cadre
                    CustomPaint(
                      size: Size(boxSize, boxSize * 0.75),
                      painter: _ScannerBorderPainter(
                        color: _isDetected ? AppColors.brandEmerald : AppColors.brandOrange,
                      ),
                    ),

                    // Ligne laser animée
                    if (!_isDetected)
                      AnimatedBuilder(
                        animation: _scanLineAnimation,
                        builder: (context, _) {
                          final topPos = (boxSize * 0.75 - 4) * _scanLineAnimation.value;
                          return Positioned(
                            top: topPos,
                            left: 12,
                            right: 12,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.brandOrange.withValues(alpha: 0.0),
                                    AppColors.brandOrange,
                                    AppColors.brandOrange.withValues(alpha: 0.0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brandOrange.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Badge de détection réussie
                    if (_isDetected)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.brandEmerald,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandEmerald.withValues(alpha: 0.5),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Code Détecté !',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 4. Instructions au-dessus / en-dessous du cadre
            Positioned(
              left: 20,
              right: 20,
              top: (size.height / 2) - (boxSize * 0.75 / 2) - 52,
              child: Text(
                widget.hintText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),

            // 5. Barre Supérieure (Header avec Contrôles)
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _isTorchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                      color: _isTorchOn ? AppColors.warning : Colors.white,
                    ),
                    tooltip: 'Flash / Torche',
                    style: IconButton.styleFrom(
                      backgroundColor: _isTorchOn ? AppColors.warning.withValues(alpha: 0.3) : Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: _switchCamera,
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                    tooltip: 'Changer de Caméra',
                    style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  ),
                ],
              ),
            ),

            // 6. Pied de page : Saisie manuelle de secours
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: _showManualInput
                  ? Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.brandNavy,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Saisie manuelle du code :',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                                onPressed: () => setState(() => _showManualInput = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _manualInputCtrl,
                                  autofocus: true,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: 61510001002...',
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white12,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _submitManual(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _submitManual,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brandOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showManualInput = true),
                        icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white),
                        label: const Text(
                          'Code abîmé ? Saisir au clavier',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white12,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Peintre personnalisé dessinant les 4 angles arrondis du viseur.
class _ScannerBorderPainter extends CustomPainter {
  final Color color;
  static const double cornerLength = 32.0;
  static const double strokeWidth = 4.0;

  const _ScannerBorderPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Coin Haut-Gauche
    canvas.drawLine(const Offset(0, 0), Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerLength), paint);

    // Coin Haut-Droit
    canvas.drawLine(Offset(w, 0), Offset(w - cornerLength, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cornerLength), paint);

    // Coin Bas-Gauche
    canvas.drawLine(Offset(0, h), Offset(cornerLength, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - cornerLength), paint);

    // Coin Bas-Droit
    canvas.drawLine(Offset(w, h), Offset(w - cornerLength, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

