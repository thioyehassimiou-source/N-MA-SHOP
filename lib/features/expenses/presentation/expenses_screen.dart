import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_metric_card.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../application/expense_providers.dart';
import 'new_expense_dialog.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _searchQuery = '';
  ExpenseCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(expensesDataProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: asyncData.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(48.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (data) {
          final filtered = data.expenses.where((e) {
            final matchesQuery = e.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.reference.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCategory = _selectedCategory == null || e.category == _selectedCategory;
            return matchesQuery && matchesCategory;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Dépenses',
                subtitle: 'Suivi de vos frais opérationnels et charges',
                icon: Icons.money_off_outlined,
                gradientColors: const [Color(0xFFEF4444), Color(0xFFB91C1C)], // Red gradient
              ),
              const SizedBox(height: AppSpacing.lg),

              // Métriques
              LayoutBuilder(
                builder: (context, c) {
                  final isMobile = c.maxWidth < 800;
                  final cardWidth = isMobile ? double.infinity : (c.maxWidth - AppSpacing.lg * 3) / 4;
                  return Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: AppMetricCard(
                          title: 'Dépenses du mois',
                          value: formatGnf(data.thisMonthAmount),
                          icon: Icons.calendar_today_outlined,
                          iconColor: context.colors.error,
                          iconBackgroundColor: context.colors.errorContainer,
                          badgeText: 'Ce mois-ci',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: AppMetricCard(
                          title: 'Loyer (Mois)',
                          value: formatGnf(data.categoryAmounts[ExpenseCategory.rent] ?? 0),
                          icon: Icons.home_work_outlined,
                          iconColor: context.colors.error,
                          iconBackgroundColor: context.colors.errorContainer,
                          badgeText: 'Charges Fixes',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: AppMetricCard(
                          title: 'Salaires (Mois)',
                          value: formatGnf(data.categoryAmounts[ExpenseCategory.salary] ?? 0),
                          icon: Icons.people_outline,
                          iconColor: context.colors.primary,
                          iconBackgroundColor: context.colors.primaryContainer,
                          badgeText: 'Personnel',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: AppMetricCard(
                          title: 'Autres Charges',
                          value: formatGnf(
                            data.thisMonthAmount -
                            (data.categoryAmounts[ExpenseCategory.rent] ?? 0) -
                            (data.categoryAmounts[ExpenseCategory.salary] ?? 0)
                          ),
                          icon: Icons.pie_chart_outline,
                          iconColor: context.colors.tertiary,
                          iconBackgroundColor: context.colors.tertiaryContainer,
                          badgeText: 'Divers',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Tableau des dépenses
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Rechercher une dépense...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ExpenseCategory?>(
                                value: _selectedCategory,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Toutes catégories')),
                                  ...ExpenseCategory.values.map(
                                    (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _selectedCategory = val),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: () => NewExpenseDialog.show(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nouvelle Dépense'),
                          style: FilledButton.styleFrom(
                            backgroundColor: context.colors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.money_off_csred_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'Aucune dépense trouvée',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Enregistrez vos frais de fonctionnement ici.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text('Référence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                                Expanded(flex: 3, child: Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                                Expanded(flex: 2, child: Text('Catégorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                                Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant), textAlign: TextAlign.end)),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final expense = filtered[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        expense.reference,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(expense.description, style: const TextStyle(fontSize: 13)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: AppChip(
                                        label: expense.category.label,
                                        status: AppChipStatus.neutral,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        formatDate(expense.date),
                                        style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        formatGnf(expense.amount),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.colors.error),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
