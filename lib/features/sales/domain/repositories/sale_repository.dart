import '../../../../core/domain/payment_method.dart';

/// Données d'en-tête d'une vente à persister.
class NewSaleData {
  const NewSaleData({
    required this.id,
    required this.reference,
    required this.customerId,
    required this.date,
    required this.total,
    required this.amountPaid,
    required this.paymentMethod,
    required this.note,
    this.userId,
    this.sellerName,
  });

  final String id;
  final String reference;
  final String? customerId;
  final DateTime date;
  final int total;
  final int amountPaid;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? userId;
  final String? sellerName;
}

/// Une ligne de vente à persister (prix ET coût figés au moment de la vente).
class NewSaleLine {
  const NewSaleLine({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.label,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
  });

  final String id;
  final String saleId;
  final String productId;
  final String label;
  final int quantity;
  final int unitPrice;
  final int unitCost;
  final int lineTotal;
}

/// Représentation d'une vente passée pour l'historique complet.
class SaleHistoryItem {
  const SaleHistoryItem({
    required this.id,
    required this.reference,
    required this.date,
    required this.customerName,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentMethod,
    required this.isCancelled,
    this.sellerName,
    this.userId,
    this.itemsSummary,
  });

  final String id;
  final String reference;
  final DateTime date;
  final String customerName;
  final int totalAmount;
  final int amountPaid;
  final PaymentMethod paymentMethod;
  final bool isCancelled;
  final String? sellerName;
  final String? userId;
  final String? itemsSummary;

  bool get isCredit => amountPaid < totalAmount;
  bool get isFullyPaid => amountPaid >= totalAmount;
}

/// Persistance des ventes et de leurs lignes.
abstract interface class SaleRepository {
  /// Numéro de ticket lisible et continu pour l'année de [date] (ex. V-2026-000123).
  Future<String> nextReference(DateTime date);

  Future<void> createSale(NewSaleData data);

  Future<void> addLines(List<NewSaleLine> lines);

  Future<List<SaleHistoryItem>> getAllSales({int limit = 100});
}
