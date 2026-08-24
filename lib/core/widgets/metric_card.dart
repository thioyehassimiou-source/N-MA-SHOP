import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Carte indicateur du tableau de bord : label + icône colorée, grande valeur,
/// et une ligne de tendance (texte coloré + précision discrète).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.iconBackground,
    this.valueColor,
    this.trendText,
    this.trendColor,
    this.trendHint,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Couleurs facultatives : par défaut, celles du template de la boutique.
  final Color? iconColor;
  final Color? iconBackground;
  final Color? valueColor;

  /// Ex. « +14 % » ou « 3 en attente ».
  final String? trendText;
  final Color? trendColor;

  /// Ex. « vs hier ».
  final String? trendHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      hoverBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.labelSm.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? (iconColor ?? colors.primary).withValues(alpha: 0.15)
                      : (iconBackground ?? colors.secondaryContainer),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: iconColor ?? colors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.headlineMd.copyWith(
              color: valueColor ?? colors.onSurface,
            ),
          ),
          if (trendText != null) ...[
            const SizedBox(height: AppSpacing.base),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  trendText!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: trendColor ?? colors.primary,
                  ),
                ),
                if (trendHint != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      trendHint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
