import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/users.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../auth/application/auth_providers.dart';
import '../application/equipe_providers.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class EquipeScreen extends ConsumerWidget {
  const EquipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersListProvider);
    final currentUser = ref.watch(authProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: 'Équipe & Utilisateurs',
          subtitle: 'Gérez les accès à la plateforme N\'MaShop',
          icon: Icons.people_outline_rounded,
          gradientColors: const [Colors.indigo, Colors.blue],
          actions: [
            AppButton(
              label: 'Ajouter',
              icon: Icons.person_add_outlined,
              onPressed: () => _showAddUserDialog(context, ref),
            ),
          ],
        ),
        Expanded(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('Erreur: $err')),
            data: (users) {
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.xl),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isMe = user.id == currentUser?.id;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: user.isActive ? context.colors.primaryContainer : context.colors.surfaceContainerHighest,
                            child: Text(
                              user.initials,
                              style: TextStyle(
                                color: user.isActive ? context.colors.primary : context.colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: AppTypography.labelMd.copyWith(
                                        color: user.isActive ? null : context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      const AppChip(
                                        label: 'Moi',
                                        status: AppChipStatus.neutral,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    AppChip(
                                      label: user.role == UserRole.admin ? 'Administrateur' : 'Vendeur',
                                      status: user.role == UserRole.admin ? AppChipStatus.warning : AppChipStatus.success,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Text(
                                      'Créé le ${formatDate(user.createdAt)}',
                                      style: AppTypography.bodySm.copyWith(color: context.colors.onSurfaceVariant.withValues(alpha: 0.7)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: user.isActive,
                                onChanged: isMe
                                    ? null // Un utilisateur ne peut pas se désactiver lui-même
                                    : (val) {
                                        ref.read(equipeControllerProvider.notifier).toggleStatus(user.id, val);
                                      },
                              ),
                              if (user.lastLoginAt != null)
                                Text(
                                  'Dernière connexion: ${formatDateTime(user.lastLoginAt!)}',
                                  style: AppTypography.bodySm.copyWith(fontSize: 10, color: context.colors.onSurfaceVariant.withValues(alpha: 0.7)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddUserDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    UserRole selectedRole = UserRole.cashier;
    bool isLoading = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppFormDialog(
              title: 'Ajouter un utilisateur',
              subtitle: 'Créer un nouvel accès pour l\'équipe',
              icon: Icons.person_add_outlined,
              gradientColors: const [Color(0xFF0F1B3D), Color(0xFF1A2B52)],
              width: 450,
              primaryLabel: 'Créer',
              primaryIcon: Icons.check_circle_outline,
              isPrimaryLoading: isLoading,
              onCancel: isLoading ? null : () => Navigator.pop(ctx),
              onPrimary: isLoading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty || pwdCtrl.text.isEmpty) {
                        setState(() => error = 'Veuillez remplir tous les champs');
                        return;
                      }
                      setState(() {
                        isLoading = true;
                        error = null;
                      });
                      try {
                        await ref.read(equipeControllerProvider.notifier).createUser(
                              fullName: nameCtrl.text,
                              password: pwdCtrl.text,
                              role: selectedRole,
                            );
                        if (context.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() {
                          error = e.toString();
                          isLoading = false;
                        });
                      }
                    },
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      color: context.colors.errorContainer,
                      child: Text(
                        error!,
                        style: TextStyle(color: context.colors.error),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppFormField(
                    label: 'Nom complet',
                    controller: nameCtrl,
                    icon: Icons.person_outline,
                    isRequired: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppFormField(
                    label: 'Mot de passe',
                    controller: pwdCtrl,
                    icon: Icons.lock_outline,
                    isRequired: true,
                    obscureText: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Rôle', style: AppTypography.labelMd),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(value: UserRole.cashier, label: Text('Vendeur')),
                      ButtonSegment(value: UserRole.admin, label: Text('Admin')),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (set) {
                      setState(() => selectedRole = set.first);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
