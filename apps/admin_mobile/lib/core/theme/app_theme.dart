import 'package:flutter/material.dart';

abstract final class AppTheme {
  // N'MaShop Brand Colors
  static const primaryIndigo = Color(0xFF4F46E5);
  static const primaryViolet = Color(0xFF6366F1);
  static const primaryLightBg = Color(0xFFEEF2FF);

  // Background & Surfaces
  static const bgSlate = Color(0xFFF8FAFC);
  static const surfaceWhite = Colors.white;
  static const borderSlate = Color(0xFFE2E8F0);
  static const borderFocus = Color(0xFF4F46E5);

  // Accents & Badges
  static const emeraldActive = Color(0xFF10B981);
  static const emeraldBg = Color(0xFFECFDF5);
  static const amberTrial = Color(0xFFF59E0B);
  static const amberBg = Color(0xFFFFFBEB);
  static const cyanSms = Color(0xFF06B6D4);
  static const cyanBg = Color(0xFFECFEFF);
  static const roseAlert = Color(0xFFF43F5E);
  static const roseBg = Color(0xFFFFF1F2);

  // Typography
  static const textDark = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryIndigo, primaryViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgSlate,
      primaryColor: primaryIndigo,
      colorScheme: const ColorScheme.light(
        primary: primaryIndigo,
        secondary: primaryViolet,
        surface: surfaceWhite,
        onSurface: textDark,
        primaryContainer: primaryLightBg,
        onPrimaryContainer: primaryIndigo,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgSlate,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textDark,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 2,
        shadowColor: const Color(0x0F0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borderSlate),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryIndigo,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: primaryIndigo.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryIndigo,
          side: const BorderSide(color: primaryIndigo, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgSlate,
        selectedColor: primaryLightBg,
        labelStyle: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: primaryIndigo, fontSize: 13, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: borderSlate),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSlate),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSlate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryIndigo, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
    );
  }
}
