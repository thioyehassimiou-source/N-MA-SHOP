import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/database/database.dart';
import 'package:nmashop/core/database/tables/audit_logs.dart';
import 'package:nmashop/core/database/tables/expenses.dart';
import 'package:nmashop/core/database/tables/users.dart';
import 'package:nmashop/core/domain/cash_movement_type.dart';
import 'package:nmashop/core/sync/sync_queue_service.dart';
import 'package:nmashop/features/caisse/data/repositories/drift_caisse_repository.dart';
import 'package:nmashop/features/expenses/data/repositories/drift_expense_repository.dart';
import 'package:nmashop/features/receivables/data/services/drift_repayment_service.dart';
import 'package:nmashop/features/receivables/domain/repayment_draft.dart';
import 'package:nmashop/features/security/domain/services/audit_log_service.dart';

class _FakeAuditLog implements AuditLogService {
  @override
  Future<List<AuditLog>> getLogs() async => [];

  @override
  Future<void> logAction({
    required String userId,
    required String userName,
    required AuditActionType actionType,
    required String details,
  }) async {}
}

void main() {
  late AppDatabase db;
  late SyncQueueService syncQueueService;

  final testDate = DateTime(2026, 9, 14, 15, 30);

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    syncQueueService = SyncQueueService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncQueue Integration for Expenses, Repayments and Cash Movements', () {
    test('DriftExpenseRepository.insertExpense enqueues an expense into sync_queue', () async {
      final repo = DriftExpenseRepository(
        db,
        currentUserRole: UserRole.admin,
        currentUserId: 'admin-1',
        currentUserName: 'Admin',
        auditLog: _FakeAuditLog(),
        syncQueue: syncQueueService,
      );

      await repo.insertExpense(
        category: ExpenseCategory.rent,
        amount: 750000,
        description: 'Loyer boutique Septembre',
        date: testDate,
        paymentMethod: PaymentMethod.cash,
      );

      // Vérifier table expenses
      final expenses = await db.select(db.expenses).get();
      expect(expenses.length, equals(1));
      expect(expenses.first.amount, equals(750000));

      // Vérifier sync_queue
      final pending = await syncQueueService.getPendingEvents();
      expect(pending.length, equals(1));
      expect(pending.first.entityType, equals('expense'));
      expect(pending.first.action, equals('create'));

      final payload = jsonDecode(pending.first.payload) as Map<String, dynamic>;
      expect(payload['amount'], equals(750000));
      expect(payload['categoryIndex'], equals(ExpenseCategory.rent.index));
      expect(payload['description'], equals('Loyer boutique Septembre'));
    });

    test('DriftRepaymentService.record enqueues credit payments into sync_queue', () async {
      final repaymentService = DriftRepaymentService(
        db: db,
        syncQueue: syncQueueService,
        clock: () => testDate,
      );

      // Créer un client et une vente à crédit
      const customerId = 'cust-diallo';
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: customerId,
              name: 'Mamadou Diallo',
              phone: const Value('+224620000000'),
            ),
          );

      const saleId = 'sale-credit-1';
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: saleId,
              reference: 'FAC-CREDIT-01',
              customerId: const Value(customerId),
              totalAmount: const Value(500000),
              amountPaid: const Value(200000), // Reste 300 000 GNF
              paymentMethod: const Value(PaymentMethod.credit),
              date: Value(testDate),
            ),
          );

      // Remboursement de 150 000 GNF
      final draft = RepaymentDraft(
        customerId: customerId,
        amount: 150000,
        method: PaymentMethod.cash,
        date: testDate,
      );

      final result = await repaymentService.record(draft);
      expect(result.amountApplied, equals(150000));
      expect(result.remainingBalance, equals(150000));

      // Vérifier sync_queue
      final pending = await syncQueueService.getPendingEvents();
      expect(pending.length, equals(1));
      expect(pending.first.entityType, equals('payment'));
      expect(pending.first.action, equals('create'));

      final payload = jsonDecode(pending.first.payload) as Map<String, dynamic>;
      expect(payload['amount'], equals(150000));
      expect(payload['customerId'], equals(customerId));
      expect(payload['saleId'], equals(saleId));
      expect(payload['paymentMethodIndex'], equals(PaymentMethod.cash.index));
    });

    test('DriftCaisseRepository.insertMovement enqueues cash movements into sync_queue', () async {
      final caisseRepo = DriftCaisseRepository(
        db,
        syncQueue: syncQueueService,
      );

      await caisseRepo.insertMovement(
        type: CashMovementType.outflow,
        description: 'Achat ampoules caisse',
        amount: 35000,
        paymentMethod: PaymentMethod.cash,
      );

      final movements = await db.select(db.cashMovements).get();
      expect(movements.length, equals(1));
      expect(movements.first.amount, equals(35000));

      final pending = await syncQueueService.getPendingEvents();
      expect(pending.length, equals(1));
      expect(pending.first.entityType, equals('cashMovement'));
      expect(pending.first.action, equals('create'));

      final payload = jsonDecode(pending.first.payload) as Map<String, dynamic>;
      expect(payload['amount'], equals(35000));
      expect(payload['typeIndex'], equals(CashMovementType.outflow.index));
      expect(payload['description'], equals('Achat ampoules caisse'));
    });
  });
}
