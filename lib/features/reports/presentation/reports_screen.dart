import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/database/tables/expenses.dart';
import '../application/reports_providers.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;

  Future<void> _exportCsv(ReportData data, ReportRange range) async {
    setState(() => _isExporting = true);
    try {
      final dayFmt = DateFormat('dd/MM/yyyy', 'fr');
      final buf = StringBuffer();

      buf.writeln("Rapport N'MaShop \u2014 ${range.label}");
      buf.writeln('G\u00e9n\u00e9r\u00e9 le ${dayFmt.format(DateTime.now())}');
      buf.writeln();

      buf.writeln('INDICATEURS CL\u00c9S');
      buf.writeln('Chiffre d\'Affaires,${formatGnf(data.revenue)}');
      buf.writeln('B\u00e9n\u00e9fice Brut,${formatGnf(data.grossProfit)}');
      buf.writeln('Total D\u00e9penses,${formatGnf(data.totalExpenses)}');
      buf.writeln('B\u00e9n\u00e9fice Net,${formatGnf(data.netProfit)}');
      buf.writeln('Ventes,${data.salesCount}');
      buf.writeln('Commandes Livr\u00e9es,${data.ordersCount}');
      buf.writeln();

      if (data.dailyRevenues.isNotEmpty) {
        buf.writeln('\u00c9VOLUTION JOURNALI\u00c8RE');
        buf.writeln('Date,Chiffre d\'Affaires,B\u00e9n\u00e9fice');
        for (final d in data.dailyRevenues) {
          buf.writeln('${dayFmt.format(d.date)},${formatGnf(d.revenue)},${formatGnf(d.profit)}');
        }
        buf.writeln();
      }

      if (data.topProducts.isNotEmpty) {
        buf.writeln('TOP PRODUITS');
        buf.writeln('Produit,Quantit\u00e9 vendue,Chiffre d\'Affaires');
        for (final p in data.topProducts) {
          buf.writeln('${p.name},${p.quantitySold},${formatGnf(p.revenue)}');
        }
        buf.writeln();
      }

      if (data.expensesByCategory.isNotEmpty) {
        buf.writeln('D\u00c9PENSES PAR CAT\u00c9GORIE');
        buf.writeln('Cat\u00e9gorie,Montant');
        for (final e in data.expensesByCategory) {
          buf.writeln('${e.category.label},${formatGnf(e.total)}');
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'rapport_nmashop_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buf.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'CSV exporté : ${file.path}',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(reportDataProvider);
    final range = ref.watch(reportRangeProvider);

    return Column(
      children: [
        AppPageHeader(
          title: 'Rapports & Analytiques',
          subtitle: 'Pilotez la rentabilit\u00e9 de votre commerce',
          icon: Icons.bar_chart_rounded,
          gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          actions: [
            asyncData.whenOrNull(
              data: (data) => _isExporting
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _exportCsv(data, range),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Exporter CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
            ) ?? const SizedBox.shrink(),
          ],
          bottom: _PeriodSelector(current: range),
        ),
        Expanded(
          child: asyncData.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (data) => data.salesCount == 0 && data.totalExpenses == 0
                ? _EmptyReportState(range: range)
                : _ReportBody(data: data, range: range),
          ),
        ),
      ],
    );
  }
}

// ─── Sélecteur de période ────────────────────────────────────────────────────

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.current});
  final ReportRange current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(ReportPeriod p, String label) {
      final active = current.period == p;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label, style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : context.colors.onSurfaceVariant,
          )),
          selected: active,
          selectedColor: const Color(0xFF6366F1),
          backgroundColor: context.colors.surfaceContainerHighest,
          side: BorderSide.none,
          onSelected: (_) {
            ref.read(reportRangeProvider.notifier).updateRange(ReportRange.forPeriod(p));
          },
        ),
      );
    }

    return Row(
      children: [
        chip(ReportPeriod.today, "Aujourd'hui"),
        chip(ReportPeriod.week, 'Semaine'),
        chip(ReportPeriod.month, 'Mois'),
        chip(ReportPeriod.year, 'Année'),
        const SizedBox(width: 4),
        ActionChip(
          label: const Text('Personnalisé', style: TextStyle(fontSize: 12)),
          backgroundColor: context.colors.surfaceContainerHighest,
          side: BorderSide.none,
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
              locale: const Locale('fr'),
            );
            if (picked != null) {
              ref.read(reportRangeProvider.notifier).updateRange(ReportRange.forPeriod(
                ReportPeriod.custom,
                customStart: picked.start,
                customEnd: picked.end,
              ));
            }
          },
        ),
      ],
    );
  }
}

// ─── Corps du rapport ────────────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.data, required this.range});
  final ReportData data;
  final ReportRange range;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI Cards
          _KpiGrid(data: data),
          const SizedBox(height: 24),

          // 2. Graphique CA/Bénéfice
          if (data.dailyRevenues.isNotEmpty) ...[
            _RevenueChart(dailyData: data.dailyRevenues),
            const SizedBox(height: 24),
          ],

          // 3. Top Produits & Dépenses par catégorie
          LayoutBuilder(builder: (ctx, c) {
            final topProducts = _TopProductsCard(products: data.topProducts);
            final expenses = _ExpensesByCategoryCard(
              expenses: data.expensesByCategory,
              total: data.totalExpenses,
            );

            if (c.maxWidth < 800) {
              return Column(children: [
                topProducts,
                const SizedBox(height: 24),
                expenses,
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: topProducts),
                const SizedBox(width: 24),
                Expanded(child: expenses),
              ],
            );
          }),
          const SizedBox(height: 24),

          // 4. Résumé financier
          _FinancialSummary(data: data),
        ],
      ),
    );
  }
}

// ─── KPI Cards ───────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cards = [
        _KpiCard(
          label: 'Chiffre d\'Affaires',
          value: formatGnfCompact(data.revenue),
          subtitle: '${data.salesCount} ventes',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF6366F1),
          bgColor: const Color(0xFFEEF2FF),
        ),
        _KpiCard(
          label: 'Bénéfice Net',
          value: formatGnfCompact(data.netProfit),
          subtitle: data.netProfit >= 0 ? 'Rentable' : 'Déficitaire',
          icon: Icons.account_balance_rounded,
          color: data.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          bgColor: data.netProfit >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        ),
        _KpiCard(
          label: 'Total Dépenses',
          value: formatGnfCompact(data.totalExpenses),
          subtitle: '${data.expensesByCategory.length} catégories',
          icon: Icons.money_off_rounded,
          color: const Color(0xFFF59E0B),
          bgColor: const Color(0xFFFFF7ED),
        ),
        _KpiCard(
          label: 'Commandes Livrées',
          value: '${data.ordersCount}',
          subtitle: formatGnfCompact(data.ordersRevenue),
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFF5F3FF),
        ),
      ];

      if (c.maxWidth < 600) {
        return Column(
          children: cards.map((card) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: card,
          )).toList(),
        );
      }
      return Row(
        children: cards.map((card) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: card,
          ),
        )).toList(),
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String label, value, subtitle;
  final IconData icon;
  final Color color, bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

// ─── Graphique CA / Bénéfice ─────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.dailyData});
  final List<DailyRevenue> dailyData;

  @override
  Widget build(BuildContext context) {
    final dayFmt = DateFormat('dd/MM', 'fr');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Évolution du Chiffre d\'Affaires',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              _LegendDot(color: const Color(0xFF6366F1), label: 'CA'),
              const SizedBox(width: 16),
              _LegendDot(color: const Color(0xFF10B981), label: 'Bénéfice'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: dailyData.map((d) => d.revenue.toDouble()).fold(0.0, (a, b) => a > b ? a : b) * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = dailyData[groupIndex];
                      final label = rodIndex == 0 ? 'CA' : 'Bénéfice';
                      final val = rodIndex == 0 ? d.revenue : d.profit;
                      return BarTooltipItem(
                        '$label\n${formatGnfCompact(val)}',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final i = val.toInt();
                        if (i < 0 || i >= dailyData.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayFmt.format(dailyData[i].date),
                            style: TextStyle(fontSize: 10, color: context.colors.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (val, meta) => Text(
                        formatGnfCompact(val),
                        style: TextStyle(fontSize: 9, color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calcInterval(dailyData),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.colors.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: List.generate(dailyData.length, (i) {
                  final d = dailyData[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: d.revenue.toDouble(),
                        color: const Color(0xFF6366F1),
                        width: dailyData.length > 15 ? 6 : 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: d.profit.toDouble().clamp(0, double.infinity),
                        color: const Color(0xFF10B981),
                        width: dailyData.length > 15 ? 6 : 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calcInterval(List<DailyRevenue> data) {
    final maxVal = data.map((d) => d.revenue.toDouble()).fold(0.0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) return 1;
    return (maxVal / 4).roundToDouble();
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant)),
      ],
    );
  }
}

// ─── Top Produits ────────────────────────────────────────────────────────────

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.products});
  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text('Top 5 Produits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            Text('Aucune vente sur cette période', style: TextStyle(color: context.colors.onSurfaceVariant))
          else
            ...List.generate(products.length, (i) {
              final p = products[i];
              final maxQty = products.first.quantitySold;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: i == 0 ? const Color(0xFFF59E0B) : context.colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: i == 0 ? Colors.white : context.colors.onSurfaceVariant,
                            ),
                          )),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Text('${p.quantitySold} unités', style: TextStyle(fontSize: 12, color: context.colors.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        Text(formatGnfCompact(p.revenue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxQty > 0 ? p.quantitySold / maxQty : 0,
                        backgroundColor: context.colors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(i == 0 ? const Color(0xFFF59E0B) : const Color(0xFF6366F1)),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Dépenses par catégorie ──────────────────────────────────────────────────

class _ExpensesByCategoryCard extends StatelessWidget {
  const _ExpensesByCategoryCard({required this.expenses, required this.total});
  final List<ExpenseByCat> expenses;
  final int total;

  static const _catColors = <Color>[
    Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF3B82F6),
    Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFF14B8A6), Color(0xFF6366F1), Color(0xFF6B7280),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              const Text('Dépenses par catégorie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text(formatGnfCompact(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 16),
          if (expenses.isEmpty)
            Text('Aucune dépense sur cette période', style: TextStyle(color: context.colors.onSurfaceVariant))
          else ...[
            // Mini pie chart
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: List.generate(expenses.length, (i) {
                    final e = expenses[i];
                    final pct = total > 0 ? (e.total / total * 100) : 0.0;
                    return PieChartSectionData(
                      color: _catColors[i % _catColors.length],
                      value: e.total.toDouble(),
                      title: '${pct.round()}%',
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      radius: 40,
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            ...List.generate(expenses.length, (i) {
              final e = expenses[i];
              final pct = total > 0 ? (e.total / total * 100).toStringAsFixed(0) : '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: _catColors[i % _catColors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.category.label, style: const TextStyle(fontSize: 13))),
                    Text('$pct%', style: TextStyle(fontSize: 12, color: context.colors.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    Text(formatGnfCompact(e.total), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── Résumé financier ────────────────────────────────────────────────────────

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 20),
              SizedBox(width: 8),
              Text('Résumé Financier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryLine(label: 'Chiffre d\'Affaires (ventes)', value: data.revenue, color: const Color(0xFF6366F1)),
          _SummaryLine(label: 'Encaissé', value: data.collected, color: const Color(0xFF10B981)),
          _SummaryLine(label: 'Créances (argent dehors)', value: data.receivables, color: const Color(0xFFF59E0B)),
          const Divider(height: 24),
          _SummaryLine(label: 'Bénéfice brut (marge)', value: data.grossProfit, color: const Color(0xFF10B981)),
          _SummaryLine(label: 'Total dépenses', value: -data.totalExpenses, color: const Color(0xFFEF4444), isNegative: true),
          const Divider(height: 24),
          _SummaryLine(
            label: 'BÉNÉFICE NET',
            value: data.netProfit,
            color: data.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
    this.isNegative = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool isBold;
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(
            fontSize: isBold ? 15 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          ))),
          Text(
            '${isNegative ? "- " : ""}${formatGnf(value.abs())}',
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── État vide illustré ───────────────────────────────────────────────────────

class _EmptyReportState extends StatelessWidget {
  const _EmptyReportState({required this.range});
  final ReportRange range;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône illustrée
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.12),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                size: 52,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune donnée pour cette période',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.colors.onSurface,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Il n\'y a aucune vente ni dépense\npour « ${range.label} ».\nEffectuez des ventes pour voir vos rapports.',
              style: TextStyle(
                fontSize: 14,
                color: context.colors.onSurfaceVariant,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: null, // passif — guide l'utilisateur
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              label: const Text('Aller à la caisse'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
