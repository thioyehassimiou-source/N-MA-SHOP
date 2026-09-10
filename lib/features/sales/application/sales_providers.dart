import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../security/application/security_providers.dart';
import '../data/repositories/drift_customer_repository.dart';
import '../data/repositories/drift_product_repository.dart';
import '../data/repositories/drift_sale_repository.dart';
import '../data/repositories/drift_stock_repository.dart';
import '../data/services/drift_sale_service.dart';
import '../domain/repositories/customer_repository.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/repositories/sale_repository.dart';
import '../domain/repositories/stock_repository.dart';
import '../domain/services/sale_service.dart';
import '../domain/usecases/record_sale.dart';

/// Câblage Riverpod du moteur de vente.

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => DriftProductRepository(ref.watch(databaseProvider)),
);

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => DriftStockRepository(ref.watch(databaseProvider)),
);

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => DriftSaleRepository(ref.watch(databaseProvider)),
);

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => DriftCustomerRepository(ref.watch(databaseProvider)),
);

final saleServiceProvider = Provider<SaleService>(
  (ref) => DriftSaleService(
    db: ref.watch(databaseProvider),
    products: ref.watch(productRepositoryProvider),
    stock: ref.watch(stockRepositoryProvider),
    sales: ref.watch(saleRepositoryProvider),
    currentUser: ref.watch(authProvider),
    auditLog: ref.watch(auditLogServiceProvider),
  ),
);

final recordSaleUseCaseProvider = Provider<RecordSaleUseCase>(
  (ref) => RecordSaleUseCase(ref.watch(saleServiceProvider)),
);

/// Historique des ventes pour l'administration et le suivi complet.
final allSalesProvider = FutureProvider<List<SaleHistoryItem>>((ref) {
  return ref.watch(saleRepositoryProvider).getAllSales();
});
