import '../entities/seller_performance.dart';

/// Détail d'une vente réalisée par un vendeur.
class SellerSaleItem {
  const SellerSaleItem({
    required this.id,
    required this.reference,
    required this.date,
    required this.customerName,
    required this.totalAmount,
    required this.amountPaid,
    required this.isCancelled,
  });

  final String id;
  final String reference;
  final DateTime date;
  final String customerName;
  final int totalAmount;
  final int amountPaid;
  final bool isCancelled;

  int get remaining => totalAmount - amountPaid;
}

/// Client servi par un vendeur avec ses statistiques associées.
class SellerCustomerItem {
  const SellerCustomerItem({
    required this.id,
    required this.name,
    this.phone,
    required this.salesCount,
    required this.totalSpent,
  });

  final String id;
  final String name;
  final String? phone;
  final int salesCount;
  final int totalSpent;
}

/// Contrat du repository dédié au suivi des vendeurs et agents commerciaux.
abstract interface class SellerRepository {
  /// Retourne la liste des performances commerciales de tous les vendeurs sur la période [start, end].
  Future<List<SellerPerformance>> getSellersPerformance({
    DateTime? start,
    DateTime? end,
  });

  /// Retourne les ventes conclues par un vendeur spécifique.
  /// Si [sellerId] est null, retourne les ventes non attribuées.
  Future<List<SellerSaleItem>> getSellerSales(
    String? sellerId, {
    DateTime? start,
    DateTime? end,
  });

  /// Retourne les clients servis par un vendeur spécifique.
  Future<List<SellerCustomerItem>> getSellerCustomers(
    String? sellerId, {
    DateTime? start,
    DateTime? end,
  });
}
