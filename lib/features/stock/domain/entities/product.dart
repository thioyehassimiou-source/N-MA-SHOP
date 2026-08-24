/// Fiche produit du catalogue, vue métier découplée de Drift.
///
/// La couche data mappe la ligne Drift `Product` vers cette entité ; aucune
/// couche au-dessus de `data/` ne connaît le type généré par Drift.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.reference,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.weightedAverageCost,
    required this.isActive,
    this.imageUrl,
    this.barcode,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Référence / code interne (facultatif).
  final String? reference;

  /// Unité de vente : pièce, kg, litre…
  final String unit;

  /// Prix d'achat unitaire (GNF).
  final int purchasePrice;

  /// Prix de vente unitaire (GNF).
  final int salePrice;

  /// Quantité actuellement en stock.
  final int stockQuantity;

  /// Seuil d'alerte de stock faible.
  final int lowStockThreshold;

  /// Coût moyen pondéré courant (GNF) — base de valorisation.
  final int weightedAverageCost;

  final bool isActive;
  final String? imageUrl;

  /// Code-barres EAN/QR (facultatif).
  final String? barcode;

  final DateTime createdAt;
}
