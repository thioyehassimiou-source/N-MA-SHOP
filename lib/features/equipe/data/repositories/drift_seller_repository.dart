import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../domain/entities/seller_performance.dart';
import '../../domain/repositories/seller_repository.dart';

/// Implémentation Drift SQLite pour l'analyse des performances des vendeurs.
class DriftSellerRepository implements SellerRepository {
  DriftSellerRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<SellerPerformance>> getSellersPerformance({
    DateTime? start,
    DateTime? end,
  }) async {
    // 1. Récupérer tous les utilisateurs (vendeurs & admins)
    final allUsers = await (_db.select(_db.users)
          ..orderBy([(u) => OrderingTerm(expression: u.createdAt)]))
        .get();

    // 2. Récupérer toutes les ventes actives sur la période demandée
    final salesQuery = _db.select(_db.sales)
      ..where((s) {
        Expression<bool> predicate = s.isCancelled.equals(false);
        if (start != null) {
          predicate = predicate & s.date.isBiggerOrEqualValue(start);
        }
        if (end != null) {
          predicate = predicate & s.date.isSmallerOrEqualValue(end);
        }
        return predicate;
      });

    final sales = await salesQuery.get();

    // Grouper les ventes par userId (ou null)
    final salesByUserId = <String?, List<Sale>>{};
    for (final sale in sales) {
      salesByUserId.putIfAbsent(sale.userId, () => []).add(sale);
    }

    final performances = <SellerPerformance>[];
    final processedUserIds = <String>{};

    // 3. Calculer les métriques pour chaque utilisateur enregistré
    for (final user in allUsers) {
      processedUserIds.add(user.id);
      final userSales = salesByUserId[user.id] ?? const <Sale>[];

      final salesCount = userSales.length;
      final totalRevenue = userSales.fold<int>(0, (sum, s) => sum + s.totalAmount);
      final totalCollected = userSales.fold<int>(0, (sum, s) => sum + s.amountPaid);
      final totalRemaining = totalRevenue - totalCollected;
      final customersServedCount = userSales
          .map((s) => s.customerId)
          .where((cid) => cid != null)
          .toSet()
          .length;

      performances.add(
        SellerPerformance(
          sellerId: user.id,
          sellerName: user.fullName,
          role: user.role,
          isActive: user.isActive,
          commissionRate: user.commissionRate,
          salesCount: salesCount,
          totalRevenue: totalRevenue,
          totalCollected: totalCollected,
          totalRemaining: totalRemaining,
          customersServedCount: customersServedCount,
        ),
      );
    }

    // 4. Gérer les ventes historiques d'anciens utilisateurs supprimés
    for (final entry in salesByUserId.entries) {
      final uid = entry.key;
      if (uid != null && !processedUserIds.contains(uid)) {
        final groupSales = entry.value;
        final name = groupSales.first.sellerName ?? 'Vendeur archivé';
        final totalRevenue = groupSales.fold<int>(0, (sum, s) => sum + s.totalAmount);
        final totalCollected = groupSales.fold<int>(0, (sum, s) => sum + s.amountPaid);

        performances.add(
          SellerPerformance(
            sellerId: uid,
            sellerName: name,
            isActive: false,
            commissionRate: 0.0,
            salesCount: groupSales.length,
            totalRevenue: totalRevenue,
            totalCollected: totalCollected,
            totalRemaining: totalRevenue - totalCollected,
            customersServedCount: groupSales
                .map((s) => s.customerId)
                .where((cid) => cid != null)
                .toSet()
                .length,
          ),
        );
      }
    }

    // 5. Gérer les ventes non attribuées (antérieures à la v20)
    final unassignedSales = salesByUserId[null];
    if (unassignedSales != null && unassignedSales.isNotEmpty) {
      final totalRevenue = unassignedSales.fold<int>(0, (sum, s) => sum + s.totalAmount);
      final totalCollected = unassignedSales.fold<int>(0, (sum, s) => sum + s.amountPaid);

      performances.add(
        SellerPerformance(
          sellerId: null,
          sellerName: 'Non attribué',
          isActive: true,
          commissionRate: 0.0,
          salesCount: unassignedSales.length,
          totalRevenue: totalRevenue,
          totalCollected: totalCollected,
          totalRemaining: totalRevenue - totalCollected,
          customersServedCount: unassignedSales
              .map((s) => s.customerId)
              .where((cid) => cid != null)
              .toSet()
              .length,
        ),
      );
    }

    // Trier : les plus performants en CA en premier
    performances.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return performances;
  }

  @override
  Future<List<SellerSaleItem>> getSellerSales(
    String? sellerId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final query = _db.select(_db.sales).join([
      leftOuterJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.sales.customerId),
      ),
    ]);

    query.where(
      sellerId != null
          ? _db.sales.userId.equals(sellerId)
          : _db.sales.userId.isNull(),
    );

    if (start != null) {
      query.where(_db.sales.date.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where(_db.sales.date.isSmallerOrEqualValue(end));
    }

    query.orderBy([
      OrderingTerm(expression: _db.sales.date, mode: OrderingMode.desc),
    ]);

    final rows = await query.get();
    return rows.map((row) {
      final s = row.readTable(_db.sales);
      final c = row.readTableOrNull(_db.customers);
      return SellerSaleItem(
        id: s.id,
        reference: s.reference,
        date: s.date,
        customerName:
            c?.name ?? (s.customerId != null ? 'Client' : 'Client comptoir'),
        totalAmount: s.totalAmount,
        amountPaid: s.amountPaid,
        isCancelled: s.isCancelled,
      );
    }).toList();
  }

  @override
  Future<List<SellerCustomerItem>> getSellerCustomers(
    String? sellerId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final query = _db.select(_db.sales).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.sales.customerId),
      ),
    ]);

    query.where(
      sellerId != null
          ? _db.sales.userId.equals(sellerId)
          : _db.sales.userId.isNull(),
    );
    query.where(_db.sales.isCancelled.equals(false));

    if (start != null) {
      query.where(_db.sales.date.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where(_db.sales.date.isSmallerOrEqualValue(end));
    }

    final rows = await query.get();
    final customerStats = <String, ({Customer customer, int count, int total})>{};

    for (final row in rows) {
      final s = row.readTable(_db.sales);
      final c = row.readTable(_db.customers);
      final existing = customerStats[c.id];
      if (existing == null) {
        customerStats[c.id] = (customer: c, count: 1, total: s.totalAmount);
      } else {
        customerStats[c.id] = (
          customer: c,
          count: existing.count + 1,
          total: existing.total + s.totalAmount,
        );
      }
    }

    final list = customerStats.values.map((val) {
      return SellerCustomerItem(
        id: val.customer.id,
        name: val.customer.name,
        phone: val.customer.phone,
        salesCount: val.count,
        totalSpent: val.total,
      );
    }).toList();

    list.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return list;
  }
}
