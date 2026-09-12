import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_contacts.dart';
import '../../../core/license/license_model.dart';
import '../../../core/license/license_provider.dart';
import '../../../core/services/hardware_id_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/url_launcher_helper.dart';

/// Carte et dialogue officiel pour contacter le développeur et commander une licence N'MaShop.
class DeveloperContactCard extends StatefulWidget {
  const DeveloperContactCard({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<DeveloperContactCard> createState() => _DeveloperContactCardState();
}

class _DeveloperContactCardState extends State<DeveloperContactCard> {
  String? _hardwareId;

  @override
  void initState() {
    super.initState();
    HardwareIdService.getHardwareId().then((id) {
      if (mounted) {
        setState(() => _hardwareId = id);
      }
    });
  }

  Future<void> _openWhatsApp() async {
    final ref = _hardwareId ?? 'Non détecté';
    final url = AppContacts.getWhatsAppOrderUrl(referenceCode: ref);
    final ok = await UrlLauncherHelper.openUrl(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp automatiquement. Utilisez le numéro ci-dessous.')),
      );
    }
  }

  Future<void> _callPhone() async {
    await UrlLauncherHelper.openUrl('tel:${AppContacts.phoneRaw}');
  }

  Future<void> _sendEmail() async {
    final ref = _hardwareId ?? 'Non détecté';
    final url = 'mailto:${AppContacts.email}?subject=Demande%20de%20Licence%20NMaShop&body=Bonjour%20Hassimiou,%0D%0A%0D%0AJe%20souhaite%20commander%20une%20licence%20N\'MaShop%20pour%20ma%20boutique.%0D%0ARéférence%20machine%20:%20$ref';
    await UrlLauncherHelper.openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec badge d'assistance
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.contact_support_rounded, size: 20, color: AppColors.brandOrange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Besoin d\'une Licence Officielle ?',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Contactez directement le développeur pour activer votre logiciel :',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Coordonnées du développeur (Hassimiou Thioye)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    const Text(
                      AppContacts.developerName,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Concepteur',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    SelectableText(
                      AppContacts.phone,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: AppContacts.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Numéro copié !'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    SelectableText(
                      AppContacts.email,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Référence Machine (Hardware ID)
          if (_hardwareId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.computer_rounded, size: 15, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Réf. Machine : $_hardwareId',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _hardwareId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Référence machine copiée !'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 12, color: Color(0xFFB45309)),
                          SizedBox(width: 4),
                          Text('Copier', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          // Boutons d'action WhatsApp & Appel
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _callPhone,
                icon: const Icon(Icons.phone_rounded, size: 16),
                label: const Text('Appeler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _sendEmail,
                icon: const Icon(Icons.email_outlined, size: 16),
                label: const Text('Email'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              FilledButton.icon(
                onPressed: _openWhatsApp,
                icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                label: const Text('Commander sur WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Boîte de dialogue affichant l'activation directe de licence et les contacts du développeur
abstract final class DeveloperContactDialog {
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => const _LicenseActionDialogContent(),
    );
  }
}

class _LicenseActionDialogContent extends ConsumerStatefulWidget {
  const _LicenseActionDialogContent();

  @override
  ConsumerState<_LicenseActionDialogContent> createState() => _LicenseActionDialogContentState();
}

class _LicenseActionDialogContentState extends ConsumerState<_LicenseActionDialogContent> {
  final _keyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isActivating = false;
  String? _errorMsg;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _keyCtrl.text = data.text!.trim();
        _errorMsg = null;
      });
    }
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isActivating = true;
      _errorMsg = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final res = await ref.read(licenseProvider.notifier).activate(_keyCtrl.text.trim());

    if (res.result == LicenseActivationResult.success) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 Félicitations ! Votre licence a été activée avec succès.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isActivating = false;
          if (res.result == LicenseActivationResult.expiredKey) {
            _errorMsg = 'Cette clé de licence est expirée.';
          } else if (res.result == LicenseActivationResult.deviceMismatch) {
            _errorMsg = 'Cette clé est dédiée à un autre ordinateur.';
          } else {
            _errorMsg = 'Clé de licence invalide ou format incorrect.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseInfoProvider);
    final isGracePeriod = license.isGracePeriod;
    final isStrictlyLicensed = license.isStrictlyLicensed;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── En-tête de la boîte de dialogue ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isGracePeriod
                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                          : isStrictlyLicensed
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : AppColors.brandOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGracePeriod
                          ? Icons.warning_amber_rounded
                          : isStrictlyLicensed
                              ? Icons.verified_rounded
                              : Icons.vpn_key_rounded,
                      size: 20,
                      color: isGracePeriod
                          ? const Color(0xFFEF4444)
                          : isStrictlyLicensed
                              ? const Color(0xFF10B981)
                              : AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Licence & Activation N\'MaShop',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          license.statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isGracePeriod
                                ? const Color(0xFFDC2626)
                                : isStrictlyLicensed
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Section 1 : Activer une clé (priorité n°1) ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.key_rounded, size: 16, color: AppColors.brandOrange),
                          const SizedBox(width: 6),
                          const Text(
                            'Activer une clé de licence',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste_rounded, size: 14),
                            label: const Text('Coller', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _keyCtrl,
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'NMAS-XXXX-XXXX...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Veuillez saisir votre clé de licence';
                          final parts = v.trim().split('-');
                          if (parts.isEmpty || parts[0] != 'NMAS' || (parts.length != 3 && parts.length != 4)) {
                            return 'Format invalide (ex: NMAS-XXXXXXXX-XXXXXXXX)';
                          }
                          return null;
                        },
                      ),
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMsg!,
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _isActivating ? null : _activate,
                        icon: _isActivating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: Text(_isActivating ? 'Vérification...' : 'Valider & Activer la licence'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Séparateur & Coordonnées du développeur ──
              const DeveloperContactCard(compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
