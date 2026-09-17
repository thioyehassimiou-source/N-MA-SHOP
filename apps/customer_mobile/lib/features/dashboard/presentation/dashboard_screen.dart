import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_card.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../receivables/presentation/receivables_screen.dart';
import 'dashboard_controller.dart';
import 'widgets/kpi_card.dart';
import 'widgets/sync_freshness_badge.dart';

String formatGnf(num amount) => AppFormatters.formatCurrency(amount);
String formatGnfCompact(num amount) => '${AppFormatters.formatCompactNumber(amount)} GNF';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final data = state.data;

    final totalSales = data?.today.totalSales ?? 0;
    final cash = data?.today.cashCollected ?? 0;
    final momo = data?.today.momoCollected ?? 0;
    final credit = data?.today.creditIssued ?? 0;

    final cashRatio = totalSales > 0 ? (cash / totalSales).clamp(0.0, 1.0) : 0.0;
    final momoRatio = totalSales > 0 ? (momo / totalSales).clamp(0.0, 1.0) : 0.0;
    final creditRatio = totalSales > 0 ? (credit / totalSales).clamp(0.0, 1.0) : 0.0;

    final shopName = data?.shop.name ?? 'Ma Boutique';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        shape: const Border(bottom: BorderSide(color: AppColors.outline, width: 1)),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shopName,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: state.isOffline ? AppColors.warning : AppColors.brandEmerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.isOffline ? 'Mode Hors-ligne' : 'Synchro en direct',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlertsScreen()),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: AppColors.onSurface, size: 22),
                if (data != null && data.unreadAlertsCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${data.unreadAlertsCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.read(dashboardControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.onSurface, size: 22),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
        color: AppColors.primary,
        child: state.isLoading && data == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Badge Fraîcheur Synchro
                  Center(
                    child: SyncFreshnessBadge(
                      lastSyncTime: data?.shop.lastSyncAt,
                      isOffline: state.isOffline,
                      onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. HERO CARD NAVY (Conforme au Desktop _PageHeader)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroNavyGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x330F1B3D),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.brandEmerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.brandEmerald.withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 6, color: AppColors.brandEmerald),
                                  SizedBox(width: 6),
                                  Text(
                                    'EN LIGNE',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${data?.today.salesCount ?? 0} vente(s) aujourd\'hui',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Bonjour, Patron ! 👋',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Voici le résumé de votre commerce aujourd\'hui',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _BannerStat(
                                label: 'CA du jour',
                                value: formatGnf(totalSales),
                                icon: Icons.trending_up_rounded,
                                iconColor: AppColors.brandEmerald,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BannerStat(
                                label: 'En caisse',
                                value: formatGnf(cash),
                                icon: Icons.account_balance_wallet_rounded,
                                iconColor: AppColors.brandOrange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. ACTIONS RAPIDES POS (Bouton Vente Orange & Boutons Secondaires)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => widget.onNavigateToTab?.call(1), // Sales tab
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                          label: const Text('Nouvelle Vente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onNavigateToTab?.call(2), // Treasury tab
                          icon: const Icon(Icons.account_balance_rounded, size: 18),
                          label: const Text('Caisse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandNavy,
                            side: const BorderSide(color: AppColors.outline),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 4. GRILLE DES KPI (Conforme à _MetricsGrid Desktop)
                  const Text(
                    'INDICATEURS DU JOUR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      KpiCard(
                        title: 'Ventes du jour',
                        value: formatGnfCompact(totalSales),
                        subtitle: '${data?.today.salesCount ?? 0} transaction(s)',
                        icon: Icons.shopping_cart_rounded,
                        color: AppColors.iconPurple,
                      ),
                      KpiCard(
                        title: 'Solde de caisse',
                        value: formatGnfCompact(cash),
                        subtitle: 'Disponible',
                        icon: Icons.account_balance_rounded,
                        color: AppColors.iconGreen,
                      ),
                      KpiCard(
                        title: 'Argent dehors (Crédits)',
                        value: formatGnfCompact(data?.receivables.totalAmount ?? 0),
                        subtitle: '${data?.receivables.debtorsCount ?? 0} débiteur(s)',
                        icon: Icons.credit_card_rounded,
                        color: AppColors.iconOrange,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ReceivablesScreen()),
                          );
                        },
                      ),
                      KpiCard(
                        title: 'Produits en alerte',
                        value: '${data?.stock.outOfStockCount ?? 0}',
                        subtitle: (data?.stock.outOfStockCount ?? 0) > 0 ? 'Rupture détectée' : 'Stock optimal',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.iconRed,
                        onTap: () => widget.onNavigateToTab?.call(3), // Stock tab
                      ),
                      KpiCard(
                        title: 'Dettes à payer',
                        value: formatGnfCompact(0),
                        subtitle: 'Aux fournisseurs',
                        icon: Icons.storefront_rounded,
                        color: AppColors.iconNavy,
                      ),
                      KpiCard(
                        title: 'Ticket moyen',
                        value: formatGnfCompact((data?.today.salesCount ?? 0) > 0 ? (totalSales / data!.today.salesCount).round() : 0),
                        subtitle: 'Par transaction',
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.iconTeal,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 5. RÉPARTITION DES MODES DE PAIEMENT
                  NmaMobileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MODES DE PAIEMENT DU JOUR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PaymentMethodRow(
                          label: 'Espèces',
                          amount: cash,
                          ratio: cashRatio,
                          color: AppColors.brandEmerald,
                          icon: Icons.payments_rounded,
                        ),
                        const SizedBox(height: 12),
                        _PaymentMethodRow(
                          label: 'Orange Money / Mobile',
                          amount: momo,
                          ratio: momoRatio,
                          color: AppColors.brandOrange,
                          icon: Icons.phone_android_rounded,
                        ),
                        const SizedBox(height: 12),
                        _PaymentMethodRow(
                          label: 'Ventes à Crédit',
                          amount: credit,
                          ratio: creditRatio,
                          color: AppColors.warning,
                          icon: Icons.assignment_late_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _BannerStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final String label;
  final int amount;
  final double ratio;
  final Color color;
  final IconData icon;

  const _PaymentMethodRow({
    required this.label,
    required this.amount,
    required this.ratio,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                ),
              ],
            ),
            Text(
              formatGnf(amount),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
