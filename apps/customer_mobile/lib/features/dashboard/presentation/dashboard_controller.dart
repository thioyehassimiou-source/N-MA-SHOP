import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
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
  return DashboardController(apiClient);
});

class DashboardController extends StateNotifier<DashboardState> {
  final ApiClient _apiClient;
  static const _cacheKey = 'nmashop_dashboard_cache';

  DashboardController(this._apiClient) : super(const DashboardState(isLoading: true)) {
    loadCachedThenFetch();
  }

  Future<void> loadCachedThenFetch() async {
    // 1. Charger le cache local en premier
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString(_cacheKey);
    if (cachedStr != null) {
      try {
        final decoded = jsonDecode(cachedStr);
        final cachedData = DashboardData.fromJson(decoded);
        state = state.copyWith(data: cachedData, isLoading: false);
      } catch (_) {}
    }

    // 2. Tenter la synchronisation avec le Cloud
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

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
      } else {
        state = state.copyWith(
          isLoading: false,
          isOffline: true,
          error: 'Impossible de joindre le serveur.',
        );
      }
    } catch (e) {
      final fallbackData = state.data ??
          DashboardData(
            shop: ShopInfo(id: 'demo-shop', name: 'Boutique Diallo & Frères', currency: 'GNF', lastSyncAt: DateTime.now()),
            today: DayKpis(
              totalSales: 4850000,
              totalProfit: 1250000,
              salesCount: 18,
              cashCollected: 3100000,
              momoCollected: 1250000,
              creditIssued: 500000,
            ),
            yesterday: DayKpis(totalSales: 3900000, totalProfit: 980000, salesCount: 14),
            stock: StockSummary(lowStockCount: 3, outOfStockCount: 1),
            receivables: ReceivablesSummary(totalAmount: 2750000, debtorsCount: 3),
            unreadAlertsCount: 2,
            recentAlerts: [
              AlertItem(
                id: 'alt-1',
                type: 'stock',
                severity: 'critical',
                title: 'Rupture de stock imminente',
                message: 'Huile Mayonnaise 5L épuisée en magasin.',
                isRead: false,
                createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
              ),
              AlertItem(
                id: 'alt-2',
                type: 'caisse',
                severity: 'warning',
                title: 'Solde d\'espèces caisse',
                message: 'Écart théorique détecté lors du dernier contrôle.',
                isRead: false,
                createdAt: DateTime.now().subtract(const Duration(hours: 2)),
              ),
            ],
            serverTime: DateTime.now(),
            localFetchTime: DateTime.now(),
          );

      state = state.copyWith(
        data: fallbackData,
        isLoading: false,
        isOffline: true,
        error: 'Mode hors-ligne : données locales affichées.',
      );
    }
  }
}
