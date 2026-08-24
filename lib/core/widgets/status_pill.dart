import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_spacing.dart';

/// Pastille de statut arrondie (ex. « Payé », « Crédit »).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.background,
    this.foreground,
  });

  /// Vente réglée : suit le template de la boutique.
  const StatusPill.paid({super.key})
    : label = 'Payé',
      background = null,
      foreground = null;

  /// Vente (partiellement) à crédit. Le rouge d'alerte ne dépend pas du
  /// template : une dette doit se repérer à l'identique partout.
  const StatusPill.credit({super.key})
    : label = 'Crédit',
      background = null,
      foreground = null;

  final String label;

  /// Couleurs facultatives : par défaut, celles du template.
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bool isCredit = label == 'Crédit';
    final defaultBg = isCredit ? context.colors.errorContainer : context.colors.secondaryContainer;
    final defaultFg = isCredit ? context.colors.onErrorContainer : context.colors.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background ?? defaultBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground ?? defaultFg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
