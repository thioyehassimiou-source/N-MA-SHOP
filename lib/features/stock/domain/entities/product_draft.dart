import '../errors.dart';

/// Données saisies pour créer ou modifier un produit du catalogue.
///
/// Ne porte ni identifiant, ni date de création, ni coût moyen pondéré : ces
/// champs sont gérés par la couche data (le CMP n'est pas ajusté par une simple
/// édition de fiche — voir le module d'ajustement de stock à venir).
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.reference,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    this.imageUrl,
    this.barcode,
  });

  final String name;
  final String? reference;
  final String unit;
  final int purchasePrice;
  final int salePrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final String? imageUrl;
  final String? barcode;

  /// Validations pures (sans accès base). Retourne la première erreur trouvée,
  /// ou `null` si la saisie est saine.
  ///
  /// **Règles métier appliquées :**
  /// * [RULE-020] Nom de produit obligatoire.
  /// * [RULE-021] Prix d'achat et de vente non négatifs.
  /// * [RULE-022] Quantité en stock non négative.
  /// * [RULE-023] Seuil d'alerte non négatif.
  ProductError? validate() {
    if (name.trim().isEmpty) return const MissingProductNameError();
    if (purchasePrice < 0 || salePrice < 0) return const NegativePriceError();
    if (stockQuantity < 0) return const NegativeStockError();
    if (lowStockThreshold < 0) return const NegativeThresholdError();
    return null;
  }
}
