import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/first_run_provider.dart';

class StepOptions extends ConsumerWidget {
  const StepOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firstRunControllerProvider);
    final controller = ref.read(firstRunControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Options Initiales',
                style: AppTypography.headlineMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            'Personnalisez le comportement au démarrage et l\'intégration à votre système.',
            style: AppTypography.bodyMd.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: ListView(
              children: [
                _buildOptionTile(
                  context,
                  title: 'Créer un raccourci sur le bureau',
                  subtitle: 'Permet de lancer N\'MaShop rapidement depuis votre bureau Linux/Windows.',
                  icon: Icons.desktop_windows_rounded,
                  value: state.createDesktopShortcut,
                  onChanged: (val) => controller.setCreateDesktopShortcut(val),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildOptionTile(
                  context,
                  title: 'Lancer automatiquement au démarrage du PC',
                  subtitle: 'Démarre N\'MaShop en arrière-plan lorsque vous allumez votre poste de caisse.',
                  icon: Icons.power_settings_new_rounded,
                  value: state.autoLaunchAtStartup,
                  onChanged: (val) => controller.setAutoLaunchAtStartup(val),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildOptionTile(
                  context,
                  title: 'Rapports d\'erreurs & Diagnostics anonymes',
                  subtitle: 'Aide l\'équipe à améliorer la stabilité et les performances sur ordinateurs modestes.',
                  icon: Icons.analytics_outlined,
                  value: state.enableAnalytics,
                  onChanged: (val) => controller.setEnableAnalytics(val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.5)
              : colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (val) => onChanged(val ?? false),
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: value
                ? AppColors.primary.withValues(alpha: 0.12)
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            icon,
            color: value ? AppColors.primary : colors.onSurfaceVariant,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: AppTypography.labelMd.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySm.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
