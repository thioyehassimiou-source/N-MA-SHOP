import 'package:drift/drift.dart';

/// File d'attente locale de synchronisation vers l'API Cloud (N'MaShop Mobile).
///
/// Permet un fonctionnement 100% offline-first : chaque opération métier
/// (vente, mouvement de stock, dépense...) enregistre un événement atomique
/// dans cette table, qui est ensuite dépilé de façon asynchrone par [DesktopSyncWorker].
class SyncQueue extends Table {
  @override
  String get tableName => 'sync_queue';

  IntColumn get id => integer().autoIncrement()();

  /// Identifiant unique d'idempotence (UUID v4).
  TextColumn get eventId => text()();

  /// Type d'entité métier : 'sale', 'payment', 'stock', 'expense', 'customer', 'audit'.
  TextColumn get entityType => text()();

  /// Identifiant local de l'entité.
  TextColumn get entityId => text()();

  /// Nature de l'opération : 'create', 'update', 'cancel'.
  TextColumn get action => text()();

  /// Données sérialisées en JSON compact.
  TextColumn get payload => text()();

  /// Date de mise en file d'attente.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Nombre de tentatives d'envoi.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Horodatage de la dernière tentative.
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Statut de l'envoi : 0 = en attente (pending), 1 = en cours (sending), 2 = échoué (failed).
  IntColumn get status => integer().withDefault(const Constant(0))();

  /// Dernier message d'erreur réseau / serveur (le cas échéant).
  TextColumn get errorMessage => text().nullable()();
}
