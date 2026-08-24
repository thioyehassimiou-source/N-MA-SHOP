import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_metric_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../application/caisse_providers.dart';
import '../data/repositories/drift_caisse_repository.dart';
import '../../../core/domain/payment_method.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class CaisseScreen extends ConsumerStatefulWidget {
  const CaisseScreen({super.key});

  @override
  ConsumerState<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends ConsumerState<CaisseScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Toutes';

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(caisseDataProvider);
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
          error: (err, stack) => Center(
            child: Text('Erreur lors du chargement de la caisse : $err'),
          ),
          data: (data) {
            final filteredMovements = data.movements.where((m) {
              final matchesQuery = m.reference.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  m.description.toLowerCase().contains(_searchQuery.toLowerCase());
              if (_selectedFilter == 'Entrées') {
                return matchesQuery && m.type == CashMovementType.inflow;
              } else if (_selectedFilter == 'Sorties') {
                return matchesQuery && m.type == CashMovementType.outflow;
              }
              return matchesQuery;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: 'Gestion de Caisse & Trésorerie',
                  subtitle: 'Suivi en temps réel des flux de trésorerie et encaissements',
                  icon: Icons.account_balance_wallet_outlined,
                  gradientColors: const [Color(0xFF006054), Color(0xFF0F7B6C)],
                ),
                const SizedBox(height: AppSpacing.lg),
                // 1. En-tête des métriques de caisse
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 800;
                    return Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.lg,
                      children: [
                        SizedBox(
                          width: isMobile ? double.infinity : (constraints.maxWidth - AppSpacing.lg * 3) / 4,
                          child: AppMetricCard(
                            title: 'Solde de Caisse Actuel',
                            value: formatGnf(data.currentBalance),
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: context.colors.primary,
                            iconBackgroundColor: context.colors.primaryContainer,
                            badgeText: 'Temps réel',
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : (constraints.maxWidth - AppSpacing.lg * 3) / 4,
                          child: AppMetricCard(
                            title: 'Entrées du Jour',
                            value: formatGnf(data.todayInflow),
                            icon: Icons.arrow_downward_rounded,
                            iconColor: AppColors.brandEmerald,
                            iconBackgroundColor: context.colors.secondaryContainer,
                            badgeText: 'Encaissements',
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : (constraints.maxWidth - AppSpacing.lg * 3) / 4,
                          child: AppMetricCard(
                            title: 'Sorties du Jour',
                            value: formatGnf(data.todayOutflow),
                            icon: Icons.arrow_upward_rounded,
                            iconColor: context.colors.error,
                            iconBackgroundColor: context.colors.errorContainer,
                            badgeText: 'Décaissements',
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : (constraints.maxWidth - AppSpacing.lg * 3) / 4,
                          child: AppMetricCard(
                            title: 'Opérations du Jour',
                            value: '${data.todayOperationsCount}',
                            icon: Icons.receipt_long_outlined,
                            iconColor: context.colors.tertiary,
                            iconBackgroundColor: context.colors.tertiaryContainer,
                            badgeText: 'Transactions',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // 2. Section Filtres et Mouvements
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barre d'outils / Filtres
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Rechercher une opération...',
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
                          DropdownButtonHideUnderline(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                items: const [
                                  DropdownMenuItem(value: 'Toutes', child: Text('Toutes les opérations')),
                                  DropdownMenuItem(value: 'Entrées', child: Text('Entrées (Crédits)')),
                                  DropdownMenuItem(value: 'Sorties', child: Text('Sorties (Débits)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedFilter = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: () => _showMovementDialog(context, isInflow: true),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Entrée'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandEmerald,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: () => _showMovementDialog(context, isInflow: false),
                            icon: Icon(Icons.remove, size: 18, color: context.colors.error),
                            label: Text('Sortie', style: TextStyle(color: context.colors.error)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.colors.error),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Tableau des mouvements
                      if (filteredMovements.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.account_balance_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'Aucun mouvement de caisse trouvé',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Les encaissements et décaissements s\'afficheront automatiquement ici.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredMovements.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = filteredMovements[index];
                            final isInflow = m.type == CashMovementType.inflow;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isInflow ? context.colors.secondaryContainer : context.colors.errorContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      m.icon,
                                      color: isInflow ? AppColors.brandEmerald : context.colors.error,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.description,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          '${m.reference} • ${formatDate(m.date)} à ${formatTime(m.date)}',
                                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppChip(
                                    label: m.paymentMethodName,
                                    status: AppChipStatus.neutral,
                                  ),
                                  const SizedBox(width: 24),
                                  Text(
                                    '${isInflow ? '+' : '-'}${formatGnf(m.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isInflow ? AppColors.brandEmerald : context.colors.error,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

  void _showMovementDialog(BuildContext context, {required bool isInflow}) {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AppFormDialog(
        title: isInflow ? 'Nouvelle Entrée de Caisse' : 'Nouveau Décaissement',
        subtitle: 'Enregistrez un nouveau mouvement de caisse',
        icon: isInflow ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        gradientColors: isInflow
            ? const [Color(0xFF10B981), Color(0xFF059669)]
            : const [Color(0xFFDC2626), Color(0xFFEF4444)],
        width: 450,
        primaryLabel: 'Enregistrer',
        primaryIcon: Icons.save_outlined,
        onCancel: () => Navigator.pop(ctx),
        onPrimary: () async {
          final desc = descController.text.trim();
          final amountStr = amountController.text.trim();
          if (desc.isEmpty || amountStr.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Veuillez remplir tous les champs')),
            );
            return;
          }

          final amount = int.tryParse(amountStr);
          if (amount == null || amount <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Le montant doit être valide')),
            );
            return;
          }

          // Enregistrement via le repository
          await ref.read(caisseRepositoryProvider).insertMovement(
                type: isInflow ? CashMovementType.inflow : CashMovementType.outflow,
                description: desc,
                amount: amount,
                paymentMethod: PaymentMethod.cash, // On suppose espèces par défaut pour la caisse
              );

          // Invalider le provider pour rafraîchir les données
          ref.invalidate(caisseDataProvider);

          if (context.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isInflow ? 'Entrée enregistrée avec succès' : 'Décaissement enregistré avec succès',
                ),
              ),
            );
          }
        },
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFormField(
              label: 'Motif / Description',
              controller: descController,
              icon: Icons.description_outlined,
              hint: 'ex: Apport initial, Frais de transport...',
              isRequired: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppFormField(
              label: 'Montant (GNF)',
              controller: amountController,
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              isRequired: true,
            ),
          ],
        ),
      ),
    );
  }
}
