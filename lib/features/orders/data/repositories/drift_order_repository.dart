import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/tables/orders.dart';
import '../../../../core/providers/database_provider.dart';

export '../../../../core/database/tables/orders.dart'
    show OrderStatus, OrderStatusX, DeliveryType, DeliveryTypeX;

final orderRepositoryProvider = Provider<DriftOrderRepository>((ref) {
  return DriftOrderRepository(ref.watch(databaseProvider));
});

class OrderLine {
  final String productId;
  final String label;
  final int unitPrice;
  final int quantity;

  const OrderLine({
    required this.productId,
    required this.label,
    required this.unitPrice,
    required this.quantity,
  });

  int get lineTotal => unitPrice * quantity;
}

class DriftOrderRepository {
  DriftOrderRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  /// Stream réactif de toutes les commandes, triées par date décroissante.
  Stream<List<Order>> watchAllOrders() {
    return (_db.select(_db.orders)
          ..orderBy([(o) => OrderingTerm(expression: o.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Stream des lignes d'une commande donnée.
  Stream<List<OrderItem>> watchOrderItems(String orderId) {
    return (_db.select(_db.orderItems)
          ..where((oi) => oi.orderId.equals(orderId)))
        .watch();
  }

  /// Insère une nouvelle commande avec ses lignes.
  Future<void> insertOrder({
    required String customerName,
    String? customerPhone,
    String? customerId,
    required DeliveryType deliveryType,
    String? deliveryAddress,
    String? note,
    required List<OrderLine> lines,
  }) async {
    final orderId = _uuid.v4();
    final seq = await _db.select(_db.orders).get().then((l) => l.length + 1);
    final ref = 'CMD-${DateTime.now().year}-${seq.toString().padLeft(4, '0')}';
    final total = lines.fold<int>(0, (s, l) => s + l.lineTotal);

    await _db.transaction(() async {
      await _db.into(_db.orders).insert(
        OrdersCompanion.insert(
          id: orderId,
          reference: ref,
          customerName: customerName,
          customerPhone: Value(customerPhone),
          customerId: Value(customerId),
          status: Value(OrderStatus.pending),
          deliveryType: Value(deliveryType),
          deliveryAddress: Value(deliveryAddress),
          totalAmount: Value(total),
          note: Value(note),
        ),
      );

      for (final line in lines) {
        await _db.into(_db.orderItems).insert(
          OrderItemsCompanion.insert(
            id: _uuid.v4(),
            orderId: orderId,
            productId: line.productId,
            label: line.label,
            unitPrice: line.unitPrice,
            quantity: line.quantity,
            lineTotal: line.lineTotal,
          ),
        );
      }
    });
  }

  /// Avance la commande au statut suivant.
  Future<void> advanceStatus(String orderId) async {
    final order = await (_db.select(_db.orders)
          ..where((o) => o.id.equals(orderId)))
        .getSingle();
    final next = order.status.nextStatus;
    if (next == null) return;

    await (_db.update(_db.orders)..where((o) => o.id.equals(orderId))).write(
      OrdersCompanion(
        status: Value(next),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Annule une commande.
  Future<void> cancelOrder(String orderId) async {
    await (_db.update(_db.orders)..where((o) => o.id.equals(orderId))).write(
      OrdersCompanion(
        status: const Value(OrderStatus.cancelled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Supprime définitivement une commande et ses éléments associés
  Future<void> deleteOrder(String orderId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.deliveries)..where((d) => d.orderId.equals(orderId))).go();
      await (_db.delete(_db.orderItems)..where((oi) => oi.orderId.equals(orderId))).go();
      await (_db.delete(_db.orders)..where((o) => o.id.equals(orderId))).go();
    });
  }
}
