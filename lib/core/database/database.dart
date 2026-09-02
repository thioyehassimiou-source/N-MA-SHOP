import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/products.dart';
import 'tables/sales.dart';
import 'tables/stock.dart';
import 'tables/suppliers.dart';
import 'tables/audit_logs.dart';
import 'tables/users.dart';
import 'tables/cash_movements.dart';
import 'tables/expenses.dart';
import 'tables/orders.dart';
import 'tables/deliveries.dart';
import 'tables/admin_clients.dart';
import 'tables/admin_licenses.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Products,
    Customers,
    Sales,
    SaleItems,
    CreditPayments,
    StockMovements,
    Suppliers,
    Purchases,
    PurchaseItems,
    SupplierPayments,
    Users,
    CashMovements,
    Expenses,
    Orders,
    OrderItems,
    Couriers,
    Deliveries,
    AuditLogs,
    AdminClients,
    AdminLicenses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructeur de test : base en mémoire, sans fichier ni path_provider.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(suppliers);
            await m.createTable(purchases);
            await m.createTable(purchaseItems);
            await m.createTable(supplierPayments);
          }
          if (from < 3) {
            await m.createTable(users);
          }
          if (from < 4) {
            // Passage au mono-utilisateur : conservation du compte le plus ancien.
            await m.alterTable(TableMigration(users));
            await customStatement(
              'DELETE FROM users WHERE id NOT IN '
              '(SELECT id FROM users ORDER BY created_at ASC LIMIT 1)',
            );
          }
          if (from < 5) {
            // Suppression des tables de comptabilité SYSCOHADA — abandonnées en V1.
            // La gestion commerciale ne nécessite pas de plan comptable.
            await customStatement(
              'DROP TABLE IF EXISTS journal_lines',
            );
            await customStatement(
              'DROP TABLE IF EXISTS journal_entries',
            );
            await customStatement(
              'DROP TABLE IF EXISTS accounts',
            );
          }
          if (from < 6) {
            // Retrait des décimales (passage de REAL à INTEGER pour les quantités et coûts).
            // Migration destructive pour repartir sur une base saine sans vrac.
            await customStatement('DROP TABLE IF EXISTS credit_payments');
            await customStatement('DROP TABLE IF EXISTS supplier_payments');
            await customStatement('DROP TABLE IF EXISTS purchase_items');
            await customStatement('DROP TABLE IF EXISTS purchases');
            await customStatement('DROP TABLE IF EXISTS sale_items');
            await customStatement('DROP TABLE IF EXISTS sales');
            await customStatement('DROP TABLE IF EXISTS stock_movements');
            await customStatement('DROP TABLE IF EXISTS products');

            await m.createTable(products);
            await m.createTable(sales);
            await m.createTable(saleItems);
            await m.createTable(creditPayments);
            await m.createTable(stockMovements);
            await m.createTable(purchases);
            await m.createTable(purchaseItems);
            await m.createTable(supplierPayments);
          }
          if (from < 7) {
            if (!await _hasColumn('sales', 'is_cancelled')) {
              await m.addColumn(sales, sales.isCancelled);
            }
            if (!await _hasColumn('purchases', 'is_cancelled')) {
              await m.addColumn(purchases, purchases.isCancelled);
            }
          }
          if (from < 8) {
            await m.createTable(cashMovements);
          }
          if (from < 9) {
            if (!await _hasColumn('products', 'image_url')) {
              await m.addColumn(products, products.imageUrl);
            }
          }
          if (from < 10) {
            await m.createTable(expenses);
          }
          if (from < 11) {
            await m.createTable(orders);
            await m.createTable(orderItems);
          }
          if (from < 12) {
            await m.createTable(couriers);
            await m.createTable(deliveries);
          }
          if (from < 13) {
            if (!await _hasColumn('users', 'role')) {
              await m.addColumn(users, users.role);
            }
            if (!await _hasColumn('users', 'is_active')) {
              await m.addColumn(users, users.isActive);
            }
          }
          if (from < 14) {
            await m.createTable(auditLogs);
          }
          if (from < 15) {
            // Ajout du champ code-barres pour le scan caméra POS.
            if (!await _hasColumn('products', 'barcode')) {
              await m.addColumn(products, products.barcode);
            }
          }
          if (from < 16) {
            await m.createTable(adminClients);
            await m.createTable(adminLicenses);
          }
          if (from < 17) {
            if (!await _hasColumn('users', 'avatar_path')) {
              await m.addColumn(users, users.avatarPath);
            }
          }
          if (from < 18) {
            // Migration pour appliquer ON DELETE CASCADE aux tables enfants
            await m.alterTable(TableMigration(saleItems));
            await m.alterTable(TableMigration(creditPayments));
            await m.alterTable(TableMigration(purchaseItems));
            await m.alterTable(TableMigration(supplierPayments));
            await m.alterTable(TableMigration(orderItems));
            await m.alterTable(TableMigration(deliveries));
          }
        },
        beforeOpen: (details) async {
          // Intégrité référentielle et optimisations de performance SQLite (pour PC modestes / HDD).
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA cache_size = -64000');
        },
      );

  /// Vérifie dynamiquement si une colonne existe dans une table SQLite.
  /// Utile pour éviter l'erreur "duplicate column name" si la base a été
  /// initialisée par onCreate dans une version intermédiaire.
  Future<bool> _hasColumn(String tableName, String columnName) async {
    final result = await customSelect(
      "SELECT COUNT(*) AS c FROM pragma_table_info('$tableName') WHERE name = '$columnName'",
    ).getSingle();
    return result.read<int>('c') > 0;
  }

  /// Purge complète de toutes les tables de la base de données SQLite local.
  /// Grâce à ON DELETE CASCADE (v18), la suppression des entités parentes
  /// supprime automatiquement et atomiquement leurs enfants, garantissant
  /// 100% d'intégrité relationnelle sans conflits d'ordre manuel.
  Future<void> purgeAllData() async {
    await transaction(() async {
      // 1. Flux transactionnels (Cascade supprime automatiquement sale_items, credit_payments, etc.)
      await delete(sales).go();
      await delete(purchases).go();
      await delete(orders).go();

      // 2. Historiques et journaux
      await delete(stockMovements).go();
      await delete(cashMovements).go();
      await delete(expenses).go();
      await delete(auditLogs).go();

      // 3. Entités parentes maîtresses
      await delete(products).go();
      await delete(customers).go();
      await delete(suppliers).go();
      await delete(couriers).go();

      // 4. Données administratives et sécurité
      await delete(adminLicenses).go();
      await delete(adminClients).go();
      await delete(users).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // Le nom du fichier est interne et ne change pas lors d'un rebranding.
    final file = File(p.join(dir.path, 'gescompta.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

