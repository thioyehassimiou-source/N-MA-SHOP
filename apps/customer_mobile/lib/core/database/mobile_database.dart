import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'mobile_database.g.dart';

// ── Tables SQLite Local-First ──

class MobileUsers extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text().withLength(min: 1, max: 200)();
  TextColumn get role => text().withDefault(const Constant('admin'))();
  TextColumn get pinHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileShops extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get currency => text().withDefault(const Constant('GNF'))();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileProducts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get reference => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pièce'))();
  IntColumn get purchasePrice => integer().withDefault(const Constant(0))();
  IntColumn get salePrice => integer().withDefault(const Constant(0))();
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  IntColumn get weightedAverageCost => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get barcode => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileSales extends Table {
  TextColumn get id => text()();
  TextColumn get reference => text()();
  TextColumn get customerId => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();
  IntColumn get paymentMethod => integer().withDefault(const Constant(0))();
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get sellerName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileSaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get productId => text()();
  TextColumn get label => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get unitPrice => integer().withDefault(const Constant(0))();
  IntColumn get unitCost => integer().withDefault(const Constant(0))();
  IntColumn get lineTotal => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileStockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  IntColumn get type => integer()(); // 0: Purchase, 1: Sale, 2: Adjustment
  IntColumn get quantity => integer()();
  IntColumn get unitCost => integer().withDefault(const Constant(0))();
  TextColumn get sourceReference => text().nullable()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileCustomers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileSuppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get company => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MobilePurchases extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text()();
  IntColumn get totalAmount => integer().withDefault(const Constant(0))();
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class MobilePurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId => text()();
  TextColumn get productId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get unitPrice => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer().withDefault(const Constant(0))();
  TextColumn get category => text().withDefault(const Constant('Divers'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MobileSyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get payload => text()();
  IntColumn get status => integer().withDefault(const Constant(0))(); // 0: Pending, 1: Synced, 2: Failed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Base de Données Principale ──

@DriftDatabase(tables: [
  MobileUsers,
  MobileShops,
  MobileProducts,
  MobileCategories,
  MobileSales,
  MobileSaleItems,
  MobileStockMovements,
  MobileCustomers,
  MobileSuppliers,
  MobilePurchases,
  MobilePurchaseItems,
  MobileExpenses,
  MobileSyncQueue,
])
class MobileDatabase extends _$MobileDatabase {
  MobileDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'nmashop_mobile_local.db'));
    return NativeDatabase.createInBackground(file);
  });
}

// ── Riverpod Provider ──

final mobileDatabaseProvider = Provider<MobileDatabase>((ref) {
  final db = MobileDatabase();
  ref.onDispose(() => db.close());
  return db;
});
