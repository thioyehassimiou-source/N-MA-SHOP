import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables/expenses.dart';
import '../domain/cash_movement_type.dart';

/// Service pour peupler la base de données avec des données réelles et captivantes
/// pour des démonstrations vidéo, tests ou tournages.
class DemoDataSeeder {
  static const _uuid = Uuid();

  /// Purge complètement toutes les données métier de la base de données.
  static Future<void> clearDatabase(AppDatabase db) async {
    return db.transaction(() async {
      await db.delete(db.saleItems).go();
      await db.delete(db.sales).go();
      await db.delete(db.creditPayments).go();
      await db.delete(db.stockMovements).go();
      await db.delete(db.purchaseItems).go();
      await db.delete(db.purchases).go();
      await db.delete(db.supplierPayments).go();
      await db.delete(db.suppliers).go();
      await db.delete(db.customers).go();
      await db.delete(db.products).go();
      await db.delete(db.expenses).go();
      await db.delete(db.cashMovements).go();
      await db.delete(db.orders).go();
      await db.delete(db.orderItems).go();
      await db.delete(db.deliveries).go();
      await db.delete(db.couriers).go();
      await db.delete(db.auditLogs).go();
    });
  }

  /// Injecte un jeu complet de données de démonstration dans [db].
  static Future<void> seedDatabase(AppDatabase db) async {
    return db.transaction(() async {
      // 1. Purger les anciennes données pour repartir à propre
      await clearDatabase(db);

    final now = DateTime.now();

    // ── 2. Produits ────────────────────────────────────────────────────────
    final products = [
      ProductsCompanion.insert(
        id: _uuid.v4(),
        name: 'Sac de Riz Parfumé (50kg)',
        reference: const Value('RIZ-50KG'),
        unit: const Value('sac'),
        purchasePrice: const Value(290000),
        salePrice: const Value(340000),
        stockQuantity: const Value(42),
        lowStockThreshold: const Value(10),
        weightedAverageCost: const Value(290000),
        imageUrl: const Value('assets/images/prod_rice_bag.png'),
        barcode: const Value('6001001001'),
        createdAt: Value(now.subtract(const Duration(days: 30))),
      ),
      ProductsCompanion.insert(
        id: _uuid.v4(),
        name: 'Huile de Palme Raffinée (5L)',
        reference: const Value('HUILE-5L'),
        unit: const Value('bidon'),
        purchasePrice: const Value(70000),
        salePrice: const Value(85000),
        stockQuantity: const Value(28),
        lowStockThreshold: const Value(8),
        weightedAverageCost: const Value(70000),
        imageUrl: const Value('assets/images/prod_oil_bottle.png'),
        barcode: const Value('6001001002'),
        createdAt: Value(now.subtract(const Duration(days: 30))),
      ),
      ProductsCompanion.insert(
        id: _uuid.v4(),
        name: 'Sucre Blanc Raffiné (1kg)',
        reference: const Value('SUCRE-1KG'),
        unit: const Value('paquet'),
        purchasePrice: const Value(9500),
        salePrice: const Value(12000),
        stockQuantity: const Value(115),
        lowStockThreshold: const Value(20),
        weightedAverageCost: const Value(9500),
        imageUrl: const Value('assets/images/prod_usb_drive.png'),
        barcode: const Value('6001001003'),
        createdAt: Value(now.subtract(const Duration(days: 30))),
      ),
      ProductsCompanion.insert(
        id: _uuid.v4(),
        name: 'Lait Concentré Sucré (Carton de 24)',
        reference: const Value('LAIT-CART'),
        unit: const Value('carton'),
        purchasePrice: const Value(150000),
        salePrice: const Value(180000),
        stockQuantity: const Value(16),
        lowStockThreshold: const Value(5),
        weightedAverageCost: const Value(150000),
        imageUrl: const Value('assets/images/prod_hp_laptop.png'),
        barcode: const Value('6001001004'),
        createdAt: Value(now.subtract(const Duration(days: 30))),
      ),
      ProductsCompanion.insert(
        id: _uuid.v4(),
        name: 'Savon de Marseille (Lot de 5)',
        reference: const Value('SAVON-5P'),
        unit: const Value('lot'),
        purchasePrice: const Value(18000),
        salePrice: const Value(25000),
        stockQuantity: const Value(4), // Seuil d'alerte !
        lowStockThreshold: const Value(10),
        weightedAverageCost: const Value(18000),
        imageUrl: const Value('assets/images/prod_mouse.png'),
        barcode: const Value('6001001005'),
        createdAt: Value(now.subtract(const Duration(days: 30))),
      ),
      ProductsCompanion.insert(
        id: _uuid.v4(),
        name: 'Café Nescafé Original (200g)',
        reference: const Value('CAFE-200G'),
        unit: const Value('boîte'),
        purchasePrice: const Value(35000),
        salePrice: const Value(45000),
        stockQuantity: const Value(35),
        lowStockThreshold: const Value(5),
        weightedAverageCost: const Value(35000),
        imageUrl: const Value('assets/images/prod_headphones.png'),
        barcode: const Value('6001001006'),
        createdAt: Value(now.subtract(const Duration(days: 30))),
      ),
      ProductsCompanion.insert(
        id: _uuid.v4(),
        name: 'Pack Eau Minérale (1.5L x 6)',
        reference: const Value('EAU-PACK'),
        unit: const Value('pack'),
        purchasePrice: const Value(25000),
        salePrice: const Value(35000),
        stockQuantity: const Value(50),
        lowStockThreshold: const Value(15),
        weightedAverageCost: const Value(25000),
        imageUrl: const Value('assets/images/prod_smartwatch.png'),
        barcode: const Value('6001001007'),
        createdAt: Value(now.subtract(const Duration(days: 30))),
      ),
      ProductsCompanion.insert(
        id: _uuid.v4(),
        name: 'Biscuits Prince Chocolat (Carton)',
        reference: const Value('BISC-PRINCE'),
        unit: const Value('carton'),
        purchasePrice: const Value(50000),
        salePrice: const Value(65000),
        stockQuantity: const Value(22),
        lowStockThreshold: const Value(6),
        weightedAverageCost: const Value(50000),
        imageUrl: const Value('assets/images/prod_printer.png'),
        barcode: const Value('6001001008'),
        createdAt: Value(now.subtract(const Duration(days: 30))),
      ),
    ];

    for (final p in products) {
      await db.into(db.products).insert(p);
    }

    final pRiz = products[0];
    final pHuile = products[1];
    final pSucre = products[2];
    final pLait = products[3];
    final pSavon = products[4];
    final pCafe = products[5];
    final pEau = products[6];

    // ── 3. Clients ─────────────────────────────────────────────────────────
    final cBahId = _uuid.v4();
    final cSyllaId = _uuid.v4();
    final cCamaraId = _uuid.v4();

    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: cBahId,
            name: 'Ibrahima Bah',
            phone: const Value('621 11 22 33'),
            address: const Value('Kaloum, Conakry'),
            createdAt: Value(now.subtract(const Duration(days: 20))),
          ),
        );

    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: cSyllaId,
            name: 'Mariama Sylla',
            phone: const Value('624 55 66 77'),
            address: const Value('Kipé, Ratoma'),
            createdAt: Value(now.subtract(const Duration(days: 15))),
          ),
        );

    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: cCamaraId,
            name: 'Ousmane Camara',
            phone: const Value('628 88 99 00'),
            address: const Value('Hamdallaye, Dixinn'),
            createdAt: Value(now.subtract(const Duration(days: 10))),
          ),
        );

    // ── 4. Fournisseurs ───────────────────────────────────────────────────
    final fSoguifId = _uuid.v4();
    final fComptoirId = _uuid.v4();

    await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(
            id: fSoguifId,
            name: 'SOGUIF Import-Export',
            phone: const Value('622 90 90 90'),
            email: const Value('contact@soguif.gn'),
            createdAt: Value(now.subtract(const Duration(days: 45))),
          ),
        );

    await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(
            id: fComptoirId,
            name: 'Comptoir Sylla & Frères',
            phone: const Value('625 44 33 22'),
            email: const Value('sylla.import@gmail.com'),
            createdAt: Value(now.subtract(const Duration(days: 40))),
          ),
        );

    // ── 5. Ventes historiques (10 derniers jours pour des graphiques riches) ─
    final randomDays = [10, 8, 6, 5, 4, 3, 2, 1, 0];
    int ticketIndex = 101;

    for (final dayOffset in randomDays) {
      final saleDate = now.subtract(Duration(days: dayOffset, hours: (ticketIndex % 6) + 1));
      final saleId = _uuid.v4();

      // Vente 1 : Grand panier comptant (Espèces / Mobile Money)
      final total1 = 340000 + 85000 + 24000;
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: saleId,
              reference: 'V-2026-${ticketIndex.toString().padLeft(5, '0')}',
              date: Value(saleDate),
              totalAmount: Value(total1),
              amountPaid: Value(total1),
              paymentMethod: Value(ticketIndex % 2 == 0 ? PaymentMethod.cash : PaymentMethod.mobileMoney),
              createdAt: Value(saleDate),
            ),
          );

      await db.into(db.saleItems).insert(
            SaleItemsCompanion.insert(
              id: _uuid.v4(),
              saleId: saleId,
              productId: pRiz.id.value,
              label: pRiz.name.value,
              quantity: 1,
              unitPrice: 340000,
              unitCost: const Value(290000),
              lineTotal: 340000,
            ),
          );

      await db.into(db.saleItems).insert(
            SaleItemsCompanion.insert(
              id: _uuid.v4(),
              saleId: saleId,
              productId: pHuile.id.value,
              label: pHuile.name.value,
              quantity: 1,
              unitPrice: 85000,
              unitCost: const Value(70000),
              lineTotal: 85000,
            ),
          );

      await db.into(db.saleItems).insert(
            SaleItemsCompanion.insert(
              id: _uuid.v4(),
              saleId: saleId,
              productId: pSucre.id.value,
              label: pSucre.name.value,
              quantity: 2,
              unitPrice: 12000,
              unitCost: const Value(9500),
              lineTotal: 24000,
            ),
          );

      ticketIndex++;
    }

    // ── 6. Ventes à Crédit (Créances clients actives) ───────────────────────
    // Crédit 1 : Ibrahima Bah
    final creditSaleId1 = _uuid.v4();
    final creditDate1 = now.subtract(const Duration(days: 4));
    await db.into(db.sales).insert(
          SalesCompanion.insert(
            id: creditSaleId1,
            reference: 'V-2026-${ticketIndex.toString().padLeft(5, '0')}',
            customerId: Value(cBahId),
            date: Value(creditDate1),
            totalAmount: const Value(520000), // 1 Riz + 1 Lait
            amountPaid: const Value(200000),  // Reste 320 000 GNF de créance
            paymentMethod: const Value(PaymentMethod.credit),
            note: const Value('Avance versée 200.000 GNF, solde prévu fin de mois'),
            createdAt: Value(creditDate1),
          ),
        );

    await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: _uuid.v4(),
            saleId: creditSaleId1,
            productId: pRiz.id.value,
            label: pRiz.name.value,
            quantity: 1,
            unitPrice: 340000,
            unitCost: const Value(290000),
            lineTotal: 340000,
          ),
        );

    await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: _uuid.v4(),
            saleId: creditSaleId1,
            productId: pLait.id.value,
            label: pLait.name.value,
            quantity: 1,
            unitPrice: 180000,
            unitCost: const Value(150000),
            lineTotal: 180000,
          ),
        );
    ticketIndex++;

    // Crédit 2 : Ousmane Camara
    final creditSaleId2 = _uuid.v4();
    final creditDate2 = now.subtract(const Duration(days: 2));
    await db.into(db.sales).insert(
          SalesCompanion.insert(
            id: creditSaleId2,
            reference: 'V-2026-${ticketIndex.toString().padLeft(5, '0')}',
            customerId: Value(cCamaraId),
            date: Value(creditDate2),
            totalAmount: const Value(135000), // 3 Savons + 1 Eau + 1 Café
            amountPaid: const Value(50000),   // Reste 85 000 GNF
            paymentMethod: const Value(PaymentMethod.credit),
            createdAt: Value(creditDate2),
          ),
        );

    await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: _uuid.v4(),
            saleId: creditSaleId2,
            productId: pSavon.id.value,
            label: pSavon.name.value,
            quantity: 1,
            unitPrice: 25000,
            unitCost: const Value(18000),
            lineTotal: 25000,
          ),
        );

    await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: _uuid.v4(),
            saleId: creditSaleId2,
            productId: pEau.id.value,
            label: pEau.name.value,
            quantity: 1,
            unitPrice: 35000,
            unitCost: const Value(25000),
            lineTotal: 35000,
          ),
        );

    await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: _uuid.v4(),
            saleId: creditSaleId2,
            productId: pCafe.id.value,
            label: pCafe.name.value,
            quantity: 1,
            unitPrice: 45000,
            unitCost: const Value(35000),
            lineTotal: 45000,
          ),
        );

    // ── 7. Dépenses opérationnelles ─────────────────────────────────────────
    await db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            id: _uuid.v4(),
            reference: 'DEP-2026-0001',
            category: ExpenseCategory.rent,
            amount: 500000,
            date: Value(now.subtract(const Duration(days: 12))),
            description: 'Loyer mensuel magasin Madina',
            paymentMethod: const Value(PaymentMethod.cash),
          ),
        );

    await db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            id: _uuid.v4(),
            reference: 'DEP-2026-0002',
            category: ExpenseCategory.utilities,
            amount: 120000,
            date: Value(now.subtract(const Duration(days: 7))),
            description: 'Recharge compteur EDG & eau',
            paymentMethod: const Value(PaymentMethod.mobileMoney),
          ),
        );

    await db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            id: _uuid.v4(),
            reference: 'DEP-2026-0003',
            category: ExpenseCategory.transport,
            amount: 85000,
            date: Value(now.subtract(const Duration(days: 3))),
            description: 'Frais de transport stock depuis le port',
            paymentMethod: const Value(PaymentMethod.cash),
          ),
        );

    // ── 8. Mouvements de caisse initiaux ──────────────────────────────────
    await db.into(db.cashMovements).insert(
          CashMovementsCompanion.insert(
            id: _uuid.v4(),
            reference: 'CAISSE-IN-0001',
            description: 'Fond de caisse initial',
            amount: 1500000,
            type: CashMovementType.inflow,
            date: Value(now.subtract(const Duration(days: 15))),
            paymentMethod: const Value(PaymentMethod.cash),
          ),
        );
    });
  }
}
