import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';
import '../../stock/presentation/stock_screen.dart';
import '../../receivables/presentation/receivables_screen.dart';

class LocalAlertItem {
  final String id;
  final String title;
  final String message;
  final String severity; // 'critical', 'warning', 'info'
  final DateTime date;
  final String category; // 'stock', 'receivable', 'sync'
  final VoidCallback? onAction;

  LocalAlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.date,
    required this.category,
    this.onAction,
  });
}

final dismissedAlertIdsProvider = StateProvider<Set<String>>((ref) => {});

final alertsDataProvider = FutureProvider.autoDispose<List<LocalAlertItem>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);
  final dismissed = ref.watch(dismissedAlertIdsProvider);

  final List<LocalAlertItem> items = [];
  final now = DateTime.now();

  // 1. Alertes de Stock (Rupture ou stock bas)
  final products = await db.select(db.mobileProducts).get();
  for (final p in products) {
    if (p.stockQuantity <= 0) {
      final id = 'stock-out-${p.id}';
      if (!dismissed.contains(id)) {
        items.add(
          LocalAlertItem(
            id: id,
            title: 'Rupture de Stock : ${p.name}',
            message: 'Le stock est épuisé (0 ${p.unit}). Pensez à réapprovisionner auprès de vos fournisseurs.',
            severity: 'critical',
            date: now,
            category: 'stock',
          ),
        );
      }
    } else if (p.stockQuantity <= p.lowStockThreshold) {
      final id = 'stock-low-${p.id}';
      if (!dismissed.contains(id)) {
        items.add(
          LocalAlertItem(
            id: id,
            title: 'Stock Faible : ${p.name}',
            message: 'Il ne reste que ${p.stockQuantity} ${p.unit} en rayon (seuil critique : ${p.lowStockThreshold}).',
            severity: 'warning',
            date: now,
            category: 'stock',
          ),
        );
      }
    }
  }

  // 2. Alertes de Créances clients impayées
  final customers = await db.select(db.mobileCustomers).get();
  final custMap = {for (final c in customers) c.id: c.name};
  final sales = await db.select(db.mobileSales).get();
  final Map<String, int> debtPerCustomer = {};
  for (final s in sales) {
    if (!s.isCancelled && s.amountPaid < s.total) {
      final due = s.total - s.amountPaid;
      final custName = s.customerId != null ? (custMap[s.customerId] ?? 'Client Débiteur') : 'Client au comptoir';
      debtPerCustomer[custName] = (debtPerCustomer[custName] ?? 0) + due;
    }
  }

  for (final entry in debtPerCustomer.entries) {
    if (entry.value > 100000) {
      final id = 'debt-${entry.key}';
      if (!dismissed.contains(id)) {
        items.add(
          LocalAlertItem(
            id: id,
            title: 'Créance Importante : ${entry.key}',
            message: 'Ce client vous doit actuellement ${AppFormatters.formatCurrency(entry.value)}. Un rappel est recommandé.',
            severity: entry.value > 500000 ? 'critical' : 'warning',
            date: now.subtract(const Duration(hours: 2)),
            category: 'receivable',
          ),
        );
      }
    }
  }

  // 3. Information Système & Sécurité
  items.add(
    LocalAlertItem(
      id: 'sys-backup-reminder',
      title: 'Système N\'MaShop 100% Autonome',
      message: 'Base SQLite locale active. Vos données de caisse sont protégées sur cet appareil.',
      severity: 'info',
      date: now.subtract(const Duration(days: 1)),
      category: 'sync',
    ),
  );

  return items;
});

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: NmaMobileAppBar(
        title: 'Centre d\'Alertes & Notifications',
        subtitle: 'Stocks critiques, créances & système',
        onLeadingPressed: () => Navigator.of(context).maybePop(),
        leadingIcon: Icons.arrow_back_rounded,
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(alertsDataProvider),
          ),
        ],
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Erreur de chargement ($err)', style: const TextStyle(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(alertsDataProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle_outline_rounded, size: 56, color: AppColors.brandEmerald),
                  SizedBox(height: 12),
                  Text('Tout est en ordre !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.brandNavy)),
                  SizedBox(height: 4),
                  Text('Aucune rupture de stock ni alerte critique à signaler.', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            );
          }

          final criticalCount = alerts.where((a) => a.severity == 'critical').length;
          final warningCount = alerts.where((a) => a.severity == 'warning').length;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(alertsDataProvider),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                // Synthèse
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAlertKpi('Critiques', '$criticalCount', AppColors.error, Icons.error_rounded),
                      Container(height: 30, width: 1, color: AppColors.border),
                      _buildAlertKpi('Avertissements', '$warningCount', AppColors.warning, Icons.warning_rounded),
                      Container(height: 30, width: 1, color: AppColors.border),
                      _buildAlertKpi('Total Actif', '${alerts.length}', AppColors.brandNavy, Icons.notifications_active_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text('NOTIFICATIONS EN COURS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8)),
                const SizedBox(height: 8),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final a = alerts[index];
                    final isCritical = a.severity == 'critical';
                    final isWarning = a.severity == 'warning';

                    final color = isCritical
                        ? AppColors.error
                        : isWarning
                            ? AppColors.warning
                            : const Color(0xFF2563EB);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBright,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCritical
                              ? AppColors.error.withValues(alpha: 0.4)
                              : isWarning
                                  ? AppColors.warning.withValues(alpha: 0.4)
                                  : AppColors.outline.withValues(alpha: 0.4),
                          width: isCritical ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isCritical
                                  ? Icons.error_rounded
                                  : isWarning
                                      ? Icons.warning_amber_rounded
                                      : Icons.info_outline_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.brandNavy),
                                      ),
                                    ),
                                    Text(
                                      AppFormatters.formatRelativeTime(a.date),
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a.message,
                                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.3),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (a.category == 'stock')
                                      InkWell(
                                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockScreen())),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.brandNavy,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('Gérer Stock', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    else if (a.category == 'receivable')
                                      InkWell(
                                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceivablesScreen())),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.brandOrange,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('Voir Créances', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () {
                                        ref.read(dismissedAlertIdsProvider.notifier).update((state) => {...state, a.id});
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Text('Ignorer', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertKpi(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}
