import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/sync/desktop_sync_worker.dart';
import '../data/repositories/drift_receivables_repository.dart';
import '../data/services/drift_repayment_service.dart';
import '../domain/credit_summary.dart';
import '../domain/repositories/receivables_repository.dart';
import '../domain/services/repayment_service.dart';
import '../domain/usecases/record_repayment.dart';

/// Câblage Riverpod du cahier de crédit.

final receivablesRepositoryProvider = Provider<ReceivablesRepository>(
  (ref) => DriftReceivablesRepository(ref.watch(databaseProvider)),
);

/// Flux réactif des clients débiteurs (se met à jour à chaque vente/règlement).
final creditSummariesProvider = StreamProvider<List<CreditSummary>>(
  (ref) => ref.watch(receivablesRepositoryProvider).watchCreditSummaries(),
);

final repaymentServiceProvider = Provider<RepaymentService>(
  (ref) => DriftRepaymentService(
    db: ref.watch(databaseProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
  ),
);

final recordRepaymentUseCaseProvider = Provider<RecordRepaymentUseCase>(
  (ref) => RecordRepaymentUseCase(ref.watch(repaymentServiceProvider)),
);
