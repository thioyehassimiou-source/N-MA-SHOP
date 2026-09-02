import 'package:drift/drift.dart';

import '../../domain/payment_method.dart';
import 'products.dart';

/// Table des fournisseurs
class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Achats effectués auprès des fournisseurs
class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  
  /// Montant total de l'achat (GNF)
  IntColumn get totalAmount => integer()();
  
  /// Montant déjà réglé (GNF)
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();
  
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  /// Indique si l'achat a été annulé.
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lignes d'un achat
class PurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId => text().references(Purchases, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #id)();
  
  /// Quantité achetée
  IntColumn get quantity => integer()();
  
  /// Prix d'achat unitaire (GNF)
  IntColumn get unitPrice => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Règlements effectués aux fournisseurs (pour les dettes)
class SupplierPayments extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId => text().references(Purchases, #id, onDelete: KeyAction.cascade)();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  
  /// Montant réglé (GNF)
  IntColumn get amount => integer()();
  
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  
  /// Moyen de paiement utilisé
  IntColumn get paymentMethod => intEnum<PaymentMethod>()();

  @override
  Set<Column> get primaryKey => {id};
}
