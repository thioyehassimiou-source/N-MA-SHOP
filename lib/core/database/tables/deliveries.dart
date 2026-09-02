import 'package:drift/drift.dart';

import 'orders.dart';

export 'orders.dart' show Orders;

/// Véhicule utilisé par le livreur
enum VehicleType {
  moto,
  voiture,
  camionnette,
  autre,
}

extension VehicleTypeX on VehicleType {
  String get label {
    switch (this) {
      case VehicleType.moto:
        return 'Moto';
      case VehicleType.voiture:
        return 'Voiture';
      case VehicleType.camionnette:
        return 'Camionnette';
      case VehicleType.autre:
        return 'Autre';
    }
  }
}

/// Statut de la livraison
enum DeliveryStatus {
  pending,   // Assigné mais pas encore parti
  transit,   // En cours de livraison
  delivered, // Livré avec succès
  failed,    // Échec ou retour
}

extension DeliveryStatusX on DeliveryStatus {
  String get label {
    switch (this) {
      case DeliveryStatus.pending:
        return 'À expédier';
      case DeliveryStatus.transit:
        return 'En transit';
      case DeliveryStatus.delivered:
        return 'Livrée';
      case DeliveryStatus.failed:
        return 'Échec / Retour';
    }
  }
}

/// Base de données des livreurs (internes ou externes)
class Couriers extends Table {
  @override
  String get tableName => 'couriers';

  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  TextColumn get phone => text().nullable()();

  IntColumn get vehicleType =>
      intEnum<VehicleType>().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Suivi des expéditions
class Deliveries extends Table {
  @override
  String get tableName => 'deliveries';

  TextColumn get id => text()();

  /// Commande rattachée
  TextColumn get orderId => text().references(Orders, #id, onDelete: KeyAction.cascade)();

  /// Livreur assigné
  TextColumn get courierId => text().references(Couriers, #id)();

  /// État de l'expédition
  IntColumn get status =>
      intEnum<DeliveryStatus>().withDefault(const Constant(0))();

  /// Frais de livraison dus au livreur
  IntColumn get deliveryFee => integer().withDefault(const Constant(0))();

  /// Date de l'assignation
  DateTimeColumn get assignedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Date de fin (livraison ou échec)
  DateTimeColumn get completedAt => dateTime().nullable()();

  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
