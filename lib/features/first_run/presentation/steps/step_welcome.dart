import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class StepWelcome extends StatelessWidget {
  const StepWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo N'MaShop avec halo lumineux
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.storefront_rounded,
                size: 54,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Bienvenue dans N\'MaShop',
            style: AppTypography.headlineLg.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            'Logiciel professionnel de gestion commerciale & caisse POS',
            style: AppTypography.bodyLg.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  context,
                  icon: Icons.offline_bolt_rounded,
                  title: '100% Hors-ligne (Offline-First)',
                  subtitle: 'Vos données restent stockées sur votre ordinateur en toute sécurité.',
                ),
                const Divider(height: AppSpacing.lg),
                _buildFeatureRow(
                  context,
                  icon: Icons.speed_rounded,
                  title: 'Encaissement & Gestion Ultra-Rapide',
                  subtitle: 'Interface optimisée pour ordinateurs de caisse et écrans tactiles.',
                ),
                const Divider(height: AppSpacing.lg),
                _buildFeatureRow(
                  context,
                  icon: Icons.shield_outlined,
                  title: 'Assistant de Premier Démarrage',
                  subtitle: 'Ce court processus va vous guider pour valider la configuration initiale.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.bodySm.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
