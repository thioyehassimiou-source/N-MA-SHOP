import 'dart:convert';

/// Représente un événement unitaire prêt à être synchronisé vers le Cloud.
class SyncEventDto {
  final String eventId;
  final String entityType;
  final String entityId;
  final String action;
  final DateTime timestamp;
  final int sequenceNumber;
  final int schemaVersion;
  final Map<String, dynamic> data;

  const SyncEventDto({
    required this.eventId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.timestamp,
    this.sequenceNumber = 0,
    this.schemaVersion = 1,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'sequenceNumber': sequenceNumber,
        'schemaVersion': schemaVersion,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
      };

  factory SyncEventDto.fromJson(Map<String, dynamic> json) => SyncEventDto(
        eventId: json['eventId'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String,
        action: json['action'] as String,
        sequenceNumber: (json['sequenceNumber'] as num?)?.toInt() ?? 0,
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        timestamp: DateTime.parse(json['timestamp'] as String),
        data: (json['data'] as Map).cast<String, dynamic>(),
      );

  String toPayloadString() => jsonEncode(data);
}

/// Lot d'événements envoyé par le Desktop vers le Cloud.
class SyncBatchRequest {
  final String machineId;
  final String licenseKey;
  final DateTime sentAt;
  final List<SyncEventDto> events;

  const SyncBatchRequest({
    required this.machineId,
    required this.licenseKey,
    required this.sentAt,
    required this.events,
  });

  Map<String, dynamic> toJson() => {
        'machineId': machineId,
        'licenseKey': licenseKey,
        'sentAt': sentAt.toIso8601String(),
        'events': events.map((e) => e.toJson()).toList(),
      };
}

/// DTO pour les lignes de vente synchronisées.
class SaleLineSyncData {
  final String productId;
  final String label;
  final int quantity;
  final int unitPrice;
  final int unitCost;
  final int lineTotal;

  const SaleLineSyncData({
    required this.productId,
    required this.label,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'label': label,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'unitCost': unitCost,
        'lineTotal': lineTotal,
      };
}

/// DTO pour la vente synchronisée.
class SaleSyncPayload {
  final String saleId;
  final String reference;
  final String? customerId;
  final String? customerName;
  final DateTime date;
  final int totalAmount;
  final int amountPaid;
  final int paymentMethodIndex;
  final String? mobileMoneyProvider;
  final String? note;
  final String? sellerId;
  final String? sellerName;
  final bool isCancelled;
  final List<SaleLineSyncData> lines;

  const SaleSyncPayload({
    required this.saleId,
    required this.reference,
    this.customerId,
    this.customerName,
    required this.date,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentMethodIndex,
    this.mobileMoneyProvider,
    this.note,
    this.sellerId,
    this.sellerName,
    this.isCancelled = false,
    required this.lines,
  });

  Map<String, dynamic> toJson() => {
        'saleId': saleId,
        'reference': reference,
        'customerId': customerId,
        'customerName': customerName,
        'date': date.toIso8601String(),
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'paymentMethodIndex': paymentMethodIndex,
        'mobileMoneyProvider': mobileMoneyProvider,
        'note': note,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'isCancelled': isCancelled,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

/// DTO pour les règlements de dettes / créances.
class CreditPaymentSyncPayload {
  final String paymentId;
  final String saleId;
  final String customerId;
  final int amount;
  final DateTime date;
  final int paymentMethodIndex;

  const CreditPaymentSyncPayload({
    required this.paymentId,
    required this.saleId,
    required this.customerId,
    required this.amount,
    required this.date,
    required this.paymentMethodIndex,
  });

  Map<String, dynamic> toJson() => {
        'paymentId': paymentId,
        'saleId': saleId,
        'customerId': customerId,
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentMethodIndex': paymentMethodIndex,
      };
}

/// DTO pour les mouvements de stock.
class StockMovementSyncPayload {
  final String movementId;
  final String productId;
  final int typeIndex;
  final int quantity;
  final int unitCost;
  final String? sourceReference;
  final String? reason;
  final DateTime date;

  const StockMovementSyncPayload({
    required this.movementId,
    required this.productId,
    required this.typeIndex,
    required this.quantity,
    required this.unitCost,
    this.sourceReference,
    this.reason,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'movementId': movementId,
        'productId': productId,
        'typeIndex': typeIndex,
        'quantity': quantity,
        'unitCost': unitCost,
        'sourceReference': sourceReference,
        'reason': reason,
        'date': date.toIso8601String(),
      };
}

/// DTO pour les mouvements manuels de caisse.
class CashMovementSyncPayload {
  final String movementId;
  final String reference;
  final String description;
  final int amount;
  final int typeIndex;
  final DateTime date;
  final int paymentMethodIndex;

  const CashMovementSyncPayload({
    required this.movementId,
    required this.reference,
    required this.description,
    required this.amount,
    required this.typeIndex,
    required this.date,
    required this.paymentMethodIndex,
  });

  Map<String, dynamic> toJson() => {
        'movementId': movementId,
        'reference': reference,
        'description': description,
        'amount': amount,
        'typeIndex': typeIndex,
        'date': date.toIso8601String(),
        'paymentMethodIndex': paymentMethodIndex,
      };
}

/// DTO pour les dépenses opérationnelles.
class ExpenseSyncPayload {
  final String expenseId;
  final String reference;
  final int categoryIndex;
  final int amount;
  final DateTime date;
  final String description;
  final int paymentMethodIndex;

  const ExpenseSyncPayload({
    required this.expenseId,
    required this.reference,
    required this.categoryIndex,
    required this.amount,
    required this.date,
    required this.description,
    required this.paymentMethodIndex,
  });

  Map<String, dynamic> toJson() => {
        'expenseId': expenseId,
        'reference': reference,
        'categoryIndex': categoryIndex,
        'amount': amount,
        'date': date.toIso8601String(),
        'description': description,
        'paymentMethodIndex': paymentMethodIndex,
      };
}
