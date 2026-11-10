import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/license/mobile_license_model.dart';
import '../../../core/license/mobile_license_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../shell/main_navigation_shell.dart';

/// Écran de verrouillage et d'activation de licence sur smartphone.
class MobileLicenseGateScreen extends ConsumerStatefulWidget {
  final bool isModal;

  const MobileLicenseGateScreen({super.key, this.isModal = false});

  @override
  ConsumerState<MobileLicenseGateScreen> createState() => _MobileLicenseGateScreenState();
}

class _MobileLicenseGateScreenState extends ConsumerState<MobileLicenseGateScreen> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _keyController.text = data.text!.trim().toUpperCase();
        _errorMessage = null;
      });
    }
  }

  Future<void> _sendWhatsAppRequest() async {
    const adminPhone = '224624193069';
    const message = '''
Bonjour Hassimiou Thioye,

Je souhaite activer la licence de mon application N'MaShop Mobile pour ma boutique.

Merci de m'indiquer la marche à suivre pour obtenir ma clé d'activation.
''';

    final uri = Uri.parse('https://wa.me/$adminPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contactez le support officiel N\'MaShop au +224 624 19 30 69.')),
        );
      }
    }
  }

  Future<void> _activate() async {
    final rawKey = _keyController.text.trim();
    if (rawKey.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir ou coller votre clé de licence.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(mobileLicenseProvider.notifier).activate(rawKey);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Licence activée avec succès ! Bienvenue sur N\'MaShop.'),
          backgroundColor: AppColors.brandEmerald,
          duration: Duration(seconds: 3),
        ),
      );

      if (widget.isModal) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationShell()),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Clé de licence invalide.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final licenseAsync = ref.watch(mobileLicenseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isModal
          ? AppBar(
              title: const Text('Gestion de la Licence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: licenseAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, _) => Center(child: Text('Erreur : $err')),
            data: (license) {
              final isExpired = license.isExpired;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Center(child: BrandLogo(height: 48, showCard: false)),
                  const SizedBox(height: 20),

                  // Carte d'état de la licence
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: isExpired
                          ? const LinearGradient(
                              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : AppColors.heroNavyGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (isExpired ? Colors.red : AppColors.brandNavy).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isExpired ? Icons.lock_clock_rounded : Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isExpired
                              ? 'Période d\'essai terminée'
                              : (license.isInGracePeriod ? 'Période de Grâce (5 jours)' : 'Licence Boutique'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isExpired
                              ? 'Pour continuer à utiliser N\'MaShop et enregistrer vos ventes, activez votre clé officielle.'
                              : (license.status == MobileLicenseStatus.trial
                                  ? 'Il vous reste ${license.daysLeft} jour(s) d\'essai gratuit.'
                                  : 'Statut : ${license.statusLabel}'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bloc de Saisie de Clé Officielle
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.vpn_key_rounded, size: 18, color: AppColors.brandOrange),
                            SizedBox(width: 8),
                            Text(
                              'Entrez votre Clé d\'Activation',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.brandNavy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Collez la clé de licence reçue du développeur (format NMAS-...) :',
                          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _keyController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          decoration: InputDecoration(
                            hintText: 'NMAS-YYYYMMDD-XXXXXXXX',
                            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted, letterSpacing: 0.5),
                            prefixIcon: const Icon(Icons.key_rounded, color: AppColors.brandOrange),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.paste_rounded, color: AppColors.brandNavy),
                              tooltip: 'Coller',
                              onPressed: _pasteFromClipboard,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _activate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Valider et Débloquer ma Boutique', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bloc Assistance & Contact Support (Pas besoin d'envoyer quoi que ce soit)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.headset_mic_rounded, size: 18, color: AppColors.brandNavy),
                            SizedBox(width: 8),
                            Text(
                              'Besoin d\'une clé d\'activation ?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.brandNavy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Contactez directement l\'administrateur N\'MaShop. Vous n\'avez rien à copier ni envoyer : donnez simplement le nom de votre boutique pour recevoir votre clé.',
                          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _sendWhatsAppRequest,
                            icon: const Icon(Icons.chat_rounded, size: 18, color: Colors.white),
                            label: const Text('Contacter sur WhatsApp (+224 624 19 30 69)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

