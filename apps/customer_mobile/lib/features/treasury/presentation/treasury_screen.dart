import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

enum TreasuryPeriod { today, last7Days, thisMonth }

final treasuryPeriodProvider = StateProvider<TreasuryPeriod>((ref) => TreasuryPeriod.today);

final treasuryDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);
  final period = ref.watch(treasuryPeriodProvider);
  final prefs = await SharedPreferences.getInstance();

  List<MobileExpense> allExpenses = await db.select(db.mobileExpenses).get();
  List<MobileSale> allSales = await db.select(db.mobileSales).get();

  // Initialiser quelques exemples si vide
  if (allExpenses.isEmpty) {
    final now = DateTime.now();
    await db.into(db.mobileExpenses).insert(
      MobileExpensesCompanion.insert(
        id: 'exp-${now.millisecondsSinceEpoch}-1',
        title: 'Transport Réassort Marchandises',
        amount: const drift.Value(25000),
        category: const drift.Value('Transport'),
        note: const drift.Value('Taxi-bagage grand marché'),
        createdAt: drift.Value(now.subtract(const Duration(hours: 3))),
      ),
    );
    await db.into(db.mobileExpenses).insert(
      MobileExpensesCompanion.insert(
        id: 'exp-${now.millisecondsSinceEpoch}-2',
        title: 'Achat Sacs Emballages Plastiques',
        amount: const drift.Value(15000),
        category: const drift.Value('Sacs/Emballages'),
        note: const drift.Value('100 sacs imprimés N\'MaShop'),
        createdAt: drift.Value(now.subtract(const Duration(hours: 1))),
      ),
    );
    allExpenses = await db.select(db.mobileExpenses).get();
  }

  final now = DateTime.now();
  final todayDateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final openingFloat = prefs.getInt('nmashop_cash_float_$todayDateKey') ?? 0;

  DateTime startDate;
  switch (period) {
    case TreasuryPeriod.today:
      startDate = DateTime(now.year, now.month, now.day);
      break;
    case TreasuryPeriod.last7Days:
      startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      break;
    case TreasuryPeriod.thisMonth:
      startDate = DateTime(now.year, now.month, 1);
      break;
  }

  int cashCollected = 0;
  int momoCollected = 0;
  int cardCollected = 0;
  int totalSalesAmount = 0;

  for (final s in allSales) {
    if (s.isCancelled) continue;
    if (s.date.isAfter(startDate) || s.date.isAtSameMomentAs(startDate)) {
      totalSalesAmount += s.total;
      if (s.paymentMethod == 0) {
        cashCollected += s.amountPaid;
      } else if (s.paymentMethod == 1 || s.paymentMethod == 2) {
        momoCollected += s.amountPaid;
      } else {
        cardCollected += s.amountPaid;
      }
    }
  }

  int totalExpenses = 0;
  final Map<String, int> expensesByCategory = {};
  final List<MobileExpense> filteredExpenses = [];

  for (final e in allExpenses) {
    if (e.createdAt.isAfter(startDate) || e.createdAt.isAtSameMomentAs(startDate)) {
      filteredExpenses.add(e);
      totalExpenses += e.amount;
      expensesByCategory[e.category] = (expensesByCategory[e.category] ?? 0) + e.amount;
    }
  }

  // Solde théorique en espèces : Fond de caisse + Ventes espèces - Dépenses espèces
  final theoreticalCash = (openingFloat + cashCollected - totalExpenses).clamp(0, 9999999999);

  filteredExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return {
    'openingFloat': openingFloat,
    'todayDateKey': todayDateKey,
    'cashCollected': cashCollected,
    'momoCollected': momoCollected,
    'cardCollected': cardCollected,
    'totalSalesAmount': totalSalesAmount,
    'totalExpenses': totalExpenses,
    'theoreticalCash': theoreticalCash,
    'expensesByCategory': expensesByCategory,
    'filteredExpenses': filteredExpenses,
  };
});

class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treasuryAsync = ref.watch(treasuryDataProvider);
    final currentPeriod = ref.watch(treasuryPeriodProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: NmaMobileAppBar(
        title: 'Suivi de Caisse & Trésorerie',
        subtitle: 'Bilan des flux, pointage & dépenses',
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(treasuryDataProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_treasury_expense',
        onPressed: () => _showAddExpenseModal(context, ref),
        backgroundColor: AppColors.error,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text(
          'Sortie Caisse',
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
          final openingFloat = data['openingFloat'] as int? ?? 0;
          final todayDateKey = data['todayDateKey'] as String? ?? '';
          final cashCollected = data['cashCollected'] as int? ?? 0;
          final momoCollected = data['momoCollected'] as int? ?? 0;
          final cardCollected = data['cardCollected'] as int? ?? 0;
          final totalExpenses = data['totalExpenses'] as int? ?? 0;
          final theoreticalCash = data['theoreticalCash'] as int? ?? 0;
          final expensesByCategory = (data['expensesByCategory'] as Map<String, int>?) ?? {};
          final expenses = (data['filteredExpenses'] as List<MobileExpense>?) ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            children: [
              // ── FILTRES PÉRIODE ──
              Row(
                children: [
                  _buildPeriodChip(ref, currentPeriod, TreasuryPeriod.today, 'Aujourd\'hui'),
                  const SizedBox(width: 8),
                  _buildPeriodChip(ref, currentPeriod, TreasuryPeriod.last7Days, '7 Derniers Jours'),
                  const SizedBox(width: 8),
                  _buildPeriodChip(ref, currentPeriod, TreasuryPeriod.thisMonth, 'Ce Mois'),
                ],
              ),
              const SizedBox(height: 14),

              // ── HERO CARD : SOLDE THÉORIQUE CAISSE ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.heroNavyGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandNavy.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.point_of_sale_rounded, color: AppColors.brandOrangeLight, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'SOLDE THÉORIQUE ESPÈCES',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _showEditOpeningFloatModal(context, ref, todayDateKey, openingFloat),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Fond Caisse', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppFormatters.formatCurrency(theoreticalCash),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFormulaItem('Fond initial', '+ ${AppFormatters.formatCurrency(openingFloat)}', Colors.white70),
                          const Text('+', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                          _buildFormulaItem('Ventes cash', '+ ${AppFormatters.formatCurrency(cashCollected)}', AppColors.brandEmerald),
                          const Text('-', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                          _buildFormulaItem('Dépenses', '- ${AppFormatters.formatCurrency(totalExpenses)}', const Color(0xFFF87171)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── BOUTONS ACTIONS RAPIDES (Point de caisse & Fond de caisse) ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCashCountModal(
                        context,
                        ref,
                        theoreticalCash: theoreticalCash,
                        openingFloat: openingFloat,
                        cashCollected: cashCollected,
                        momoCollected: momoCollected,
                        totalExpenses: totalExpenses,
                      ),
                      icon: const Icon(Icons.calculate_rounded, size: 18),
                      label: const Text('Faire le Point (Clôture)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditOpeningFloatModal(context, ref, todayDateKey, openingFloat),
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.brandOrange),
                      label: const Text('Ajuster Fond', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.border),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── AUTRES FLUX (Mobile Money & Cartes) ──
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Mobile Money',
                      subtitle: 'Orange & MoMo',
                      value: AppFormatters.formatCurrency(momoCollected),
                      icon: Icons.phone_android_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Banque & Carte',
                      subtitle: 'Virements & TPE',
                      value: AppFormatters.formatCurrency(cardCollected),
                      icon: Icons.credit_card_rounded,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Dépenses',
                      subtitle: '${expenses.length} sortie(s)',
                      value: AppFormatters.formatCurrency(totalExpenses),
                      icon: Icons.trending_down_rounded,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── RÉPARTITION DES DÉPENSES PAR CATÉGORIE ──
              if (expensesByCategory.isNotEmpty) ...[
                const Text(
                  'RÉPARTITION PAR CATÉGORIE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: expensesByCategory.entries.map((entry) {
                      final cat = entry.key;
                      final amt = entry.value;
                      final ratio = totalExpenses > 0 ? (amt / totalExpenses).clamp(0.0, 1.0) : 0.0;
                      final percent = (ratio * 100).toStringAsFixed(1);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(_getCategoryIcon(cat), size: 16, color: _getCategoryColor(cat)),
                                    const SizedBox(width: 6),
                                    Text(cat, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                  ],
                                ),
                                Text(
                                  '${AppFormatters.formatCurrency(amt)} ($percent%)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: AppColors.border,
                                valueColor: AlwaysStoppedAnimation<Color>(_getCategoryColor(cat)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ── HISTORIQUE DES DÉPENSES DÉTAILLÉ ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HISTORIQUE DES DÉPENSES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8),
                  ),
                  Text(
                    '${expenses.length} opération(s)',
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (expenses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 36, color: AppColors.brandEmerald),
                      SizedBox(height: 8),
                      Text('Aucune sortie de caisse sur cette période', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12.5)),
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
                    return _buildExpenseTile(context, ref, exp);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodChip(WidgetRef ref, TreasuryPeriod current, TreasuryPeriod target, String label) {
    final isSelected = current == target;
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(treasuryPeriodProvider.notifier).state = target,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandNavy : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.brandNavy : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.brandNavy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulaItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: color),
              Text(subtitle, style: const TextStyle(fontSize: 9.5, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.brandNavy), maxLines: 1),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(BuildContext context, WidgetRef ref, MobileExpense exp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getCategoryColor(exp.category).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getCategoryIcon(exp.category), color: _getCategoryColor(exp.category), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exp.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(
                  '${exp.category} • ${AppFormatters.formatDateTime(exp.createdAt)}${exp.note != null && exp.note!.isNotEmpty ? " • ${exp.note}" : ""}',
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '- ${AppFormatters.formatCurrency(exp.amount)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
              InkWell(
                onTap: () => _confirmDeleteExpense(context, ref, exp),
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'transport':
        return Icons.local_taxi_rounded;
      case 'loyer':
        return Icons.house_rounded;
      case 'électricité':
      case 'electricite':
        return Icons.bolt_rounded;
      case 'salaire':
        return Icons.badge_rounded;
      case 'approvisionnement':
        return Icons.inventory_2_rounded;
      case 'sacs/emballages':
      case 'emballages':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'transport':
        return const Color(0xFF2563EB);
      case 'loyer':
        return const Color(0xFF7C3AED);
      case 'électricité':
      case 'electricite':
        return AppColors.warning;
      case 'salaire':
        return AppColors.brandEmerald;
      case 'approvisionnement':
        return AppColors.brandOrange;
      case 'sacs/emballages':
      case 'emballages':
        return const Color(0xFF0D9488);
      default:
        return AppColors.secondary;
    }
  }

  // ── MODALE FOND DE CAISSE INITIAL ──
  void _showEditOpeningFloatModal(BuildContext context, WidgetRef ref, String todayDateKey, int currentFloat) {
    final floatCtrl = TextEditingController(text: currentFloat > 0 ? currentFloat.toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceBright,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: AppColors.brandOrange, size: 22),
                    SizedBox(width: 8),
                    Text('Fond de Caisse Initial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Définissez la monnaie d\'ouverture présente physiquement dans le tiroir au démarrage de la journée.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: floatCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Montant Fond de Caisse (GNF)',
                    hintText: 'ex: 100000',
                    prefixIcon: const Icon(Icons.monetization_on_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [50000, 100000, 200000, 500000].map((v) {
                    return ActionChip(
                      label: Text(AppFormatters.formatCurrency(v), style: const TextStyle(fontSize: 11)),
                      onPressed: () => floatCtrl.text = v.toString(),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final newAmt = int.tryParse(floatCtrl.text.trim()) ?? 0;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('nmashop_cash_float_$todayDateKey', newAmt);
                    ref.invalidate(treasuryDataProvider);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fond de caisse fixé à ${AppFormatters.formatCurrency(newAmt)}'), backgroundColor: AppColors.brandEmerald),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enregistrer le Fond de Caisse', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── MODALE SAISIE DÉPENSE ──
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
              color: AppColors.surfaceBright,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.receipt_rounded, color: AppColors.error, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SORTIE DE CAISSE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.error, letterSpacing: 0.8)),
                          Text('Enregistrer une Dépense', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Motif / Intitulé *',
                      hintText: 'ex: Taxi réassort, Sacs emballage, Déjeuner équipe',
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
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) {
                            if (val != null) setStateModal(() => selectedCategory = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick chips
                  Wrap(
                    spacing: 6,
                    children: [5000, 10000, 25000, 50000, 100000].map((v) {
                      return ActionChip(
                        label: Text(AppFormatters.formatCurrency(v), style: const TextStyle(fontSize: 10.5)),
                        onPressed: () => amountCtrl.text = v.toString(),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Note / Justificatif (optionnel)',
                      hintText: 'ex: Reçu N° 4029 ou bénéficiaire',
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
                    child: const Text('Valider la Dépense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── MODALE POINTAGE / CLÔTURE DE CAISSE (BILAN Z) ──
  void _showCashCountModal(
    BuildContext context,
    WidgetRef ref, {
    required int theoreticalCash,
    required int openingFloat,
    required int cashCollected,
    required int momoCollected,
    required int totalExpenses,
  }) {
    final countedCtrl = TextEditingController();
    int difference = 0;
    bool hasEnteredCount = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          final countedAmt = int.tryParse(countedCtrl.text.trim()) ?? 0;
          if (hasEnteredCount) {
            difference = countedAmt - theoreticalCash;
          }

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceBright,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.point_of_sale_rounded, color: AppColors.brandNavy, size: 24),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CLÔTURE & POINTAGE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.brandOrange, letterSpacing: 0.8)),
                          Text('Point de Caisse Quotidien', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Récapitulatif théorique
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryLine('Fond de caisse initial', '+ ${AppFormatters.formatCurrency(openingFloat)}'),
                        _buildSummaryLine('Encaissements Espèces', '+ ${AppFormatters.formatCurrency(cashCollected)}'),
                        _buildSummaryLine('Mobile Money (hors caisse cash)', AppFormatters.formatCurrency(momoCollected)),
                        _buildSummaryLine('Dépenses Espèces décaissées', '- ${AppFormatters.formatCurrency(totalExpenses)}', isNegative: true),
                        const Divider(height: 16),
                        _buildSummaryLine('SOLDE THÉORIQUE ATTENDU', AppFormatters.formatCurrency(theoreticalCash), isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Saisie montant physique compté
                  TextField(
                    controller: countedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Montant physique compté dans le tiroir (GNF) *',
                      hintText: 'ex: 450000',
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      setStateModal(() {
                        hasEnteredCount = true;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Affichage de l'écart
                  if (hasEnteredCount) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: difference == 0
                            ? AppColors.brandEmerald.withValues(alpha: 0.12)
                            : difference > 0
                                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                : AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: difference == 0
                              ? AppColors.brandEmerald
                              : difference > 0
                                  ? const Color(0xFF2563EB)
                                  : AppColors.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            difference == 0
                                ? Icons.check_circle_rounded
                                : difference > 0
                                    ? Icons.trending_up_rounded
                                    : Icons.warning_rounded,
                            color: difference == 0
                                ? AppColors.brandEmerald
                                : difference > 0
                                    ? const Color(0xFF2563EB)
                                    : AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  difference == 0
                                      ? 'Caisse Parfaite (Aucun écart)'
                                      : difference > 0
                                          ? 'Excédent de Caisse : +${AppFormatters.formatCurrency(difference)}'
                                          : 'Manquant de Caisse : ${AppFormatters.formatCurrency(difference)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: difference == 0
                                        ? AppColors.brandEmerald
                                        : difference > 0
                                            ? const Color(0xFF2563EB)
                                            : AppColors.error,
                                  ),
                                ),
                                Text(
                                  difference == 0
                                      ? 'Les espèces réelles correspondent exactement aux écritures comptables.'
                                      : difference > 0
                                          ? 'Il y a plus d\'argent dans le tiroir que prévu par les ventes.'
                                          : 'Il manque de l\'argent par rapport aux ventes et dépenses saisies.',
                                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bouton Partager Bilan Z (WhatsApp)
                  ElevatedButton.icon(
                    onPressed: () => _shareBilanZ(
                      openingFloat: openingFloat,
                      cashCollected: cashCollected,
                      momoCollected: momoCollected,
                      totalExpenses: totalExpenses,
                      theoreticalCash: theoreticalCash,
                      countedCash: countedAmt,
                      difference: difference,
                    ),
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: const Text('Partager le Bilan Z (WhatsApp / SMS)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Fermer le Point de Caisse', style: TextStyle(color: AppColors.brandNavy, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryLine(String title, String val, {bool isNegative = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: isTotal ? 12.5 : 11.5, fontWeight: isTotal ? FontWeight.bold : FontWeight.w500, color: isTotal ? AppColors.brandNavy : AppColors.onSurfaceVariant)),
          Text(
            val,
            style: TextStyle(
              fontSize: isTotal ? 13.5 : 12,
              fontWeight: FontWeight.bold,
              color: isTotal
                  ? AppColors.brandNavy
                  : isNegative
                      ? AppColors.error
                      : AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareBilanZ({
    required int openingFloat,
    required int cashCollected,
    required int momoCollected,
    required int totalExpenses,
    required int theoreticalCash,
    required int countedCash,
    required int difference,
  }) async {
    final now = DateTime.now();
    final dateStr = AppFormatters.formatDateTime(now);

    final msg = '''
📊 *BILAN DE CLÔTURE DE CAISSE (Z)* 📊
━━━━━━━━━━━━━━━━━━━━
🏪 *N'MaShop POS*
📅 Date : $dateStr

💰 *FLUX ESPÈCES (TIROIR)* :
• Fond d'ouverture : ${AppFormatters.formatCurrency(openingFloat)}
• Ventes Espèces : +${AppFormatters.formatCurrency(cashCollected)}
• Dépenses Caisse : -${AppFormatters.formatCurrency(totalExpenses)}
────────────────────
💼 *SOLDE THÉORIQUE ATTENDU* : ${AppFormatters.formatCurrency(theoreticalCash)}
💵 *ESPÈCES COMPTÉES* : ${AppFormatters.formatCurrency(countedCash)}
⚖️ *ÉCART DE CAISSE* : ${difference >= 0 ? "+${AppFormatters.formatCurrency(difference)}" : AppFormatters.formatCurrency(difference)} ${difference == 0 ? "✅ (Parfait)" : difference > 0 ? "🔵 (Excédent)" : "🔴 (Manquant)"}

📱 *AUTRES MODES ENCAISSÉS* :
• Mobile Money : ${AppFormatters.formatCurrency(momoCollected)}
━━━━━━━━━━━━━━━━━━━━
_Généré automatiquement par N'MaShop Mobile_
''';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _confirmDeleteExpense(BuildContext context, WidgetRef ref, MobileExpense exp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette dépense ?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous annuler la dépense "${exp.title}" de ${AppFormatters.formatCurrency(exp.amount)} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(mobileDatabaseProvider);
              await (db.delete(db.mobileExpenses)..where((tbl) => tbl.id.equals(exp.id))).go();
              ref.invalidate(treasuryDataProvider);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dépense supprimée')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
