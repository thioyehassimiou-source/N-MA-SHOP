import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'pin_setup_screen.dart';

class PairingScanScreen extends ConsumerStatefulWidget {
  const PairingScanScreen({super.key});

  @override
  ConsumerState<PairingScanScreen> createState() => _PairingScanScreenState();
}

class _PairingScanScreenState extends ConsumerState<PairingScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _processQrCode(barcode.rawValue!);
  }

  void _processQrCode(String raw) {
    setState(() => _isProcessing = true);

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['type'] != 'nmashop_pairing' && decoded['token'] == null) {
        _showError('Format de QR code non reconnu pour N\'MaShop.');
        setState(() => _isProcessing = false);
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(
            token: decoded['token'] ?? raw,
            serverUrl: decoded['serverUrl'] ?? StorageService.defaultServerUrl,
            shopName: decoded['shopName'] ?? 'Boutique',
            currency: decoded['currency'] ?? 'GNF',
          ),
        ),
      );
    } catch (_) {
      // Si ce n'est pas du JSON, peut-être est-ce directement le jeton brut
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(
            token: raw.trim(),
            serverUrl: StorageService.defaultServerUrl,
            shopName: 'Ma Boutique',
            currency: 'GNF',
          ),
        ),
      );
    }
  }

  void _showManualInputDialog() {
    final tokenController = TextEditingController();
    final urlController = TextEditingController(text: StorageService.defaultServerUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liaison manuelle / Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Jeton de jumelage ou ID boutique',
                hintText: 'Ex: pair-uuid-123',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL API Cloud',
                hintText: 'http://10.0.2.2:3000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (tokenController.text.trim().isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PinSetupScreen(
                      token: tokenController.text.trim(),
                      serverUrl: urlController.text.trim(),
                      shopName: 'Boutique N\'MaShop',
                      currency: 'GNF',
                    ),
                  ),
                );
              }
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Lier ma boutique',
          style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: AppColors.onSurface),
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'Pointez l\'appareil photo vers le QR code affiché dans les paramètres de votre caisse N\'MaShop Desktop.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleBarcode,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: _showManualInputDialog,
                  icon: const Icon(Icons.keyboard, color: AppColors.onSurfaceVariant),
                  label: const Text(
                    'Saisir un code manuellement',
                    style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
