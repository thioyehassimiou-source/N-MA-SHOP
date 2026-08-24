import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../data/repositories/drift_dashboard_repository.dart';
import '../domain/entities/dashboard_snapshot.dart';
import '../domain/repositories/dashboard_repository.dart';

export '../domain/entities/dashboard_snapshot.dart'
    show DailySalesPoint, PaymentBreakdownItem;

/// Une vente récente, prête à l'affichage (langage commerçant).
class RecentSaleView {
  const RecentSaleView({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.date,
    required this.amount,
    required this.paid,
    required this.isCancelled,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final DateTime date;
  final int amount;
  final bool paid;
  final bool isCancelled;
  final String? imageUrl;
}

/// Toutes les données de l'écran Accueil.
class DashboardData {
  const DashboardData({
    required this.todaySales,
    required this.todayProfit,
    required this.owed,
    required this.owedCount,
    required this.cashAvailable,
    required this.lowStock,
    required this.recentSales,
    required this.salesGrowth,
    required this.profitGrowth,
    required this.weeklyGrowth,
    required this.dailySales,
    required this.paymentBreakdown,
    this.supplierDebt = 0,
    this.avgTicket,
    this.creditRate,
  });

  final int todaySales;
  final int todayProfit;
  final int owed;
  final int owedCount;
  final int cashAvailable;
  final List<LowStockItem> lowStock;
  final List<RecentSaleView> recentSales;

  /// Variations en % (null si pas de référence antérieure).
  final double? salesGrowth;
  final double? profitGrowth;
  final double? weeklyGrowth;

  /// Ventes par jour sur 7 jours (graphique CA).
  final List<DailySalesPoint> dailySales;

  /// Répartition par mode de paiement.
  final List<PaymentBreakdownItem> paymentBreakdown;

  /// Indicateurs enrichis.
  final int supplierDebt;
  final double? avgTicket;
  final double? creditRate;
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DriftDashboardRepository(ref.watch(databaseProvider)),
);

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final snapshot = await ref
      .watch(dashboardRepositoryProvider)
      .load(DateTime.now());

  double? growth(int current, int previous) =>
      previous <= 0 ? null : (current - previous) / previous * 100;

  return DashboardData(
    todaySales: snapshot.todaySales,
    todayProfit: snapshot.todayProfit,
    owed: snapshot.owed,
    owedCount: snapshot.owedCount,
    cashAvailable: snapshot.cashAvailable,
    lowStock: snapshot.lowStock,
    recentSales: snapshot.recentSales.map((s) {
      return RecentSaleView(
        id: s.id,
        title: s.title,
        subtitle: s.subtitle,
        icon: Icons.shopping_bag_outlined,
        date: s.date,
        amount: s.amount,
        paid: s.paid,
        isCancelled: s.isCancelled,
        imageUrl: s.imageUrl,
      );
    }).toList(),
    salesGrowth: growth(snapshot.todaySales, snapshot.yesterdaySales),
    profitGrowth: growth(snapshot.todayProfit, snapshot.yesterdayProfit),
    weeklyGrowth: growth(snapshot.thisWeekSales, snapshot.prevWeekSales),
    dailySales: snapshot.dailySales,
    paymentBreakdown: snapshot.paymentBreakdown,
    supplierDebt: snapshot.supplierDebt,
    avgTicket: snapshot.avgTicket,
    creditRate: snapshot.creditRate,
  );
});

