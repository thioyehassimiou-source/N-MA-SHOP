import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Thème de l'application, assemblé à partir des tokens de la charte
/// ([AppColors], [AppTypography], [AppSpacing]). Interface épurée, lisible sur
/// matériel modeste.
class AppTheme {
  /// Thème clair dérivé du template choisi par le commerçant.
  static ThemeData light([AppPalette palette = AppPalette.fallback]) {
    final primaryColor = palette.primaryColor;

    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: primaryColor.withValues(alpha: 0.12),
      onPrimaryContainer: primaryColor,
      secondary: primaryColor,
      onSecondary: Colors.white,
      secondaryContainer: primaryColor.withValues(alpha: 0.12),
      onSecondaryContainer: primaryColor,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.background,
      onSurface: AppColors.onSurface,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );
    return _base(scheme, palette);
  }

  /// Thème sombre dérivé du template choisi par le commerçant.
  static ThemeData dark([AppPalette palette = AppPalette.fallback]) {
    final primaryColor = palette.primaryColor;

    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: primaryColor.withValues(alpha: 0.25),
      onPrimaryContainer: Colors.white,
      secondary: primaryColor,
      onSecondary: Colors.white,
      secondaryContainer: primaryColor.withValues(alpha: 0.2),
      onSecondaryContainer: Colors.white,
      error: const Color(0xFFF87171),
      onError: const Color(0xFF450A0A),
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: const Color(0xFFFEE2E2),
      surface: palette.darkSidebarTop,
      onSurface: const Color(0xFFF8FAFC),
      surfaceContainerLowest: palette.darkSidebarBottom,
      surfaceContainerLow: palette.darkSidebarTop,
      surfaceContainer: const Color(0xFF16254E),
      surfaceContainerHigh: const Color(0xFF1E3163),
      surfaceContainerHighest: const Color(0xFF2A427E),
      onSurfaceVariant: const Color(0xFFAABBCC),
      outline: const Color(0xFF334155),
      outlineVariant: const Color(0xFF1E3163),
    );
    return _base(scheme, palette);
  }

  static ThemeData _base(ColorScheme scheme, AppPalette palette) {
    final textTheme = const TextTheme(
      displayLarge: AppTypography.displayLg,
      headlineLarge: AppTypography.headlineLg,
      headlineMedium: AppTypography.headlineMd,
      titleLarge: AppTypography.headlineMd,
      titleMedium: AppTypography.labelMd,
      bodyLarge: AppTypography.bodyLg,
      bodyMedium: AppTypography.bodyMd,
      bodySmall: AppTypography.bodySm,
      labelLarge: AppTypography.labelMd,
      labelMedium: AppTypography.labelMd,
      labelSmall: AppTypography.labelSm,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      colorScheme: scheme,
      extensions: [AppPaletteTheme(palette)],
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: AppTypography.labelMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg), // SaaS buttons are not pills
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: AppTypography.labelMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}

/// Rend le template courant accessible depuis n'importe quel widget, pour les
/// besoins que [ColorScheme] ne couvre pas (couleur d'accent, libellé).
@immutable
class AppPaletteTheme extends ThemeExtension<AppPaletteTheme> {
  const AppPaletteTheme(this.palette);

  final AppPalette palette;

  @override
  AppPaletteTheme copyWith({AppPalette? palette}) =>
      AppPaletteTheme(palette ?? this.palette);

  @override
  AppPaletteTheme lerp(covariant AppPaletteTheme? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// Raccourcis de thème dans les widgets : `context.colors.primary`.
extension ThemeContextX on BuildContext {
  /// Nuancier du thème courant.
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Template visuel choisi par le commerçant.
  AppPalette get palette =>
      Theme.of(this).extension<AppPaletteTheme>()?.palette ??
      AppPalette.fallback;
}
