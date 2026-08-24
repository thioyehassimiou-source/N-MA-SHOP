import 'package:drift/drift.dart';

/// Fiche produit — noyau commun à tous les secteurs.
///
/// Les champs sectoriels (péremption, lot, DCI, variantes…) seront ajoutés
/// dans des tables satellites lors de l'activation des modules sectoriels.
class Products extends Table {
  @override
  String get tableName => 'products';

  TextColumn get id => text()();

  /// Nom commercial du produit.
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Référence / code interne (facultatif).
  TextColumn get reference => text().nullable()();

  /// Unité de vente : pièce, kg, m, litre, coupon…
  TextColumn get unit => text().withDefault(const Constant('pièce'))();

  /// Prix d'achat unitaire (GNF, sans décimales — le GNF n'a pas de subdivision usuelle).
  IntColumn get purchasePrice => integer().withDefault(const Constant(0))();

  /// Prix de vente unitaire (GNF).
  IntColumn get salePrice => integer().withDefault(const Constant(0))();

  /// Quantité actuellement en stock (vrac retiré, unités entières uniquement).
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();

  /// Seuil d'alerte de stock faible.
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(0))();

  /// Coût moyen pondéré courant (GNF) — base de valorisation.
  IntColumn get weightedAverageCost => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Chemin ou URL de la photo du produit (facultatif).
  TextColumn get imageUrl => text().nullable()();

  /// Code-barres EAN/QR du produit (facultatif — utilisé pour le scan caméra POS).
  TextColumn get barcode => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
