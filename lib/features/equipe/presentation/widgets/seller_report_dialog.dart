import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/tables/users.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/services/app_print_service.dart';
import '../../../../core/services/pdf_seller_report_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/equipe_providers.dart';
import '../../application/sellers_providers.dart';
import '../../domain/entities/seller_performance.dart';

class SellerReportDialog extends ConsumerStatefulWidget {
  const SellerReportDialog({
    super.key,
    required this.seller,
  });

  final SellerPerformance seller;

  @override
  ConsumerState<SellerReportDialog> createState() => _SellerReportDialogState();
}

class _SellerReportDialogState extends ConsumerState<SellerReportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final range = ref.read(sellerRangeProvider);
      final sales =
          await ref.read(sellerSalesProvider(widget.seller.sellerId).future);
      final customers =
          await ref.read(sellerCustomersProvider(widget.seller.sellerId).future);
      final settings = ref.read(appSettingsProvider);
      if (!mounted) return;

      await AppPrintService.printDocument(
        context: context,
        documentName:
            'Rapport_${widget.seller.sellerName}_${range.label}',
        onLayout: (_) => PdfSellerReportService.generateSellerReportPdf(
          seller: widget.seller,
          sales: sales,
          customers: customers,
          range: range,
          businessName: settings.businessName,
          businessPhone: settings.businessPhone,
          businessAddress: settings.businessAddress,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export PDF : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showEditCommissionDialog() async {
    final controller = TextEditingController(
      text: widget.seller.commissionRate.toStringAsFixed(1),
    );

    final updated = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le taux de commission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vendeur : ${widget.seller.sellerName}'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Taux de commission (%)',
                hintText: 'Ex: 5.0',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val >= 0) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (updated != null && widget.seller.sellerId != null) {
      await ref
          .read(equipeControllerProvider.notifier)
          .updateCommissionRate(widget.seller.sellerId!, updated);
      ref.invalidate(sellerPerformancesProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(sellerRangeProvider);
    final salesAsync = ref.watch(sellerSalesProvider(widget.seller.sellerId));
    final customersAsync =
        ref.watch(sellerCustomersProvider(widget.seller.sellerId));
    final currentUser = ref.watch(authProvider);
    final isAdmin = currentUser?.role == UserRole.admin;
    final dayFmt = DateFormat('dd/MM/yyyy HH:mm', 'fr');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 900,
        height: 720,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-Tête du Vendeur ──
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: widget.seller.isActive
                      ? context.colors.primaryContainer
                      : context.colors.surfaceContainerHighest,
                  child: Text(
                    widget.seller.sellerName.isNotEmpty
                        ? widget.seller.sellerName.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 20,
                      color: widget.seller.isActive
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.seller.sellerName,
                            style: AppTypography.headlineMd,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (widget.seller.role != null)
                            AppChip(
                              label: widget.seller.role == UserRole.admin
                                  ? 'Administrateur'
                                  : 'Vendeur',
                              status: widget.seller.role == UserRole.admin
                                  ? AppChipStatus.warning
                                  : AppChipStatus.success,
                            ),
                          if (!widget.seller.isActive) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const AppChip(
                              label: 'Archivé',
                              status: AppChipStatus.error,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Période : ${range.label}',
                            style: AppTypography.bodySm.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Text(
                            'Commission : ${widget.seller.commissionRate.toStringAsFixed(1)} %',
                            style: AppTypography.labelSm.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isAdmin && widget.seller.sellerId != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            InkWell(
                              onTap: _showEditCommissionDialog,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Métriques Clés (KPIs) ──
            Row(
              children: [
                _buildKpi(
                  context,
                  title: 'Chiffre d\'Affaires',
                  value: formatGnf(widget.seller.totalRevenue),
                  icon: Icons.trending_up_rounded,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: AppSpacing.md),
                _buildKpi(
                  context,
                  title: 'Montant Encaissé',
                  value: formatGnf(widget.seller.totalCollected),
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.brandEmerald,
                ),
                const SizedBox(width: AppSpacing.md),
                _buildKpi(
                  context,
                  title: 'Impayés / Crédits',
                  value: formatGnf(widget.seller.totalRemaining),
                  icon: Icons.receipt_long_outlined,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: AppSpacing.md),
                _buildKpi(
                  context,
                  title: 'Commission Due',
                  value: formatGnf(widget.seller.commissionAmount),
                  icon: Icons.savings_outlined,
                  color: Colors.orange.shade800,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Onglets Ventes / Clients ──
            TabBar(
              controller: _tabController,
              labelColor: context.colors.primary,
              unselectedLabelColor: context.colors.onSurfaceVariant,
              indicatorColor: context.colors.primary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  text: 'Ventes Réalisées (${widget.seller.salesCount})',
                ),
                Tab(
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  text: 'Clients Servis (${widget.seller.customersServedCount})',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Contenu des Onglets ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1 : Ventes
                  salesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Erreur: $err')),
                    data: (sales) {
                      if (sales.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucune vente enregistrée pour ce vendeur sur la période.',
                            style: AppTypography.bodyMd.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: sales.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final s = sales[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              s.isCancelled
                                  ? Icons.cancel_outlined
                                  : Icons.check_circle_outline,
                              color: s.isCancelled
                                  ? Colors.red
                                  : AppColors.brandEmerald,
                            ),
                            title: Text(
                              '${s.reference}  •  ${s.customerName}',
                              style: AppTypography.labelMd,
                            ),
                            subtitle: Text(dayFmt.format(s.date)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatGnf(s.totalAmount),
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (s.remaining > 0)
                                  Text(
                                    'Reste: ${formatGnf(s.remaining)}',
                                    style: AppTypography.labelSm.copyWith(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  Text(
                                    'Payé',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.brandEmerald,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Tab 2 : Clients
                  customersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Erreur: $err')),
                    data: (customers) {
                      if (customers.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucun client rattaché à ce vendeur sur la période.',
                            style: AppTypography.bodyMd.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: customers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = customers[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  context.colors.surfaceContainerHighest,
                              child: const Icon(Icons.person_outline, size: 18),
                            ),
                            title: Text(c.name, style: AppTypography.labelMd),
                            subtitle: Text(c.phone ?? 'Sans contact'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatGnf(c.totalSpent),
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${c.salesCount} achat${c.salesCount > 1 ? 's' : ''}',
                                  style: AppTypography.labelSm.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Barre d'Actions Inférieure ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppButton.secondary(
                  label: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                AppButton(
                  label:
                      _isExporting ? 'Génération...' : 'Imprimer / Exporter PDF',
                  icon: Icons.print_outlined,
                  onPressed: _isExporting ? null : _exportPdf,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpi(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.labelSm.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
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
