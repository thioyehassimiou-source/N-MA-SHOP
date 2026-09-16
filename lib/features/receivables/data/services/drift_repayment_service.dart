import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/sync/models/sync_event_payloads.dart';
import '../../../../core/sync/sync_queue_service.dart';
import '../../domain/errors.dart';
import '../../domain/repayment_draft.dart';
import '../../domain/services/repayment_service.dart';

/// Implémentation Drift du remboursement de crédit.
///
/// Une seule transaction : répartit le montant sur les ventes dues (des plus
/// anciennes aux plus récentes), diminue leur reste dû, trace chaque règlement
/// dans `credit_payments`. Toute exception ⇒ ROLLBACK complet.
class DriftRepaymentService implements RepaymentService {
  DriftRepaymentService({
    required AppDatabase db,
    SyncQueueService? syncQueue,
    String Function()? idGenerator,
    DateTime Function()? clock,
  }) : _db = db,
       _syncQueue = syncQueue,
       _newId = idGenerator ?? (() => const Uuid().v4()),
       _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final SyncQueueService? _syncQueue;
  final String Function() _newId;
  final DateTime Function() _now;

  @override
  Future<RecordedRepayment> record(RepaymentDraft draft) {
    return _db.transaction(() async {
      final date = draft.date ?? _now();

      // Ventes encore dues, des plus anciennes aux plus récentes (FIFO).
      final openSales =
          await (_db.select(_db.sales)
                ..where(
                  (s) =>
                      s.customerId.equals(draft.customerId) &
                      s.totalAmount.isBiggerThan(s.amountPaid),
                )
                ..orderBy([(s) => OrderingTerm(expression: s.date)]))
              .get();

      final balance = openSales.fold<int>(
        0,
        (sum, s) => sum + (s.totalAmount - s.amountPaid),
      );
      if (balance <= 0) {
        throw const RepaymentDomainException(NoOutstandingDebtError());
      }
      if (draft.amount > balance) {
        throw RepaymentDomainException(ExceedsDebtError(balance));
      }

      // Répartition FIFO du montant sur les ventes dues.
      var remaining = draft.amount;
      for (final sale in openSales) {
        if (remaining <= 0) break;
        final due = sale.totalAmount - sale.amountPaid;
        final applied = remaining < due ? remaining : due;
        final paymentId = _newId();

        await _db
            .into(_db.creditPayments)
            .insert(
              CreditPaymentsCompanion.insert(
                id: paymentId,
                saleId: sale.id,
                customerId: draft.customerId,
                amount: applied,
                date: Value(date),
                paymentMethod: Value(draft.method),
              ),
            );
        await (_db.update(_db.sales)..where((s) => s.id.equals(sale.id))).write(
          SalesCompanion(amountPaid: Value(sale.amountPaid + applied)),
        );

        if (_syncQueue != null) {
          await _syncQueue.enqueueCreditPayment(
            CreditPaymentSyncPayload(
              paymentId: paymentId,
              saleId: sale.id,
              customerId: draft.customerId,
              amount: applied,
              paymentMethodIndex: draft.method.index,
              date: date,
            ),
          );
        }

        remaining -= applied;
      }

      return RecordedRepayment(
        customerId: draft.customerId,
        amountApplied: draft.amount,
        remainingBalance: balance - draft.amount,
      );
    });
  }
}
