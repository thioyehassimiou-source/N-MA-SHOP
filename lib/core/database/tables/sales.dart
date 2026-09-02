import 'package:drift/drift.dart';

import '../../domain/payment_method.dart';
import 'customers.dart';
import 'products.dart';

export '../../domain/payment_method.dart' show PaymentMethod;

/// En-tête d'une vente / ticket.
class Sales extends Table {
  @override
  String get tableName => 'sales';

  TextColumn get id => text()();

  /// Numéro de ticket lisible (ex. V-2026-000123).
  TextColumn get reference => text()();

  /// Client rattaché — null pour une vente comptoir anonyme.
  TextColumn get customerId =>
      text().nullable().references(Customers, #id)();

  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  /// Montant total TTC de la vente (GNF).
  IntColumn get totalAmount => integer().withDefault(const Constant(0))();

  /// Montant déjà encaissé (< total ⇒ génère une créance).
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();

  IntColumn get paymentMethod =>
      intEnum<PaymentMethod>().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Indique si la vente a été annulée.
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ligne de vente (un produit dans un ticket).
class SaleItems extends Table {
  @override
  String get tableName => 'sale_items';

  TextColumn get id => text()();

  TextColumn get saleId => text().references(Sales, #id, onDelete: KeyAction.cascade)();

  TextColumn get productId => text().references(Products, #id)();

  /// Libellé figé au moment de la vente (le produit peut changer/être supprimé ensuite).
  TextColumn get label => text()();

  IntColumn get quantity => integer()();

  IntColumn get unitPrice => integer()();

  /// Coût unitaire au moment de la vente (CMP) — pour le calcul de la marge.
  IntColumn get unitCost => integer().withDefault(const Constant(0))();

  IntColumn get lineTotal => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Règlement d'une créance client (remboursement partiel ou total).
class CreditPayments extends Table {
  @override
  String get tableName => 'credit_payments';

  TextColumn get id => text()();

  TextColumn get saleId => text().references(Sales, #id, onDelete: KeyAction.cascade)();

  TextColumn get customerId => text().references(Customers, #id)();

  IntColumn get amount => integer()();

  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  IntColumn get paymentMethod =>
      intEnum<PaymentMethod>().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
