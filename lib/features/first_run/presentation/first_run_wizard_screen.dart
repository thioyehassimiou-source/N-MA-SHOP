import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_backdrop.dart';
import '../../../core/widgets/app_button.dart';
import '../application/first_run_provider.dart';
import '../domain/first_run_state.dart';
import 'steps/step_welcome.dart';
import 'steps/step_terms.dart';
import 'steps/step_privacy.dart';
import 'steps/step_options.dart';
import 'steps/step_summary.dart';
import 'steps/step_completed.dart';

class FirstRunWizardScreen extends ConsumerWidget {
  const FirstRunWizardScreen({super.key});

  static const _stepTitles = [
    'Bienvenue',
    'Conditions Générales',
    'Confidentialité',
    'Options Initiales',
    'Configuration',
    'Terminé',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firstRunControllerProvider);
    final controller = ref.read(firstRunControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Fond animé de la charte N'MaShop
          const AnimatedBackdrop(scrimOpacity: 0.65),

          // Fenêtre rectangulaire centrée au format bureau
          Center(
            child: Container(
              width: 900,
              height: 640,
              margin: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── En-tête du Wizard avec barre de progression ─────────────
                  _buildHeader(context, state),

                  const Divider(height: 1),

                  // ── Corps de l'étape courante ────────────────────────────────
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(state.currentStep),
                        child: _buildStepWidget(state.currentStep),
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // ── Barre de navigation (Précédent / Suivant / Terminer) ─────
                  _buildFooter(context, ref, state, controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FirstRunState state) {
    final colors = Theme.of(context).colorScheme;
    final progress = (state.currentStep + 1) / FirstRunState.totalSteps;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Branding App
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'N\'MaShop',
                    style: AppTypography.headlineMd.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'Assistant Initial',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Indicateur d'étape (Étape X sur 6)
              Text(
                'Étape ${state.currentStep + 1} sur ${FirstRunState.totalSteps} : ${_stepTitles[state.currentStep]}',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Barre de progression visuelle
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepWidget(int step) {
    switch (step) {
      case 0:
        return const StepWelcome();
      case 1:
        return const StepTerms();
      case 2:
        return const StepPrivacy();
      case 3:
        return const StepOptions();
      case 4:
        return const StepSummary();
      case 5:
        return const StepCompleted();
      default:
        return const StepWelcome();
    }
  }

  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref,
    FirstRunState state,
    FirstRunController controller,
  ) {
    final isLastStep = state.currentStep == FirstRunState.totalSteps - 1;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bouton Précédent
          if (state.currentStep > 0 && !isLastStep)
            OutlinedButton.icon(
              onPressed: state.isCompleting ? null : controller.prevStep,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Précédent'),
            )
          else
            const SizedBox.shrink(),

          Row(
            children: [
              // Bouton Suivant / Terminer
              if (!isLastStep)
                AppButton(
                  label: state.currentStep == 0
                      ? 'Commencer'
                      : (state.currentStep == 4 ? 'Terminer la configuration' : 'Suivant'),
                  icon: state.currentStep == 4 ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
                  onPressed: state.canGoNext
                      ? () {
                          controller.nextStep();
                        }
                      : null,
                )
              else
                // Bouton Final Étape 6 : Commencer à utiliser N'MaShop
                AppButton(
                  label: state.isCompleting ? 'Finalisation...' : 'Commencer à utiliser N’MaShop',
                  icon: Icons.rocket_launch_rounded,
                  onPressed: state.isCompleting
                      ? null
                      : () async {
                          await controller.completeWizard();
                          if (context.mounted) {
                            context.go('/onboarding');
                          }
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
