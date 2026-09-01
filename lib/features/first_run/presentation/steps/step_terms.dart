import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/first_run_provider.dart';
import '../legal_content.dart';

class StepTerms extends ConsumerStatefulWidget {
  const StepTerms({super.key});

  @override
  ConsumerState<StepTerms> createState() => _StepTermsState();
}

class _StepTermsState extends ConsumerState<StepTerms> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Conditions Générales d\'Utilisation',
                style: AppTypography.headlineMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            'Veuillez lire et accepter les CGU avant de continuer.',
            style: AppTypography.bodyMd.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Zone scrollable contenant le texte complet des CGU
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      LegalContent.termsOfServiceText,
                      style: AppTypography.bodySm.copyWith(
                        color: colors.onSurface,
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Checkbox d'acceptation
          InkWell(
            onTap: () => controller.setAcceptedTerms(!state.acceptedTerms),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: state.acceptedTerms,
                    onChanged: (val) => controller.setAcceptedTerms(val ?? false),
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'J\'ai lu et j\'accepte les conditions générales d\'utilisation.',
                      style: AppTypography.labelMd.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
