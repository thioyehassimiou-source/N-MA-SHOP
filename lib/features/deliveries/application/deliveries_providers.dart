import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/database/tables/deliveries.dart';
import '../../../core/database/tables/orders.dart';
import '../../../core/providers/database_provider.dart';

/// Provider pour la liste de tous les livreurs
final couriersProvider = StreamProvider<List<Courier>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.couriers)
        ..orderBy([
          (c) => OrderingTerm(expression: c.name, mode: OrderingMode.asc)
        ]))
      .watch();
});

/// Classe regroupant une livraison avec sa commande et son livreur
class DeliveryWithDetails {
  final Delivery delivery;
  final Order order;
  final Courier courier;

  DeliveryWithDetails({
    required this.delivery,
    required this.order,
    required this.courier,
  });
}

/// Provider pour suivre les expéditions en temps réel
final deliveriesProvider = StreamProvider<List<DeliveryWithDetails>>((ref) {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.deliveries).join([
    innerJoin(db.orders, db.orders.id.equalsExp(db.deliveries.orderId)),
    innerJoin(db.couriers, db.couriers.id.equalsExp(db.deliveries.courierId)),
  ])..orderBy([OrderingTerm(expression: db.deliveries.assignedAt, mode: OrderingMode.desc)]);

  return query.watch().map((rows) {
    return rows.map((row) {
      return DeliveryWithDetails(
        delivery: row.readTable(db.deliveries),
        order: row.readTable(db.orders),
        courier: row.readTable(db.couriers),
      );
    }).toList();
  });
});

/// Cas d'usage pour gérer le cycle de vie d'une livraison
class DeliveriesService {
  final AppDatabase db;

  DeliveriesService(this.db);

  /// Assigne une commande à un livreur
  Future<void> assignDelivery({
    required String orderId,
    required String courierId,
    required int deliveryFee,
    String? note,
  }) async {
    await db.transaction(() async {
      // 1. Créer la livraison
      await db.into(db.deliveries).insert(
            DeliveriesCompanion.insert(
              id: const Uuid().v4(),
              orderId: orderId,
              courierId: courierId,
              status: const Value(DeliveryStatus.transit),
              deliveryFee: Value(deliveryFee),
              note: Value(note),
            ),
          );

      // 2. Mettre à jour le statut de la commande (En préparation ou prête -> Livrée... non, plutôt on ne met rien pour l'instant ou on pourrait ajouter "en livraison". Mais on n'a pas cet état. "Prête" est bien).
      // Note: On pourrait ajouter un état à la commande, mais l'état de la livraison prendra le relais.
    });
  }

  /// Marque une livraison comme terminée avec succès
  Future<void> completeDelivery(String deliveryId) async {
    await db.transaction(() async {
      // 1. Récupérer la livraison
      final delivery = await (db.select(db.deliveries)
            ..where((d) => d.id.equals(deliveryId)))
          .getSingle();

      // 2. Mettre à jour la livraison
      await (db.update(db.deliveries)..where((d) => d.id.equals(deliveryId)))
          .write(
        DeliveriesCompanion(
          status: const Value(DeliveryStatus.delivered),
          completedAt: Value(DateTime.now()),
        ),
      );

      // 3. Mettre à jour la commande d'origine en "Livrée"
      await (db.update(db.orders)..where((o) => o.id.equals(delivery.orderId)))
          .write(
        const OrdersCompanion(status: Value(OrderStatus.delivered)),
      );
    });
  }

  /// Marque une livraison en échec
  Future<void> failDelivery(String deliveryId) async {
    await (db.update(db.deliveries)..where((d) => d.id.equals(deliveryId)))
        .write(
      DeliveriesCompanion(
        status: const Value(DeliveryStatus.failed),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Supprime définitivement un livreur et nettoie ses assignations de livraison associées
  Future<void> deleteCourier(String courierId) async {
    await db.transaction(() async {
      await (db.delete(db.deliveries)..where((d) => d.courierId.equals(courierId))).go();
      await (db.delete(db.couriers)..where((c) => c.id.equals(courierId))).go();
    });
  }
}

final deliveriesServiceProvider = Provider<DeliveriesService>((ref) {
  return DeliveriesService(ref.watch(databaseProvider));
});
