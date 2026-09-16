import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/database/database.dart';
import 'package:nmashop/core/sync/models/sync_event_payloads.dart';
import 'package:nmashop/core/sync/sync_queue_service.dart';

void main() {
  late AppDatabase db;
  late SyncQueueService syncQueueService;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    syncQueueService = SyncQueueService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncQueueService Tests', () {
    test('Initial queue should be empty', () async {
      final count = await syncQueueService.getPendingCount();
      expect(count, equals(0));

      final pending = await syncQueueService.getPendingEvents();
      expect(pending, isEmpty);
    });

    test('enqueueSale inserts event into sync_queue', () async {
      final salePayload = SaleSyncPayload(
        saleId: 'sale-001',
        reference: 'V-2026-0001',
        customerId: 'cust-1',
        customerName: 'Bah Diallo',
        date: DateTime(2026, 9, 14, 10, 30),
        totalAmount: 150000,
        amountPaid: 150000,
        paymentMethodIndex: 0,
        lines: const [
          SaleLineSyncData(
            productId: 'prod-1',
            label: 'Riz 25kg',
            quantity: 2,
            unitPrice: 75000,
            unitCost: 60000,
            lineTotal: 150000,
          ),
        ],
      );

      await syncQueueService.enqueueSale(salePayload);

      final count = await syncQueueService.getPendingCount();
      expect(count, equals(1));

      final pending = await syncQueueService.getPendingEvents();
      expect(pending.length, equals(1));
      expect(pending.first.entityType, equals('sale'));
      expect(pending.first.entityId, equals('sale-001'));
      expect(pending.first.action, equals('create'));
      expect(pending.first.attempts, equals(0));
    });

    test('enqueueCreditPayment and enqueueExpense accumulate in queue', () async {
      final payment = CreditPaymentSyncPayload(
        paymentId: 'pay-001',
        saleId: 'sale-001',
        customerId: 'cust-1',
        amount: 50000,
        date: DateTime(2026, 9, 14, 11, 00),
        paymentMethodIndex: 0,
      );

      final expense = ExpenseSyncPayload(
        expenseId: 'exp-001',
        reference: 'DEP-001',
        categoryIndex: 0,
        amount: 25000,
        date: DateTime(2026, 9, 14, 11, 15),
        description: 'Transport',
        paymentMethodIndex: 0,
      );

      await syncQueueService.enqueueCreditPayment(payment);
      await syncQueueService.enqueueExpense(expense);

      final count = await syncQueueService.getPendingCount();
      expect(count, equals(2));

      final pending = await syncQueueService.getPendingEvents();
      expect(pending.length, equals(2));
      expect(pending[0].entityType, equals('payment'));
      expect(pending[1].entityType, equals('expense'));
    });

    test('deleteEvents purges acknowledged events', () async {
      final payment = CreditPaymentSyncPayload(
        paymentId: 'pay-002',
        saleId: 'sale-002',
        customerId: 'cust-2',
        amount: 100000,
        date: DateTime(2026, 9, 14, 12, 00),
        paymentMethodIndex: 0,
      );

      await syncQueueService.enqueueCreditPayment(payment);
      final pendingBefore = await syncQueueService.getPendingEvents();
      expect(pendingBefore.length, equals(1));

      await syncQueueService.deleteEvents([pendingBefore.first.id]);

      final countAfter = await syncQueueService.getPendingCount();
      expect(countAfter, equals(0));
    });

    test('markFailed increments attempts and stores error', () async {
      final expense = ExpenseSyncPayload(
        expenseId: 'exp-002',
        reference: 'DEP-002',
        categoryIndex: 1,
        amount: 40000,
        date: DateTime(2026, 9, 14, 12, 30),
        description: 'Électricité',
        paymentMethodIndex: 0,
      );

      await syncQueueService.enqueueExpense(expense);
      final pending = await syncQueueService.getPendingEvents();
      final id = pending.first.id;

      await syncQueueService.markFailed([id], 'Network timeout error (504)');

      final updated = await (db.select(db.syncQueue)..where((t) => t.id.equals(id))).getSingle();
      expect(updated.status, equals(2));
      expect(updated.attempts, equals(1));
      expect(updated.errorMessage, contains('504'));
    });
  });
}
