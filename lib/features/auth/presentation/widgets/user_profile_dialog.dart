import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_image_picker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/database/tables/users.dart';
import '../../application/auth_providers.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_layout.dart' show kMinPasswordLength, PasswordStrengthIndicator;

/// Fenêtre modale de gestion du profil de l'utilisateur connecté.
class UserProfileDialog extends ConsumerStatefulWidget {
  const UserProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const UserProfileDialog(),
    );
  }

  @override
  ConsumerState<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends ConsumerState<UserProfileDialog> {
  final _nameFormKey = GlobalKey<FormState>();
  final _pwdFormKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  final TextEditingController _currentPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();

  bool _isSavingName = false;
  bool _isSavingPwd = false;
  bool _showChangePassword = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.fullName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarImage() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    try {
      final savedPath = await AppImagePicker.pickAvatarImage(user.id);
      if (savedPath != null && mounted) {
        await ref.read(authProvider.notifier).updateAvatar(savedPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📸 Photo de profil mise à jour avec succès !'),
              backgroundColor: AppColors.brandEmerald,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'enregistrement de la photo : $e'),
            backgroundColor: AppColors.brandRed,
          ),
        );
      }
    }
  }

  Future<void> _removeAvatarImage() async {
    try {
      await ref.read(authProvider.notifier).updateAvatar(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo de profil supprimée.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.brandRed,
          ),
        );
      }
    }
  }

  Future<void> _updateName() async {
    if (!_nameFormKey.currentState!.validate()) return;
    setState(() => _isSavingName = true);

    try {
      await ref.read(authProvider.notifier).updateName(_nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nom de profil mis à jour avec succès'),
            backgroundColor: AppColors.brandEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.brandRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_pwdFormKey.currentState!.validate()) return;
    setState(() => _isSavingPwd = true);

    try {
      await ref.read(authProvider.notifier).changePassword(
            currentPassword: _currentPwdController.text,
            newPassword: _newPwdController.text,
          );
      _currentPwdController.clear();
      _newPwdController.clear();
      _confirmPwdController.clear();
      setState(() => _showChangePassword = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Mot de passe modifié avec succès'),
            backgroundColor: AppColors.brandEmerald,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.brandRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPwd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    if (user == null) {
      return const SizedBox.shrink();
    }

    final isAdmin = user.role == UserRole.admin;
    final createdDateStr = DateFormat('d MMMM yyyy', 'fr').format(user.createdAt);
    final lastLoginStr = user.lastLoginAt != null
        ? DateFormat('d MMM yyyy à HH:mm', 'fr').format(user.lastLoginAt!)
        : 'Première connexion';
    final hasAvatar = user.avatarPath != null && user.avatarPath!.isNotEmpty && File(user.avatarPath!).existsSync();

    return AppFormDialog(
      title: 'Profil Utilisateur',
      subtitle: 'Informations personnelles & Sécurité de compte',
      icon: Icons.person_outline_rounded,
      gradientColors: const [Color(0xFF0F1B3D), Color(0xFF1A2B52)],
      width: 520,
      primaryLabel: 'Fermer',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: () => Navigator.pop(context),
      onCancel: () => Navigator.pop(context),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête avec avatar éditable & carte récapitulative
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.outlineVariant),
            ),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Changer la photo de profil',
                      child: InkWell(
                        onTap: _pickAvatarImage,
                        borderRadius: BorderRadius.circular(32),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            UserAvatar(
                              user: user,
                              size: 64,
                              backgroundColor: AppColors.brandNavy,
                              foregroundColor: Colors.white,
                              fontSize: 20,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasAvatar) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _removeAvatarImage,
                        child: const Text(
                          'Supprimer photo',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.brandRed,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.fullName,
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppChip(
                            label: isAdmin ? 'ADMINISTRATEUR' : 'VENDEUR',
                            status: isAdmin ? AppChipStatus.success : AppChipStatus.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Compte créé le $createdDateStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Dernière connexion : $lastLoginStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Formulaire de modification du Nom
          Form(
            key: _nameFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INFORMATIONS DE PROFIL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        label: 'Nom complet',
                        controller: _nameController,
                        icon: Icons.person_outline,
                        hint: 'Entrez votre nom et prénom',
                        isRequired: true,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: FilledButton.icon(
                        onPressed: _isSavingName ? null : _updateName,
                        icon: _isSavingName
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 18),
                        label: const Text('Enregistrer'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),

          // Section Mot de passe (Toggle / Expand)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 20, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Sécurité & Mot de Passe',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.colors.onSurface,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _showChangePassword = !_showChangePassword);
                },
                icon: Icon(
                  _showChangePassword ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                label: Text(_showChangePassword ? 'Masquer' : 'Changer le mot de passe'),
              ),
            ],
          ),

          if (_showChangePassword) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: Form(
                key: _pwdFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppFormField(
                      label: 'Mot de passe actuel',
                      controller: _currentPwdController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      isRequired: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      label: 'Nouveau mot de passe',
                      controller: _newPwdController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      isRequired: true,
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || v.length < kMinPasswordLength)
                          ? '$kMinPasswordLength caractères minimum'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    PasswordStrengthIndicator(password: _newPwdController.text),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      label: 'Confirmer le nouveau mot de passe',
                      controller: _confirmPwdController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      isRequired: true,
                      validator: (v) => v != _newPwdController.text ? 'Ne correspond pas' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _isSavingPwd ? null : _changePassword,
                        icon: _isSavingPwd
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.shield_outlined, size: 18),
                        label: const Text('Mettre à jour le mot de passe'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),

          // Actions du bas : Réglages & Déconnexion
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/reglages');
                },
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Paramètres Boutique'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref.read(authProvider.notifier).lock();
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.brandRed),
                label: const Text('Se déconnecter', style: TextStyle(color: AppColors.brandRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.brandRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
