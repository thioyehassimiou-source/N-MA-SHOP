import '../../../../core/domain/payment_method.dart';

/// Une ligne de vente saisie par le commerçant (avant enregistrement).
class SaleDraftLine {
  const SaleDraftLine({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final int quantity;

  /// Prix de vente unitaire retenu pour cette vente (GNF) — le commerçant
  /// peut l'ajuster par rapport au prix conseillé.
  final int unitPrice;

  /// Total de la ligne (GNF), arrondi à l'entier.
  int get lineTotal => unitPrice * quantity;
}

/// Un règlement immédiat (espèces, mobile money ou banque).
/// Le crédit n'est PAS un tender : il est déduit du reste à payer.
class PaymentTender {
  const PaymentTender({required this.method, required this.amount})
    : assert(
        method != PaymentMethod.credit,
        'Le crédit n\'est pas un règlement immédiat',
      );

  final PaymentMethod method;
  final int amount; // GNF
}

/// Intention de vente complète, prête à être soumise au moteur.
///
/// Modéliser les paiements en liste ouvre la porte, sans refonte, aux
/// paiements mixtes et partiels (extensibilité prévue au cahier des charges).
class SaleDraft {
  const SaleDraft({
    this.customerId,
    required this.lines,
    required this.tenders,
    this.note,
    this.date,
    this.userId,
    this.sellerName,
  });

  /// Client rattaché (obligatoire si une part reste à crédit).
  final String? customerId;
  final List<SaleDraftLine> lines;
  final List<PaymentTender> tenders;
  final String? note;

  /// Date de la vente ; par défaut « maintenant » côté moteur.
  final DateTime? date;

  /// Utilisateur/Vendeur ayant effectué la vente.
  final String? userId;

  /// Nom figé du vendeur au moment de la vente.
  final String? sellerName;

  /// Montant total de la vente (GNF).
  int get total => lines.fold(0, (sum, l) => sum + l.lineTotal);

  /// Montant réglé immédiatement (GNF).
  int get paidImmediately => tenders.fold(0, (sum, t) => sum + t.amount);

  /// Reste dû par le client après règlements immédiats (la créance).
  /// Peut être 0 (payé) ; négatif signifie un trop-perçu (invalide).
  int get creditAmount => total - paidImmediately;

  /// Montants encaissés par moyen de règlement (pour la comptabilité).
  Map<PaymentMethod, int> get tendersByMethod {
    final map = <PaymentMethod, int>{};
    for (final t in tenders) {
      map[t.method] = (map[t.method] ?? 0) + t.amount;
    }
    return map;
  }
}
