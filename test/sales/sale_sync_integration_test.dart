import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/database/database.dart';
import 'package:nmashop/core/database/tables/audit_logs.dart';
import 'package:nmashop/core/database/tables/users.dart';
import 'package:nmashop/core/domain/payment_method.dart';
import 'package:nmashop/core/sync/sync_queue_service.dart';
import 'package:nmashop/features/auth/domain/app_user.dart';
import 'package:nmashop/features/sales/data/repositories/drift_product_repository.dart';
import 'package:nmashop/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:nmashop/features/sales/data/repositories/drift_stock_repository.dart';
import 'package:nmashop/features/sales/data/services/drift_sale_service.dart';
import 'package:nmashop/features/sales/domain/entities/sale_draft.dart';
import 'package:nmashop/features/sales/domain/errors.dart';
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
  late DriftSaleService saleService;

  final fixedClock = DateTime(2026, 9, 14, 11, 00);

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    syncQueueService = SyncQueueService(db);

    saleService = DriftSaleService(
      db: db,
      products: DriftProductRepository(db),
      stock: DriftStockRepository(db),
      sales: DriftSaleRepository(db),
      currentUser: AppUser(
        id: 'user-admin',
        fullName: 'Administrateur',
        createdAt: fixedClock,
        role: UserRole.admin,
        isActive: true,
      ),
      auditLog: _FakeAuditLog(),
      syncQueue: syncQueueService,
      clock: () => fixedClock,
    );

    // Initialiser un produit en stock
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-riz-25',
            name: 'Riz Blanc 25kg',
            purchasePrice: const Value(200000),
            salePrice: const Value(250000),
            stockQuantity: const Value(10),
            lowStockThreshold: const Value(3),
            weightedAverageCost: const Value(200000),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Sale & SyncQueue Integration Tests', () {
    test('Recording a sale successfully enqueues a sale event into sync_queue', () async {
      final draft = SaleDraft(
        lines: const [
          SaleDraftLine(
            productId: 'prod-riz-25',
            quantity: 2,
            unitPrice: 250000,
          ),
        ],
        tenders: const [
          PaymentTender(
            method: PaymentMethod.cash,
            amount: 500000,
          ),
        ],
      );

      final result = await saleService.record(draft);
      expect(result.total, equals(500000));

      // Vérifier que sync_queue contient bien 1 événement
      final pending = await syncQueueService.getPendingEvents();
      expect(pending.length, equals(1));
      expect(pending.first.entityType, equals('sale'));
      expect(pending.first.entityId, equals(result.saleId));
      expect(pending.first.action, equals('create'));

      final payload = jsonDecode(pending.first.payload) as Map<String, dynamic>;
      expect(payload['totalAmount'], equals(500000));
      expect(payload['lines'], isNotEmpty);
      expect(payload['lines'][0]['label'], equals('Riz Blanc 25kg'));
    });

    test('Cancelling a sale enqueues a cancel event into sync_queue', () async {
      final draft = SaleDraft(
        lines: const [
          SaleDraftLine(
            productId: 'prod-riz-25',
            quantity: 1,
            unitPrice: 250000,
          ),
        ],
        tenders: const [
          PaymentTender(
            method: PaymentMethod.cash,
            amount: 250000,
          ),
        ],
      );

      final sale = await saleService.record(draft);
      await saleService.cancel(sale.saleId);

      final pending = await syncQueueService.getPendingEvents();
      expect(pending.length, equals(2));
      expect(pending[0].action, equals('create'));
      expect(pending[1].action, equals('cancel'));
      expect(pending[1].entityId, equals(sale.saleId));
    });

    test('Failed sale (insufficient stock) does not insert anything in sync_queue (ROLLBACK)', () async {
      final draft = SaleDraft(
        lines: const [
          SaleDraftLine(
            productId: 'prod-riz-25',
            quantity: 999, // Impossible
            unitPrice: 250000,
          ),
        ],
        tenders: const [
          PaymentTender(
            method: PaymentMethod.cash,
            amount: 999 * 250000,
          ),
        ],
      );

      expect(() => saleService.record(draft), throwsA(isA<SaleDomainException>()));

      final count = await syncQueueService.getPendingCount();
      expect(count, equals(0));
    });
  });
}
