import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/tables/stock.dart';
import '../../../../core/domain/payment_method.dart';
import '../../../../core/database/tables/users.dart';
import '../../../../core/database/tables/audit_logs.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../security/domain/services/audit_log_service.dart';
import '../../domain/purchase_draft.dart';
import '../../../../core/sync/sync_queue_service.dart';
import '../../../../core/sync/models/sync_event_payloads.dart';

class DriftPurchaseService {
  DriftPurchaseService(this._db, this.currentUser, this.auditLog, this._syncQueue);

  final AppDatabase _db;
  final AppUser? currentUser;
  final AuditLogService auditLog;
  final SyncQueueService _syncQueue;

  Future<void> recordPurchase(PurchaseDraft draft) async {
    await _db.transaction(() async {
      final date = draft.date ?? DateTime.now();
      final purchaseId = const Uuid().v4();
      final total = draft.totalAmount;

      // 0. Trouver ou créer le fournisseur
      final supplierName = draft.supplierName.trim();
      final existingSupplier = await (_db.select(
        _db.suppliers,
      )..where((s) => s.name.equals(supplierName))).getSingleOrNull();

      String supplierId;
      if (existingSupplier != null) {
        supplierId = existingSupplier.id;
      } else {
        supplierId = const Uuid().v4();
        await _db
            .into(_db.suppliers)
            .insert(
              SuppliersCompanion.insert(id: supplierId, name: supplierName),
            );
      }

      // 1. Créer l'achat
      await _db
          .into(_db.purchases)
          .insert(
            PurchasesCompanion.insert(
              id: purchaseId,
              supplierId: supplierId,
              totalAmount: total,
              amountPaid: Value(draft.amountPaid),
              date: Value(date),
            ),
          );

      // 2. Créer le règlement initial s'il y a lieu
      if (draft.amountPaid > 0) {
        await _db
            .into(_db.supplierPayments)
            .insert(
              SupplierPaymentsCompanion.insert(
                id: const Uuid().v4(),
                purchaseId: purchaseId,
                supplierId: supplierId,
                amount: draft.amountPaid,
                date: Value(date),
                paymentMethod: draft.paymentMethod,
              ),
            );
            
        await _syncQueue.enqueueCashMovement(
          CashMovementSyncPayload(
            movementId: purchaseId,
            reference: 'ACH-${purchaseId.substring(0, 6).toUpperCase()}',
            description: 'Achat marchandise: ${draft.supplierName}',
            amount: draft.amountPaid,
            typeIndex: 1, // outflow
            paymentMethodIndex: draft.paymentMethod.index,
            date: date,
          ),
        );
      }

      // 3. Créer les lignes d'achat et mettre à jour le stock
      for (final line in draft.lines) {
        final lineId = const Uuid().v4();

        await _db
            .into(_db.purchaseItems)
            .insert(
              PurchaseItemsCompanion.insert(
                id: lineId,
                purchaseId: purchaseId,
                productId: line.productId,
                quantity: line.quantity,
                unitPrice: line.unitPrice,
              ),
            );

        // Mettre à jour le stock et le coût moyen pondéré (CMP)
        // D'abord, récupérer l'état actuel du produit
        final productQuery = _db.select(_db.products)
          ..where((p) => p.id.equals(line.productId));
        final product = await productQuery.getSingle();

        final currentStock = product.stockQuantity;
        final currentCmp = product.weightedAverageCost;

        final newStock = currentStock + line.quantity;

        // Formule CMP : (Ancien Stock * Ancien CMP + Quantité Achetée * Prix Achat) / Nouveau Stock
        int newCmp = currentCmp;
        if (newStock > 0) {
          final totalValue =
              (currentStock * currentCmp) + (line.quantity * line.unitPrice);
          newCmp = (totalValue / newStock).round();
        }

        // Mettre à jour le produit
        await (_db.update(
          _db.products,
        )..where((p) => p.id.equals(line.productId))).write(
          ProductsCompanion(
            stockQuantity: Value(newStock),
            weightedAverageCost: Value(newCmp),
          ),
        );

        // Ajouter un mouvement de stock
        await _db
            .into(_db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                id: const Uuid().v4(),
                productId: line.productId,
                type: StockMovementType.purchase,
                quantity: line.quantity,
                unitCost: Value(newCmp),
                sourceReference: Value(purchaseId),
                date: Value(date),
              ),
            );
      }

    });
  }

  /// Récupère l'historique des paiements d'un fournisseur spécifique.
  Future<List<SupplierPayment>> getSupplierPaymentHistory(
    String supplierId,
  ) async {
    final query = _db.select(_db.supplierPayments)
      ..where((p) => p.supplierId.equals(supplierId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      ]);

    return await query.get();
  }

  /// Enregistre un nouveau règlement pour un fournisseur (paiement d'une dette).
  Future<void> recordSupplierPayment(
    String supplierId,
    int amount,
    PaymentMethod method, {
    DateTime? date,
  }) async {
    await _db.transaction(() async {
      final paymentDate = date ?? DateTime.now();

      // Ventes encore dues, des plus anciennes aux plus récentes (FIFO).
      final openPurchases =
          await (_db.select(_db.purchases)
                ..where(
                  (p) =>
                      p.supplierId.equals(supplierId) &
                      p.totalAmount.isBiggerThan(p.amountPaid),
                )
                ..orderBy([(p) => OrderingTerm(expression: p.date)]))
              .get();

      final balance = openPurchases.fold<int>(
        0,
        (sum, p) => sum + (p.totalAmount - p.amountPaid),
      );

      if (balance <= 0) {
        throw Exception("Ce fournisseur n'a aucune dette en cours.");
      }
      if (amount > balance) {
        throw Exception(
          "Le montant réglé ($amount) dépasse la dette totale ($balance).",
        );
      }

      // Répartition FIFO du montant sur les achats dus.
      var remaining = amount;
      for (final purchase in openPurchases) {
        if (remaining <= 0) break;
        final due = purchase.totalAmount - purchase.amountPaid;
        final applied = remaining < due ? remaining : due;

        await _db
            .into(_db.supplierPayments)
            .insert(
              SupplierPaymentsCompanion.insert(
                id: const Uuid().v4(),
                purchaseId: purchase.id,
                supplierId: supplierId,
                amount: applied,
                date: Value(paymentDate),
                paymentMethod: method,
              ),
            );
            
        await _syncQueue.enqueueCashMovement(
          CashMovementSyncPayload(
            movementId: const Uuid().v4(),
            reference: 'REG-${purchase.id.substring(0, 6).toUpperCase()}',
            description: 'Règlement dette fournisseur',
            amount: applied,
            typeIndex: 1, // outflow
            paymentMethodIndex: method.index,
            date: paymentDate,
          ),
        );
        await (_db.update(
          _db.purchases,
        )..where((p) => p.id.equals(purchase.id))).write(
          PurchasesCompanion(amountPaid: Value(purchase.amountPaid + applied)),
        );
        remaining -= applied;
      }
    });
  }

  /// Annule un achat (corrige une erreur).
  Future<void> cancelPurchase(String purchaseId) async {
    if (currentUser?.role != UserRole.admin) {
      throw const AuthException(AuthFailure.unauthorized);
    }

    return _db.transaction(() async {
      final purchase = await (_db.select(_db.purchases)..where((tbl) => tbl.id.equals(purchaseId))).getSingleOrNull();
      if (purchase == null) throw Exception('Achat introuvable.');
      if (purchase.isCancelled) throw Exception('Cet achat est déjà annulé.');

      // Marquer l'achat comme annulé
      await (_db.update(_db.purchases)..where((tbl) => tbl.id.equals(purchaseId)))
          .write(const PurchasesCompanion(isCancelled: Value(true)));

      // Audit Log
      await auditLog.logAction(
        userId: currentUser?.id ?? 'system',
        userName: currentUser?.fullName ?? 'Système',
        actionType: AuditActionType.purchaseDeleted,
        details: 'Annulation achat $purchaseId (Total: ${purchase.totalAmount})',
      );

      // Récupérer les lignes pour décrémenter le stock
      final items = await (_db.select(_db.purchaseItems)..where((tbl) => tbl.purchaseId.equals(purchaseId))).get();

      for (final item in items) {
        final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingle();
        final newStock = product.stockQuantity - item.quantity;

        // Mise à jour du stock (le CMP n'est volontairement pas recalculé en arrière pour la stabilité)
        await (_db.update(_db.products)..where((tbl) => tbl.id.equals(item.productId)))
            .write(ProductsCompanion(stockQuantity: Value(newStock)));

        // Mouvement de stock d'ajustement (sortie)
        await _db.into(_db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: const Uuid().v4(),
            productId: item.productId,
            type: StockMovementType.adjustment,
            quantity: -item.quantity, // Négatif car on annule une entrée
            unitCost: Value(product.weightedAverageCost),
            sourceReference: Value(purchaseId),
            reason: Value("Annulation d'achat"),
            date: Value(DateTime.now()),
          ),
        );
      }

      // Supprimer les règlements fournisseurs associés
      await (_db.delete(_db.supplierPayments)..where((tbl) => tbl.purchaseId.equals(purchaseId))).go();
    });
  }
}
