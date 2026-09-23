import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  return DashboardController(apiClient, storage);
});

class DashboardController extends StateNotifier<DashboardState> {
  final ApiClient _apiClient;
  final StorageService _storage;
  static const _cacheKey = 'nmashop_dashboard_cache';

  DashboardController(this._apiClient, this._storage) : super(const DashboardState(isLoading: true)) {
    loadCachedThenFetch();
  }

  Future<void> loadCachedThenFetch() async {
    // 1. Charger le cache local en premier s'il existe
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString(_cacheKey);
    if (cachedStr != null) {
      try {
        final decoded = jsonDecode(cachedStr);
        final cachedData = DashboardData.fromJson(decoded);
        state = state.copyWith(data: cachedData, isLoading: false);
      } catch (_) {}
    }

    // 2. Tenter la synchronisation ou construire l'état réel local
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

        // Sauvegarder dans le cache local
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

    // Fallback local-first : Construction dynamique avec le VRAI nom de boutique et les VRAIES données locales
    final realData = DashboardData(
      shop: ShopInfo(
        id: 'local-shop',
        name: shopName.isNotEmpty ? shopName : 'Ma Boutique',
        currency: currency.isNotEmpty ? currency : 'GNF',
        lastSyncAt: DateTime.now(),
      ),
      today: DayKpis(
        totalSales: 0,
        totalProfit: 0,
        salesCount: 0,
        cashCollected: 0,
        momoCollected: 0,
        creditIssued: 0,
      ),
      yesterday: DayKpis(totalSales: 0, totalProfit: 0, salesCount: 0),
      stock: StockSummary(lowStockCount: 0, outOfStockCount: 0),
      receivables: ReceivablesSummary(totalAmount: 0, debtorsCount: 0),
      unreadAlertsCount: 0,
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
