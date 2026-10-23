import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/cash_movement_type.dart';
import '../../../core/domain/payment_method.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/z_report_data.dart';

final zReportDataProvider = FutureProvider.family<ZReportData, DateTime?>((ref, targetDate) async {
  final db = ref.watch(databaseProvider);
  final settings = ref.watch(appSettingsProvider);
  final currentUser = ref.watch(authProvider);

  final date = targetDate ?? DateTime.now();
  final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
  final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  // 1. Calcul du Solde d'Ouverture (Opérations antérieures à aujourd'hui)
  final priorSales = await (db.select(db.sales)
        ..where((s) =>
            s.date.isSmallerThanValue(startOfDay) &
            s.isCancelled.equals(false) &
            s.paymentMethod.equals(PaymentMethod.cash.index)))
      .get();
  final priorSalesCash = priorSales.fold<int>(0, (sum, s) => sum + s.amountPaid);

  final priorCreditPayments = await (db.select(db.creditPayments)
        ..where((cp) =>
            cp.date.isSmallerThanValue(startOfDay) &
            cp.paymentMethod.equals(PaymentMethod.cash.index)))
      .get();
  final priorCreditCash = priorCreditPayments.fold<int>(0, (sum, cp) => sum + cp.amount);

  final priorMovements = await (db.select(db.cashMovements)
        ..where((m) => m.date.isSmallerThanValue(startOfDay)))
      .get();
  int priorInflows = 0;
  int priorOutflows = 0;
  for (final m in priorMovements) {
    if (m.type == CashMovementType.inflow) {
      priorInflows += m.amount;
    } else {
      priorOutflows += m.amount;
    }
  }

  final priorExpenses = await (db.select(db.expenses)
        ..where((e) =>
            e.date.isSmallerThanValue(startOfDay) &
            e.paymentMethod.equals(PaymentMethod.cash.index)))
      .get();
  final priorExpensesCash = priorExpenses.fold<int>(0, (sum, e) => sum + e.amount);

  final priorPurchases = await (db.select(db.purchases)
        ..where((p) =>
            p.date.isSmallerThanValue(startOfDay) &
            p.isCancelled.equals(false)))
      .get();
  final priorPurchasesCash = priorPurchases.fold<int>(0, (sum, p) => sum + p.amountPaid);

  final priorSupplierPayments = await (db.select(db.supplierPayments)
        ..where((sp) =>
            sp.date.isSmallerThanValue(startOfDay) &
            sp.paymentMethod.equals(PaymentMethod.cash.index)))
      .get();
  final priorSupplierPaymentsCash = priorSupplierPayments.fold<int>(0, (sum, sp) => sum + sp.amount);

  final openingBalance = priorSalesCash +
      priorCreditCash +
      priorInflows -
      priorOutflows -
      priorExpensesCash -
      priorPurchasesCash -
      priorSupplierPaymentsCash;

  // 2. Ventes de la journée
  final todaySales = await (db.select(db.sales)
        ..where((s) =>
            s.date.isBiggerOrEqualValue(startOfDay) &
            s.date.isSmallerOrEqualValue(endOfDay) &
            s.isCancelled.equals(false)))
      .get();

  int totalSalesCount = todaySales.length;
  int totalRevenue = 0;
  int cashSales = 0;
  int mobileMoneySales = 0;
  int bankSales = 0;
  int creditSales = 0;

  for (final s in todaySales) {
    totalRevenue += s.totalAmount;
    if (s.paymentMethod == PaymentMethod.cash) {
      cashSales += s.amountPaid;
    } else if (s.paymentMethod == PaymentMethod.mobileMoney) {
      mobileMoneySales += s.amountPaid;
    } else if (s.paymentMethod == PaymentMethod.bank) {
      bankSales += s.amountPaid;
    }
    // Reste dû non réglé
    if (s.totalAmount > s.amountPaid) {
      creditSales += (s.totalAmount - s.amountPaid);
    }
  }

  // 3. Règlements de créances du jour
  final todayCreditPayments = await (db.select(db.creditPayments)
        ..where((cp) =>
            cp.date.isBiggerOrEqualValue(startOfDay) &
            cp.date.isSmallerOrEqualValue(endOfDay)))
      .get();

  int creditPaymentsCash = 0;
  int creditPaymentsMobile = 0;
  int creditPaymentsBank = 0;
  int totalCreditPayments = 0;

  for (final cp in todayCreditPayments) {
    totalCreditPayments += cp.amount;
    if (cp.paymentMethod == PaymentMethod.cash) {
      creditPaymentsCash += cp.amount;
    } else if (cp.paymentMethod == PaymentMethod.mobileMoney) {
      creditPaymentsMobile += cp.amount;
    } else if (cp.paymentMethod == PaymentMethod.bank) {
      creditPaymentsBank += cp.amount;
    }
  }

  // 4. Mouvements manuels de caisse du jour
  final todayMovements = await (db.select(db.cashMovements)
        ..where((m) =>
            m.date.isBiggerOrEqualValue(startOfDay) &
            m.date.isSmallerOrEqualValue(endOfDay)))
      .get();

  int manualInflowCash = 0;
  int manualOutflowCash = 0;
  for (final m in todayMovements) {
    if (m.type == CashMovementType.inflow) {
      manualInflowCash += m.amount;
    } else {
      manualOutflowCash += m.amount;
    }
  }

  // 5. Dépenses d'exploitation du jour
  final todayExpenses = await (db.select(db.expenses)
        ..where((e) =>
            e.date.isBiggerOrEqualValue(startOfDay) &
            e.date.isSmallerOrEqualValue(endOfDay)))
      .get();

  int expensesCash = 0;
  int expensesOther = 0;
  for (final e in todayExpenses) {
    if (e.paymentMethod == PaymentMethod.cash) {
      expensesCash += e.amount;
    } else {
      expensesOther += e.amount;
    }
  }

  // 6. Achats marchandises et règlements fournisseurs
  final todayPurchases = await (db.select(db.purchases)
        ..where((p) =>
            p.date.isBiggerOrEqualValue(startOfDay) &
            p.date.isSmallerOrEqualValue(endOfDay) &
            p.isCancelled.equals(false)))
      .get();
  int purchasesCash = todayPurchases.fold<int>(0, (sum, p) => sum + p.amountPaid);

  final todaySupplierPayments = await (db.select(db.supplierPayments)
        ..where((sp) =>
            sp.date.isBiggerOrEqualValue(startOfDay) &
            sp.date.isSmallerOrEqualValue(endOfDay) &
            sp.paymentMethod.equals(PaymentMethod.cash.index)))
      .get();
  int supplierPaymentsCash = todaySupplierPayments.fold<int>(0, (sum, sp) => sum + sp.amount);

  // 7. Calcul du Solde Théorique Espèces
  final totalInflow = cashSales + creditPaymentsCash + manualInflowCash;
  final totalOutflow = manualOutflowCash + expensesCash + purchasesCash + supplierPaymentsCash;
  final theoreticalCash = openingBalance + totalInflow - totalOutflow;

  final cashierName = (currentUser?.fullName != null && currentUser!.fullName.isNotEmpty)
      ? currentUser.fullName
      : 'Gérant / Caissier';

  return ZReportData(
    date: date,
    generatedAt: DateTime.now(),
    businessName: settings.businessName.isNotEmpty ? settings.businessName : 'Ma Boutique',
    businessPhone: settings.businessPhone,
    businessAddress: settings.businessAddress,
    businessNif: settings.businessNif,
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
    countedCash: theoreticalCash, // Par défaut égal au théorique
    discrepancy: 0,
    denominations: const {},
    notes: '',
  );
});
