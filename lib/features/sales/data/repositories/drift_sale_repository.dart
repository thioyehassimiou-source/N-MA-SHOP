import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../domain/repositories/sale_repository.dart';

/// Implémentation Drift de [SaleRepository].
class DriftSaleRepository implements SaleRepository {
  DriftSaleRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String> nextReference(DateTime date) async {
    final year = date.year;
    final count = _db.sales.id.count(
      filter:
          _db.sales.date.isBiggerOrEqualValue(DateTime(year)) &
          _db.sales.date.isSmallerThanValue(DateTime(year + 1)),
    );
    final query = _db.selectOnly(_db.sales)..addColumns([count]);
    final n = await query.map((row) => row.read(count) ?? 0).getSingle();
    return 'V-$year-${(n + 1).toString().padLeft(6, '0')}';
  }

  @override
  Future<void> createSale(NewSaleData data) async {
    await _db
        .into(_db.sales)
        .insert(
          SalesCompanion.insert(
            id: data.id,
            reference: data.reference,
            customerId: Value(data.customerId),
            date: Value(data.date),
            totalAmount: Value(data.total),
            amountPaid: Value(data.amountPaid),
            paymentMethod: Value(data.paymentMethod),
            note: Value(data.note),
            userId: Value(data.userId),
            sellerName: Value(data.sellerName),
          ),
        );
  }

  @override
  Future<void> addLines(List<NewSaleLine> lines) async {
    if (lines.isEmpty) return;
    await _db.batch((b) {
      b.insertAll(_db.saleItems, [
        for (final l in lines)
          SaleItemsCompanion.insert(
            id: l.id,
            saleId: l.saleId,
            productId: l.productId,
            label: l.label,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
            unitCost: Value(l.unitCost),
            lineTotal: l.lineTotal,
          ),
      ]);
    });
  }

  @override
  Future<List<SaleHistoryItem>> getAllSales({int limit = 200}) async {
    final sales = await (_db.select(_db.sales)
          ..orderBy([
            (s) => OrderingTerm(expression: s.date, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();

    if (sales.isEmpty) return const [];

    final customerIds =
        sales.map((s) => s.customerId).whereType<String>().toSet().toList();
    final customerMap = <String, String>{};
    if (customerIds.isNotEmpty) {
      final custs = await (_db.select(
        _db.customers,
      )..where((c) => c.id.isIn(customerIds))).get();
      for (final c in custs) {
        customerMap[c.id] = c.name;
      }
    }

    final saleIds = sales.map((s) => s.id).toList();
    final itemRows = await (_db.select(
      _db.saleItems,
    )..where((it) => it.saleId.isIn(saleIds))).get();
    final itemsMap = <String, List<String>>{};
    for (final it in itemRows) {
      itemsMap.putIfAbsent(it.saleId, () => []).add('${it.quantity}x ${it.label}');
    }

    return sales.map((s) {
      final items = itemsMap[s.id] ?? const [];
      final summary = items.isNotEmpty ? items.join(', ') : 'Vente';
      return SaleHistoryItem(
        id: s.id,
        reference: s.reference,
        date: s.date,
        customerName: s.customerId != null
            ? (customerMap[s.customerId] ?? 'Client')
            : 'Client comptoir',
        totalAmount: s.totalAmount,
        amountPaid: s.amountPaid,
        paymentMethod: s.paymentMethod,
        isCancelled: s.isCancelled,
        sellerName: s.sellerName,
        userId: s.userId,
        itemsSummary: summary,
      );
    }).toList();
  }
}
