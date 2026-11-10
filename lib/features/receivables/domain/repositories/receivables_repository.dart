import '../../../../core/domain/payment_method.dart';
import '../credit_summary.dart';

/// Accès au cahier de crédit : qui doit combien.
abstract interface class ReceivablesRepository {
  /// Flux réactif des clients ayant un solde dû, du plus gros débiteur au plus
  /// petit. Un client sans reste dû n'apparaît pas.
  ///
  /// L'enregistrement d'un remboursement passe par le `RecordRepaymentUseCase`
  /// (il génère aussi l'écriture comptable), pas par ce dépôt de lecture.
  Stream<List<CreditSummary>> watchCreditSummaries();

  /// Récupère l'historique chronologique des paiements d'un client.
  Future<List<PaymentHistoryItem>> getPaymentHistory(String customerId);
}

/// Représente un paiement/tranche de remboursement effectué par un client.
class PaymentHistoryItem {
  const PaymentHistoryItem({
    required this.amount,
    required this.date,
    this.paymentMethod = PaymentMethod.cash,
    this.saleReference,
  });

  final int amount;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? saleReference;
}
