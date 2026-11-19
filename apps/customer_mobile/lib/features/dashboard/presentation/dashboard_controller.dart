import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/mobile_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/dashboard_models.dart';

class DashboardState {
  final DashboardData? data;
  final bool isLoading;
  final bool isOffline;
  final String? error;

  const DashboardState({
    this.data,
    this.isLoading = false,
    this.isOffline = false,
    this.error,
  });

  DashboardState copyWith({
    DashboardData? data,
    bool? isLoading,
    bool? isOffline,
    String? error,
  }) {
    return DashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
      error: error,
    );
  }
}

final dashboardControllerProvider = StateNotifierProvider<DashboardController, DashboardState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  final db = ref.watch(mobileDatabaseProvider);
  return DashboardController(apiClient, storage, db);
});

class DashboardController extends StateNotifier<DashboardState> {
  final ApiClient _apiClient;
  final StorageService _storage;
  final MobileDatabase _db;
  static const _cacheKey = 'nmashop_dashboard_cache';

  DashboardController(this._apiClient, this._storage, this._db) : super(const DashboardState(isLoading: true)) {
    loadCachedThenFetch();
  }

  Future<void> loadCachedThenFetch() async {
    // 1. Calcul immédiat depuis SQLite local (zéro mock/dummy data)
    await refresh();
  }

  Future<void> refresh() async {
    final shopName = await _storage.getShopName();
    final currency = await _storage.getCurrency();

    // 1. Priorité absolue au local-first : calcul immédiat 100% dynamique depuis SQLite
    try {
      final sales = await _db.select(_db.mobileSales).get();
      final saleItems = await _db.select(_db.mobileSaleItems).get();
      final products = await _db.select(_db.mobileProducts).get();
      final expenses = await _db.select(_db.mobileExpenses).get();
      final purchases = await _db.select(_db.mobilePurchases).get();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final todayDateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));

      final prefs = await SharedPreferences.getInstance();
      int openingFloat = prefs.getInt('nmashop_cash_float_$todayDateKey') ?? 0;
      try {
        final treasuryRows = await _db.customSelect(
          'SELECT opening_float FROM mobile_treasury WHERE date_key = ? LIMIT 1',
          variables: [drift.Variable.withString(todayDateKey)],
        ).get();
        if (treasuryRows.isNotEmpty) {
          openingFloat = treasuryRows.first.read<int>('opening_float');
        }
      } catch (_) {}

      // Calcul des coûts unitaires pour profit réel
      final Map<String, int> saleCosts = {};
      for (final item in saleItems) {
        int itemUnitCost = item.unitCost;
        if (itemUnitCost <= 0) {
          final prod = products.where((p) => p.id == item.productId).firstOrNull;
          if (prod != null) {
            itemUnitCost = prod.weightedAverageCost > 0 ? prod.weightedAverageCost : prod.purchasePrice;
          }
        }
        saleCosts[item.saleId] = (saleCosts[item.saleId] ?? 0) + (itemUnitCost * item.quantity);
      }

      int totalSales = 0;
      int salesCount = 0;
      int cashCollected = 0;
      int momoCollected = 0;
      int cardCollected = 0;
      int creditIssued = 0;
      int totalCostOfSales = 0;

      for (final s in sales) {
        if (s.isCancelled) continue;
        if (s.date.isAfter(todayStart.subtract(const Duration(milliseconds: 1))) && s.date.isBefore(todayEnd)) {
          totalSales += s.total;
          salesCount++;
          if (s.paymentMethod == 0) {
            cashCollected += s.amountPaid;
          } else if (s.paymentMethod == 1 || s.paymentMethod == 2 || s.paymentMethod == 3) {
            momoCollected += s.amountPaid;
          } else if (s.paymentMethod == 4) {
            cardCollected += s.amountPaid;
          }
          if (s.total > s.amountPaid) {
            creditIssued += (s.total - s.amountPaid);
          }
          totalCostOfSales += saleCosts[s.id] ?? 0;
        }
      }

      int expToday = 0;
      for (final e in expenses) {
        if (e.createdAt.isAfter(todayStart.subtract(const Duration(milliseconds: 1))) && e.createdAt.isBefore(todayEnd)) {
          expToday += e.amount;
        }
      }

      // Solde de caisse réel physique en tiroir : Fond d'ouverture + Ventes cash - Dépenses espèces
      final cashInBox = (openingFloat + cashCollected - expToday).clamp(0, 9999999999);
      final grossMargin = totalSales - totalCostOfSales;
      final totalProfit = grossMargin - expToday;

      // Calcul 100% dynamique de la veille (hier)
      int yesterdaySales = 0;
      int yesterdayCount = 0;
      int yesterdayCost = 0;
      for (final s in sales) {
        if (!s.isCancelled && s.date.isAfter(yesterdayStart.subtract(const Duration(milliseconds: 1))) && s.date.isBefore(todayStart)) {
          yesterdaySales += s.total;
          yesterdayCount++;
          yesterdayCost += saleCosts[s.id] ?? 0;
        }
      }
      int yesterdayExpenses = 0;
      for (final e in expenses) {
        if (e.createdAt.isAfter(yesterdayStart.subtract(const Duration(milliseconds: 1))) && e.createdAt.isBefore(todayStart)) {
          yesterdayExpenses += e.amount;
        }
      }
      final yesterdayProfit = (yesterdaySales - yesterdayCost) - yesterdayExpenses;

      // Alertes de stock dynamiques
      int lowStock = 0;
      int outOfStock = 0;
      for (final p in products) {
        if (p.stockQuantity <= 0) {
          outOfStock++;
        } else if (p.lowStockThreshold > 0 && p.stockQuantity <= p.lowStockThreshold) {
          lowStock++;
        }
      }

      // Créances réelles (crédits accordés impayés)
      int totalReceivables = 0;
      final Set<String> distinctDebtors = {};
      for (final s in sales) {
        if (!s.isCancelled && s.total > s.amountPaid) {
          totalReceivables += (s.total - s.amountPaid);
          final key = (s.customerId != null && s.customerId!.trim().isNotEmpty)
              ? s.customerId!.trim()
              : s.reference;
          distinctDebtors.add(key);
        }
      }

      // Dettes réelles envers les fournisseurs
      int totalSupplierDebts = 0;
      for (final p in purchases) {
        if (!p.isCancelled && p.totalAmount > p.amountPaid) {
          totalSupplierDebts += (p.totalAmount - p.amountPaid);
        }
      }

      final localData = DashboardData(
        shop: ShopInfo(
          id: 'local-shop',
          name: shopName.isNotEmpty ? shopName : 'Ma Boutique N\'MaShop',
          currency: currency.isNotEmpty ? currency : 'GNF',
          lastSyncAt: DateTime.now(),
        ),
        today: DayKpis(
          totalSales: totalSales,
          totalProfit: totalProfit,
          salesCount: salesCount,
          cashCollected: cashCollected,
          momoCollected: momoCollected,
          cardCollected: cardCollected,
          creditIssued: creditIssued,
          cashInBox: cashInBox,
          expenses: expToday,
        ),
        yesterday: DayKpis(
          totalSales: yesterdaySales,
          totalProfit: yesterdayProfit,
          salesCount: yesterdayCount,
        ),
        stock: StockSummary(lowStockCount: lowStock, outOfStockCount: outOfStock),
        receivables: ReceivablesSummary(
          totalAmount: totalReceivables,
          debtorsCount: distinctDebtors.length,
          debtsToSuppliers: totalSupplierDebts,
        ),
        unreadAlertsCount: lowStock + outOfStock,
        recentAlerts: [],
        serverTime: DateTime.now(),
        localFetchTime: DateTime.now(),
      );

      state = state.copyWith(
        data: localData,
        isLoading: false,
        isOffline: true,
        error: null,
      );
    } catch (_) {
      // Données propres à 0 si SQLite est encore vide
      state = state.copyWith(
        data: DashboardData(
          shop: ShopInfo(
            id: 'local-shop',
            name: shopName.isNotEmpty ? shopName : 'Ma Boutique N\'MaShop',
            currency: currency.isNotEmpty ? currency : 'GNF',
            lastSyncAt: DateTime.now(),
          ),
          today: DayKpis(totalSales: 0, totalProfit: 0, salesCount: 0, cashCollected: 0, momoCollected: 0, cardCollected: 0, creditIssued: 0, cashInBox: 0, expenses: 0),
          yesterday: DayKpis(totalSales: 0, totalProfit: 0, salesCount: 0),
          stock: StockSummary(lowStockCount: 0, outOfStockCount: 0),
          receivables: ReceivablesSummary(totalAmount: 0, debtorsCount: 0, debtsToSuppliers: 0),
          unreadAlertsCount: 0,
          recentAlerts: [],
          serverTime: DateTime.now(),
          localFetchTime: DateTime.now(),
        ),
        isLoading: false,
        isOffline: true,
        error: null,
      );
    }

    // 2. Synchronisation distante en arrière-plan sans bloquer l'interface
    try {
      final response = await _apiClient.get('/api/v1/mobile/dashboard');
      if (response.statusCode == 200 && response.data != null) {
        final data = DashboardData.fromJson(response.data as Map<String, dynamic>);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(response.data));

        state = state.copyWith(
          data: data,
          isLoading: false,
          isOffline: false,
          error: null,
        );
      }
    } catch (_) {}
  }
}
