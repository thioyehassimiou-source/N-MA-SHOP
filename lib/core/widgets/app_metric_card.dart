import 'package:flutter/material.dart';
import 'app_card.dart';

/// Carte de métrique principale — design inspiré du dashboard de référence.
///
/// Affiche un titre, une valeur principale et une description secondaire.
/// L'icône est dans un carré arrondi coloré (style app scolaire/SaaS).
class AppMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String badgeText;
  final Color? badgeColor;
  final double? progressValue;
  final Color? progressColor;

  const AppMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.badgeText,
    this.badgeColor,
    this.progressValue,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Détection d'un indicateur de tendance
    IconData? trendIcon;
    Color effectiveBadgeColor = badgeColor ?? theme.colorScheme.onSurfaceVariant;
    
    if (badgeText.startsWith('+')) {
      trendIcon = Icons.trending_up_rounded;
      effectiveBadgeColor = const Color(0xFF10B981); // Vert
    } else if (badgeText.startsWith('-')) {
      trendIcon = Icons.trending_down_rounded;
      effectiveBadgeColor = const Color(0xFFEF4444); // Rouge
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - anim)),
          child: Opacity(
            opacity: anim,
            child: child,
          ),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête : Icône + Titre
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? iconColor.withValues(alpha: 0.15)
                        : iconBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: iconBackgroundColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Valeur principale
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Badge / Indicateur de tendance
            if (badgeText.isNotEmpty)
              Row(
                children: [
                  if (trendIcon != null) ...[
                    Icon(trendIcon, size: 14, color: effectiveBadgeColor),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: effectiveBadgeColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            // Barre de progression optionnelle
            if (progressValue != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressValue!.clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? theme.colorScheme.primary,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

