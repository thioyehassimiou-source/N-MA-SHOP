import 'package:flutter/material.dart';

/// Template visuel de la boutique.
///
/// Chaque métier a ses codes : le bleu clinique d'une pharmacie ne convient pas
/// à une boutique de mode. Le commerçant choisit son template à la
/// configuration, et il colore toute l'application.
///
/// [id] est persisté dans les préférences : ne jamais le renommer.
enum AppPalette {
  nmashop(
    id: 'nmashop',
    label: 'N\'MaShop Officiel',
    trade: 'Charte officielle Orange & Navy',
    seed: Color(0xFFE85D04),
    accent: Color(0xFF0F1B3D),
  ),
  emeraude(
    id: 'emeraude',
    label: 'Émeraude',
    trade: 'Commerce général & Supérette',
    seed: Color(0xFF10B981),
    accent: Color(0xFF062E28),
  ),
  clinique(
    id: 'clinique',
    label: 'Clinique & Santé',
    trade: 'Pharmacie, santé & cosmétique',
    seed: Color(0xFF06B6D4),
    accent: Color(0xFF083344),
  ),
  prune(
    id: 'prune',
    label: 'Prune Prestige',
    trade: 'Mode, vêtements & beauté',
    seed: Color(0xFFC026D3),
    accent: Color(0xFF3B0764),
  ),
  safran(
    id: 'safran',
    label: 'Safran & Ambre',
    trade: 'Alimentation, resto & boulangerie',
    seed: Color(0xFFF59E0B),
    accent: Color(0xFF451A03),
  ),
  indigo(
    id: 'indigo',
    label: 'Indigo High-Tech',
    trade: 'Électronique, téléphonie & IT',
    seed: Color(0xFF6366F1),
    accent: Color(0xFF1E1B4B),
  ),
  ardoise(
    id: 'ardoise',
    label: 'Ardoise & Cuivre',
    trade: 'Quincaillerie, BTP & matériaux',
    seed: Color(0xFF64748B),
    accent: Color(0xFF0F172A),
  ),
  afrique(
    id: 'afrique',
    label: 'Terre d\'Afrique',
    trade: 'Artisanat, culture & textile',
    seed: Color(0xFFC2410C),
    accent: Color(0xFF431407),
  );

  const AppPalette({
    required this.id,
    required this.label,
    required this.trade,
    required this.seed,
    required this.accent,
  });

  /// Identifiant stable, stocké dans les préférences.
  final String id;

  /// Nom affiché au commerçant.
  final String label;

  /// Métiers auxquels ce template s'adresse.
  final String trade;

  /// Couleur mère maîtresse (boutons, éléments actifs, icônes).
  final Color seed;

  /// Couleur d'accentuation sombre pour les dégradés et arrière-plans sombres.
  final Color accent;

  /// Template appliqué par défaut, avant tout choix du commerçant.
  static const fallback = AppPalette.nmashop;

  /// Retrouve un template par son [id]. Retombe sur [fallback] si l'id est
  /// inconnu (template supprimé lors d'une mise à jour, préférence corrompue).
  static AppPalette fromId(String? id) {
    return AppPalette.values.firstWhere(
      (p) => p.id == id,
      orElse: () => fallback,
    );
  }

  /// Couleur primaire principale pour les boutons et éléments actifs.
  Color get primaryColor => seed;

  /// Couleur d'accentuation / mise en valeur.
  Color get highlightColor => seed;

  /// Couleur sombre supérieure pour la barre latérale et les bannières premium.
  Color get darkSidebarTop => accent;

  /// Couleur sombre inférieure pour la barre latérale et les bannières premium.
  Color get darkSidebarBottom => Color.alphaBlend(Colors.black.withValues(alpha: 0.35), accent);

  /// Template suggéré pour un domaine d'activité choisi à la configuration.
  ///
  /// Simple pré-sélection : le commerçant reste libre de changer.
  static AppPalette suggestedFor(String? businessDomain) {
    if (businessDomain == null) return fallback;
    final domain = businessDomain.toLowerCase();

    if (domain.contains('pharmacie') || domain.contains('santé')) {
      return AppPalette.clinique;
    }
    if (domain.contains('mode') ||
        domain.contains('cosmétique') ||
        domain.contains('beauté')) {
      return AppPalette.prune;
    }
    if (domain.contains('alimentation') ||
        domain.contains('restaurant') ||
        domain.contains('boulangerie')) {
      return AppPalette.safran;
    }
    if (domain.contains('électronique') ||
        domain.contains('informatique') ||
        domain.contains('téléphonie')) {
      return AppPalette.indigo;
    }
    if (domain.contains('quincaillerie') ||
        domain.contains('matéri') ||
        domain.contains('équipement')) {
      return AppPalette.ardoise;
    }
    return fallback;
  }
}
