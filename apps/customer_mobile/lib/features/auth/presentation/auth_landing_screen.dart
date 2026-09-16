import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../shell/main_navigation_shell.dart';
import 'pairing_scan_screen.dart';
import 'pin_setup_screen.dart';

class AuthLandingScreen extends ConsumerWidget {
  const AuthLandingScreen({super.key});

  void _startInstantDemo(BuildContext context, WidgetRef ref) async {
    // Mode démo immédiat : pré-remplit les accès pour tester sans barrière
    final storage = ref.read(storageServiceProvider);
    await storage.saveAuthData(
      accessToken: 'demo-token-jwt',
      refreshToken: 'demo-refresh-token',
      shopId: 'shop-diallo-001',
      shopName: 'Boutique Diallo & Frères',
      currency: 'GNF',
      serverUrl: StorageService.defaultServerUrl,
    );

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      (route) => false,
    );
  }

  void _showManualEntryDialog(BuildContext context) {
    final tokenController = TextEditingController();
    final urlController = TextEditingController(text: StorageService.defaultServerUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Liaison manuelle / Adresse caisse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Jeton de jumelage ou ID caisse',
                hintText: 'Ex: pair-caisse-01',
                prefixIcon: Icon(Icons.vpn_key_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL API Serveur',
                hintText: 'http://localhost:3000',
                prefixIcon: Icon(Icons.dns_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final token = tokenController.text.trim().isNotEmpty
                  ? tokenController.text.trim()
                  : 'pair-auto-${DateTime.now().millisecondsSinceEpoch}';
              final url = urlController.text.trim().isNotEmpty
                  ? urlController.text.trim()
                  : StorageService.defaultServerUrl;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PinSetupScreen(
                    token: token,
                    serverUrl: url,
                    shopName: 'Boutique N\'MaShop',
                    currency: 'GNF',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Halo d'ambiance haut de gamme
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // Badge officiel
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.shield_outlined, color: AppColors.primary, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'N\'MASHOP MOBILE • COMPTE DU PATRON',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Logo & Titres
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Connexion & Jumelage',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Associez ce smartphone à votre caisse pour débloquer votre cockpit commercial en temps réel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.4),
                  ),

                  const Spacer(),

                  // Option 1 : Bouton principal QR Code
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PairingScanScreen()),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                      label: const Text(
                        'Scanner le QR Code sur la caisse',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Option 2 : Saisie manuelle
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showManualEntryDialog(context),
                      icon: const Icon(Icons.keyboard_outlined, size: 20, color: AppColors.onSurface),
                      label: const Text(
                        'Lier avec un code manuel ou IP',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Option 3 : Mode Démo Immédiat
                  TextButton.icon(
                    onPressed: () => _startInstantDemo(context, ref),
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 18),
                    label: const Text(
                      'Visiter l\'application en Mode Démo (1 clic)',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bas de page : Note de sécurité
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_rounded, size: 14, color: AppColors.onSurfaceVariant),
                      SizedBox(width: 6),
                      Text(
                        'Chiffrement local AES-256 • Protégé par code PIN',
                        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
