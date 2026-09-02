import 'package:drift/drift.dart';

import 'customers.dart';
import 'products.dart';

export 'customers.dart' show Customers;

/// Statut du cycle de vie d'une commande (inspiré du flow StockFlow).
enum OrderStatus {
  pending,    // Nouvelle commande reçue (WhatsApp, téléphone…)
  confirmed,  // Confirmée par le gérant
  preparing,  // En cours de préparation
  ready,      // Prête — en attente de livraison / retrait
  delivered,  // Livrée / Récupérée et payée
  cancelled,  // Annulée
}

/// Type de livraison de la commande.
enum DeliveryType {
  pickup,   // Retrait en boutique
  delivery, // Livraison à domicile
}

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:    return 'Nouvelle';
      case OrderStatus.confirmed:  return 'Confirmée';
      case OrderStatus.preparing:  return 'En préparation';
      case OrderStatus.ready:      return 'Prête';
      case OrderStatus.delivered:  return 'Livrée';
      case OrderStatus.cancelled:  return 'Annulée';
    }
  }

  /// Prochaine étape dans le cycle de vie (null = état terminal).
  OrderStatus? get nextStatus {
    switch (this) {
      case OrderStatus.pending:    return OrderStatus.confirmed;
      case OrderStatus.confirmed:  return OrderStatus.preparing;
      case OrderStatus.preparing:  return OrderStatus.ready;
      case OrderStatus.ready:      return OrderStatus.delivered;
      case OrderStatus.delivered:  return null;
      case OrderStatus.cancelled:  return null;
    }
  }

  String? get nextActionLabel {
    switch (this) {
      case OrderStatus.pending:    return 'Confirmer';
      case OrderStatus.confirmed:  return 'Préparer';
      case OrderStatus.preparing:  return 'Marquer prête';
      case OrderStatus.ready:      return 'Marquer livrée';
      case OrderStatus.delivered:  return null;
      case OrderStatus.cancelled:  return null;
    }
  }
}

extension DeliveryTypeX on DeliveryType {
  String get label {
    switch (this) {
      case DeliveryType.pickup:   return 'Retrait en boutique';
      case DeliveryType.delivery: return 'Livraison à domicile';
    }
  }
}

/// En-tête d'une commande client.
class Orders extends Table {
  @override
  String get tableName => 'orders';

  TextColumn get id => text()();

  /// Numéro lisible, ex: CMD-2026-0001
  TextColumn get reference => text()();

  // ── Client (libre ou lié à la table Customers) ──────────────────
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();

  // ── Cycle de vie ────────────────────────────────────────────────
  IntColumn get status => intEnum<OrderStatus>().withDefault(const Constant(0))();

  // ── Livraison ───────────────────────────────────────────────────
  IntColumn get deliveryType => intEnum<DeliveryType>().withDefault(const Constant(0))();
  TextColumn get deliveryAddress => text().nullable()();

  // ── Finances ────────────────────────────────────────────────────
  IntColumn get totalAmount => integer().withDefault(const Constant(0))();

  // ── Méta ────────────────────────────────────────────────────────
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ligne de commande (un produit dans la commande).
class OrderItems extends Table {
  @override
  String get tableName => 'order_items';

  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #id)();

  /// Libellé figé au moment de la commande.
  TextColumn get label => text()();
  IntColumn get unitPrice => integer()();
  IntColumn get quantity => integer()();
  IntColumn get lineTotal => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
