import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../receivables/presentation/receivables_screen.dart';
import 'dashboard_controller.dart';
import 'widgets/sync_freshness_badge.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isAmountHidden = false;

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        title: Row(
          children: [
            // Avatar Circle with initial
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                shopName.isNotEmpty ? shopName[0].toUpperCase() : 'B',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Bonjour Patron 👋',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: state.isOffline ? Colors.amber : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$shopName • ${state.isOffline ? 'Hors-ligne' : 'En direct'}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
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
          // Notification card button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AlertsScreen()),
                    );
                  },
                  icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A), size: 22),
                  tooltip: 'Alertes & Notifications',
                ),
                if (data != null && data.unreadAlertsCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${data.unreadAlertsCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.read(dashboardControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 22),
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
        color: AppColors.primary,
        child: state.isLoading && data == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Sync freshness badge
                  Center(
                    child: SyncFreshnessBadge(
                      lastSyncTime: data?.shop.lastSyncAt,
                      isOffline: state.isOffline,
                      onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Out of stock alert banner if critical
                  if (data != null && (data.stock.outOfStockCount > 0 || data.unreadAlertsCount > 0)) ...[
                    GestureDetector(
                      onTap: () => widget.onNavigateToTab?.call(3), // Stock tab
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEE2E2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.stock.outOfStockCount > 0
                                        ? '${data.stock.outOfStockCount} article(s) en rupture de stock !'
                                        : '${data.unreadAlertsCount} alerte(s) de caisse à vérifier',
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Appuyez pour régulariser le stock immédiatement.',
                                    style: TextStyle(color: Color(0xFFB91C1C), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFFDC2626)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // HERO CARD - DEEP NAVY (AppColors.heroNavyGradient) WITH EYE TOGGLE & PRO BADGE
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroNavyGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandNavy.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row with Badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'PATRON PRO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${data?.today.salesCount ?? 0} vente(s) aujourd\'hui',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title with Eye Toggle Icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CHIFFRE D\'AFFAIRES DU JOUR',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isAmountHidden = !_isAmountHidden;
                                });
                              },
                              icon: Icon(
                                _isAmountHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white70,
                                size: 20,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              tooltip: _isAmountHidden ? 'Afficher les montants' : 'Masquer les montants',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Large Sales Figure
                        Text(
                          _isAmountHidden ? '•••••••• FCFA' : AppFormatters.formatCurrency(totalSales),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Estimated profit pill
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.trending_up_rounded, color: Color(0xFF34D399), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isAmountHidden
                                        ? 'Marge : ••••• FCFA'
                                        : 'Marge estimée : +${AppFormatters.formatCurrency(data?.today.totalProfit ?? 0)}',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Settlement Distribution Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ENCAISSEMENTS',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                            Text(
                              '${((cashRatio + momoRatio) * 100).toInt()}% encaissements faits',
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 8,
                            child: Row(
                              children: [
                                if (cashRatio > 0)
                                  Expanded(
                                    flex: (cashRatio * 100).toInt(),
                                    child: Container(color: const Color(0xFF3B82F6)),
                                  ),
                                if (momoRatio > 0)
                                  Expanded(
                                    flex: (momoRatio * 100).toInt(),
                                    child: Container(color: const Color(0xFFF97316)),
                                  ),
                                if (creditRatio > 0)
                                  Expanded(
                                    flex: (creditRatio * 100).toInt(),
                                    child: Container(color: const Color(0xFFA855F7)),
                                  ),
                                if (totalSales == 0)
                                  Expanded(
                                    child: Container(color: Colors.white12),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Pill Detail Button
                        InkWell(
                          onTap: () => widget.onNavigateToTab?.call(1), // Ventes tab
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Voir le détail des ventes',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F172A), size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // PASTEL QUICK ACTION CARDS (2x2 GRID)
                  Row(
                    children: [
                      // Soft Blue Card: Encaisser
                      Expanded(
                        child: _buildPastelCard(
                          title: 'Encaisser',
                          subtitle: _isAmountHidden ? '•••• FCFA' : AppFormatters.formatCurrency(cash),
                          detailText: 'Espèces tiroir',
                          icon: Icons.account_balance_wallet_rounded,
                          bgColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                          iconColor: const Color(0xFF2563EB),
                          textColor: const Color(0xFF1E3A8A),
                          onTap: () => widget.onNavigateToTab?.call(2), // Caisse / Trésorerie
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Soft Green Card: Nouv. Vente
                      Expanded(
                        child: _buildPastelCard(
                          title: 'Nouv. Vente',
                          subtitle: '+ Saisir ticket',
                          detailText: 'Comptoir rapide',
                          icon: Icons.add_shopping_cart_rounded,
                          bgColor: const Color(0xFFECFDF5),
                          borderColor: const Color(0xFFA7F3D0),
                          iconColor: const Color(0xFF059669),
                          textColor: const Color(0xFF064E3B),
                          onTap: () => widget.onNavigateToTab?.call(2), // Caisse tab
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Soft Purple Card: Créances
                      Expanded(
                        child: _buildPastelCard(
                          title: 'Créances',
                          subtitle: _isAmountHidden ? '•••• FCFA' : AppFormatters.formatCurrency(data?.receivables.totalAmount ?? 0),
                          detailText: '${data?.receivables.debtorsCount ?? 0} débiteur(s)',
                          icon: Icons.people_alt_rounded,
                          bgColor: const Color(0xFFF3E8FF),
                          borderColor: const Color(0xFFDDD6FE),
                          iconColor: const Color(0xFF7C3AED),
                          textColor: const Color(0xFF4C1D95),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ReceivablesScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Soft Amber Card: Inventaire
                      Expanded(
                        child: _buildPastelCard(
                          title: 'Inventaire',
                          subtitle: '${data?.stock.lowStockCount ?? 0} alertes',
                          detailText: data?.stock.outOfStockCount != null && data!.stock.outOfStockCount > 0
                              ? '${data.stock.outOfStockCount} ruptures !'
                              : 'Stock sous contrôle',
                          icon: Icons.inventory_2_rounded,
                          bgColor: const Color(0xFFFFFBEB),
                          borderColor: const Color(0xFFFDE68A),
                          iconColor: const Color(0xFFD97706),
                          textColor: const Color(0xFF78350F),
                          onTap: () => widget.onNavigateToTab?.call(3), // Stock tab
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // GOLDEN AMBER BANNER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Assistant Stock Pro',
                                style: TextStyle(
                                  color: Color(0xFF78350F),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Vos prévisions de commande sont prêtes pour cette semaine.',
                                style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => widget.onNavigateToTab?.call(3),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Voir',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // RECENT ALERTS / ACTIVITY SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Activité & Notifications',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AlertsScreen()),
                          );
                        },
                        child: const Text('Tout voir', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (data != null && data.recentAlerts.isNotEmpty) ...[
                    ...data.recentAlerts.map(
                      (alert) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (alert.severity == 'critical'
                                        ? const Color(0xFFEF4444)
                                        : alert.severity == 'warning'
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF3B82F6))
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                alert.severity == 'critical'
                                    ? Icons.error_outline_rounded
                                    : alert.severity == 'warning'
                                        ? Icons.warning_amber_rounded
                                        : Icons.info_outline_rounded,
                                color: alert.severity == 'critical'
                                    ? const Color(0xFFEF4444)
                                    : alert.severity == 'warning'
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF3B82F6),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    alert.message,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              AppFormatters.formatRelativeTime(alert.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Aucune anomalie détectée. Tout tourne rond en boutique !',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildPastelCard({
    required String title,
    required String subtitle,
    required String detailText,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                Icon(Icons.arrow_outward_rounded, color: iconColor.withValues(alpha: 0.6), size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              detailText,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

