import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/database/database.dart';
import '../../../core/services/pdf_receipt_service.dart';
import '../../../core/theme/app_colors.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_metric_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../application/devis_providers.dart';
import 'new_invoice_dialog.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class DevisScreen extends ConsumerStatefulWidget {
  const DevisScreen({super.key});

  @override
  ConsumerState<DevisScreen> createState() => _DevisScreenState();
}

class _DevisScreenState extends ConsumerState<DevisScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(devisDataProvider);
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
          error: (err, _) =>
              Center(child: Text('Erreur : $err')),
          data: (data) {
            final filtered = data.documents.where((d) {
              final matchesQuery = d.reference.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  d.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
              if (_selectedFilter == 'En attente') {
                return matchesQuery && d.status == DevisStatus.pending;
              } else if (_selectedFilter == 'Payées') {
                return matchesQuery && d.status == DevisStatus.paid;
              }
              return matchesQuery;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: 'Devis & Factures Proforma',
                  subtitle: 'Émission et suivi des documents commerciaux professionnels',
                  icon: Icons.description_outlined,
                  gradientColors: const [Color(0xFF0F1B3D), Color(0xFF1A2B52)],
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
                            title: 'Factures en attente',
                            value: '${data.pendingCount}',
                            icon: Icons.hourglass_top_rounded,
                            iconColor: context.colors.error,
                            iconBackgroundColor: context.colors.errorContainer,
                            badgeText: 'À encaisser',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AppMetricCard(
                            title: 'Montant en attente',
                            value: formatGnf(data.pendingAmount),
                            icon: Icons.receipt_long_outlined,
                            iconColor: context.colors.error,
                            iconBackgroundColor: context.colors.errorContainer,
                            badgeText: 'Non encaissé',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AppMetricCard(
                            title: 'Factures payées',
                            value: formatGnf(data.paidMonthAmount),
                            icon: Icons.check_circle_outline,
                            iconColor: AppColors.brandEmerald,
                            iconBackgroundColor: context.colors.secondaryContainer,
                            badgeText: 'Encaissé',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AppMetricCard(
                            title: 'Total documents',
                            value: '${data.totalDocumentsCount}',
                            icon: Icons.folder_outlined,
                            iconColor: context.colors.primary,
                            iconBackgroundColor: context.colors.primaryContainer,
                            badgeText: 'Tous types',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // Tableau des Factures & Devis
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Rechercher une facture ou un client...',
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
                                  DropdownMenuItem(value: 'Tous', child: Text('Tous les documents')),
                                  DropdownMenuItem(value: 'En attente', child: Text('En attente')),
                                  DropdownMenuItem(value: 'Payées', child: Text('Payées')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedFilter = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: () => NewInvoiceDialog.show(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nouvelle Facture'),
                            style: FilledButton.styleFrom(
                              backgroundColor: context.colors.primary,
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
                                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'Aucun document trouvé',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Les factures et devis s\'afficheront ici.',
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
                                  Expanded(flex: 2, child: Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                                  Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                                  Expanded(flex: 1, child: Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                                  Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant), textAlign: TextAlign.end)),
                                  const SizedBox(width: 40), // space for actions
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final doc = filtered[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          doc.reference,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(doc.customerName, style: const TextStyle(fontSize: 13)),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          formatDate(doc.date),
                                          style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: _StatusChip(status: doc.status),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          formatGnf(doc.totalAmount),
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      // ── Actions ──────────────────────────────
                                      SizedBox(
                                        width: 40,
                                        child: _DevisActionMenu(doc: doc, ref: ref),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final DevisStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DevisStatus.paid:
        return const AppChip(label: 'Payée', status: AppChipStatus.success);
      case DevisStatus.invoiced:
        return const AppChip(label: 'Partiel', status: AppChipStatus.warning);
      case DevisStatus.accepted:
        return const AppChip(label: 'Accepté', status: AppChipStatus.success);
      case DevisStatus.pending:
        return const AppChip(label: 'En attente', status: AppChipStatus.error);
    }
  }
}

// ── Menu d'actions sur une facture ─────────────────────────────────────────
class _DevisActionMenu extends ConsumerWidget {
  const _DevisActionMenu({required this.doc, required this.ref});

  final DevisDocumentView doc;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: context.colors.onSurfaceVariant),
      tooltip: 'Actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'print',
          child: Row(children: [
            Icon(Icons.print_outlined, size: 18),
            SizedBox(width: 10),
            Text('Réimprimer PDF'),
          ]),
        ),
        if (doc.status != DevisStatus.paid)
          const PopupMenuItem(
            value: 'pay',
            child: Row(children: [
              Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
              SizedBox(width: 10),
              Text('Marquer comme Payée', style: TextStyle(color: Colors.green)),
            ]),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Annuler / Supprimer', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
      onSelected: (value) async {
        final db = ref.read(databaseProvider);
        switch (value) {
          case 'print':
            final settings = ref.read(appSettingsProvider);
            // Reconstruct basic receipt from sale record
            final receiptData = ReceiptData(
              reference: doc.reference,
              date: doc.date,
              businessName: settings.businessName,
              businessPhone: settings.businessPhone,
              businessAddress: settings.businessAddress,
              businessNif: settings.businessNif,
              lines: const [],
              total: doc.totalAmount,
              amountPaid: doc.status == DevisStatus.paid ? doc.totalAmount : 0,
              creditAmount: doc.status == DevisStatus.paid ? 0 : doc.totalAmount,
              paymentMethodLabel: 'Proforma',
              customerName: doc.customerName,
            );
            await Printing.layoutPdf(
              name: 'Facture_${doc.reference}',
              onLayout: (_) => PdfReceiptService.generateReceiptPdf(receiptData),
            );
            break;

          case 'pay':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text('Confirmer le paiement'),
                content: Text('Marquer ${doc.reference} comme entièrement payée ?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
                ],
              ),
            );
            if (confirmed == true) {
              await (db.update(db.sales)..where((s) => s.id.equals(doc.id))).write(
                SalesCompanion(amountPaid: drift.Value(doc.totalAmount)),
              );
              ref.invalidate(devisDataProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Facture marquée comme payée'), backgroundColor: Colors.green),
                );
              }
            }
            break;

          case 'delete':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text('Annuler la facture'),
                content: Text('Supprimer définitivement ${doc.reference} ?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await (db.update(db.sales)..where((s) => s.id.equals(doc.id))).write(
                const SalesCompanion(isCancelled: drift.Value(true)),
              );
              ref.invalidate(devisDataProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Facture supprimée'), backgroundColor: Colors.red),
                );
              }
            }
            break;
        }
      },
    );
  }
}
