import '../../../../core/domain/payment_method.dart';

/// Une vente récente, données pures (aucun widget). L'icône d'affichage est
/// décidée par la présentation.
class RecentSale {
  const RecentSale({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    required this.paid,
    required this.isCancelled,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime date;
  final int amount;
  final bool paid;
  final bool isCancelled;
  final String? imageUrl;
}

/// Produit sous son seuil d'alerte, réduit à ce qu'affiche l'accueil.
class LowStockItem {
  const LowStockItem({
    required this.name,
    required this.unit,
    required this.stockQuantity,
  });

  final String name;
  final String unit;
  final int stockQuantity;
}

/// Ventes d'un jour donné, pour le graphique CA 7 jours.
class DailySalesPoint {
  const DailySalesPoint({required this.date, required this.total});
  final DateTime date;
  final int total;
}

/// Répartition d'un mode de paiement : montant total encaissé.
class PaymentBreakdownItem {
  const PaymentBreakdownItem({required this.method, required this.amount});
  final PaymentMethod method;
  final int amount;
}

/// Agrégats de l'écran Accueil, calculés côté SQL (aucune table n'est chargée
/// entièrement en mémoire). Les variations en % sont dérivées dans la couche
/// application à partir des valeurs courante / précédente.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.todaySales,
    required this.yesterdaySales,
    required this.todayProfit,
    required this.yesterdayProfit,
    required this.thisWeekSales,
    required this.prevWeekSales,
    required this.owed,
    required this.owedCount,
    required this.cashAvailable,
    required this.lowStock,
    required this.recentSales,
    required this.dailySales,
    required this.paymentBreakdown,
    required this.supplierDebt,
    required this.avgTicket,
    required this.creditRate,
  });

  final int todaySales;
  final int yesterdaySales;
  final int todayProfit;
  final int yesterdayProfit;
  final int thisWeekSales;
  final int prevWeekSales;

  /// Total restant dû sur toutes les ventes (créances).
  final int owed;

  /// Nombre de ventes partiellement ou non réglées.
  final int owedCount;

  /// Solde des comptes de trésorerie (classe 5).
  final int cashAvailable;

  /// Produits actifs sous le seuil d'alerte, du plus bas au plus haut.
  final List<LowStockItem> lowStock;

  /// Cinq ventes les plus récentes.
  final List<RecentSale> recentSales;

  /// Ventes par jour sur les 7 derniers jours (pour le graphique CA).
  final List<DailySalesPoint> dailySales;

  /// Répartition par mode de paiement.
  final List<PaymentBreakdownItem> paymentBreakdown;

  /// Dettes fournisseurs.
  final int supplierDebt;

  /// Ticket moyen.
  final double? avgTicket;

  /// Taux de ventes à crédit (0–100).
  final double? creditRate;
}
