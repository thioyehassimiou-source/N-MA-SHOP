import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/mobile_database.dart';

class MobileQuoteItem {
  final String productId;
  final String label;
  final int quantity;
  final int unitPrice;
  final int lineTotal;

  const MobileQuoteItem({
    required this.productId,
    required this.label,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'label': label,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal,
      };

  factory MobileQuoteItem.fromMap(Map<String, dynamic> map) => MobileQuoteItem(
        productId: map['productId'] as String? ?? '',
        label: map['label'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (map['unitPrice'] as num?)?.toInt() ?? 0,
        lineTotal: (map['lineTotal'] as num?)?.toInt() ?? 0,
      );
}

class MobileQuote {
  final String id;
  final String reference;
  final String customerName;
  final String customerPhone;
  final DateTime date;
  final DateTime validUntil;
  final int total;
  final String status; // 'pending', 'converted', 'cancelled'
  final String? note;
  final List<MobileQuoteItem> items;

  const MobileQuote({
    required this.id,
    required this.reference,
    required this.customerName,
    this.customerPhone = '',
    required this.date,
    required this.validUntil,
    required this.total,
    this.status = 'pending',
    this.note,
    this.items = const [],
  });

  bool get isPending => status == 'pending';
  bool get isConverted => status == 'converted';
  bool get isCancelled => status == 'cancelled';
}

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  final db = ref.watch(mobileDatabaseProvider);
  return QuotesRepository(db);
});

class QuotesRepository {
  final MobileDatabase _db;
  bool _tableInitialized = false;

  QuotesRepository(this._db);

  Future<void> _ensureTable() async {
    if (_tableInitialized) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS mobile_quotes (
        id TEXT PRIMARY KEY,
        reference TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        date TEXT NOT NULL,
        valid_until TEXT NOT NULL,
        total INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        note TEXT,
        items_json TEXT NOT NULL
      );
    ''');
    _tableInitialized = true;
  }

  Future<List<MobileQuote>> getQuotes() async {
    await _ensureTable();
    final rows = await _db.customSelect(
      'SELECT * FROM mobile_quotes ORDER BY date DESC',
    ).get();

    return rows.map((row) {
      final itemsJson = row.read<String>('items_json');
      List<MobileQuoteItem> items = [];
      try {
        final decoded = jsonDecode(itemsJson) as List;
        items = decoded.map((e) => MobileQuoteItem.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}

      return MobileQuote(
        id: row.read<String>('id'),
        reference: row.read<String>('reference'),
        customerName: row.read<String>('customer_name'),
        customerPhone: row.read<String?>('customer_phone') ?? '',
        date: DateTime.parse(row.read<String>('date')),
        validUntil: DateTime.parse(row.read<String>('valid_until')),
        total: row.read<int>('total'),
        status: row.read<String>('status'),
        note: row.read<String?>('note'),
        items: items,
      );
    }).toList();
  }

  Future<void> saveQuote(MobileQuote quote) async {
    await _ensureTable();
    final itemsJson = jsonEncode(quote.items.map((i) => i.toMap()).toList());

    await _db.customStatement('''
      INSERT OR REPLACE INTO mobile_quotes (
        id, reference, customer_name, customer_phone, date, valid_until, total, status, note, items_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [
      quote.id,
      quote.reference,
      quote.customerName,
      quote.customerPhone,
      quote.date.toIso8601String(),
      quote.validUntil.toIso8601String(),
      quote.total,
      quote.status,
      quote.note,
      itemsJson,
    ]);
  }

  Future<void> updateStatus(String id, String status) async {
    await _ensureTable();
    await _db.customStatement(
      'UPDATE mobile_quotes SET status = ? WHERE id = ?;',
      [status, id],
    );
  }

  Future<void> deleteQuote(String id) async {
    await _ensureTable();
    await _db.customStatement(
      'DELETE FROM mobile_quotes WHERE id = ?;',
      [id],
    );
  }

  /// Convertit un devis validé en vente réelle de caisse (déduit les stocks et enregistre le paiement).
  Future<String> convertQuoteToSale({
    required MobileQuote quote,
    required int paymentMethod, // 0: Espèces, 1: Orange Money, 2: Wave, 5: Crédit
    required int amountPaid,
  }) async {
    final now = DateTime.now();
    final saleId = 'sale-${now.millisecondsSinceEpoch}';
    final refCode = 'FAC-${now.millisecondsSinceEpoch % 10000}';

    // 1. Enregistrer la vente dans MobileSales
    await _db.into(_db.mobileSales).insert(
      MobileSalesCompanion.insert(
        id: saleId,
        reference: refCode,
        date: drift.Value(now),
        total: drift.Value(quote.total),
        amountPaid: drift.Value(amountPaid),
        paymentMethod: drift.Value(paymentMethod),
        customerId: drift.Value(quote.customerName),
        sellerName: const drift.Value('Administrateur'),
        note: drift.Value('Issu du Devis ${quote.reference}'),
      ),
    );

    // 2. Traiter les articles du devis
    final allProducts = await _db.select(_db.mobileProducts).get();
    int index = 1;

    for (final item in quote.items) {
      final product = allProducts.where((p) => p.id == item.productId).firstOrNull;
      final unitCost = product?.purchasePrice ?? 0;

      // Ligne de vente
      await _db.into(_db.mobileSaleItems).insert(
        MobileSaleItemsCompanion.insert(
          id: 'item-${now.millisecondsSinceEpoch}-$index',
          saleId: saleId,
          productId: item.productId,
          label: item.label,
          quantity: drift.Value(item.quantity),
          unitPrice: drift.Value(item.unitPrice),
          unitCost: drift.Value(unitCost),
          lineTotal: drift.Value(item.lineTotal),
        ),
      );

      if (product != null) {
        // Mouvement de stock de sortie
        await _db.into(_db.mobileStockMovements).insert(
          MobileStockMovementsCompanion.insert(
            id: 'mvt-${now.millisecondsSinceEpoch}-$index',
            productId: product.id,
            type: 1, // Vente
            quantity: -item.quantity,
            unitCost: drift.Value(unitCost),
            sourceReference: drift.Value(refCode),
            reason: drift.Value('Conversion Devis ${quote.reference}'),
            date: drift.Value(now),
          ),
        );

        // Décrémenter la quantité en rayon
        final newStock = (product.stockQuantity - item.quantity).clamp(0, 999999);
        await (_db.update(_db.mobileProducts)..where((tbl) => tbl.id.equals(product.id))).write(
          MobileProductsCompanion(stockQuantity: drift.Value(newStock)),
        );
      }

      index++;
    }

    // 3. Marquer le devis comme 'converted'
    await updateStatus(quote.id, 'converted');

    return saleId;
  }
}

