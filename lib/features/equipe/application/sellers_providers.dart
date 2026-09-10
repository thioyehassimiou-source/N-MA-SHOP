import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../reports/application/reports_providers.dart';
import '../data/repositories/drift_seller_repository.dart';
import '../domain/entities/seller_performance.dart';
import '../domain/repositories/seller_repository.dart';

/// Provider du repository des vendeurs et performances commerciales.
final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftSellerRepository(db);
});

/// État de la période sélectionnée pour les performances des vendeurs.
class SellerRangeNotifier extends Notifier<ReportRange> {
  @override
  ReportRange build() => ReportRange.forPeriod(ReportPeriod.month);

  void updateRange(ReportRange range) {
    state = range;
  }
}

final sellerRangeProvider =
    NotifierProvider<SellerRangeNotifier, ReportRange>(SellerRangeNotifier.new);

/// Liste des performances de tous les vendeurs sur la période courante.
final sellerPerformancesProvider =
    FutureProvider<List<SellerPerformance>>((ref) async {
  final repo = ref.watch(sellerRepositoryProvider);
  final range = ref.watch(sellerRangeProvider);
  return repo.getSellersPerformance(start: range.start, end: range.end);
});

/// Ventes détaillées d'un vendeur donné sur la période sélectionnée.
final sellerSalesProvider =
    FutureProvider.family<List<SellerSaleItem>, String?>((ref, sellerId) async {
  final repo = ref.watch(sellerRepositoryProvider);
  final range = ref.watch(sellerRangeProvider);
  return repo.getSellerSales(sellerId, start: range.start, end: range.end);
});

/// Clients servis par un vendeur donné sur la période sélectionnée.
final sellerCustomersProvider =
    FutureProvider.family<List<SellerCustomerItem>, String?>(
        (ref, sellerId) async {
  final repo = ref.watch(sellerRepositoryProvider);
  final range = ref.watch(sellerRangeProvider);
  return repo.getSellerCustomers(sellerId, start: range.start, end: range.end);
});
