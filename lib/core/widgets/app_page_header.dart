import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

import 'package:nmashop/core/theme/app_theme.dart';

/// En-tête premium réutilisable pour tous les écrans de N'MaShop.
///
/// Affiche une icône avec gradient, un titre, un sous-titre et une zone
/// d'actions (boutons, filtres…). Applique une séparation visuelle en bas.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Deux couleurs pour le gradient de l'icône (ex. [Colors.blue, Colors.indigo]).
  final List<Color> gradientColors;

  /// Boutons ou widgets placés à droite du titre (ex. "Nouveau produit").
  final List<Widget> actions;

  /// Widget optionnel affiché sous la ligne titre/actions (ex. chips de filtre).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        bottom != null ? AppSpacing.md : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icône avec gradient
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),

              // Titre + sous-titre
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.colors.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Zone d'actions
              if (actions.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ],
            ],
          ),

          // Widget optionnel sous la ligne principale (filtres, chips…)
          if (bottom != null) ...[
            const SizedBox(height: AppSpacing.md),
            bottom!,
          ],
        ],
      ),
    );
  }
}
