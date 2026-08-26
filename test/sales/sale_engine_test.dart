import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/database/database.dart';
import 'package:nmashop/core/database/tables/stock.dart';
import 'package:nmashop/core/domain/payment_method.dart';
import 'package:nmashop/features/sales/data/repositories/drift_product_repository.dart';
import 'package:nmashop/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:nmashop/features/sales/data/repositories/drift_stock_repository.dart';
import 'package:nmashop/features/sales/data/services/drift_sale_service.dart';
import 'package:nmashop/features/sales/domain/entities/sale_draft.dart';
import 'package:nmashop/features/sales/domain/errors.dart';
import 'package:nmashop/features/sales/domain/usecases/record_sale.dart';
import 'package:nmashop/features/security/domain/services/audit_log_service.dart';
import 'package:nmashop/core/database/tables/audit_logs.dart';
import 'package:nmashop/features/auth/domain/app_user.dart';
import 'package:nmashop/core/database/tables/users.dart';

class FakeAuditLogService implements AuditLogService {
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

/// Banc d'essai du moteur : vraie base en mémoire, IDs déterministes, horloge figée.
class _Engine {
  _Engine(this.db) {
    var seq = 0;
    String nextId() => 'id-${seq++}';
    final fixedClock = DateTime(2026, 7, 7, 10);

    final service = DriftSaleService(
      db: db,
      products: DriftProductRepository(db),
      stock: DriftStockRepository(db, idGenerator: nextId),
      sales: DriftSaleRepository(db),
      currentUser: AppUser(
        id: 'admin-1',
        fullName: 'Admin Test',
        createdAt: fixedClock,
        role: UserRole.admin,
        isActive: true,
      ),
      auditLog: FakeAuditLogService(),
      idGenerator: nextId,
      clock: () => fixedClock,
    );
    this.service = service;
    useCase = RecordSaleUseCase(service);
  }

  final AppDatabase db;
  late final DriftSaleService service;
  late final RecordSaleUseCase useCase;
}

Future<void> _addProduct(
  AppDatabase db, {
  required String id,
  required String name,
  int salePrice = 0,
  int stock = 0,
  int cmp = 0,
  String unit = 'pièce',
}) {
  return db.into(db.products).insert(ProductsCompanion.insert(
        id: id,
        name: name,
        salePrice: Value(salePrice),
        stockQuantity: Value(stock),
        weightedAverageCost: Value(cmp),
        unit: Value(unit),
      ));
}

void main() {
  late AppDatabase db;
  late _Engine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = _Engine(db);
  });

  tearDown(() => db.close());

  test('Vente normale en espèces : vente, ligne, stock, encaissement', () async {
    await _addProduct(db,
        id: 'p1', name: 'Huile', salePrice: 150000, stock: 10, cmp: 100000);

    final result = await engine.useCase(SaleDraft(
      lines: const [SaleDraftLine(productId: 'p1', quantity: 2, unitPrice: 150000)],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 300000)],
    ));

    expect(result, isA<RecordSaleSuccess>());
    final sale = (result as RecordSaleSuccess).sale;
    expect(sale.total, 300000);
    expect(sale.amountPaid, 300000);
    expect(sale.creditAmount, 0);
    expect(sale.dominantMethod, PaymentMethod.cash);
    expect(sale.reference, 'V-2026-000001');

    final sales = await db.select(db.sales).get();
    expect(sales, hasLength(1));
    final items = await db.select(db.saleItems).get();
    expect(items, hasLength(1));
    expect(items.single.unitCost, 100000);

    final product = await (db.select(db.products)
          ..where((t) => t.id.equals('p1')))
        .getSingle();
    expect(product.stockQuantity, 8); // 10 - 2
  });

  test('Bénéfice = total − coût des marchandises (CMP)', () async {
    await _addProduct(db,
        id: 'p1', name: 'Sucre', salePrice: 12000, stock: 100, cmp: 9000);

    final result = await engine.useCase(SaleDraft(
      lines: const [SaleDraftLine(productId: 'p1', quantity: 5, unitPrice: 12000)],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 60000)],
    )) as RecordSaleSuccess;

    // 5 × 12000 = 60000 ; coût 5 × 9000 = 45000 ; marge = 15000.
    expect(result.sale.total, 60000);
    expect(result.sale.profit, 15000);
  });

  test('Vente multi-produits : totaux, lignes et mouvements corrects', () async {
    await _addProduct(db,
        id: 'p1', name: 'Huile', salePrice: 150000, stock: 10, cmp: 100000);
    await _addProduct(db,
        id: 'p2', name: 'Riz', salePrice: 50000, stock: 20, cmp: 40000);

    final result = await engine.useCase(SaleDraft(
      lines: const [
        SaleDraftLine(productId: 'p1', quantity: 1, unitPrice: 150000),
        SaleDraftLine(productId: 'p2', quantity: 3, unitPrice: 50000),
      ],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 300000)],
    )) as RecordSaleSuccess;

    expect(result.sale.total, 300000); // 150000 + 150000
    expect(result.sale.profit, 300000 - (100000 + 3 * 40000)); // 80000

    final items = await db.select(db.saleItems).get();
    expect(items, hasLength(2));

    final movements = await db.select(db.stockMovements).get();
    expect(movements, hasLength(2));
    expect(movements.every((m) => m.quantity < 0), isTrue); // sorties
  });

  test('Mouvements de stock : sortie négative, type vente, coût figé', () async {
    await _addProduct(db,
        id: 'p1', name: 'Lait', salePrice: 8000, stock: 15, cmp: 6000);

    await engine.useCase(SaleDraft(
      lines: const [SaleDraftLine(productId: 'p1', quantity: 4, unitPrice: 8000)],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 32000)],
    ));

    final movement = (await db.select(db.stockMovements).get()).single;
    expect(movement.quantity, -4);
    expect(movement.unitCost, 6000);
    expect(movement.sourceReference, 'V-2026-000001');
  });

  test('Vente à crédit : amountPaid partiel, creditAmount correct', () async {
    await db.into(db.customers).insert(
        CustomersCompanion.insert(id: 'c1', name: 'Mamadou'));
    await _addProduct(db,
        id: 'p1', name: 'Tissu', salePrice: 200000, stock: 10, cmp: 150000);

    // Payé 50000 en espèces, reste 150000 à crédit.
    final result = await engine.useCase(SaleDraft(
      customerId: 'c1',
      lines: const [SaleDraftLine(productId: 'p1', quantity: 1, unitPrice: 200000)],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 50000)],
    )) as RecordSaleSuccess;

    expect(result.sale.total, 200000);
    expect(result.sale.amountPaid, 50000);
    expect(result.sale.creditAmount, 150000);
    expect(result.sale.isCredit, isTrue);

    final sale = (await db.select(db.sales).get()).single;
    expect(sale.amountPaid, 50000);
    expect(sale.totalAmount - sale.amountPaid, 150000); // reste dû
  });

  test('Crédit sans client : refus (validation), rien enregistré', () async {
    await _addProduct(db,
        id: 'p1', name: 'Tissu', salePrice: 200000, stock: 10, cmp: 150000);

    final result = await engine.useCase(SaleDraft(
      lines: const [SaleDraftLine(productId: 'p1', quantity: 1, unitPrice: 200000)],
      tenders: const [], // rien payé ⇒ tout à crédit
    ));

    expect(result, isA<RecordSaleFailure>());
    expect((result as RecordSaleFailure).error, isA<CreditRequiresCustomerError>());
    expect(await db.select(db.sales).get(), isEmpty);
  });

  test('Stock insuffisant : échec + ROLLBACK complet', () async {
    await _addProduct(db,
        id: 'p1', name: 'Huile', salePrice: 150000, stock: 1, cmp: 100000);

    final result = await engine.useCase(SaleDraft(
      lines: const [SaleDraftLine(productId: 'p1', quantity: 5, unitPrice: 150000)],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 750000)],
    ));

    expect(result, isA<RecordSaleFailure>());
    expect((result as RecordSaleFailure).error, isA<InsufficientStockError>());

    // Rien ne doit subsister : ni vente, ni ligne, ni mouvement.
    expect(await db.select(db.sales).get(), isEmpty);
    expect(await db.select(db.saleItems).get(), isEmpty);
    expect(await db.select(db.stockMovements).get(), isEmpty);

    // Le stock d'origine est intact.
    final product =
        await (db.select(db.products)..where((t) => t.id.equals('p1'))).getSingle();
    expect(product.stockQuantity, 1);
  });

  test('Vente vide : refus immédiat', () async {
    final result = await engine.useCase(const SaleDraft(lines: [], tenders: []));
    expect(result, isA<RecordSaleFailure>());
    expect((result as RecordSaleFailure).error, isA<EmptySaleError>());
  });

  test('Numérotation continue des ventes', () async {
    await _addProduct(db, id: 'p1', name: 'X', salePrice: 1000, stock: 100, cmp: 500);

    final r1 = await engine.useCase(SaleDraft(
      lines: const [SaleDraftLine(productId: 'p1', quantity: 1, unitPrice: 1000)],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 1000)],
    )) as RecordSaleSuccess;
    final r2 = await engine.useCase(SaleDraft(
      lines: const [SaleDraftLine(productId: 'p1', quantity: 1, unitPrice: 1000)],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 1000)],
    )) as RecordSaleSuccess;

    expect(r1.sale.reference, 'V-2026-000001');
    expect(r2.sale.reference, 'V-2026-000002');
  });

  test('Annulation de vente : restauration des stocks et marquage isCancelled', () async {
    await _addProduct(db, id: 'p1', name: 'X', salePrice: 1000, stock: 100, cmp: 500);

    final r1 = await engine.useCase(SaleDraft(
      lines: const [SaleDraftLine(productId: 'p1', quantity: 5, unitPrice: 1000)],
      tenders: const [PaymentTender(method: PaymentMethod.cash, amount: 5000)],
    )) as RecordSaleSuccess;

    // Le stock passe à 95.
    var product = await (db.select(db.products)..where((t) => t.id.equals('p1'))).getSingle();
    expect(product.stockQuantity, 95);

    // Mouvement de sortie.
    var movements = await db.select(db.stockMovements).get();
    expect(movements.length, 1);
    expect(movements.first.quantity, -5);

    // On annule la vente.
    await engine.service.cancel(r1.sale.saleId);

    // Le stock revient à 100.
    product = await (db.select(db.products)..where((t) => t.id.equals('p1'))).getSingle();
    expect(product.stockQuantity, 100);

    // La vente est marquée comme annulée.
    final sale = await (db.select(db.sales)..where((s) => s.id.equals(r1.sale.saleId))).getSingle();
    expect(sale.isCancelled, isTrue);

    // Un mouvement d'ajustement positif a été créé.
    movements = await db.select(db.stockMovements).get();
    expect(movements.length, 2);
    final adjustment = movements.last;
    expect(adjustment.quantity, 5);
    expect(adjustment.type, StockMovementType.adjustment);
    expect(adjustment.reason, 'Annulation de vente');
  });
}
