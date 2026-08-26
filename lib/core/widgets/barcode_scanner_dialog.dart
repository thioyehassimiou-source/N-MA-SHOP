import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/scanner_server.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dialog de scan code-barres via la caméra ou via smartphone (réseau local).
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

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Webcam (PC)
  MobileScannerController? _cameraController;

  // Serveur local (Smartphone)
  final ScannerServer _scannerServer = ScannerServer();
  StreamSubscription? _serverSubscription;
  bool _serverStarting = true;

  bool _detected = false;
  int _currentTabIndex = 0;
  
  // Variables pour scanner USB (Douchette)
  String _usbBarcodeBuffer = '';
  Timer? _usbDebounceTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Démarrer le serveur local (onglet Smartphone)
    _scannerServer.start().then((_) {
      if (mounted) setState(() => _serverStarting = false);
    });
    _serverSubscription = _scannerServer.onBarcodeScanned.listen(_onCodeDetected);
  }

  void _onTabChanged() {
    if (_tabController.index == _currentTabIndex) return;
    _currentTabIndex = _tabController.index;
    
    if (_currentTabIndex == 0) {
      // Passer à l'onglet Webcam → initialiser la caméra si pas encore fait
      _initCamera();
    } else {
      // Quitter l'onglet Webcam → libérer la caméra pour économiser les ressources
      _disposeCamera();
    }
  }

  void _initCamera() {
    if (_cameraController != null) return;
    setState(() {
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: false,
      );
    });
  }

  void _disposeCamera() {
    setState(() {
      _cameraController?.dispose();
      _cameraController = null;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _serverSubscription?.cancel();
    _scannerServer.stop();
    _cameraController?.dispose();
    super.dispose();
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_usbBarcodeBuffer.isNotEmpty) {
        _onCodeDetected(_usbBarcodeBuffer);
        _usbBarcodeBuffer = '';
      }
      return;
    }

    if (event.character != null && event.character!.isNotEmpty) {
      _usbBarcodeBuffer += event.character!;
      _usbDebounceTimer?.cancel();
      _usbDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _usbBarcodeBuffer = ''; // Réinitialiser si pas d'entrée rapide
      });
    }
  }

  void _onCameraDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    _onCodeDetected(barcode!.rawValue!);
  }

  void _onCodeDetected(String code) {
    if (_detected || !mounted) return;
    setState(() => _detected = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) Navigator.of(context).pop(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final dialogH = (screenH * 0.85).clamp(480.0, 600.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          _onKeyEvent(event);
          return KeyEventResult.ignored;
        },
        child: SizedBox(
          width: 460,
          height: dialogH,
          child: Column(
            children: [
              // ─── En-tête ──────────────────────────────────────────────
              _buildHeader(),

              // ─── Contenu (Onglets) ────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWebcamTab(),
                    _buildSmartphoneTab(),
                  ],
                ),
              ),

              // ─── Pied ─────────────────────────────────────────────────
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.md,
        top: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandNavy, Color(0xFF1A3060)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Scanner un code-barres',
                  style: AppTypography.labelMd.copyWith(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFE85D04),
            labelColor: const Color(0xFFE85D04),
            unselectedLabelColor: Colors.white70,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                icon: Icon(Icons.videocam_outlined, size: 20),
                text: 'Webcam PC',
                iconMargin: EdgeInsets.only(bottom: 2),
              ),
              Tab(
                icon: Icon(Icons.phone_iphone_outlined, size: 20),
                text: 'Smartphone',
                iconMargin: EdgeInsets.only(bottom: 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebcamTab() {
    // Onglet Webcam : la caméra n'est initialisée que quand on est sur cet onglet
    if (_cameraController == null) {
      // Proposer d'activer la caméra
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.videocam_outlined, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Activer la caméra',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cliquez sur le bouton pour démarrer\nla caméra de votre PC.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Démarrer la caméra'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Si la caméra reste noire ou ne fonctionne pas, utilisez la version navigateur :',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  if (_scannerServer.serverUrl != null) {
                    final uri = Uri.parse(_scannerServer.serverUrl!).replace(host: '127.0.0.1');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Ouvrir dans le navigateur'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _cameraController!,
          onDetect: _onCameraDetect,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text('Caméra indisponible', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      error.errorDetails?.message ?? 'Vérifiez que votre webcam est branchée.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Utilisez l\'onglet Smartphone pour scanner sans webcam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        _ScannerOverlay(detected: _detected),
        if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS)
          Positioned(
            bottom: 16,
            right: 16,
            child: IconButton.filled(
              onPressed: () => _cameraController?.toggleTorch(),
              icon: const Icon(Icons.flashlight_on_rounded),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
      ],
    );
  }

  Widget _buildSmartphoneTab() {
    if (_serverStarting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Démarrage du serveur local...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_scannerServer.serverUrl == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Impossible de démarrer le serveur local.\nVérifiez votre connexion réseau Wi-Fi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                _InstructionRow(
                  number: '1',
                  text: 'Connectez votre téléphone au même réseau Wi-Fi que ce PC.',
                ),
                const SizedBox(height: 8),
                _InstructionRow(
                  number: '2',
                  text: "Scannez le QR Code ci-dessous (sur cet écran PC) pour connecter votre téléphone.",
                ),
                const SizedBox(height: 8),
                _InstructionRow(
                  number: '3',
                  text: "Sur votre téléphone, prenez en photo le CODE-BARRES (les lignes noires) du produit.",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: _scannerServer.serverUrl!,
              version: QrVersions.auto,
              size: 160.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Lien direct sélectionnable
          SelectableText(
            _scannerServer.serverUrl!,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ou copiez ce lien et collez-le dans le navigateur de votre téléphone.',
            style: AppTypography.bodySm.copyWith(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: AppSpacing.md),
      child: _detected
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text('Code détecté !',
                    style: AppTypography.labelMd.copyWith(color: Colors.green)),
              ],
            )
          : Text(
              'Ou saisissez manuellement la référence produit',
              style: AppTypography.bodySm.copyWith(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
    );
  }
}

// ─── Widget instruction numérotée ─────────────────────────────────────────────

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}

// ─── Overlay viseur animé (onglet Webcam) ────────────────────────────────────

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.detected});
  final bool detected;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OverlayPainter(detected: detected));
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

    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutRect, const Radius.circular(12)));
    canvas.drawPath(Path.combine(PathOperation.difference, fullPath, holePath), bgPaint);

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
