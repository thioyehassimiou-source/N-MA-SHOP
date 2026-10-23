import 'package:intl/intl.dart';

import '../../../core/format/formatters.dart';

/// Données synthétiques et exhaustives pour le Rapport de Clôture Journalière (Rapport Z).
class ZReportData {
  const ZReportData({
    required this.date,
    required this.generatedAt,
    required this.businessName,
    required this.businessPhone,
    required this.businessAddress,
    required this.businessNif,
    required this.cashierName,
    required this.totalSalesCount,
    required this.totalRevenue,
    required this.cashSales,
    required this.mobileMoneySales,
    required this.bankSales,
    required this.creditSales,
    required this.creditPaymentsCash,
    required this.creditPaymentsMobile,
    required this.creditPaymentsBank,
    required this.totalCreditPayments,
    required this.manualInflowCash,
    required this.manualOutflowCash,
    required this.expensesCash,
    required this.expensesOther,
    required this.purchasesCash,
    required this.supplierPaymentsCash,
    required this.openingBalance,
    required this.theoreticalCash,
    required this.countedCash,
    required this.discrepancy,
    this.denominations = const {},
    this.notes = '',
  });

  /// Date de l'activité clôturée
  final DateTime date;

  /// Horodatage précis de l'édition du rapport
  final DateTime generatedAt;

  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String businessNif;
  final String cashierName;

  // ── Activité commerciale & Ventes directes ──
  final int totalSalesCount;
  final int totalRevenue;
  final int cashSales;
  final int mobileMoneySales;
  final int bankSales;
  final int creditSales;

  // ── Recouvrement de créances clients ──
  final int creditPaymentsCash;
  final int creditPaymentsMobile;
  final int creditPaymentsBank;
  final int totalCreditPayments;

  // ── Mouvements de caisse & Décaissements ──
  final int manualInflowCash;
  final int manualOutflowCash;
  final int expensesCash;
  final int expensesOther;
  final int purchasesCash;
  final int supplierPaymentsCash;

  // ── Audit & Rapprochement physique ──
  final int openingBalance;
  final int theoreticalCash;
  final int countedCash;
  final int discrepancy; // countedCash - theoreticalCash
  final Map<int, int> denominations;
  final String notes;

  /// Total des entrées physiques en espèces dans la journée
  int get totalInflowCash => cashSales + creditPaymentsCash + manualInflowCash;

  /// Total des sorties physiques en espèces dans la journée
  int get totalOutflowCash => manualOutflowCash + expensesCash + purchasesCash + supplierPaymentsCash;

  /// Flux net d'espèces du jour
  int get netCashFlow => totalInflowCash - totalOutflowCash;

  /// Total global des fonds encaissés (tous moyens confondus)
  int get totalCollectedToday => cashSales + mobileMoneySales + bankSales + totalCreditPayments;

  /// Panier moyen par vente
  int get averageBasket => totalSalesCount > 0 ? (totalRevenue / totalSalesCount).round() : 0;

  /// Copie avec modification du montant compté et des dénominations
  ZReportData copyWithCounted({
    required int countedCash,
    Map<int, int>? denominations,
    String? notes,
  }) {
    return ZReportData(
      date: date,
      generatedAt: DateTime.now(),
      businessName: businessName,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
      businessNif: businessNif,
      cashierName: cashierName,
      totalSalesCount: totalSalesCount,
      totalRevenue: totalRevenue,
      cashSales: cashSales,
      mobileMoneySales: mobileMoneySales,
      bankSales: bankSales,
      creditSales: creditSales,
      creditPaymentsCash: creditPaymentsCash,
      creditPaymentsMobile: creditPaymentsMobile,
      creditPaymentsBank: creditPaymentsBank,
      totalCreditPayments: totalCreditPayments,
      manualInflowCash: manualInflowCash,
      manualOutflowCash: manualOutflowCash,
      expensesCash: expensesCash,
      expensesOther: expensesOther,
      purchasesCash: purchasesCash,
      supplierPaymentsCash: supplierPaymentsCash,
      openingBalance: openingBalance,
      theoreticalCash: theoreticalCash,
      countedCash: countedCash,
      discrepancy: countedCash - theoreticalCash,
      denominations: denominations ?? this.denominations,
      notes: notes ?? this.notes,
    );
  }

  /// Synthèse textuelle enrichie prête pour partage WhatsApp / SMS
  String toShareableText() {
    final df = DateFormat('dd/MM/yyyy à HH:mm', 'fr');
    final dateStr = DateFormat('dd/MM/yyyy', 'fr').format(date);
    final ecartSign = discrepancy > 0 ? '+${formatGnf(discrepancy)}' : formatGnf(discrepancy);
    final ecartStatus = discrepancy == 0
        ? '✅ PARFAIT (0 GNF)'
        : (discrepancy > 0 ? '⚠️ EXCÉDENT ($ecartSign)' : '🚨 DÉFICIT / MANQUANT ($ecartSign)');

    return '''
📊 *CLÔTURE DE CAISSE (RAPPORT Z)*
🏪 *$businessName*
📅 Date : $dateStr (Généré le ${df.format(generatedAt)})
👤 Opérateur / Caissier : $cashierName
---------------------------------
💰 *CHIFFRE D'AFFAIRES DU JOUR*
• Ventes totales : ${formatGnf(totalRevenue)} ($totalSalesCount ventes)
• Espèces reçues : ${formatGnf(cashSales)}
• Mobile Money (OM / MoMo) : ${formatGnf(mobileMoneySales)}
• Virement / Chèque : ${formatGnf(bankSales)}
• Ventes à Crédit : ${formatGnf(creditSales)}

📥 *RECOUVREMENT CRÉANCES*
• Crédits récupérés : ${formatGnf(totalCreditPayments)}

📤 *DÉCAISSEMENTS ESPÈCES*
• Dépenses d'exploitation : ${formatGnf(expensesCash)}
• Achats / Fournisseurs : ${formatGnf(purchasesCash + supplierPaymentsCash)}
• Retraits de caisse : ${formatGnf(manualOutflowCash)}
• Total décaissé : ${formatGnf(totalOutflowCash)}

💵 *RAPPROCHEMENT DU TIROIR-CAISSE*
• Fond de départ : ${formatGnf(openingBalance)}
• Entrées espèces : +${formatGnf(totalInflowCash)}
• Sorties espèces : -${formatGnf(totalOutflowCash)}
• -------------------------------
• *SOLDE THÉORIQUE* : ${formatGnf(theoreticalCash)}
• *MONTANT COMPTÉ* : ${formatGnf(countedCash)}
• *ÉCART DE CAISSE* : $ecartStatus
${notes.trim().isNotEmpty ? '\n📝 *Notes* : $notes' : ''}
---------------------------------
_Généré via N'MaShop Desktop v2.0_
''';
  }
}
