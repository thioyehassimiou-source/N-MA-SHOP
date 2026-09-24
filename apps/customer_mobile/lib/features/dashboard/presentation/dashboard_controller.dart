import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString(_cacheKey);
    if (cachedStr != null) {
      try {
        final decoded = jsonDecode(cachedStr);
        final cachedData = DashboardData.fromJson(decoded);
        state = state.copyWith(data: cachedData, isLoading: false);
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    final shopName = await _storage.getShopName();
    final currency = await _storage.getCurrency();

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
        return;
      }
    } catch (_) {}

    // Construction dynamique depuis la base de données locale SQLite (MobileDatabase)
    final sales = await _db.select(_db.mobileSales).get();
    final products = await _db.select(_db.mobileProducts).get();
    final expenses = await _db.select(_db.mobileExpenses).get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    int totalSales = 0;
    int salesCount = 0;
    int cashCollected = 0;
    int momoCollected = 0;
    int creditIssued = 0;

    for (final s in sales) {
      if (s.date.isAfter(todayStart) || s.date.isAtSameMomentAs(todayStart)) {
        totalSales += s.total;
        salesCount++;
        if (s.paymentMethod == 0) {
          cashCollected += s.amountPaid;
        } else if (s.paymentMethod == 1 || s.paymentMethod == 2 || s.paymentMethod == 3) {
          momoCollected += s.amountPaid;
        }
        if (s.total > s.amountPaid) {
          creditIssued += (s.total - s.amountPaid);
        }
      }
    }

    int expToday = 0;
    for (final e in expenses) {
      if (e.createdAt.isAfter(todayStart) || e.createdAt.isAtSameMomentAs(todayStart)) {
        expToday += e.amount;
      }
    }

    int lowStock = 0;
    int outOfStock = 0;
    for (final p in products) {
      if (p.stockQuantity <= 0) {
        outOfStock++;
      } else if (p.lowStockThreshold > 0 && p.stockQuantity <= p.lowStockThreshold) {
        lowStock++;
      }
    }

    final realData = DashboardData(
      shop: ShopInfo(
        id: 'local-shop',
        name: shopName.isNotEmpty ? shopName : 'Ma Boutique',
        currency: currency.isNotEmpty ? currency : 'GNF',
        lastSyncAt: DateTime.now(),
      ),
      today: DayKpis(
        totalSales: totalSales,
        totalProfit: (totalSales * 0.2 - expToday).round(), // Profit estimé
        salesCount: salesCount,
        cashCollected: cashCollected,
        momoCollected: momoCollected,
        creditIssued: creditIssued,
      ),
      yesterday: DayKpis(totalSales: 0, totalProfit: 0, salesCount: 0),
      stock: StockSummary(lowStockCount: lowStock, outOfStockCount: outOfStock),
      receivables: ReceivablesSummary(totalAmount: creditIssued, debtorsCount: creditIssued > 0 ? 1 : 0),
      unreadAlertsCount: lowStock + outOfStock,
      recentAlerts: [],
      serverTime: DateTime.now(),
      localFetchTime: DateTime.now(),
    );

    state = state.copyWith(
      data: realData,
      isLoading: false,
      isOffline: true,
      error: 'Mode local-first actif.',
    );
  }
}
