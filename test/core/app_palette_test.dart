import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/theme/app_colors.dart';
import 'package:nmashop/core/theme/app_palette.dart';
import 'package:nmashop/core/theme/app_theme.dart';

void main() {
  group('AppPalette.fromId', () {
    test('retrouve chaque template par son identifiant', () {
      for (final palette in AppPalette.values) {
        expect(AppPalette.fromId(palette.id), palette);
      }
    });

    test('retombe sur le template par défaut si l\'identifiant est inconnu', () {
      expect(AppPalette.fromId(null), AppPalette.fallback);
      expect(AppPalette.fromId(''), AppPalette.fallback);
      expect(AppPalette.fromId('template-supprimé'), AppPalette.fallback);
    });

    test('les identifiants sont uniques', () {
      final ids = AppPalette.values.map((p) => p.id).toSet();
      expect(ids.length, AppPalette.values.length);
    });
  });

  group('AppPalette.suggestedFor', () {
    test('propose un template cohérent avec le métier', () {
      expect(
        AppPalette.suggestedFor('Pharmacie & Santé'),
        AppPalette.clinique,
      );
      expect(AppPalette.suggestedFor('Mode & Prêt-à-porter'), AppPalette.prune);
      expect(
        AppPalette.suggestedFor('Alimentation Générale'),
        AppPalette.safran,
      );
      expect(
        AppPalette.suggestedFor('Électronique & Informatique'),
        AppPalette.indigo,
      );
      expect(
        AppPalette.suggestedFor('Quincaillerie & Matériaux'),
        AppPalette.ardoise,
      );
    });

    test('retombe sur le défaut pour un domaine inconnu ou absent', () {
      expect(AppPalette.suggestedFor(null), AppPalette.fallback);
      expect(AppPalette.suggestedFor('Autre'), AppPalette.fallback);
    });
  });

  group('AppTheme', () {
    test('chaque template produit un thème clair et sombre distincts', () {
      for (final palette in AppPalette.values) {
        final light = AppTheme.light(palette);
        final dark = AppTheme.dark(palette);

        expect(light.colorScheme.primary, AppColors.primary);
        expect(dark.colorScheme.primary, const Color(0xFFE85D04)); // N'MaShop Orange
        expect(light.colorScheme.brightness, Brightness.light);
        expect(dark.colorScheme.brightness, Brightness.dark);
      }
    });

    test('le template est exposé aux widgets via l\'extension de thème', () {
      final theme = AppTheme.light(AppPalette.prune);
      expect(theme.extension<AppPaletteTheme>()?.palette, AppPalette.prune);
    });

    test('le rouge d\'erreur ne dépend pas du template', () {
      final errors = AppPalette.values
          .map((p) => AppTheme.light(p).colorScheme.error)
          .toSet();
      expect(errors.length, 1);
    });
  });
}
