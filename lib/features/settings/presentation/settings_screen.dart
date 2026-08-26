import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_model.dart';
import '../../../core/license/license_provider.dart';
import '../../../core/providers/app_settings_provider.dart';
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
import 'package:intl/intl.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/widgets/auth_layout.dart' show kMinPasswordLength, PasswordStrengthIndicator;
import '../../../core/database/tables/users.dart';
import '../../onboarding/presentation/setup_screen.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/export_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoPath = pickedFile.path;
      });
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
          gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
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
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: context.colors.primaryContainer,
                  backgroundImage: _logoPath != null
                      ? FileImage(File(_logoPath!))
                      : null,
                  child: _logoPath == null
                      ? Icon(
                          Icons.storefront_outlined,
                          size: 30,
                          color: context.colors.primary,
                        )
                      : null,
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
              Divider(color: context.colors.outlineVariant),
              const SizedBox(height: AppSpacing.xs),
              _buildSecurityItem(
                Icons.delete_forever,
                'Réinitialiser la configuration (Test)',
                trailing: AppButton.secondary(
                  label: 'Réinitialiser',
                  onPressed: _confirmReset,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Réinitialise la configuration : la boutique et les comptes repartent à
  /// zéro, mais les ventes et le stock déjà saisis sont conservés.
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppFormDialog(
        title: 'Réinitialiser la configuration ?',
        subtitle: 'La fiche boutique et TOUS les comptes utilisateurs seront supprimés, et vous repasserez par l\'écran de bienvenue.\n\nVos ventes, produits et écritures comptables sont conservés.',
        icon: Icons.warning_amber_rounded,
        gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
        width: 450,
        primaryLabel: 'Réinitialiser',
        primaryIcon: Icons.delete_forever,
        onCancel: () => Navigator.pop(dialogContext, false),
        onPrimary: () => Navigator.pop(dialogContext, true),
        body: const SizedBox.shrink(),
      ),
    );
    if (!(confirmed ?? false)) return;

    // Les comptes d'abord : le routeur ne doit pas basculer sur l'écran de
    // connexion avec une base de comptes encore pleine.
    await ref.read(authProvider.notifier).deleteAccount();
    await ref.read(appSettingsProvider.notifier).resetSetup();
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

  /// Choix du template visuel : réservé aux utilisateurs avec licence.
  Widget _buildAppearanceTab() {
    final selected = ref.watch(paletteProvider);
    final settings = ref.watch(appSettingsProvider);
    final license = ref.watch(licenseProvider);
    
    final bool hasLicense = license.isLicensed;
    final bool useCustom = settings.useCustomTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
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
                      'Apparence de la boutique',
                      style: AppTypography.labelMd.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "Personnalisez les couleurs de votre espace de travail.",
                      style: AppTypography.bodySm.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
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
            
            // Toggle Theme Personnalisé (seulement si licence)
            if (hasLicense) ...[
              Container(
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.outlineVariant),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Utiliser un thème personnalisé',
                    style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Remplace la charte graphique bleue et orange par défaut de N\'MaShop.',
                    style: AppTypography.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  value: useCustom,
                  onChanged: (value) {
                    ref.read(appSettingsProvider.notifier).updateUseCustomTheme(value);
                  },
                  activeThumbColor: context.colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            if (!hasLicense)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'La personnalisation du thème est réservée aux utilisateurs disposant d\'une licence active. Actuellement, vous utilisez le thème N\'MaShop par défaut.',
                        style: const TextStyle(color: Color(0xFFB45309), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Sélecteur de palettes (actif uniquement si licence + useCustom)
            Opacity(
              opacity: (hasLicense && useCustom) ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !(hasLicense && useCustom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Palettes disponibles',
                      style: AppTypography.labelSm.copyWith(color: context.colors.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PalettePicker(
                      selected: selected,
                      onSelected: (palette) {
                        ref.read(appSettingsProvider.notifier).updateSettings(paletteId: palette.id);
                      },
                    ),
                  ],
                ),
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: context.colors.primaryFixed,
                  foregroundColor: context.colors.primary,
                  child: Text(
                    user?.initials ?? '?',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
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
                        isTrial 
                            ? 'L\'application sera bloquée à la fin de l\'essai.' 
                            : 'Votre licence est active et valide.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isTrial ? const Color(0xFFB45309) : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isTrial)
                  AppButton(
                    label: 'Activer',
                    onPressed: () => context.go('/licence'),
                  ),
              ],
            ),
          ),
        ],
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
            gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
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

    final nameCtrl = TextEditingController(text: user.fullName);
    final formKey = GlobalKey<FormState>();

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppFormDialog(
        title: 'Éditer le profil',
        subtitle: 'Modifiez vos informations personnelles',
        icon: Icons.person_outline,
        gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        width: 400,
        primaryLabel: 'Enregistrer',
        primaryIcon: Icons.save_outlined,
        onCancel: () => Navigator.pop(dialogContext, false),
        onPrimary: () async {
          if (!formKey.currentState!.validate()) return;
          final errorColor = Theme.of(context).colorScheme.error;
          try {
            await ref
                .read(authProvider.notifier)
                .updateName(nameCtrl.text);
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          } catch (e) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  backgroundColor: errorColor,
                  content: Text('Erreur: $e'),
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
                label: 'Nom complet',
                controller: nameCtrl,
                icon: Icons.person_outline,
                isRequired: true,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Champ requis' : null,
              ),
            ],
          ),
        ),
      ),
    );

    nameCtrl.dispose();

    if ((changed ?? false) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.colors.primary,
          content: Text('Profil mis à jour.'),
        ),
      );
    }
  }
}


