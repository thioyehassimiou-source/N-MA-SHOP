import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../application/business_providers.dart';

class BusinessSummaryScreen extends ConsumerWidget {
  const BusinessSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessSummaryProvider);
    final monthName = _monthLabel(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bilan', style: AppTypography.headlineLg),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Performances et indicateurs clés en temps réel.',
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      monthName.toUpperCase(),
                      style: AppTypography.labelMd.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (s) => SingleChildScrollView(
                child: Column(children: [_buildMetricsGrid(s, monthName)]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(dynamic s, String monthName) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
        final childAspectRatio = constraints.maxWidth > 800 ? 2.5 : 3.5;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricBentoCard(
              title: 'Ventes du mois',
              amount: formatGnf(s.monthSales),
              icon: Icons.payments_outlined,
              color: context.colors.primary,
              subtitle: 'Chiffre d\'affaires brut',
            ),
            _MetricBentoCard(
              title: 'Bénéfice estimé',
              amount: formatGnf(s.monthProfit),
              icon: Icons.trending_up,
              color: context.colors.primaryContainer,
              subtitle: 'Marge brute générée',
              isHighlight: true,
            ),
            _MetricBentoCard(
              title: 'Argent encaissé',
              amount: formatGnf(s.cashCollectedThisMonth),
              icon: Icons.account_balance_wallet_outlined,
              color: context.colors.secondary,
              subtitle: 'Trésorerie réelle perçue',
            ),
            _MetricBentoCard(
              title: 'Créances clients',
              amount: formatGnf(s.owedToMe),
              icon: Icons.group_outlined,
              color: context.colors.error,
              subtitle: 'Total de l\'argent dehors',
            ),
          ],
        );
      },
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return months[d.month - 1];
  }
}

class _MetricBentoCard extends StatelessWidget {
  const _MetricBentoCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.isHighlight = false,
  });

  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  amount,
                  style: AppTypography.headlineLg.copyWith(
                    color: isHighlight ? color : context.colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  subtitle,
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
