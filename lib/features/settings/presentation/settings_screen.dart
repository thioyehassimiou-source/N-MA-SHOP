import 'package:flutter/material.dart';
import '../../../core/utils/app_image_picker.dart';
import '../../../core/widgets/app_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_model.dart';
import '../../../core/license/license_provider.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/palette_picker.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/services/update_service.dart';
import 'package:intl/intl.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/widgets/user_profile_dialog.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/widgets/auth_layout.dart' show kMinPasswordLength, PasswordStrengthIndicator;
import '../../../core/database/tables/users.dart';
import '../../onboarding/presentation/setup_screen.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/export_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _nifController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  String? _selectedDomain;
  String? _logoPath;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _nameController = TextEditingController(text: settings.businessName);
    _nifController = TextEditingController(text: settings.businessNif);
    _emailController = TextEditingController(text: settings.businessEmail);
    _addressController = TextEditingController(text: settings.businessAddress);
    _phoneController = TextEditingController(text: settings.businessPhone);
    _selectedDomain = kDomaines.contains(settings.businessDomain)
        ? settings.businessDomain
        : null;
    _logoPath = settings.logoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nifController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final savedPath = await AppImagePicker.pickLogoImage();
      if (savedPath != null && mounted) {
        setState(() {
          _logoPath = savedPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur sélection logo: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(appSettingsProvider.notifier)
          .updateSettings(
            businessName: _nameController.text.trim(),
            businessNif: _nifController.text.trim(),
            businessEmail: _emailController.text.trim(),
            businessAddress: _addressController.text.trim(),
            businessPhone: _phoneController.text.trim(),
            currency: kDeviseCode,
            logoPath: _logoPath,
            businessDomain: _selectedDomain,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil enregistré avec succès'),
            backgroundColor: context.colors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.containerMax,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderWithTabs(),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBusinessProfileTab(),
                        _buildAppearanceTab(),
                        _buildSecurityTab(),
                        _buildUserManagement(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderWithTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPageHeader(
          title: 'Paramètres',
          subtitle: 'Configurez votre boutique',
          icon: Icons.settings_outlined,
          gradientColors: const [AppColors.brandNavy, AppColors.brandNavyLight],
        ),
        TabBar(
          tabs: const [
            Tab(text: 'Profil'),
            Tab(text: 'Apparence'),
            Tab(text: 'Sécurité'),
            Tab(text: 'Compte'),
          ],
          indicatorColor: context.colors.primary,
          labelColor: context.colors.primary,
          unselectedLabelColor: context.colors.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _buildBusinessProfile() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profil de l\'entreprise',
                    style: AppTypography.labelMd.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Gérez vos informations publiques et de facturation.',
                    style: AppTypography.bodySm.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              AppButton(
                label: _isSaving ? 'Enregistrement...' : 'Enregistrer',
                onPressed: _isSaving ? null : _saveProfile,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickLogo,
                child: ClipOval(
                  child: AppImage(
                    imagePath: _logoPath,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.storefront_outlined,
                    fallbackColor: context.colors.primary,
                    enableZoomOnTap: false,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildTextField('Nom de l\'entreprise', _nameController),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: "Domaine d'activité",
                  value: _selectedDomain,
                  items: kDomaines,
                  onChanged: (v) => setState(() => _selectedDomain = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _buildTextField('NIF', _nifController)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildTextField('Adresse E-mail', _emailController),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'Adresse de l\'entreprise',
                  _addressController,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildTextField(
                  'Téléphone du commerce',
                  _phoneController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
          hint: const Text('Non renseigné'),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
        ),
      ],
    );
  }

  Widget _buildRightSidebar() {
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outils & Sécurité',
                style: AppTypography.labelMd.copyWith(
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildSecurityItem(
                Icons.save_alt,
                'Sauvegarde Locale (Base de données)',
                trailing: AppButton.secondary(
                  label: 'Sauvegarder',
                  onPressed: () async {
                    final success = await ExportService.backupDatabase();
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Sauvegarde réussie'), backgroundColor: context.colors.primary),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.restore_page_rounded,
                'Restauration de la base de données',
                trailing: AppButton.secondary(
                  label: 'Restaurer',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AppFormDialog(
                        title: 'Restaurer une sauvegarde ?',
                        subtitle: 'Cette action remplacera l\'intégralité des données actuelles par le fichier de sauvegarde sélectionné.\n\nL\'application réactualisera ensuite votre tableau de bord.',
                        icon: Icons.warning_amber_rounded,
                        gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                        width: 480,
                        primaryLabel: 'Sélectionner & Restaurer',
                        primaryIcon: Icons.restore_rounded,
                        onCancel: () => Navigator.pop(dialogContext, false),
                        onPrimary: () => Navigator.pop(dialogContext, true),
                        body: const SizedBox.shrink(),
                      ),
                    );
                    if (!(confirmed ?? false)) return;

                    final success = await ExportService.restoreDatabase();
                    if (mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Restauration réussie ! Redirection vers le tableau de bord...'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        context.go('/');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Restauration annulée ou échouée.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.file_download,
                'Exporter les ventes (CSV)',
                trailing: AppButton.secondary(
                  label: 'Exporter',
                  onPressed: () async {
                    final db = ref.read(databaseProvider);
                    final success = await ExportService.exportSalesToCsv(db);
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Export réussi'), backgroundColor: context.colors.primary),
                      );
                    }
                  },
                ),
              ),
              Divider(color: context.colors.outlineVariant),
              _buildSecurityItem(
                Icons.auto_stories_outlined,
                'Revoir la présentation (Onboarding)',
                trailing: AppButton.secondary(
                  label: 'Revoir',
                  onPressed: () => context.go('/onboarding'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.tune_rounded,
                'Assistant de configuration boutique',
                trailing: AppButton.secondary(
                  label: 'Lancer',
                  onPressed: () => context.go('/setup'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.restart_alt_rounded,
                'Réinitialiser comme 1ère installation (Tester le wizard)',
                trailing: AppButton.secondary(
                  label: 'Réinitialiser',
                  onPressed: _resetFullInstallation,
                ),
              ),
              Divider(color: context.colors.outlineVariant),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.history,
                'Journal d\'activité (Audit Logs)',
                trailing: AppButton.secondary(
                  label: 'Consulter',
                  onPressed: () => context.go('/settings/audit'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.lock_reset,
                'Changer le mot de passe',
                trailing: AppButton.secondary(
                  label: 'Changer',
                  onPressed: () => _changePassword(),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.delete_sweep_rounded,
                'Vider les données de la boutique (Produits, Ventes & Stock)',
                trailing: AppButton.secondary(
                  label: 'Purger les données',
                  onPressed: _clearAppData,
                ),
              ),
              Divider(color: context.colors.outlineVariant),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.system_update_rounded,
                'Vérifier les mises à jour (v${UpdateService.currentVersion})',
                trailing: AppButton.secondary(
                  label: 'Vérifier',
                  onPressed: _checkAppUpdate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Purge l'ensemble des données de vente et de stock de la boutique.
  Future<void> _clearAppData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppFormDialog(
        title: 'Vider les données de la boutique ?',
        subtitle:
            'Cette action va effacer les données de vente et de stock : tous les produits, ventes, créances, dépenses et historiques de caisse seront supprimés.\n\nVotre compte administrateur et votre licence restent conservés.',
        icon: Icons.delete_sweep_rounded,
        gradientColors: const [Color(0xFFDC2626), AppColors.error],
        width: 480,
        primaryLabel: 'Purger les données',
        primaryIcon: Icons.delete_forever_rounded,
        onCancel: () => Navigator.pop(dialogContext, false),
        onPrimary: () => Navigator.pop(dialogContext, true),
        body: const SizedBox.shrink(),
      ),
    );
    if (!(confirmed ?? false)) return;

    final db = ref.read(databaseProvider);
    await db.purgeAllData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🧹 Données métier purifiées avec succès.'),
          backgroundColor: context.colors.primary,
        ),
      );
    }
  }

  /// Remet l'application à zéro comme au tout premier démarrage après l'installation sur Windows.
  Future<void> _resetFullInstallation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppFormDialog(
        title: 'Réinitialiser comme au premier démarrage ?',
        subtitle:
            'Cette action réinitialisera l\'application N\'MaShop comme si elle venait d\'être installée sur un nouvel ordinateur Windows :\n\n'
            '• La licence sera réinitialisée en mode essai (15 jours)\n'
            '• Toutes les données métier et comptes seront purgés\n'
            '• L\'assistant de configuration initiale sera relancé.',
        icon: Icons.restart_alt_rounded,
        gradientColors: const [Color(0xFFEA580C), Color(0xFFC2410C)],
        width: 500,
        primaryLabel: 'Réinitialiser & Démarrer Assistant',
        primaryIcon: Icons.rocket_launch_rounded,
        onCancel: () => Navigator.pop(dialogContext, false),
        onPrimary: () => Navigator.pop(dialogContext, true),
        body: const SizedBox.shrink(),
      ),
    );
    if (!(confirmed ?? false)) return;

    final db = ref.read(databaseProvider);
    await db.purgeAllData();
    await ref.read(authProvider.notifier).lock();
    ref.read(accountExistsProvider.notifier).set(false);
    await ref.read(appSettingsProvider.notifier).resetSetup();

    if (mounted) {
      context.go('/onboarding');
    }
  }

  /// Vérifie si une nouvelle mise à jour de N'MaShop est disponible sans bloquer l'application.
  Future<void> _checkAppUpdate() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final info = await UpdateService.checkForUpdates();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      showDialog(
        context: context,
        builder: (dialogContext) => AppFormDialog(
          title: 'Mise à jour N\'MaShop',
          subtitle: 'Version installée : v${info.currentVersion} (Build ${info.buildNumber})\n'
              'Date de publication : ${UpdateService.releaseDate}\n\n'
              '${info.hasUpdate ? "🎉 Une nouvelle version (v${info.latestVersion}) est disponible !" : "✅ Votre application est parfaitement à jour !"}\n\n'
              '${info.releaseNotes}',
          icon: Icons.system_update_rounded,
          gradientColors: const [AppColors.brandOrange, AppColors.brandOrangeLight],
          width: 500,
          primaryLabel: info.hasUpdate ? 'Télécharger' : 'D\'accord',
          primaryIcon: info.hasUpdate ? Icons.download_rounded : Icons.check_circle_outline,
          onCancel: () => Navigator.pop(dialogContext),
          onPrimary: () async {
            Navigator.pop(dialogContext);
            if (info.hasUpdate) {
              final uri = Uri.parse(info.downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          body: const SizedBox.shrink(),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vérification terminée : vous utilisez la dernière version (v${UpdateService.currentVersion}).'),
            backgroundColor: context.colors.primary,
          ),
        );
      }
    }
  }

  Widget _buildSecurityItem(
    IconData icon,
    String title, {
    required Widget trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, color: context.colors.onSurfaceVariant, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(title, style: AppTypography.bodySm)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
        ),
    );
  }

  /// Section d'Apparence : sélection directe de templates visuels prédéfinis prêts à l'emploi.
  Widget _buildAppearanceTab() {
    final selected = ref.watch(paletteProvider);
    final license = ref.watch(licenseProvider);
    final currentThemeMode = ref.watch(themeProvider);
    final bool hasLicense = license.isLicensed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Carte 1 : Templates Visuels Prédéfinis ──
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected.seed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.style_rounded, color: selected.seed, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Templates Visuels Prédéfinis',
                              style: AppTypography.labelMd.copyWith(
                                color: context.colors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Choisissez un thème graphique prêt à l\'emploi adapté à votre secteur.',
                              style: AppTypography.bodySm.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!hasLicense)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_rounded, size: 14, color: context.colors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: context.colors.onSurfaceVariant,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Bannière indiquant le template actif
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: selected.seed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected.seed.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: selected.seed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: selected.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Template Actif : ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            children: [
                              TextSpan(
                                text: '${selected.label} (${selected.trade})',
                                style: TextStyle(color: selected.seed, fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(
                                text: ' — Appliqué sur l\'ensemble de l\'application.',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                if (!hasLicense)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warningContainer),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: AppColors.warning),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Les templates personnalisés sont disponibles pour les abonnés licenciés. Vous utilisez actuellement le template officiel N\'MaShop.',
                            style: TextStyle(color: AppColors.onWarningContainer, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Galerie de choix direct des templates visuels
                Opacity(
                  opacity: hasLicense ? 1.0 : 0.5,
                  child: IgnorePointer(
                    ignoring: !hasLicense,
                    child: PalettePicker(
                      selected: selected,
                      onSelected: (palette) {
                        ref.read(appSettingsProvider.notifier).updatePalette(palette.id);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Carte 2 : Mode d'Affichage (Clair / Sombre / Système) ──
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.contrast_rounded, color: AppColors.brandOrange, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode d\'Affichage',
                          style: AppTypography.labelMd.copyWith(
                            color: context.colors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ajustez le contraste lumineux selon vos conditions de travail.',
                          style: AppTypography.bodySm.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeModeTile(
                        title: 'Mode Clair',
                        subtitle: 'Journée & Caisse',
                        icon: Icons.light_mode_rounded,
                        mode: ThemeMode.light,
                        currentMode: currentThemeMode,
                        activeColor: AppColors.brandOrange,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildThemeModeTile(
                        title: 'Mode Sombre',
                        subtitle: 'Confort visuel nocturne',
                        icon: Icons.dark_mode_rounded,
                        mode: ThemeMode.dark,
                        currentMode: currentThemeMode,
                        activeColor: const Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildThemeModeTile(
                        title: 'Système',
                        subtitle: 'Automatique selon l\'OS',
                        icon: Icons.brightness_auto_rounded,
                        mode: ThemeMode.system,
                        currentMode: currentThemeMode,
                        activeColor: AppColors.brandNavy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required Color activeColor,
  }) {
    final isSelected = currentMode == mode;
    return InkWell(
      onTap: () => ref.read(themeProvider.notifier).setMode(mode),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : context.colors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? activeColor : context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? activeColor : context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compte unique du boutiquier : identité
  Widget _buildUserManagement() {
    final user = ref.watch(authProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compte & sécurité',
              style: AppTypography.labelMd.copyWith(color: context.colors.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Un seul compte administre la boutique.',
              style: AppTypography.bodySm.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                UserAvatar(
                  user: user,
                  size: 48,
                  fontSize: 16,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? 'Boutiquier', style: AppTypography.labelMd),
                      Text(
                        user?.lastLoginAt == null
                            ? 'Boutiquier'
                            : 'Dernière ouverture : ${DateFormat('d MMM y, HH:mm', 'fr').format(user!.lastLoginAt!)}',
                        style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppChip(
                        label: user?.role == UserRole.admin ? 'ADMIN' : 'VENDEUR',
                        status: user?.role == UserRole.admin ? AppChipStatus.success : AppChipStatus.warning,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton.secondary(icon: Icons.edit_rounded, label: 'Éditer Profil', onPressed: () => _editProfile(user)),
                    const SizedBox(width: AppSpacing.md),
                    AppButton.secondary(icon: Icons.logout_rounded, label: 'Se déconnecter', onPressed: () => ref.read(authProvider.notifier).lock()),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildBusinessProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _buildBusinessProfile(),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLicenseCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildRightSidebar(),
        ],
      ),
    );
  }

  Widget _buildLicenseCard() {
    final license = ref.watch(licenseProvider);
    final bool isTrial = license.status == LicenseStatus.trial;
    
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: context.colors.primary, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Licence d\'utilisation',
                style: AppTypography.labelMd.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isTrial ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTrial ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isTrial ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTrial ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                    color: isTrial ? const Color(0xFFD97706) : const Color(0xFF059669),
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        license.statusLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isTrial ? const Color(0xFFB45309) : const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        license.detailedDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: isTrial ? const Color(0xFFB45309) : const Color(0xFF047857),
                        ),
                      ),
                      if (license.maskedKey != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Clé active : ${license.maskedKey}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (!isTrial) ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Effacer la licence ?'),
                              content: const Text('Cela réinitialisera l\'application PC en mode essai gratuit de 7 jours.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Réinitialiser', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(licenseProvider.notifier).resetLicense();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Licence effacée — Mode essai réinitialisé !')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Effacer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    AppButton(
                      label: isTrial ? 'Activer' : 'Changer la clé',
                      onPressed: () => _showActivationDialog(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActivationDialog(BuildContext context) async {
    final keyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isActivating = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Activer la licence'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Collez ici la clé de licence que vous avez reçue :',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: keyCtrl,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'NMAS-...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isActivating
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isActivating = true;
                          errorMsg = null;
                        });

                        await Future.delayed(const Duration(milliseconds: 300));
                        if (!ctx.mounted) return;

                        final res = await ref.read(licenseProvider.notifier).activate(keyCtrl.text.trim());

                        if (res.result == LicenseActivationResult.success) {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('🎉 Licence activée avec succès !')),
                            );
                          }
                        } else {
                          setDialogState(() {
                            isActivating = false;
                            if (res.result == LicenseActivationResult.expiredKey) {
                              errorMsg = 'Cette clé est expirée.';
                            } else if (res.result == LicenseActivationResult.deviceMismatch) {
                              errorMsg = 'Cette clé est dédiée à un autre ordinateur !';
                            } else {
                              errorMsg = 'Clé invalide ou format incorrect.';
                            }
                          });
                        }
                      },
                child: isActivating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Activer'),
              ),
            ],
          );
        },
      ),
    );
  }


  /// Dialogue de changement du mot de passe (actuel + nouveau + confirmation).
  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AppFormDialog(
            title: 'Changer le mot de passe',
            subtitle: 'Mettez à jour vos informations de connexion',
            icon: Icons.lock_reset_rounded,
            gradientColors: const [AppColors.tertiary, Color(0xFF6D28D9)],
            width: 450,
            primaryLabel: 'Enregistrer',
            primaryIcon: Icons.save_outlined,
            onCancel: () => Navigator.pop(dialogContext, false),
            onPrimary: () async {
              if (!formKey.currentState!.validate()) return;
              final errorColor = Theme.of(context).colorScheme.error;
              try {
                await ref
                    .read(authProvider.notifier)
                    .changePassword(
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } on AuthException catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      backgroundColor: errorColor,
                      content: Text(e.message),
                    ),
                  );
                }
              }
            },
            body: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppFormField(
                    label: 'Mot de passe actuel',
                    controller: currentCtrl,
                    icon: Icons.lock_outline,
                    obscureText: true,
                    isRequired: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppFormField(
                    label: 'Nouveau mot de passe',
                    controller: newCtrl,
                    icon: Icons.lock_outline,
                    obscureText: true,
                    isRequired: true,
                    onChanged: (_) => setDialogState(() {}),
                    validator: (v) => (v == null || v.length < kMinPasswordLength)
                        ? '$kMinPasswordLength caractères minimum'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PasswordStrengthIndicator(password: newCtrl.text),
                  const SizedBox(height: AppSpacing.md),
                  AppFormField(
                    label: 'Confirmer',
                    controller: confirmCtrl,
                    icon: Icons.lock_outline,
                    obscureText: true,
                    isRequired: true,
                    validator: (v) =>
                        v != newCtrl.text ? 'Ne correspond pas' : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if ((changed ?? false) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.colors.primary,
          content: Text('Mot de passe modifié.'),
        ),
      );
    }
  }

  Future<void> _editProfile(AppUser? user) async {
    if (user == null) return;
    await UserProfileDialog.show(context);
  }
}


