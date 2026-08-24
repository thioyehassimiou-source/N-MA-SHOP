import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/domain/payment_method.dart';
import '../../domain/entities/dashboard_snapshot.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// Implémentation Drift de [DashboardRepository].
///
/// Chaque indicateur est une requête agrégée (SUM/COUNT) ou une requête bornée
/// (5 ventes récentes, produits sous le seuil) : aucune table complète n'est
/// chargée en mémoire.
class DriftDashboardRepository implements DashboardRepository {
  DriftDashboardRepository(this._db);

  final AppDatabase _db;

  @override
  Future<DashboardSnapshot> load(DateTime now) async {
    final startToday = DateTime(now.year, now.month, now.day);
    final endToday = startToday.add(const Duration(days: 1));
    final startYesterday = startToday.subtract(const Duration(days: 1));
    final startWeek = startToday.subtract(const Duration(days: 7));
    final startPrevWeek = startToday.subtract(const Duration(days: 14));

    // Toutes les requêtes en parallèle pour la performance
    final results = await Future.wait([
      _salesSum(startToday, endToday),        // 0
      _salesSum(startYesterday, startToday),  // 1
      _profit(startToday, endToday),           // 2
      _profit(startYesterday, startToday),     // 3
      _salesSum(startWeek, endToday),          // 4
      _salesSum(startPrevWeek, startWeek),     // 5
      _owed(),                                  // 6
      _owedCount(),                             // 7
      _cashAvailable(),                         // 8
    ]);

    final dailySales = await _dailySales(startWeek, endToday);
    final paymentBreakdown = await _paymentBreakdown();
    final supplierDebt = await _supplierDebt();
    final avgTicket = await _avgTicket(startWeek, endToday);
    final creditRate = await _creditRate(startWeek, endToday);
    final lowStockList = await _lowStock();
    final recentSalesList = await _recentSales();

    return DashboardSnapshot(
      todaySales: results[0],
      yesterdaySales: results[1],
      todayProfit: results[2],
      yesterdayProfit: results[3],
      thisWeekSales: results[4],
      prevWeekSales: results[5],
      owed: results[6],
      owedCount: results[7],
      cashAvailable: results[8],
      lowStock: lowStockList,
      recentSales: recentSalesList,
      dailySales: dailySales,
      paymentBreakdown: paymentBreakdown,
      supplierDebt: supplierDebt,
      avgTicket: avgTicket,
      creditRate: creditRate,
    );
  }

  /// Σ(total_amount) des ventes sur [start, end).
  Future<int> _salesSum(DateTime start, DateTime end) async {
    final sum = _db.sales.totalAmount.sum();
    final q = _db.selectOnly(_db.sales)
      ..addColumns([sum])
      ..where(
        _db.sales.date.isBiggerOrEqualValue(start) &
            _db.sales.date.isSmallerThanValue(end) &
            _db.sales.isCancelled.equals(false),
      );
    return (await q.getSingle()).read(sum) ?? 0;
  }

  /// Bénéfice = Σ(line_total − arrondi(unit_cost × quantity)) **par ligne**, sur
  /// les ventes de [start, end). L'arrondi par ligne reproduit exactement
  /// l'ancien calcul Dart.
  Future<int> _profit(DateTime start, DateTime end) async {
    final profit = CustomExpression<int>(
      'COALESCE(SUM(sale_items.line_total - '
      'CAST(round(sale_items.unit_cost * sale_items.quantity) AS INTEGER)), 0)',
    );
    final q =
        _db.selectOnly(_db.saleItems).join([
            innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
          ])
          ..addColumns([profit])
          ..where(
            _db.sales.date.isBiggerOrEqualValue(start) &
                _db.sales.date.isSmallerThanValue(end) &
                _db.sales.isCancelled.equals(false),
          );
    return (await q.getSingle()).read(profit) ?? 0;
  }

  /// Σ(total_amount − amount_paid) sur toutes les ventes.
  Future<int> _owed() async {
    final owed = (_db.sales.totalAmount - _db.sales.amountPaid).sum();
    final q = _db.selectOnly(_db.sales)..addColumns([owed])..where(_db.sales.isCancelled.equals(false));
    return (await q.getSingle()).read(owed) ?? 0;
  }

  /// Nombre de ventes dont le total dépasse le montant réglé.
  Future<int> _owedCount() async {
    final count = _db.sales.id.count();
    final q = _db.selectOnly(_db.sales)
      ..addColumns([count])
      ..where(_db.sales.totalAmount.isBiggerThan(_db.sales.amountPaid) & _db.sales.isCancelled.equals(false));
    return (await q.getSingle()).read(count) ?? 0;
  }

  /// Encaissements totaux = Σ(amount_paid) sur toutes les ventes.
  /// Simple et direct — sans journalLines.
  Future<int> _cashAvailable() async {
    final sum = _db.sales.amountPaid.sum();
    final q = _db.selectOnly(_db.sales)..addColumns([sum])..where(_db.sales.isCancelled.equals(false));
    return (await q.getSingle()).read(sum) ?? 0;
  }

  Future<List<LowStockItem>> _lowStock() async {
    final rows =
        await (_db.select(_db.products)
              ..where(
                (p) =>
                    p.isActive.equals(true) &
                    p.stockQuantity.isSmallerOrEqual(p.lowStockThreshold),
              )
              ..orderBy([(p) => OrderingTerm(expression: p.stockQuantity)]))
            .get();
    return rows
        .map(
          (r) => LowStockItem(
            name: r.name,
            unit: r.unit,
            stockQuantity: r.stockQuantity,
          ),
        )
        .toList(growable: false);
  }

  Future<List<RecentSale>> _recentSales() async {
    final sales =
        await (_db.select(_db.sales)
              ..orderBy([
                (s) =>
                    OrderingTerm(expression: s.date, mode: OrderingMode.desc),
              ])
              ..limit(5))
            .get();
    if (sales.isEmpty) return const [];

    final saleIds = sales.map((s) => s.id).toList();
    final customerIds = sales
        .map((s) => s.customerId)
        .whereType<String>()
        .toSet()
        .toList();

    // Lignes des 5 ventes + jointure produits pour récupérer imageUrl
    final itemRows = await (_db.select(_db.saleItems).join([
      leftOuterJoin(
        _db.products,
        _db.products.id.equalsExp(_db.saleItems.productId),
      ),
    ])..where(_db.saleItems.saleId.isIn(saleIds))).get();

    final itemsBySale = <String, List<SaleItem>>{};
    // Map saleId -> first product imageUrl
    final imageUrlBySale = <String, String?>{};
    for (final row in itemRows) {
      final it = row.readTable(_db.saleItems);
      itemsBySale.putIfAbsent(it.saleId, () => []).add(it);
      // Keep first image found for each sale
      if (!imageUrlBySale.containsKey(it.saleId)) {
        try {
          final prod = row.readTable(_db.products);
          imageUrlBySale[it.saleId] = prod.imageUrl;
        } catch (_) {
          imageUrlBySale[it.saleId] = null;
        }
      }
    }

    final customerNames = <String, String>{};
    if (customerIds.isNotEmpty) {
      final custs = await (_db.select(
        _db.customers,
      )..where((c) => c.id.isIn(customerIds))).get();
      for (final c in custs) {
        customerNames[c.id] = c.name;
      }
    }

    return sales
        .map((s) {
          final its = itemsBySale[s.id] ?? const [];
          final first = its.isNotEmpty ? its.first.label : 'Vente';
          final extra = its.length > 1 ? ' +${its.length - 1}' : '';
          return RecentSale(
            id: s.id,
            title: '$first$extra',
            subtitle: s.customerId != null
                ? (customerNames[s.customerId] ?? 'Client')
                : 'Client comptoir',
            date: s.date,
            amount: s.totalAmount,
            paid: s.amountPaid >= s.totalAmount,
            isCancelled: s.isCancelled,
            imageUrl: imageUrlBySale[s.id],
          );
        })
        .toList(growable: false);
  }

  /// Ventes par jour sur les 7 derniers jours, pour le graphique CA.
  Future<List<DailySalesPoint>> _dailySales(
      DateTime start, DateTime end) async {
    final days = <DailySalesPoint>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(endDay)) {
      final next = cursor.add(const Duration(days: 1));
      final total = await _salesSum(cursor, next);
      days.add(DailySalesPoint(date: cursor, total: total));
      cursor = next;
    }
    return days;
  }

  /// Répartition des ventes par mode de paiement (7 derniers jours).
  Future<List<PaymentBreakdownItem>> _paymentBreakdown() async {
    final rows = _db.select(_db.sales)
      ..where((s) => s.isCancelled.equals(false));
    final all = await rows.get();

    final totals = <PaymentMethod, int>{};
    for (final s in all) {
      final method = s.paymentMethod;
      totals[method] = (totals[method] ?? 0) + s.amountPaid;
    }
    return totals.entries
        .map((e) => PaymentBreakdownItem(method: e.key, amount: e.value))
        .toList();
  }

  /// Dettes fournisseurs (solde des achats non réglés).
  Future<int> _supplierDebt() async {
    final owed = (_db.purchases.totalAmount - _db.purchases.amountPaid).sum();
    final q = _db.selectOnly(_db.purchases)..addColumns([owed]);
    return (await q.getSingle()).read(owed) ?? 0;
  }

  /// Ticket moyen sur les 7 derniers jours.
  Future<double?> _avgTicket(DateTime start, DateTime end) async {
    final avg = _db.sales.totalAmount.avg();
    final q = _db.selectOnly(_db.sales)
      ..addColumns([avg])
      ..where(
        _db.sales.date.isBiggerOrEqualValue(start) &
            _db.sales.date.isSmallerThanValue(end) &
            _db.sales.isCancelled.equals(false),
      );
    return (await q.getSingle()).read(avg);
  }

  /// Taux de ventes à crédit (%) sur les 7 derniers jours.
  Future<double?> _creditRate(DateTime start, DateTime end) async {
    final total = _db.sales.id.count();
    final credit = _db.sales.id.count(
      filter: _db.sales.paymentMethod.equalsValue(PaymentMethod.credit),
    );
    final q = _db.selectOnly(_db.sales)
      ..addColumns([total, credit])
      ..where(
        _db.sales.date.isBiggerOrEqualValue(start) &
            _db.sales.date.isSmallerThanValue(end) &
            _db.sales.isCancelled.equals(false),
      );
    final row = await q.getSingle();
    final t = row.read(total) ?? 0;
    if (t == 0) return null;
    final c = row.read(credit) ?? 0;
    return (c / t) * 100;
  }
}
