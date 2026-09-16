import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../data/repositories/drift_suppliers_repository.dart';
import '../data/services/drift_purchase_service.dart';
import '../domain/repositories/suppliers_repository.dart';
import '../domain/supplier_summary.dart';

import '../../auth/application/auth_providers.dart';
import '../../security/application/security_providers.dart';

import '../../../core/sync/desktop_sync_worker.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return DriftSuppliersRepository(ref.watch(databaseProvider));
});

final purchaseServiceProvider = Provider<DriftPurchaseService>((ref) {
  return DriftPurchaseService(
    ref.watch(databaseProvider),
    ref.watch(authProvider),
    ref.watch(auditLogServiceProvider),
    ref.watch(syncQueueServiceProvider),
  );
});

/// Flux réactif de tous les fournisseurs ayant une dette ou un achat enregistré.
final supplierSummariesProvider = StreamProvider<List<SupplierSummary>>((ref) {
  return ref.watch(suppliersRepositoryProvider).watchSupplierSummaries();
});

/// Flux réactif des achats récents
final recentPurchasesProvider = StreamProvider<List<RecentPurchaseView>>((ref) {
  return ref.watch(suppliersRepositoryProvider).watchRecentPurchases();
});
