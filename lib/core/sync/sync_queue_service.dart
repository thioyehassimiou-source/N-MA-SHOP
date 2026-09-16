import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'models/sync_event_payloads.dart';

/// Service gérant l'insertion et le cycle de vie des événements dans la [SyncQueue].
class SyncQueueService {
  final AppDatabase _db;
  final Uuid _uuid;

  SyncQueueService(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  /// Enregistre un événement de vente dans la file locale.
  Future<void> enqueueSale(SaleSyncPayload sale) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            eventId: _uuid.v4(),
            entityType: 'sale',
            entityId: sale.saleId,
            action: 'create',
            payload: jsonEncode(sale.toJson()),
            createdAt: Value(sale.date),
          ),
        );
  }

  /// Enregistre une annulation de vente dans la file locale.
  Future<void> enqueueSaleCancellation(String saleId) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            eventId: _uuid.v4(),
            entityType: 'sale',
            entityId: saleId,
            action: 'cancel',
            payload: jsonEncode({'saleId': saleId, 'isCancelled': true}),
          ),
        );
  }

  /// Enregistre un remboursement / règlement de créance.
  Future<void> enqueueCreditPayment(CreditPaymentSyncPayload payment) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            eventId: _uuid.v4(),
            entityType: 'payment',
            entityId: payment.paymentId,
            action: 'create',
            payload: jsonEncode(payment.toJson()),
            createdAt: Value(payment.date),
          ),
        );
  }

  /// Enregistre un mouvement manuel de caisse (entrée ou sortie).
  Future<void> enqueueCashMovement(CashMovementSyncPayload movement) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            eventId: _uuid.v4(),
            entityType: 'cashMovement',
            entityId: movement.movementId,
            action: 'create',
            payload: jsonEncode(movement.toJson()),
            createdAt: Value(movement.date),
          ),
        );
  }

  /// Enregistre une dépense opérationnelle.
  Future<void> enqueueExpense(ExpenseSyncPayload expense) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            eventId: _uuid.v4(),
            entityType: 'expense',
            entityId: expense.expenseId,
            action: 'create',
            payload: jsonEncode(expense.toJson()),
            createdAt: Value(expense.date),
          ),
        );
  }

  /// Enregistre un mouvement de stock.
  Future<void> enqueueStockMovement(StockMovementSyncPayload movement) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            eventId: _uuid.v4(),
            entityType: 'stock',
            entityId: movement.movementId,
            action: 'create',
            payload: jsonEncode(movement.toJson()),
            createdAt: Value(movement.date),
          ),
        );
  }

  /// Nombre maximal d'essais avant mise au rebut (dead-letter).
  static const int maxAttempts = 10;

  /// Calcule le délai de temporisation (backoff) en secondes selon le nombre de tentatives.
  static int calculateBackoffSeconds(int attempts) {
    if (attempts <= 1) return 30;
    if (attempts == 2) return 60;
    if (attempts == 3) return 120;
    if (attempts == 4) return 300;
    return 600;
  }

  /// Récupère les événements en attente prêts pour l'envoi en respectant le backoff.
  Future<List<SyncQueueData>> getPendingEvents({int limit = 50}) async {
    final now = DateTime.now();
    final candidates = await (_db.select(_db.syncQueue)
          ..where((t) => t.status.equals(0) | (t.status.equals(2) & t.attempts.isSmallerThanValue(maxAttempts)))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit * 2))
        .get();

    return candidates.where((item) {
      if (item.status == 0) return true; // Nouvel événement : envoi immédiat
      if (item.lastAttemptAt == null) return true;
      final waitSec = calculateBackoffSeconds(item.attempts);
      return now.difference(item.lastAttemptAt!).inSeconds >= waitSec;
    }).take(limit).toList();
  }

  /// Nombre d'événements locaux en attente de synchronisation.
  Future<int> getPendingCount() async {
    final countExpr = _db.syncQueue.id.count();
    final row = await (_db.selectOnly(_db.syncQueue)..addColumns([countExpr])).getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Supprime les événements de la file après confirmation d'ingestion par le serveur.
  Future<void> deleteEvents(List<int> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(_db.syncQueue)..where((t) => t.id.isIn(ids))).go();
  }

  /// Enregistre un échec d'envoi pour un lot d'événements avec incrémentation et backoff.
  Future<void> markFailed(List<int> ids, String errorMessage) async {
    if (ids.isEmpty) return;
    final now = DateTime.now();
    for (final id in ids) {
      final existing = await (_db.select(_db.syncQueue)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        final newAttempts = existing.attempts + 1;
        final isDeadLetter = newAttempts >= maxAttempts;
        await (_db.update(_db.syncQueue)..where((t) => t.id.equals(id))).write(
          SyncQueueCompanion(
            status: Value(isDeadLetter ? 3 : 2), // 3 = dead-letter, 2 = failed-retryable
            attempts: Value(newAttempts),
            lastAttemptAt: Value(now),
            errorMessage: Value(errorMessage),
          ),
        );
      }
    }
  }
}
