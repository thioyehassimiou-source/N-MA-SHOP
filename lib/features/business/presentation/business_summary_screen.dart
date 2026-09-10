import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_table.dart';
import '../../sales/application/sales_providers.dart';
import '../../sales/domain/repositories/sale_repository.dart';
import '../application/business_providers.dart';

class BusinessSummaryScreen extends ConsumerStatefulWidget {
  const BusinessSummaryScreen({super.key});

  @override
  ConsumerState<BusinessSummaryScreen> createState() =>
      _BusinessSummaryScreenState();
}

class _BusinessSummaryScreenState extends ConsumerState<BusinessSummaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all'; // 'all', 'paid', 'credit'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(businessSummaryProvider);
    final salesAsync = ref.watch(allSalesProvider);
    final monthName = _monthLabel(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bilan & Historique Ventes',
                      style: AppTypography.headlineLg),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Performances globales et traçabilité de toutes les ventes par vendeur.',
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Actualiser',
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      ref.invalidate(businessSummaryProvider);
                      ref.invalidate(allSalesProvider);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color:
                          context.colors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: context.colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          monthName.toUpperCase(),
                          style: AppTypography.labelMd.copyWith(
                            color: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  async.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erreur : $e')),
                    data: (s) => _buildMetricsGrid(s, monthName),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSalesSection(salesAsync),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(dynamic s, String monthName) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
        final childAspectRatio = constraints.maxWidth > 800 ? 2.5 : 3.5;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricBentoCard(
              title: 'Ventes du mois',
              amount: formatGnf(s.monthSales),
              icon: Icons.payments_outlined,
              color: context.colors.primary,
              subtitle: "Chiffre d'affaires brut",
            ),
            _MetricBentoCard(
              title: 'Bénéfice estimé',
              amount: formatGnf(s.monthProfit),
              icon: Icons.trending_up,
              color: context.colors.primaryContainer,
              subtitle: 'Marge brute générée',
              isHighlight: true,
            ),
            _MetricBentoCard(
              title: 'Argent encaissé',
              amount: formatGnf(s.cashCollectedThisMonth),
              icon: Icons.account_balance_wallet_outlined,
              color: context.colors.secondary,
              subtitle: 'Trésorerie réelle perçue',
            ),
            _MetricBentoCard(
              title: 'Créances clients',
              amount: formatGnf(s.owedToMe),
              icon: Icons.group_outlined,
              color: context.colors.error,
              subtitle: "Total de l'argent dehors",
            ),
          ],
        );
      },
    );
  }

  Widget _buildSalesSection(AsyncValue<List<SaleHistoryItem>> salesAsync) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toutes les Ventes Enregistrées',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consultez toutes les ventes avec le vendeur responsable et le statut.',
                      style: AppTypography.bodySm.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Filtres de statut
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Toutes')),
                  ButtonSegment(value: 'paid', label: Text('Payées')),
                  ButtonSegment(value: 'credit', label: Text('À crédit')),
                ],
                selected: {_selectedStatus},
                onSelectionChanged: (set) {
                  setState(() => _selectedStatus = set.first);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Barre de recherche
          SizedBox(
            width: double.infinity,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'Rechercher par référence, vendeur, client ou article...',
                hintStyle: AppTypography.bodySm.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.colors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: context.colors.outlineVariant),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          salesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text('Erreur de chargement des ventes : $e'),
              ),
            ),
            data: (sales) {
              var filtered = sales;
              if (_selectedStatus == 'paid') {
                filtered = filtered.where((s) => s.isFullyPaid).toList();
              } else if (_selectedStatus == 'credit') {
                filtered = filtered.where((s) => s.isCredit).toList();
              }

              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                filtered = filtered.where((s) {
                  final ref = s.reference.toLowerCase();
                  final seller = (s.sellerName ?? '').toLowerCase();
                  final customer = s.customerName.toLowerCase();
                  final items = (s.itemsSummary ?? '').toLowerCase();
                  return ref.contains(query) ||
                      seller.contains(query) ||
                      customer.contains(query) ||
                      items.contains(query);
                }).toList();
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: context.colors.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Aucune vente trouvée',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return AppTable(
                columns: const [
                  DataColumn(label: Text('RÉFÉRENCE')),
                  DataColumn(label: Text('DATE & HEURE')),
                  DataColumn(label: Text('CLIENT / ARTICLES')),
                  DataColumn(label: Text('VENDEUR')),
                  DataColumn(label: Text('MONTANT TOTAL')),
                  DataColumn(label: Text('STATUT')),
                ],
                rows: filtered.map((sale) {
                  final hasSeller =
                      sale.sellerName != null && sale.sellerName!.isNotEmpty;
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          sale.reference,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          formatDate(sale.date),
                          style: AppTypography.bodySm.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              sale.customerName,
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (sale.itemsSummary != null)
                              Text(
                                sale.itemsSummary!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasSeller
                                ? context.colors.primary.withValues(alpha: 0.1)
                                : context.colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hasSeller
                                  ? context.colors.primary.withValues(alpha: 0.2)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            sale.sellerName ?? 'Non attribué',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasSeller
                                  ? context.colors.primary
                                  : context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          formatGnf(sale.totalAmount),
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        sale.isCancelled
                            ? const AppChip(
                                label: 'Annulée',
                                status: AppChipStatus.error,
                              )
                            : sale.isCredit
                                ? const AppChip(
                                    label: 'Crédit',
                                    status: AppChipStatus.warning,
                                  )
                                : const AppChip(
                                    label: 'Payée',
                                    status: AppChipStatus.success,
                                  ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return months[d.month - 1];
  }
}

class _MetricBentoCard extends StatelessWidget {
  const _MetricBentoCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.isHighlight = false,
  });

  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                amount,
                style: AppTypography.headlineMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? color : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySm.copyWith(
                  color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
