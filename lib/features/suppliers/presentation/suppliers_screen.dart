import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../../../core/database/tables/users.dart';
import '../application/suppliers_providers.dart';
import '../domain/repositories/suppliers_repository.dart';
import '../domain/supplier_summary.dart';
import 'widgets/supplier_repayment_dialog.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(supplierSummariesProvider);
    final purchasesAsync = ref.watch(recentPurchasesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.containerMax),
          child: summariesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Center(child: Text('Erreur : $e')),
            ),
            data: (summaries) {
              final purchases = purchasesAsync.when(
                data: (d) => d,
                loading: () => <RecentPurchaseView>[],
                error: (err, stack) => <RecentPurchaseView>[],
              );
              return _SuppliersBody(summaries: summaries, purchases: purchases);
            },
          ),
        ),
      ),
    );
  }
}

class _SuppliersBody extends StatelessWidget {
  const _SuppliersBody({required this.summaries, required this.purchases});

  final List<SupplierSummary> summaries;
  final List<RecentPurchaseView> purchases;

  @override
  Widget build(BuildContext context) {
    final totalDebt = summaries.fold<int>(0, (sum, s) => sum + s.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: 'Achats & Fournisseurs',
          subtitle: 'Gestion des approvisionnements et dettes fournisseurs',
          icon: Icons.local_shipping_outlined,
          gradientColors: const [Color(0xFF0F1B3D), Color(0xFF1A2B52)],
          actions: [
            ElevatedButton.icon(
              onPressed: () => context.go('/nouvel-achat'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvel Achat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // ─── Bento Cards ─────────────────────────────────────────
        _TopBentoCards(totalDebt: totalDebt),
        const SizedBox(height: AppSpacing.lg),

        // ─── Contenu principal ───────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final sidebar = Column(
              children: [
                _PrioritySuppliers(summaries: summaries),
                const SizedBox(height: AppSpacing.lg),
                const _DebtExposureChart(),
              ],
            );
            final table = _RecentPurchases(purchases: purchases);

            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  table,
                  const SizedBox(height: AppSpacing.lg),
                  sidebar,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: sidebar),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 8, child: table),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Bento Cards (Total Dû + Bouton Nouvel Achat) ───────────────────────────

class _TopBentoCards extends StatelessWidget {
  const _TopBentoCards({required this.totalDebt});

  final int totalDebt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carte « Total Dû »
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.primary.withValues(alpha: 0.2),
                  context.colors.primary.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Dû',
                      style: AppTypography.labelSm.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: context.colors.error,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                RichText(
                  text: TextSpan(
                    text: formatGnf(totalDebt).replaceAll(' GNF', ' '),
                    style: AppTypography.headlineLg.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: 'GNF',
                        style: AppTypography.bodyMd.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Icon(
                      Icons.trending_down,
                      color: context.colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Dette maîtrisée',
                      style: AppTypography.bodySm.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),

        // Bandeau « Centre d'Approvisionnement »
        Expanded(
          flex: 8,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26006054),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Centre d\'Approvisionnement',
                        style: AppTypography.headlineMd.copyWith(
                          color: context.colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Gérez vos entrées de stock et soldez\nvos factures en attente facilement.',
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.primaryFixed.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Duplicate 'Nouvel Achat' button removed to avoid duplication
                // const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Fournisseurs Prioritaires ───────────────────────────────────────────────

class _PrioritySuppliers extends StatelessWidget {
  const _PrioritySuppliers({required this.summaries});

  final List<SupplierSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FOURNISSEURS PRIORITAIRES',
                style: AppTypography.labelMd.copyWith(
                  letterSpacing: 0.5,
                  color: context.colors.onSurface,
                ),
              ),
              Text(
                'Voir tout',
                style: AppTypography.labelSm.copyWith(color: context.colors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (summaries.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucun fournisseur',
                  style: TextStyle(color: context.colors.onSurfaceVariant),
                ),
              ),
            )
          else
            ...summaries
                .take(4)
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _SupplierItem(summary: s),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SupplierItem extends StatelessWidget {
  const _SupplierItem({required this.summary});

  final SupplierSummary summary;

  @override
  Widget build(BuildContext context) {
    final initials = summary.supplierName.isNotEmpty
        ? summary.supplierName.substring(0, 1).toUpperCase()
        : '?';
    final hasDebt = summary.balance > 0;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () {
        SupplierRepaymentDialog.show(context, summary);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: context.colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.supplierName,
                    style: AppTypography.labelMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${summary.purchasesCount} achat(s)',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatGnf(summary.balance),
                  style: AppTypography.labelMd.copyWith(
                    color: hasDebt ? context.colors.error : context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                AppChip(
                  label: hasDebt ? 'À régler' : 'À jour',
                  status: hasDebt ? AppChipStatus.error : AppChipStatus.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtExposureChart extends StatelessWidget {
  const _DebtExposureChart();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXPOSITION À LA DETTE',
                      style: AppTypography.labelMd.copyWith(letterSpacing: 0.5),
                    ),
                    Text(
                      'Sorties prévues (30j)',
                      style: AppTypography.bodySm.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_down, size: 14, color: context.colors.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        '-12%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _chartBar(context, 0.25, 'J-4'),
                  _chartBar(context, 0.40, 'J-3'),
                  _chartBar(context, 0.80, 'J-2', isHighlight: true),
                  _chartBar(context, 0.50, 'Hier'),
                  _chartBar(context, 0.66, 'Auj.'),
                  _chartBar(context, 1.0, 'Demain', isDanger: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartBar(BuildContext context, double heightFactor, String label, {bool isHighlight = false, bool isDanger = false}) {
    final color = isDanger 
        ? context.colors.error 
        : isHighlight 
            ? context.colors.primary 
            : context.colors.primaryContainer;
            
    final bgColor = isDanger 
        ? context.colors.errorContainer.withValues(alpha: 0.3)
        : isHighlight
            ? context.colors.primary.withValues(alpha: 0.2)
            : context.colors.surfaceContainer;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: heightFactor,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          color,
                          color.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isHighlight || isDanger ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isHighlight || isDanger ? FontWeight.bold : FontWeight.normal,
                color: isHighlight || isDanger ? color : context.colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Achats Récents ─────────────────────────────────────────────────────────

class _RecentPurchases extends ConsumerWidget {
  const _RecentPurchases({required this.purchases});

  final List<RecentPurchaseView> purchases;

  void _confirmCancel(BuildContext context, WidgetRef ref, RecentPurchaseView purchase) {
    showDialog(
      context: context,
      builder: (ctx) => AppFormDialog(
        title: 'Annuler l\'achat ?',
        subtitle: 'Attention : Le stock de ces produits sera décrémenté et les paiements associés seront effacés.\nCette action est irréversible.',
        icon: Icons.warning_amber_rounded,
        gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
        width: 450,
        primaryLabel: 'Confirmer l\'annulation',
        primaryIcon: Icons.cancel_outlined,
        onCancel: () => Navigator.pop(ctx),
        onPrimary: () async {
          Navigator.pop(ctx);
          try {
            await ref.read(purchaseServiceProvider).cancelPurchase(purchase.purchaseId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Achat annulé avec succès.')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur : $e')),
              );
            }
          }
        },
        body: const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Achats Récents', style: AppTypography.headlineMd),
                    Text(
                      'Suivi de vos acquisitions de stock',
                      style: AppTypography.bodySm.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filtrer par statut',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Filtres disponibles bientôt'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: 'Télécharger les achats',
                      onPressed: () => context.go('/rapports'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.surfaceContainerHigh),
          if (purchases.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Aucun achat récent trouvé.',
                  style: TextStyle(color: context.colors.onSurfaceVariant),
                ),
              ),
            )
          else
            AppTable(
              columns: const [
                DataColumn(label: Text('ID ACHAT')),
                DataColumn(label: Text('FOURNISSEUR')),
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('MONTANT'), numeric: true),
                DataColumn(label: Text('STATUT')),
                DataColumn(label: Text('')),
              ],
              rows: purchases.map((p) {
                final initials = p.supplierName.isNotEmpty
                    ? p.supplierName.substring(0, 1).toUpperCase()
                    : '?';
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        p.purchaseId.split('-').first.toUpperCase(),
                        style: AppTypography.labelMd.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: context.colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            p.supplierName,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        formatDateTime(p.date),
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        formatGnf(p.totalAmount),
                        style: AppTypography.labelMd,
                      ),
                    ),
                    DataCell(
                      p.isCancelled
                          ? const AppChip(
                              label: 'Annulé',
                              status: AppChipStatus.error,
                            )
                          : AppChip(
                              label: p.isPaid ? 'Payé' : 'À crédit',
                              status: p.isPaid
                                  ? AppChipStatus.success
                                  : AppChipStatus.warning,
                            ),
                    ),
                    DataCell(
                      p.isCancelled
                          ? const SizedBox()
                          : ref.watch(authProvider)?.role == UserRole.admin
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      if (value == 'cancel') {
                                        _confirmCancel(context, ref, p);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'cancel',
                                        child: Row(
                                          children: [
                                            Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                                            SizedBox(width: 8),
                                            Text('Annuler', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
