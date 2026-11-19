import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nma_mobile_header.dart';
import '../license_model.dart';
import '../license_provider.dart';

class PosLockedActivationScreen extends ConsumerStatefulWidget {
  const PosLockedActivationScreen({super.key});

  @override
  ConsumerState<PosLockedActivationScreen> createState() => _PosLockedActivationScreenState();
}

class _PosLockedActivationScreenState extends ConsumerState<PosLockedActivationScreen> {
  final _keyController = TextEditingController();
  bool _isActivating = false;
  String? _errorMessage;
  bool _copied = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _copyDeviceId(String deviceId) {
    Clipboard.setData(ClipboardData(text: deviceId));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Identifiant Machine copié dans le presse-papier !'),
        backgroundColor: AppColors.brandEmerald,
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _contactWhatsApp(String deviceId) async {
    final message = "Bonjour Support N'MaShop, ma période d'essai est terminée. Je souhaite acheter une licence d'activation pour débloquer ma caisse POS.\n"
        "• Machine/Device ID : $deviceId";
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(res.message ?? 'Caisse POS déverrouillée avec succès !')),
            ],
          ),
          backgroundColor: AppColors.brandEmerald,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _isActivating = false;
        _errorMessage = res.message ?? 'Clé invalide.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseInfoProvider);
    final deviceId = license.deviceId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const NmaMobileAppBar(
        title: 'Caisse POS Verrouillée',
        subtitle: 'Licence requise pour continuer',
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge de verrouillage animé
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.lock_rounded, color: Colors.white, size: 42),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Période d\'Essai Terminée',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandNavy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              const Text(
                'Vos 14 jours d\'essai gratuit sont arrivés à expiration. Pour continuer à enregistrer vos ventes, imprimer des tickets de caisse et gérer vos stocks, activez votre licence N\'MaShop.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Carte Machine ID
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identifiant de votre Smartphone :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone_android_rounded, size: 20, color: AppColors.brandOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            deviceId,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.8),
                          ),
                        ),
                        IconButton(
                          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 20),
                          color: _copied ? AppColors.brandEmerald : AppColors.brandOrange,
                          tooltip: 'Copier l\'identifiant',
                          onPressed: () => _copyDeviceId(deviceId),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // WhatsApp Support
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text(
                          'Acheter ma licence via WhatsApp',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _contactWhatsApp(deviceId),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Saisie de clé
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Saisir votre clé d\'activation :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _keyController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'NMAS-XXXX-YYYYMMDD-XXXX',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isActivating ? null : _submitActivation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isActivating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text(
                              'Déverrouiller ma Caisse POS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
