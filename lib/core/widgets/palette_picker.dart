import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// Galerie de choix du template visuel de la boutique.
///
/// Inspirée des sélecteurs d'apparence modernes (réglages macOS, galerie de
/// thèmes VSCode) : chaque option montre une **miniature de l'application**
/// peinte aux couleurs du template, plutôt qu'une pastille abstraite. Le
/// commerçant voit immédiatement à quoi ressemblera sa boutique.
///
/// Partagée par l'écran de configuration et les réglages.
class PalettePicker extends StatelessWidget {
  const PalettePicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.cardColor,
  });

  final AppPalette selected;
  final ValueChanged<AppPalette> onSelected;

  /// Fond des cartes non sélectionnées. Par défaut, la surface du thème.
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        // 1 à 3 colonnes selon la largeur disponible.
        final columns = (constraints.maxWidth / 190).floor().clamp(1, 4);
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: AppPalette.values
              .map(
                (p) => SizedBox(
                  width: itemWidth,
                  child: _PaletteCard(
                    palette: p,
                    isSelected: p == selected,
                    cardColor: cardColor,
                    onTap: () => onSelected(p),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.palette,
    required this.isSelected,
    required this.onTap,
    this.cardColor,
  });

  final AppPalette palette;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: isSelected,
      button: true,
      label: 'Template ${palette.label}, ${palette.trade}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: cardColor ?? scheme.surfaceContainerLowest,
            border: Border.all(
              color: isSelected ? palette.seed : scheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: palette.seed.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniApp(palette: palette),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 9, 2, 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            palette.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? palette.seed
                                  : scheme.onSurface,
                            ),
                          ),
                          Text(
                            palette.trade,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SelectDot(isSelected: isSelected, color: palette.seed),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille de sélection : cercle vide → coché plein.
class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.isSelected, required this.color});

  final bool isSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? color
              : Theme.of(context).colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }
}

/// Miniature « capture d'écran » de l'application peinte aux couleurs du
/// template : une barre d'en-tête, une carte de statistique et un bouton.
///
/// C'est un aperçu figé (indépendant du thème clair/sombre de l'appareil), à la
/// manière des vignettes de thèmes des éditeurs modernes.
class _MiniApp extends StatelessWidget {
  const _MiniApp({required this.palette});

  final AppPalette palette;

  static const _screen = Color(0xFFF6F8FA);
  static const _ink = Color(0xFFD4DAE0);
  static const _cardBorder = Color(0xFFE6EBEF);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 1.55,
        child: Column(
          children: [
            // ── Barre d'en-tête (dégradé sombre thématique) ──
            Container(
              height: 22,
              color: palette.darkSidebarTop,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _bar(30, 5, Colors.white.withValues(alpha: 0.9)),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette.seed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            // ── Corps (écran clair) ──
            Expanded(
              child: Container(
                color: _screen,
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statCard(palette),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(double.infinity, 5, _ink),
                          const SizedBox(height: 5),
                          _bar(46, 5, _ink),
                          const Spacer(),
                          // Bouton d'action (couleur maîtresse).
                          Container(
                            height: 12,
                            width: 52,
                            decoration: BoxDecoration(
                              color: palette.seed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Petite carte de statistique avec un mini graphique à barres aux couleurs du template.
  Widget _statCard(AppPalette palette) {
    return Container(
      width: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(18, 5, palette.seed),
          const SizedBox(height: 4),
          _bar(30, 3, _ink),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _chartBar(6, palette.seed.withValues(alpha: 0.55)),
              const SizedBox(width: 2),
              _chartBar(11, palette.seed),
              const SizedBox(width: 2),
              _chartBar(8, palette.seed.withValues(alpha: 0.75)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(double w, double h, Color c) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
  );

  Widget _chartBar(double h, Color c) => Container(
    width: 5,
    height: h,
    decoration: BoxDecoration(
      color: c,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
    ),
  );
}
