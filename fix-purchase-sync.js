const fs = require('fs');

const path = 'lib/features/suppliers/data/services/drift_purchase_service.dart';
let code = fs.readFileSync(path, 'utf8');

// Add imports if not present
if (!code.includes('sync_queue_service.dart')) {
  code = code.replace(
    "import '../../domain/purchase_draft.dart';",
    "import '../../domain/purchase_draft.dart';\nimport '../../../../core/sync/sync_queue_service.dart';\nimport '../../../../core/sync/models/sync_event_payloads.dart';"
  );
}

// Update constructor
code = code.replace(
  'DriftPurchaseService(this._db, this.currentUser, this.auditLog);',
  'DriftPurchaseService(this._db, this.currentUser, this.auditLog, this._syncQueue);'
);
code = code.replace(
  'final AuditLogService auditLog;',
  'final AuditLogService auditLog;\n  final SyncQueueService _syncQueue;'
);

// Add sync to recordPurchase
const paymentInsert = `paymentMethod: draft.paymentMethod,
              ),
            );`;
const paymentSync = `paymentMethod: draft.paymentMethod,
              ),
            );
            
        await _syncQueue.enqueueCashMovement(
          CashMovementSyncPayload(
            movementId: purchaseId,
            reference: 'ACH-\${purchaseId.substring(0, 6).toUpperCase()}',
            description: 'Achat marchandise: \${draft.supplierName}',
            amount: draft.amountPaid,
            typeIndex: 1, // outflow
            paymentMethodIndex: draft.paymentMethod.index,
            date: date,
          ),
        );`;
code = code.replace(paymentInsert, paymentSync);

// Add sync to recordSupplierPayment
const supplierPaymentInsert = `paymentMethod: method,
              ),
            );`;
const supplierPaymentSync = `paymentMethod: method,
              ),
            );
            
        await _syncQueue.enqueueCashMovement(
          CashMovementSyncPayload(
            movementId: const Uuid().v4(),
            reference: 'REG-\${purchase.id.substring(0, 6).toUpperCase()}',
            description: 'Règlement dette fournisseur',
            amount: applied,
            typeIndex: 1, // outflow
            paymentMethodIndex: method.index,
            date: paymentDate,
          ),
        );`;
code = code.replace(supplierPaymentInsert, supplierPaymentSync);

fs.writeFileSync(path, code);
console.log('Purchase service updated');
