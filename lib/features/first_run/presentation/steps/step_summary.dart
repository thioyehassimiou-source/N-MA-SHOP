import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/first_run_provider.dart';

class StepSummary extends ConsumerWidget {
  const StepSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firstRunControllerProvider);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Résumé de la Configuration',
                style: AppTypography.headlineMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            'Vérifiez vos paramètres avant de valider l\'assistant.',
            style: AppTypography.bodyMd.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: ListView(
              children: [
                _buildSummaryCard(
                  context,
                  title: 'Conditions Générales & Confidentialité',
                  icon: Icons.verified_user_rounded,
                  items: [
                    _SummaryItem(
                      label: 'Conditions Générales d\'Utilisation (CGU)',
                      isOk: state.acceptedTerms,
                    ),
                    _SummaryItem(
                      label: 'Politique de Confidentialité',
                      isOk: state.acceptedPrivacy,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSummaryCard(
                  context,
                  title: 'Options Système & Démarrage',
                  icon: Icons.settings_applications_rounded,
                  items: [
                    _SummaryItem(
                      label: 'Raccourci sur le bureau',
                      isOk: state.createDesktopShortcut,
                      activeText: 'Activé',
                      inactiveText: 'Désactivé',
                    ),
                    _SummaryItem(
                      label: 'Lancement au démarrage du PC',
                      isOk: state.autoLaunchAtStartup,
                      activeText: 'Activé',
                      inactiveText: 'Désactivé',
                    ),
                    _SummaryItem(
                      label: 'Rapports d\'erreurs anonymes',
                      isOk: state.enableAnalytics,
                      activeText: 'Autorisé',
                      inactiveText: 'Non autorisé',
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

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_SummaryItem> items,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      item.isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: item.isOk ? const Color(0xFF10B981) : colors.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        item.label,
                        style: AppTypography.bodySm.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      item.isOk ? item.activeText : item.inactiveText,
                      style: AppTypography.labelSm.copyWith(
                        color: item.isOk ? const Color(0xFF10B981) : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.isOk,
    this.activeText = 'Accepté',
    this.inactiveText = 'Non accepté',
  });

  final String label;
  final bool isOk;
  final String activeText;
  final String inactiveText;
}
