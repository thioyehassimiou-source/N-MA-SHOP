import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/domain/cash_movement_type.dart';
import '../../../../core/domain/payment_method.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/sync/desktop_sync_worker.dart';
import '../../../../core/sync/models/sync_event_payloads.dart';
import '../../../../core/sync/sync_queue_service.dart';

final caisseRepositoryProvider = Provider<DriftCaisseRepository>((ref) {
  return DriftCaisseRepository(
    ref.watch(databaseProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
  );
});

class DriftCaisseRepository {
  DriftCaisseRepository(this._db, {SyncQueueService? syncQueue}) : _syncQueue = syncQueue;

  final AppDatabase _db;
  final SyncQueueService? _syncQueue;
  final _uuid = const Uuid();

  /// Enregistre un mouvement manuel de caisse (Entrée ou Sortie).
  Future<void> insertMovement({
    required CashMovementType type,
    required String description,
    required int amount,
    required PaymentMethod paymentMethod,
  }) async {
    final id = _uuid.v4();
    final isOutflow = type == CashMovementType.outflow;
    final prefix = isOutflow ? 'DEC' : 'ENC';
    final ref = '$prefix-${id.substring(0, 6).toUpperCase()}';
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.into(_db.cashMovements).insert(
        CashMovementsCompanion.insert(
          id: id,
          reference: ref,
          description: description,
          amount: amount,
          type: type,
          date: Value(now),
          paymentMethod: Value(paymentMethod),
        ),
      );

      if (_syncQueue != null) {
        await _syncQueue.enqueueCashMovement(
          CashMovementSyncPayload(
            movementId: id,
            reference: ref,
            description: description,
            amount: amount,
            typeIndex: type.index,
            paymentMethodIndex: paymentMethod.index,
            date: now,
          ),
        );
      }
    });
  }
}
