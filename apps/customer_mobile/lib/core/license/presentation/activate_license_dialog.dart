import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../license_model.dart';
import '../license_provider.dart';

class ActivateLicenseDialog extends ConsumerStatefulWidget {
  final String deviceId;
  final String shopName;

  const ActivateLicenseDialog({
    super.key,
    required this.deviceId,
    required this.shopName,
  });

  static Future<bool?> show(BuildContext context, {required String deviceId, required String shopName}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ActivateLicenseDialog(deviceId: deviceId, shopName: shopName),
    );
  }

  @override
  ConsumerState<ActivateLicenseDialog> createState() => _ActivateLicenseDialogState();
}

class _ActivateLicenseDialogState extends ConsumerState<ActivateLicenseDialog> {
  final _keyController = TextEditingController();
  bool _isActivating = false;
  String? _errorMessage;
  bool _copied = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _copyDeviceId() {
    Clipboard.setData(ClipboardData(text: widget.deviceId));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Identifiant de l\'appareil copié dans le presse-papier !'),
        backgroundColor: AppColors.brandEmerald,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _contactWhatsApp() async {
    final message = "Bonjour N'MaShop, je souhaite acheter ou renouveler ma licence d'activation :\n"
        "• Boutique : ${widget.shopName}\n"
        "• Machine/Device ID : ${widget.deviceId}";
    final uri = Uri.parse('whatsapp://send?phone=224624193069&text=${Uri.encodeComponent(message)}');
    final fallbackUri = Uri.parse('https://wa.me/224624193069?text=${Uri.encodeComponent(message)}');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitActivation() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir votre clé de licence.');
      return;
    }

    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    final res = await ref.read(licenseProvider.notifier).activateKey(key);

    if (!mounted) return;

    if (res.success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(res.message ?? 'Licence activée avec succès !')),
            ],
          ),
          backgroundColor: AppColors.brandEmerald,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _isActivating = false;
        _errorMessage = res.message ?? 'Clé de licence invalide.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseInfoProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: AppColors.heroNavyGradient,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppColors.brandOrange, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activer ma Licence',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Déverrouillage N\'MaShop POS',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut actuel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: license.isPosUnlocked ? AppColors.successContainer : AppColors.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    license.isPosUnlocked ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                    size: 16,
                    color: license.isPosUnlocked ? AppColors.brandEmerald : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      license.bannerText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: license.isPosUnlocked ? AppColors.brandEmerald : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Étape 1 : Machine / Device ID
            const Text(
              '1. Votre Identifiant Unique (Machine ID) :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.brandNavy),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      widget.deviceId,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
                    color: _copied ? AppColors.brandEmerald : AppColors.brandOrange,
                    tooltip: 'Copier l\'identifiant',
                    onPressed: _copyDeviceId,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Étape 2 : Acheter / Renouveler via WhatsApp
            const Text(
              '2. Contacter l\'équipe pour obtenir une clé :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.brandNavy),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('Commander ma clé via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                onPressed: _contactWhatsApp,
              ),
            ),
            const SizedBox(height: 16),

            // Étape 3 : Saisir la clé
            const Text(
              '3. Entrez votre clé d\'activation officielle :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.brandNavy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _keyController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Ex: NMAS-XXXX-20270520-XXXXXXXX',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        ElevatedButton(
          onPressed: _isActivating ? null : _submitActivation,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          ),
          child: _isActivating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Activer ma Licence', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
