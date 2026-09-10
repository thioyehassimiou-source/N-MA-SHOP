import '../../../../core/database/tables/users.dart';

/// Performances commerciales consolidées d'un vendeur sur une période donnée.
class SellerPerformance {
  const SellerPerformance({
    required this.sellerId,
    required this.sellerName,
    this.role,
    this.isActive = true,
    this.commissionRate = 0.0,
    required this.salesCount,
    required this.totalRevenue,
    required this.totalCollected,
    required this.totalRemaining,
    required this.customersServedCount,
  });

  /// Identifiant de l'utilisateur (null si vente antérieure non attribuée).
  final String? sellerId;

  /// Nom d'affichage du vendeur (ou "Non attribué").
  final String sellerName;

  /// Rôle de l'utilisateur.
  final UserRole? role;

  /// Compte actif ou archivé/désactivé.
  final bool isActive;

  /// Taux de commission en pourcentage (ex: 5.0 pour 5%).
  final double commissionRate;

  /// Nombre total de ventes conclues sur la période.
  final int salesCount;

  /// Chiffre d'affaires total généré (GNF).
  final int totalRevenue;

  /// Montant total effectivement encaissé au comptant (GNF).
  final int totalCollected;

  /// Montant total restant à recouvrer / crédits accordés (GNF).
  final int totalRemaining;

  /// Nombre de clients uniques servis.
  final int customersServedCount;

  /// Montant de la commission due (GNF).
  int get commissionAmount => (totalRevenue * (commissionRate / 100)).round();

  /// Panier moyen (GNF).
  int get averageBasket => salesCount > 0 ? (totalRevenue / salesCount).round() : 0;

  /// Taux de recouvrement en % (encaissé / CA).
  double get collectionRate =>
      totalRevenue > 0 ? (totalCollected / totalRevenue) * 100 : 100.0;
}
