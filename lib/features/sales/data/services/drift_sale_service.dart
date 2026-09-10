import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/database/database.dart';
import '../../../../core/database/tables/audit_logs.dart';
import '../../../../core/database/tables/stock.dart';
import '../../../../core/database/tables/users.dart';
import '../../../../core/domain/payment_method.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../security/domain/services/audit_log_service.dart';
import '../../domain/entities/recorded_sale.dart';
import '../../domain/entities/sale_draft.dart';
import '../../domain/errors.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../domain/services/sale_service.dart';

/// Implémentation Drift du moteur de vente.
class DriftSaleService implements SaleService {
  DriftSaleService({
    required AppDatabase db,
    required ProductRepository products,
    required StockRepository stock,
    required SaleRepository sales,
    required AppUser? currentUser,
    required AuditLogService auditLog,
    String Function()? idGenerator,
    DateTime Function()? clock,
  }) : _db = db,
       _products = products,
       _stock = stock,
       _sales = sales,
       _currentUser = currentUser,
       _auditLog = auditLog,
       _newId = idGenerator ?? (() => const Uuid().v4()),
       _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final ProductRepository _products;
  final StockRepository _stock;
  final SaleRepository _sales;
  final AppUser? _currentUser;
  final AuditLogService _auditLog;
  final String Function() _newId;
  final DateTime Function() _now;

  @override
  Future<RecordedSale> record(SaleDraft draft) {
    return _db.transaction(() async {
      final date = draft.date ?? _now();

      // ── 1-2. Charger les produits (1 requête) et contrôler le stock ──
      final snapshots = await _products.findByIds(
        draft.lines.map((l) => l.productId),
      );

      // Cumuler les quantités par produit (un produit peut apparaître sur
      // plusieurs lignes : le contrôle porte sur le total demandé).
      final requestedByProduct = <String, int>{};
      for (final line in draft.lines) {
        requestedByProduct.update(
          line.productId,
          (q) => q + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }

      requestedByProduct.forEach((productId, requested) {
        final snap = snapshots[productId];
        if (snap == null) {
          throw SaleDomainException(ProductNotFoundError(productId));
        }
        if (snap.stockQuantity < requested) {
          throw SaleDomainException(
            InsufficientStockError(
              productLabel: snap.name,
              available: snap.stockQuantity,
              requested: requested,
              unit: snap.unit,
            ),
          );
        }
      });

      // ── 3-4. Coûts (CMP), lignes, total, marge ──
      final saleId = _newId();
      final reference = await _sales.nextReference(date);

      var costOfGoods = 0;
      final newLines = <NewSaleLine>[];
      for (final line in draft.lines) {
        final snap = snapshots[line.productId]!;
        costOfGoods += snap.weightedAverageCost * line.quantity;
        newLines.add(
          NewSaleLine(
            id: _newId(),
            saleId: saleId,
            productId: line.productId,
            label: snap.name,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            unitCost: snap.weightedAverageCost,
            lineTotal: line.lineTotal,
          ),
        );
      }

      final total = draft.total;
      final amountPaid = draft.paidImmediately;
      final creditAmount = draft.creditAmount;
      final dominant = _dominantMethod(draft);

      // ── 5-6. Créer la vente + ses lignes ──
      final sellerId = draft.userId ?? _currentUser?.id;
      final sellerName = draft.sellerName ?? _currentUser?.fullName;

      await _sales.createSale(
        NewSaleData(
          id: saleId,
          reference: reference,
          customerId: draft.customerId,
          date: date,
          total: total,
          amountPaid: amountPaid,
          paymentMethod: dominant,
          note: draft.note,
          userId: sellerId,
          sellerName: sellerName,
        ),
      );
      await _sales.addLines(newLines);

      // ── 7-8. Décrément du stock + mouvements ──
      final exits = <StockExit>[];
      requestedByProduct.forEach((productId, requested) {
        final snap = snapshots[productId]!;
        exits.add(
          StockExit(
            productId: productId,
            quantity: requested,
            unitCost: snap.weightedAverageCost,
            newStockQuantity: snap.stockQuantity - requested,
            saleReference: reference,
            date: date,
          ),
        );
      });
      await _stock.applySaleExits(exits);

      // ── 9. Résultat métier ──
      return RecordedSale(
        saleId: saleId,
        reference: reference,
        date: date,
        total: total,
        amountPaid: amountPaid,
        creditAmount: creditAmount,
        profit: total - costOfGoods,
        dominantMethod: dominant,
      );
    });
  }

  /// Mode de règlement le plus représentatif, pour l'affichage récapitulatif.
  /// Sans aucun règlement immédiat, la vente est intégralement à crédit.
  PaymentMethod _dominantMethod(SaleDraft draft) {
    if (draft.tenders.isEmpty) return PaymentMethod.credit;
    var best = draft.tenders.first;
    for (final t in draft.tenders) {
      if (t.amount > best.amount) best = t;
    }
    return best.method;
  }

  @override
  Future<void> cancel(String saleId) {
    // 🛡️ GUARD: seul un Admin peut annuler une vente.
    if (_currentUser == null || _currentUser.role == UserRole.cashier) {
      throw const AuthException(AuthFailure.unauthorized);
    }

    return _db.transaction(() async {
      final sale = await (_db.select(_db.sales)..where((tbl) => tbl.id.equals(saleId))).getSingleOrNull();
      if (sale == null) throw StateError('Vente introuvable.');
      if (sale.isCancelled) throw StateError('Cette vente est déjà annulée.');

      // Marquer la vente comme annulée
      await (_db.update(_db.sales)..where((tbl) => tbl.id.equals(saleId)))
          .write(const SalesCompanion(isCancelled: drift.Value(true)));

      // Récupérer les lignes de la vente pour restocker
      final items = await (_db.select(_db.saleItems)..where((tbl) => tbl.saleId.equals(saleId))).get();

      for (final item in items) {
        final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingle();
        final newStock = product.stockQuantity + item.quantity;

        // Mise à jour du stock
        await (_db.update(_db.products)..where((tbl) => tbl.id.equals(item.productId)))
            .write(ProductsCompanion(stockQuantity: drift.Value(newStock)));

        // Mouvement de stock d'ajustement (entrée)
        await _db.into(_db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: _newId(),
            productId: item.productId,
            type: StockMovementType.adjustment,
            quantity: item.quantity,
            unitCost: drift.Value(product.weightedAverageCost),
            sourceReference: drift.Value(sale.reference),
            reason: drift.Value('Annulation de vente'),
            date: drift.Value(_now()),
          ),
        );
      }

      // Supprimer les paiements associés
      await (_db.delete(_db.creditPayments)..where((tbl) => tbl.saleId.equals(saleId))).go();

      // 📋 AUDIT LOG: enregistrer l'annulation
      await _auditLog.logAction(
        userId: _currentUser.id,
        userName: _currentUser.fullName,
        actionType: AuditActionType.saleCancelled,
        details: 'Vente ${sale.reference} annulée.',
      );
    });
  }
}
