import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

final treasuryDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);

  List<MobileExpense> expenses = await db.select(db.mobileExpenses).get();
  List<MobileSale> sales = await db.select(db.mobileSales).get();

  // Si aucune dépense en BDD locale au premier démarrage, insérer 2 exemples
  if (expenses.isEmpty) {
    final now = DateTime.now();
    final e1 = MobileExpensesCompanion.insert(
      id: 'exp-${now.millisecondsSinceEpoch}-1',
      title: 'Transport Réassort Marchandises',
      amount: const drift.Value(25000),
      category: const drift.Value('Transport'),
      note: const drift.Value('Taxi-bagage grand marché'),
    );
    final e2 = MobileExpensesCompanion.insert(
      id: 'exp-${now.millisecondsSinceEpoch}-2',
      title: 'Achat Sacs Emballages Plastiques',
      amount: const drift.Value(15000),
      category: const drift.Value('Divers'),
      note: const drift.Value('100 sacs imprimés N\'MaShop'),
    );
    await db.into(db.mobileExpenses).insert(e1);
    await db.into(db.mobileExpenses).insert(e2);
    expenses = await db.select(db.mobileExpenses).get();
  }

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  int cashCollectedToday = 0;
  int momoCollectedToday = 0;

  for (final s in sales) {
    if (s.date.isAfter(todayStart) || s.date.isAtSameMomentAs(todayStart)) {
      if (s.paymentMethod == 0) {
        cashCollectedToday += s.amountPaid;
      } else if (s.paymentMethod == 1 || s.paymentMethod == 2 || s.paymentMethod == 3) {
        momoCollectedToday += s.amountPaid;
      }
    }
  }

  int totalExpensesToday = 0;
  for (final e in expenses) {
    if (e.createdAt.isAfter(todayStart) || e.createdAt.isAtSameMomentAs(todayStart)) {
      totalExpensesToday += e.amount;
    }
  }

  int theoreticalCash = (cashCollectedToday - totalExpensesToday).clamp(0, 999999999);

  final recentExps = expenses.reversed.map((e) => {
        'id': e.id,
        'title': e.title,
        'amount': e.amount,
        'category': e.category,
        'note': e.note ?? '',
        'date': AppFormatters.formatDateTime(e.createdAt),
      }).toList();

  return {
    'theoreticalCashInHand': theoreticalCash,
    'momoCollectedToday': momoCollectedToday,
    'expensesToday': totalExpensesToday,
    'recentExpenses': recentExps,
  };
});

class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treasuryAsync = ref.watch(treasuryDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: NmaMobileAppBar(
        title: 'Suivi de Caisse & Trésorerie',
        subtitle: 'Bilan des flux & dépenses',
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(treasuryDataProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_treasury',
        onPressed: () => _showAddExpenseModal(context, ref),
        backgroundColor: AppColors.error,
        icon: const Icon(Icons.receipt_rounded, color: Colors.white),
        label: const Text(
          'Saisir Dépense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: treasuryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Erreur de chargement ($err)', style: const TextStyle(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(treasuryDataProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (data) {
          final theoreticalCash = data['theoreticalCashInHand'] ?? 0;
          final momoToday = data['momoCollectedToday'] ?? 0;
          final expensesToday = data['expensesToday'] ?? 0;
          final expenses = (data['recentExpenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Solde de caisse théorique
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.heroNavyGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandNavy.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SOLDE THÉORIQUE CAISSE ESPÈCES', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppFormatters.formatCurrency(theoreticalCash),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Calculé automatiquement : (Ventes Espèces - Dépenses du jour)',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricBox(
                      'Encaissé Mobile Money',
                      AppFormatters.formatCurrency(momoToday),
                      Icons.phone_android_rounded,
                      const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricBox(
                      'Dépenses du Jour',
                      AppFormatters.formatCurrency(expensesToday),
                      Icons.trending_down_rounded,
                      AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'HISTORIQUE DES DÉPENSES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),

              if (expenses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                      SizedBox(height: 8),
                      Text('Aucune dépense enregistrée', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final exp = expenses[index];
                    return _buildExpenseCard(exp);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> exp) {
    final title = exp['title'] as String? ?? '';
    final amount = (exp['amount'] as num?) ?? 0;
    final cat = exp['category'] as String? ?? 'Divers';
    final date = exp['date'] as String? ?? '';
    final note = exp['note'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.output_rounded, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text('$cat • $date ${note.isNotEmpty ? "• $note" : ""}', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '- ${AppFormatters.formatCurrency(amount)}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseModal(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = 'Transport';

    final categories = ['Transport', 'Loyer', 'Électricité', 'Salaire', 'Approvisionnement', 'Sacs/Emballages', 'Divers'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_rounded, color: AppColors.error, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SORTIE DE CAISSE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.error, letterSpacing: 0.8)),
                          Text('Saisir une Dépense', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Motif / Intitulé de la dépense *',
                      hintText: 'ex: Transport réassort grossiste',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Montant (GNF) *',
                            hintText: 'ex: 25000',
                            prefixIcon: const Icon(Icons.monetization_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Catégorie',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          items: categories
                              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setStateModal(() => selectedCategory = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Note / Justificatif (optionnel)',
                      hintText: 'ex: Reçu N° 4029',
                      prefixIcon: const Icon(Icons.note_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;

                      if (title.isEmpty || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner un motif et un montant valide')),
                        );
                        return;
                      }

                      final db = ref.read(mobileDatabaseProvider);

                      final newExp = MobileExpensesCompanion.insert(
                        id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        amount: drift.Value(amount),
                        category: drift.Value(selectedCategory),
                        note: drift.Value(noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null),
                      );

                      await db.into(db.mobileExpenses).insert(newExp);
                      ref.invalidate(treasuryDataProvider);

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dépense "$title" de ${AppFormatters.formatCurrency(amount)} enregistrée !'),
                          backgroundColor: AppColors.brandEmerald,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Valider la dépense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
