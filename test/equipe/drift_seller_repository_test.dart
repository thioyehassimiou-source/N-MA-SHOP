import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/database/database.dart';
import 'package:nmashop/core/database/tables/sales.dart';
import 'package:nmashop/core/database/tables/users.dart';
import 'package:nmashop/features/auth/data/repositories/drift_auth_repository.dart';
import 'package:nmashop/features/equipe/data/repositories/drift_seller_repository.dart';

void main() {
  late AppDatabase db;
  late DriftSellerRepository sellerRepo;
  late DriftAuthRepository authRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sellerRepo = DriftSellerRepository(db);
    authRepo = DriftAuthRepository(db);
  });

  tearDown(() => db.close());

  test('Performances commerciales complètes par vendeur avec commissions et impayés', () async {
    // 1. Créer des utilisateurs
    await authRepo.defineAccount(
      fullName: 'Directeur Admin',
      password: 'adminPassword123',
    );

    final seller1 = await authRepo.createUser(
      fullName: 'Mamadou Diallo',
      password: 'password123',
      role: UserRole.cashier,
      commissionRate: 5.0,
    );

    final seller2 = await authRepo.createUser(
      fullName: 'Fatou Camara',
      password: 'password123',
      role: UserRole.cashier,
      commissionRate: 10.0,
    );

    final seller3 = await authRepo.createUser(
      fullName: 'Alpha Oumar (Nouveau)',
      password: 'password123',
      role: UserRole.cashier,
      commissionRate: 2.5,
    );

    // 2. Créer des clients
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: 'c1',
            name: 'Client Alpha',
            phone: const Value('620000001'),
          ),
        );
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: 'c2',
            name: 'Client Beta',
            phone: const Value('620000002'),
          ),
        );

    final now = DateTime(2026, 9, 9, 14, 0);

    // 3. Ventes pour Seller 1 (Mamadou)
    // Vente 1 : 500 000 GNF comptant au client c1
    await db.into(db.sales).insert(
          SalesCompanion.insert(
            id: 's1',
            reference: 'V-2026-000001',
            customerId: const Value('c1'),
            userId: Value(seller1.id),
            sellerName: Value(seller1.fullName),
            totalAmount: const Value(500000),
            amountPaid: const Value(500000),
            date: Value(now.subtract(const Duration(hours: 3))),
            paymentMethod: const Value(PaymentMethod.cash),
          ),
        );

    // Vente 2 : 300 000 GNF dont 100 000 comptant et 200 000 à crédit au client c2
    await db.into(db.sales).insert(
          SalesCompanion.insert(
            id: 's2',
            reference: 'V-2026-000002',
            customerId: const Value('c2'),
            userId: Value(seller1.id),
            sellerName: Value(seller1.fullName),
            totalAmount: const Value(300000),
            amountPaid: const Value(100000),
            date: Value(now.subtract(const Duration(hours: 2))),
            paymentMethod: const Value(PaymentMethod.cash),
          ),
        );

    // 4. Ventes pour Seller 2 (Fatou)
    // Vente 3 : 1 000 000 GNF comptant au client c1
    await db.into(db.sales).insert(
          SalesCompanion.insert(
            id: 's3',
            reference: 'V-2026-000003',
            customerId: const Value('c1'),
            userId: Value(seller2.id),
            sellerName: Value(seller2.fullName),
            totalAmount: const Value(1000000),
            amountPaid: const Value(1000000),
            date: Value(now.subtract(const Duration(hours: 1))),
            paymentMethod: const Value(PaymentMethod.mobileMoney),
          ),
        );

    // 5. Vente historique non attribuée (userId = null)
    await db.into(db.sales).insert(
          SalesCompanion.insert(
            id: 's4',
            reference: 'V-2026-000004',
            totalAmount: const Value(200000),
            amountPaid: const Value(200000),
            date: Value(now.subtract(const Duration(days: 1))),
            paymentMethod: const Value(PaymentMethod.cash),
          ),
        );

    // ── VÉRIFICATION 1 : getSellersPerformance ──
    final performances = await sellerRepo.getSellersPerformance();

    // Doit contenir les 4 utilisateurs + 1 entrée non attribuée = 5
    expect(performances.length, 5);

    // Top vendeur en CA = Fatou (1 000 000 GNF)
    final top = performances.first;
    expect(top.sellerName, 'Fatou Camara');
    expect(top.salesCount, 1);
    expect(top.totalRevenue, 1000000);
    expect(top.totalCollected, 1000000);
    expect(top.totalRemaining, 0);
    expect(top.commissionRate, 10.0);
    expect(top.commissionAmount, 100000); // 10% de 1 000 000
    expect(top.customersServedCount, 1);

    // 2ème vendeur = Mamadou (800 000 GNF)
    final second = performances[1];
    expect(second.sellerName, 'Mamadou Diallo');
    expect(second.salesCount, 2);
    expect(second.totalRevenue, 800000);
    expect(second.totalCollected, 600000);
    expect(second.totalRemaining, 200000);
    expect(second.commissionRate, 5.0);
    expect(second.commissionAmount, 40000); // 5% de 800 000
    expect(second.customersServedCount, 2);
    expect(second.averageBasket, 400000); // 800 000 / 2
    expect(second.collectionRate, 75.0); // 600 000 / 800 000 * 100

    // Vente non attribuée
    final unassigned = performances.firstWhere((p) => p.sellerId == null);
    expect(unassigned.sellerName, 'Non attribué');
    expect(unassigned.salesCount, 1);
    expect(unassigned.totalRevenue, 200000);

    // Vendeur sans vente (Alpha Oumar)
    final zeroSales = performances.firstWhere((p) => p.sellerId == seller3.id);
    expect(zeroSales.salesCount, 0);
    expect(zeroSales.totalRevenue, 0);
    expect(zeroSales.commissionAmount, 0);

    // ── VÉRIFICATION 2 : getSellerSales ──
    final mamadouSales = await sellerRepo.getSellerSales(seller1.id);
    expect(mamadouSales.length, 2);
    expect(mamadouSales.first.reference, 'V-2026-000002');
    expect(mamadouSales.first.customerName, 'Client Beta');
    expect(mamadouSales.first.remaining, 200000);

    // ── VÉRIFICATION 3 : getSellerCustomers ──
    final mamadouCustomers = await sellerRepo.getSellerCustomers(seller1.id);
    expect(mamadouCustomers.length, 2);
    expect(mamadouCustomers.first.name, 'Client Alpha');
    expect(mamadouCustomers.first.totalSpent, 500000);

    // ── VÉRIFICATION 4 : Mise à jour du taux de commission ──
    await authRepo.updateCommissionRate(seller1.id, 8.0);
    final updatedPerfs = await sellerRepo.getSellersPerformance();
    final updatedMamadou = updatedPerfs.firstWhere((p) => p.sellerId == seller1.id);
    expect(updatedMamadou.commissionRate, 8.0);
    expect(updatedMamadou.commissionAmount, 64000); // 8% de 800 000
  });
}
