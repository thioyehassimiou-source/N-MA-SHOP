import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

final reportPeriodProvider = StateProvider<String>((ref) => 'month'); // 'today', 'week', 'month', 'all'

final reportDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);
  final period = ref.watch(reportPeriodProvider);

  final now = DateTime.now();
  DateTime startDate;

  if (period == 'today') {
    startDate = DateTime(now.year, now.month, now.day);
  } else if (period == 'week') {
    startDate = now.subtract(const Duration(days: 7));
  } else if (period == 'month') {
    startDate = DateTime(now.year, now.month, 1);
  } else {
    startDate = DateTime(2020);
  }

  final sales = await db.select(db.mobileSales).get();
  final saleItems = await db.select(db.mobileSaleItems).get();
  final expenses = await db.select(db.mobileExpenses).get();

  num totalRevenue = 0;
  num totalCost = 0;
  int totalSalesCount = 0;

  for (final s in sales) {
    if (s.isCancelled) continue;
    if (s.date.isBefore(startDate)) continue;
    totalRevenue += s.total;
    totalSalesCount++;
  }

  // Calcul du coût d'achat réel des articles vendus
  for (final item in saleItems) {
    totalCost += (item.unitCost * item.quantity);
  }

  // Calcul des dépenses
  num totalExpenses = 0;
  for (final e in expenses) {
    if (e.createdAt.isBefore(startDate)) continue;
    totalExpenses += e.amount;
  }

  final grossProfit = totalRevenue - totalCost;
  final netProfit = grossProfit - totalExpenses;
  final marginPercent = totalRevenue > 0 ? ((grossProfit / totalRevenue) * 100).round() : 0;

  return {
    'totalRevenue': totalRevenue,
    'totalCost': totalCost,
    'grossProfit': grossProfit,
    'totalExpenses': totalExpenses,
    'netProfit': netProfit,
    'marginPercent': marginPercent,
    'totalSalesCount': totalSalesCount,
  };
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportDataProvider);
    final period = ref.watch(reportPeriodProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: NmaMobileAppBar(
        title: 'Bilan & Bénéfices Réels',
        subtitle: 'Marges nettes & rentabilité de la boutique',
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(reportDataProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sélecteur de période
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip(ref, 'Aujourd\'hui', 'today', period),
                  const SizedBox(width: 8),
                  _buildPeriodChip(ref, '7 Derniers Jours', 'week', period),
                  const SizedBox(width: 8),
                  _buildPeriodChip(ref, 'Ce Mois-ci', 'month', period),
                  const SizedBox(width: 8),
                  _buildPeriodChip(ref, 'Tout l\'Historique', 'all', period),
                ],
              ),
            ),
            const SizedBox(height: 16),

            reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (data) {
                final netProfit = (data['netProfit'] as num?) ?? 0;
                final isPositive = netProfit >= 0;

                return Column(
                  children: [
                    // Grande Carte BÉNÉFICE NET RÉEL
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: isPositive
                            ? const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)])
                            : const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'BÉNÉFICE NET RÉEL DÉGAGÉ',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPositive ? AppColors.brandEmerald.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Marge: ${data['marginPercent']}%',
                                  style: TextStyle(
                                    color: isPositive ? AppColors.brandEmerald : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppFormatters.formatCurrency(netProfit),
                            style: TextStyle(
                              color: isPositive ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Chiffre d\'affaires net diminué du coût d\'achat et des charges de caisse.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Détail Décomposition Financière
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DÉCOMPOSITION DU RÉSULTAT',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 14),

                          _buildFinancialRow(
                            label: 'Chiffre d\'Affaires (Recettes Ventes)',
                            amount: data['totalRevenue'],
                            color: AppColors.brandNavy,
                            isPositive: true,
                            icon: Icons.trending_up_rounded,
                          ),
                          const Divider(height: 20, color: AppColors.border),

                          _buildFinancialRow(
                            label: 'Coût d\'Achat des Marchandises Vendues',
                            amount: data['totalCost'],
                            color: const Color(0xFF64748B),
                            isPositive: false,
                            icon: Icons.inventory_2_outlined,
                          ),
                          const Divider(height: 20, color: AppColors.border),

                          _buildFinancialRow(
                            label: 'Marge Brute Réalisée',
                            amount: data['grossProfit'],
                            color: AppColors.brandOrange,
                            isPositive: true,
                            icon: Icons.monetization_on_rounded,
                          ),
                          const Divider(height: 20, color: AppColors.border),

                          _buildFinancialRow(
                            label: 'Dépenses & Frais Généraux',
                            amount: data['totalExpenses'],
                            color: AppColors.error,
                            isPositive: false,
                            icon: Icons.shopping_bag_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Indicateurs de volume
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Volume de Ventes', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  '${data['totalSalesCount']} ventes',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.brandNavy),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Panier Moyen', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  data['totalSalesCount'] > 0
                                      ? AppFormatters.formatCurrency(((data['totalRevenue'] as num) / (data['totalSalesCount'] as num)).round())
                                      : '0 GNF',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brandOrange),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(WidgetRef ref, String label, String value, String current) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppColors.brandNavy)),
      selected: isSelected,
      selectedColor: AppColors.brandNavy,
      backgroundColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
      onSelected: (_) => ref.read(reportPeriodProvider.notifier).state = value,
    );
  }

  Widget _buildFinancialRow({
    required String label,
    required num amount,
    required Color color,
    required bool isPositive,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant)),
        ),
        Text(
          '${isPositive ? "+" : "-"} ${AppFormatters.formatCurrency(amount)}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
      ],
    );
  }
}

