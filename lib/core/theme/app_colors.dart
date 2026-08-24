import 'package:flutter/material.dart';

/// Palette de couleurs N'MaShop — Design System v2.
///
/// Inspiré du design de référence : sidebar blanche, icônes colorées,
/// fond gris très clair, cartes blanches épurées.
abstract final class AppColors {
  // ── Primaire (Violet/Indigo — item actif sidebar) ──
  static const primary = Color(0xFF5B5FC7);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFE8E8FF);
  static const onPrimaryContainer = Color(0xFF3F3FA8);
  static const primaryFixed = Color(0xFFEEEEFF);

  // ── Secondaire (Bleu-gris neutre) ──
  static const secondary = Color(0xFF64748B);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFE2E8F0);
  static const onSecondaryContainer = Color(0xFF3E4D5C);
  static const onSecondaryFixedVariant = Color(0xFF475569);

  // ── Tertiaire ──
  static const tertiary = Color(0xFF7C3AED);
  static const tertiaryContainer = Color(0xFFEDE9FE);
  static const tertiaryFixed = Color(0xFFF5F3FF);
  static const onTertiaryFixedVariant = Color(0xFF6D28D9);

  // ── Avertissement (ambre) ──
  static const warning = Color(0xFFF59E0B);
  static const warningContainer = Color(0xFFFEF3C7);
  static const onWarningContainer = Color(0xFFB45309);

  // ── Erreur / Rouge ──
  static const error = Color(0xFFEF4444);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFEE2E2);
  static const onErrorContainer = Color(0xFFB91C1C);

  // ── Surfaces ──
  static const background = Color(0xFFF1F5F9);   // Gris bleuté très clair
  static const surface = Color(0xFFF1F5F9);
  static const surfaceBright = Color(0xFFFFFFFF);
  static const surfaceDim = Color(0xFFE2E8F0);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF8FAFC);
  static const surfaceContainer = Color(0xFFE2E8F0);
  static const surfaceContainerHigh = Color(0xFFCBD5E1);
  static const surfaceContainerHighest = Color(0xFF94A3B8);
  static const surfaceVariant = Color(0xFFE2E8F0);

  // ── On Surfaces (textes) ──
  static const onSurface = Color(0xFF0F172A);          // Presque noir
  static const onSurfaceVariant = Color(0xFF64748B);    // Gris-bleu
  static const onBackground = Color(0xFF0F172A);

  // ── Outline / Bordures ──
  static const outline = Color(0xFFE2E8F0);
  static const outlineVariant = Color(0xFFF1F5F9);

  // ── Inverse ──
  static const inverseSurface = Color(0xFF1E293B);
  static const inverseOnSurface = Color(0xFFFFFFFF);
  static const inversePrimary = Color(0xFF818CF8);

  // ── Scrim ──
  static const scrim = Color(0xFF000000);
  static const shadow = Color(0xFF000000);

  // ── Sidebar (blanche, style référence) ──
  static const sidebarBg = Color(0xFFFFFFFF);
  static const sidebarBorder = Color(0xFFE2E8F0);
  static const sidebarText = Color(0xFF374151);
  static const sidebarTextMuted = Color(0xFF9CA3AF);
  static const sidebarActiveText = Color(0xFF5B5FC7);
  static const sidebarActiveBg = Color(0xFFEEF2FF);

  // ── Couleurs d'icônes vives (pour les AppMetricCard) ──
  static const iconPurple = Color(0xFF5B5FC7);
  static const iconPurpleBg = Color(0xFFEEF2FF);

  static const iconRed = Color(0xFFEF4444);
  static const iconRedBg = Color(0xFFFEE2E2);

  static const iconGreen = Color(0xFF10B981);
  static const iconGreenBg = Color(0xFFD1FAE5);

  static const iconTeal = Color(0xFF14B8A6);
  static const iconTealBg = Color(0xFFCCFBF1);

  static const iconNavy = Color(0xFF3B82F6);
  static const iconNavyBg = Color(0xFFDBEAFE);

  static const iconOrange = Color(0xFFF59E0B);
  static const iconOrangeBg = Color(0xFFFEF3C7);

  static const iconCyan = Color(0xFF06B6D4);
  static const iconCyanBg = Color(0xFFCFFAFE);

  static const iconBlue = Color(0xFF6366F1);
  static const iconBlueBg = Color(0xFFE0E7FF);

  static const iconPink = Color(0xFFEC4899);
  static const iconPinkBg = Color(0xFFFCE7F3);

  static const iconAmber = Color(0xFFD97706);
  static const iconAmberBg = Color(0xFFFEF3C7);

  // ── Marque N'MaShop ──
  static const brandNavy = Color(0xFF0F1B3D);
  static const brandNavyLight = Color(0xFF1A2B52);
  static const brandOrange = Color(0xFFE85D04);
  static const brandOrangeLight = Color(0xFFFF7A2A);
  static const brandEmerald = Color(0xFF10B981);
  static const brandEmeraldLight = Color(0xFF6EE7B7);
}
