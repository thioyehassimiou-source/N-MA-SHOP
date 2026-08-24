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
    // Use the design-system primary (indigo) instead of the palette seed
    // so that the sidebar active state, buttons, etc. are always consistent
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
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

  /// Thème sombre
  static ThemeData dark([AppPalette palette = AppPalette.fallback]) {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFE85D04), // Orange N'MaShop
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFF9D3C00), // Darker Orange
      onPrimaryContainer: Color(0xFFFFDBC7),
      secondary: Color(0xFF8899BB),
      onSecondary: Color(0xFF020617),
      secondaryContainer: Color(0xFF1E293B),
      onSecondaryContainer: Color(0xFFF1F5F9),
      error: Color(0xFFF87171),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: Color(0xFF0F1B3D), // N'MaShop Navy
      onSurface: Color(0xFFF8FAFC),
      surfaceContainerLowest: Color(0xFF0A1229), // Deeper Navy
      surfaceContainerLow: Color(0xFF0F1B3D),
      surfaceContainer: Color(0xFF16254E), // Cards in dark mode
      surfaceContainerHigh: Color(0xFF1E3163),
      surfaceContainerHighest: Color(0xFF2A427E),
      onSurfaceVariant: Color(0xFFAABBCC), // Muted blue-grey
      outline: Color(0xFF334155),
      outlineVariant: Color(0xFF1E3163),
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
