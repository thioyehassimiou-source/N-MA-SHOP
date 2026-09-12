import 'package:flutter/foundation.dart';

/// Configuration et adaptation métier selon le domaine d'activité du commerce.
///
/// Permet d'adapter l'expérience utilisateur (unités prioritaires, exemples
/// de saisie dans les formulaires, mentions de reçu et suggestions PRO) sans
/// altérer l'identité visuelle officielle de l'application.
@immutable
class BusinessDomainConfig {
  const BusinessDomainConfig({
    required this.domain,
    required this.primaryUnits,
    required this.defaultUnit,
    required this.productNameHint,
    required this.referenceHint,
    required this.receiptNotice,
    required this.suggestedPaletteId,
  });

  /// Nom officiel du domaine d'activité.
  final String domain;

  /// Unités de vente prioritaires pour ce secteur (affichées en tête de liste).
  final List<String> primaryUnits;

  /// Unité sélectionnée par défaut lors de la création d'un article.
  final String defaultUnit;

  /// Texte indicatif (placeholder) pour le nom du produit.
  final String productNameHint;

  /// Texte indicatif (placeholder) pour la référence produit.
  final String referenceHint;

  /// Mention commerciale ou légale suggérée en pied de reçu.
  final String receiptNotice;

  /// Identifiant du template visuel exclusif recommandé dans Paramètres > Apparence.
  final String suggestedPaletteId;

  /// Liste globale de toutes les unités communes pour compléter la sélection.
  static const List<String> _kAllCommonUnits = [
    'pièce',
    'kg',
    'sac',
    'carton',
    'paquet',
    'litre',
    'mètre',
    'boîte',
    'bouteille',
    'lot',
    'paire',
    'palette',
    'gramme',
    'plat',
    'portion',
    'barre',
    'rouleau',
    'tube',
    'flacon',
    'ampoule',
    'plaquette',
    'ensemble',
    'kit',
  ];

  /// Retourne la liste complète ordonnée des unités avec celles du domaine en priorité.
  List<String> get allOrderedUnits {
    final set = <String>{...primaryUnits, ..._kAllCommonUnits};
    return set.toList();
  }

  /// Préréglages par domaine d'activité.
  static const Map<String, BusinessDomainConfig> presets = {
    'Alimentation Générale': BusinessDomainConfig(
      domain: 'Alimentation Générale',
      primaryUnits: ['kg', 'sac', 'carton', 'litre', 'pièce', 'boîte', 'bouteille', 'paquet', 'gramme'],
      defaultUnit: 'kg',
      productNameHint: 'Ex: Riz Parfumé 25kg, Huile Dinor 5L, Sucre en poudre',
      referenceHint: 'Ex: RIZ-25KG',
      receiptNotice: 'Les denrées alimentaires ne sont ni reprises ni échangées après ouverture.',
      suggestedPaletteId: 'emeraude',
    ),
    'Quincaillerie & Matériaux': BusinessDomainConfig(
      domain: 'Quincaillerie & Matériaux',
      primaryUnits: ['sac', 'mètre', 'barre', 'paquet', 'carton', 'pièce', 'kg', 'rouleau', 'palette'],
      defaultUnit: 'pièce',
      productNameHint: 'Ex: Ciment Portland 50kg, Fer à béton 12mm, Peinture 20L',
      referenceHint: 'Ex: CIM-50KG',
      receiptNotice: 'Marchandise vérifiée et réceptionnée au départ du magasin. Aucun retour sur matériaux découpés.',
      suggestedPaletteId: 'ardoise',
    ),
    'Mode & Prêt-à-porter': BusinessDomainConfig(
      domain: 'Mode & Prêt-à-porter',
      primaryUnits: ['pièce', 'paire', 'lot', 'ensemble', 'mètre'],
      defaultUnit: 'pièce',
      productNameHint: 'Ex: Chemise Homme Slim Fit L, Robe Soirée Fleurie, Chaussures Cuir 42',
      referenceHint: 'Ex: CH-SLIM-L',
      receiptNotice: 'Échange possible sous 48h sur présentation du reçu avec étiquette d\'origine intacte.',
      suggestedPaletteId: 'prune',
    ),
    'Électronique & Informatique': BusinessDomainConfig(
      domain: 'Électronique & Informatique',
      primaryUnits: ['pièce', 'paquet', 'lot', 'mètre', 'carton'],
      defaultUnit: 'pièce',
      productNameHint: 'Ex: Ordinateur Portable Core i5 16Go, Écran LED 24", Câble HDMI 2m',
      referenceHint: 'Ex: PC-HP-I5',
      receiptNotice: 'Garantie panne au déballage 7 jours. Conservez impérativement votre reçu.',
      suggestedPaletteId: 'indigo',
    ),
    'Cosmétique & Beauté': BusinessDomainConfig(
      domain: 'Cosmétique & Beauté',
      primaryUnits: ['pièce', 'flacon', 'tube', 'pot', 'coffret', 'lot'],
      defaultUnit: 'pièce',
      productNameHint: 'Ex: Crème Hydratante 200ml, Sérum Éclat Vitamine C, Parfum 100ml',
      referenceHint: 'Ex: CRM-HYD-200',
      receiptNotice: 'Produits d\'hygiène et cosmétiques ni repris ni échangés une fois descellés.',
      suggestedPaletteId: 'prune',
    ),
    'Pharmacie & Santé': BusinessDomainConfig(
      domain: 'Pharmacie & Santé',
      primaryUnits: ['boîte', 'plaquette', 'flacon', 'tube', 'ampoule', 'pièce', 'sachet'],
      defaultUnit: 'boîte',
      productNameHint: 'Ex: Paracétamol 500mg (Boîte de 16), Sérum physiologique 500ml',
      referenceHint: 'Ex: PARA-500',
      receiptNotice: 'Les médicaments ne sont ni repris ni échangés. Conserver hors de la portée des enfants.',
      suggestedPaletteId: 'clinique',
    ),
    'Téléphonie & Accessoires': BusinessDomainConfig(
      domain: 'Téléphonie & Accessoires',
      primaryUnits: ['pièce', 'paquet', 'lot'],
      defaultUnit: 'pièce',
      productNameHint: 'Ex: Smartphone 128Go Noir, Chargeur Rapide Type-C 25W, Écouteurs',
      referenceHint: 'Ex: TEL-A54-128',
      receiptNotice: 'Appareils garantis constructeur. Vérifier les identifiants portés sur votre reçu.',
      suggestedPaletteId: 'indigo',
    ),
    'Boulangerie & Pâtisserie': BusinessDomainConfig(
      domain: 'Boulangerie & Pâtisserie',
      primaryUnits: ['pièce', 'lot', 'paquet', 'kg', 'portion'],
      defaultUnit: 'pièce',
      productNameHint: 'Ex: Baguette Tradition, Croissant pur beurre, Gâteau 8 parts',
      referenceHint: 'Ex: BAG-TRAD',
      receiptNotice: 'Produits frais artisanaux. À consommer de préférence dans les 24 heures.',
      suggestedPaletteId: 'safran',
    ),
    'Restaurant & Alimentation': BusinessDomainConfig(
      domain: 'Restaurant & Alimentation',
      primaryUnits: ['plat', 'portion', 'bouteille', 'canette', 'pièce', 'lot'],
      defaultUnit: 'plat',
      productNameHint: 'Ex: Menu Riz au Gras + Poulet Braisé, Jus Naturel 50cl',
      referenceHint: 'Ex: PLAT-01',
      receiptNotice: 'Merci pour votre visite ! Les plats servis ne sont ni repris ni échangés.',
      suggestedPaletteId: 'safran',
    ),
    'Matériel & Équipements': BusinessDomainConfig(
      domain: 'Matériel & Équipements',
      primaryUnits: ['pièce', 'ensemble', 'kit', 'paquet', 'mètre', 'rouleau'],
      defaultUnit: 'pièce',
      productNameHint: 'Ex: Groupe Électrogène 5kVA, Motopompe 3", Panneau Solaire 300W',
      referenceHint: 'Ex: GRP-ELEC-5K',
      receiptNotice: 'Matériel garanti 6 mois pièces et main d\'œuvre en utilisation conforme.',
      suggestedPaletteId: 'ardoise',
    ),
  };

  /// Configuration standard / fallback si le domaine n'est pas spécifié ou est "Autre".
  static const BusinessDomainConfig fallback = BusinessDomainConfig(
    domain: 'Général',
    primaryUnits: ['pièce', 'kg', 'sac', 'carton', 'paquet', 'litre', 'mètre', 'boîte', 'lot'],
    defaultUnit: 'pièce',
    productNameHint: 'Ex: Nom ou désignation de l\'article',
    referenceHint: 'Auto si vide',
    receiptNotice: 'Merci de votre confiance et de votre fidélité !',
    suggestedPaletteId: 'nmashop',
  );

  /// Retrouve la configuration correspondant à un nom de domaine.
  static BusinessDomainConfig forDomain(String? domain) {
    if (domain == null || domain.trim().isEmpty) return fallback;
    final exact = presets[domain];
    if (exact != null) return exact;

    final lower = domain.toLowerCase();
    for (final entry in presets.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    if (lower.contains('pharmacie') || lower.contains('santé')) {
      return presets['Pharmacie & Santé']!;
    }
    if (lower.contains('mode') || lower.contains('vêtement') || lower.contains('habit')) {
      return presets['Mode & Prêt-à-porter']!;
    }
    if (lower.contains('quincaillerie') || lower.contains('matériau') || lower.contains('ciment')) {
      return presets['Quincaillerie & Matériaux']!;
    }
    if (lower.contains('électronique') || lower.contains('informatique') || lower.contains('ordi')) {
      return presets['Électronique & Informatique']!;
    }
    if (lower.contains('téléphone') || lower.contains('gsm')) {
      return presets['Téléphonie & Accessoires']!;
    }
    if (lower.contains('cosmétique') || lower.contains('beauté') || lower.contains('parfum')) {
      return presets['Cosmétique & Beauté']!;
    }
    if (lower.contains('boulangerie') || lower.contains('pâtisserie') || lower.contains('pain')) {
      return presets['Boulangerie & Pâtisserie']!;
    }
    if (lower.contains('restaurant') || lower.contains('café') || lower.contains('resto')) {
      return presets['Restaurant & Alimentation']!;
    }
    if (lower.contains('alimentation') || lower.contains('supérette') || lower.contains('épicerie')) {
      return presets['Alimentation Générale']!;
    }

    return fallback;
  }
}
