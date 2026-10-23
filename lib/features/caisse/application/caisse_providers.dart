import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/cash_movement_type.dart';
import '../../../core/providers/database_provider.dart';

export '../../../core/domain/cash_movement_type.dart';

class CashMovementView {
  const CashMovementView({
    required this.id,
    required this.reference,
    required this.description,
    required this.date,
    required this.amount,
    required this.type,
    required this.paymentMethodName,
    required this.icon,
  });

  final String id;
  final String reference;
  final String description;
  final DateTime date;
  final int amount;
  final CashMovementType type;
  final String paymentMethodName;
  final IconData icon;
}

class CaisseData {
  const CaisseData({
    required this.currentBalance,
    required this.todayInflow,
    required this.todayOutflow,
    required this.todayOperationsCount,
    required this.movements,
  });

  final int currentBalance;
  final int todayInflow;
  final int todayOutflow;
  final int todayOperationsCount;
  final List<CashMovementView> movements;
}

final caisseDataProvider = FutureProvider<CaisseData>((ref) async {
  final db = ref.watch(databaseProvider);

  final sales = await (db.select(db.sales)
        ..where((s) => s.isCancelled.equals(false) & s.amountPaid.isBiggerThanValue(0))
        ..orderBy([(s) => OrderingTerm(expression: s.date, mode: OrderingMode.desc)]))
      .get();

  final creditPayments = await (db.select(db.creditPayments)
        ..orderBy([(c) => OrderingTerm(expression: c.date, mode: OrderingMode.desc)]))
      .get();

  final purchases = await (db.select(db.purchases)
        ..where((p) => p.isCancelled.equals(false) & p.amountPaid.isBiggerThanValue(0))
        ..orderBy([(p) => OrderingTerm(expression: p.date, mode: OrderingMode.desc)]))
      .get();

  final supplierPayments = await (db.select(db.supplierPayments)
        ..orderBy([(sp) => OrderingTerm(expression: sp.date, mode: OrderingMode.desc)]))
      .get();

  final manualMovements = await (db.select(db.cashMovements)
        ..orderBy([(m) => OrderingTerm(expression: m.date, mode: OrderingMode.desc)]))
      .get();

  final expenses = await (db.select(db.expenses)
        ..orderBy([(e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc)]))
      .get();

  final movements = <CashMovementView>[];

  // Entrées par ventes
  for (final s in sales) {
    movements.add(
      CashMovementView(
        id: s.id,
        reference: s.reference,
        description: 'Vente directe',
        date: s.date,
        amount: s.amountPaid,
        type: CashMovementType.inflow,
        paymentMethodName: s.paymentMethod.name.toUpperCase(),
        icon: Icons.add_shopping_cart_outlined,
      ),
    );
  }

  // Entrées par règlements de crédits clients
  for (final cp in creditPayments) {
    movements.add(
      CashMovementView(
        id: cp.id,
        reference: 'REC-${cp.id.substring(0, cp.id.length > 6 ? 6 : cp.id.length).toUpperCase()}',
        description: 'Règlement de créance client',
        date: cp.date,
        amount: cp.amount,
        type: CashMovementType.inflow,
        paymentMethodName: cp.paymentMethod.name.toUpperCase(),
        icon: Icons.payments_outlined,
      ),
    );
  }

  // Sorties par achats fournisseurs
  for (final p in purchases) {
    movements.add(
      CashMovementView(
        id: p.id,
        reference: 'ACH-${p.id.substring(0, p.id.length > 6 ? 6 : p.id.length).toUpperCase()}',
        description: 'Achat marchandise',
        date: p.date,
        amount: p.amountPaid,
        type: CashMovementType.outflow,
        paymentMethodName: 'ESPÈCES',
        icon: Icons.shopping_bag_outlined,
      ),
    );
  }

  // Sorties par règlements dettes fournisseurs
  for (final sp in supplierPayments) {
    movements.add(
      CashMovementView(
        id: sp.id,
        reference: 'REG-${sp.id.substring(0, sp.id.length > 6 ? 6 : sp.id.length).toUpperCase()}',
        description: 'Règlement dette fournisseur',
        date: sp.date,
        amount: sp.amount,
        type: CashMovementType.outflow,
        paymentMethodName: sp.paymentMethod.name.toUpperCase(),
        icon: Icons.outbox_outlined,
      ),
    );
  }

  // Mouvements manuels de caisse
  for (final m in manualMovements) {
    final isInflow = m.type == CashMovementType.inflow;
    movements.add(
      CashMovementView(
        id: m.id,
        reference: m.reference,
        description: m.description,
        date: m.date,
        amount: m.amount,
        type: m.type,
        paymentMethodName: m.paymentMethod.name.toUpperCase(),
        icon: isInflow ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
      ),
    );
  }

  // Sorties par dépenses d'exploitation
  for (final e in expenses) {
    movements.add(
      CashMovementView(
        id: e.id,
        reference: e.reference,
        description: 'Dépense : ${e.description}',
        date: e.date,
        amount: e.amount,
        type: CashMovementType.outflow,
        paymentMethodName: e.paymentMethod.name.toUpperCase(),
        icon: Icons.money_off_outlined,
      ),
    );
  }

  // Trier par date décroissante
  movements.sort((a, b) => b.date.compareTo(a.date));

  final now = DateTime.now();
  final startToday = DateTime(now.year, now.month, now.day);

  int todayInflow = 0;
  int todayOutflow = 0;
  int todayOps = 0;
  int totalBalance = 0;

  for (final m in movements) {
    if (m.type == CashMovementType.inflow) {
      totalBalance += m.amount;
      if (m.date.isAfter(startToday)) {
        todayInflow += m.amount;
        todayOps++;
      }
    } else {
      totalBalance -= m.amount;
      if (m.date.isAfter(startToday)) {
        todayOutflow += m.amount;
        todayOps++;
      }
    }
  }

  return CaisseData(
    currentBalance: totalBalance,
    todayInflow: todayInflow,
    todayOutflow: todayOutflow,
    todayOperationsCount: todayOps,
    movements: movements,
  );
});
