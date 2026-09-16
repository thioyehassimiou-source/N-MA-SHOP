import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/tables/audit_logs.dart';
import '../../../../core/database/tables/expenses.dart';
import '../../../../core/database/tables/users.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/sync/desktop_sync_worker.dart';
import '../../../../core/sync/models/sync_event_payloads.dart';
import '../../../../core/sync/sync_queue_service.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../security/application/security_providers.dart';
import '../../../security/domain/services/audit_log_service.dart';

final expenseRepositoryProvider = Provider<DriftExpenseRepository>((ref) {
  final user = ref.watch(authProvider);
  return DriftExpenseRepository(
    ref.watch(databaseProvider),
    currentUserRole: user?.role,
    currentUserId: user?.id,
    currentUserName: user?.fullName,
    auditLog: ref.watch(auditLogServiceProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
  );
});

class DriftExpenseRepository {
  DriftExpenseRepository(
    this._db, {
    required UserRole? currentUserRole,
    required String? currentUserId,
    required String? currentUserName,
    required AuditLogService auditLog,
    SyncQueueService? syncQueue,
  }) : _role = currentUserRole,
       _userId = currentUserId,
       _userName = currentUserName,
       _auditLog = auditLog,
       _syncQueue = syncQueue;

  final AppDatabase _db;
  final UserRole? _role;
  final String? _userId;
  final String? _userName;
  final AuditLogService _auditLog;
  final SyncQueueService? _syncQueue;
  final _uuid = const Uuid();

  /// Enregistre une nouvelle dépense.
  Future<void> insertExpense({
    required ExpenseCategory category,
    required int amount,
    required String description,
    required DateTime date,
    required PaymentMethod paymentMethod,
    String? receiptUrl,
  }) async {
    final id = _uuid.v4();
    final ref = 'DEP-${id.substring(0, 6).toUpperCase()}';

    await _db.transaction(() async {
      await _db.into(_db.expenses).insert(
        ExpensesCompanion.insert(
          id: id,
          reference: ref,
          category: category,
          amount: amount,
          date: Value(date),
          description: description,
          paymentMethod: Value(paymentMethod),
          receiptUrl: Value(receiptUrl),
        ),
      );

      if (_syncQueue != null) {
        await _syncQueue.enqueueExpense(
          ExpenseSyncPayload(
            expenseId: id,
            reference: ref,
            categoryIndex: category.index,
            amount: amount,
            description: description,
            date: date,
            paymentMethodIndex: paymentMethod.index,
          ),
        );
      }
    });
  }

  /// Récupère toutes les dépenses.
  Future<List<Expense>> getAllExpenses() async {
    return (_db.select(_db.expenses)
          ..orderBy([(e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc)]))
        .get();
  }

  /// Supprime une dépense. Réservée à l'Admin.
  Future<void> deleteExpense(String id) async {
    // 🛡️ GUARD: seul un Admin peut supprimer une dépense.
    if (_role != UserRole.admin) {
      throw const AuthException(AuthFailure.unauthorized);
    }

    await (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();

    // 📋 AUDIT LOG
    if (_userId != null && _userName != null) {
      await _auditLog.logAction(
        userId: _userId,
        userName: _userName,
        actionType: AuditActionType.expenseDeleted,
        details: 'Dépense $id supprimée.',
      );
    }
  }
}
