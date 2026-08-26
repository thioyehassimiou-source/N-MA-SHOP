import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../application/order_providers.dart';
import '../data/repositories/drift_order_repository.dart';
import 'new_order_dialog.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../deliveries/presentation/assign_delivery_dialog.dart';

import 'package:nmashop/core/theme/app_theme.dart';

// ─── Couleurs et icônes par statut ───────────────────────────────────────────

Color _statusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:    return const Color(0xFFF59E0B);
    case OrderStatus.confirmed:  return const Color(0xFF6366F1);
    case OrderStatus.preparing:  return const Color(0xFF3B82F6);
    case OrderStatus.ready:      return const Color(0xFF10B981);
    case OrderStatus.delivered:  return const Color(0xFF059669);
    case OrderStatus.cancelled:  return const Color(0xFF6B7280);
  }
}

IconData _statusIcon(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:    return Icons.notifications_active_outlined;
    case OrderStatus.confirmed:  return Icons.check_circle_outline;
    case OrderStatus.preparing:  return Icons.restaurant_outlined;
    case OrderStatus.ready:      return Icons.inventory_outlined;
    case OrderStatus.delivered:  return Icons.local_shipping_outlined;
    case OrderStatus.cancelled:  return Icons.cancel_outlined;
  }
}

AppChipStatus _chipStatus(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:   return AppChipStatus.warning;
    case OrderStatus.confirmed: return AppChipStatus.neutral;
    case OrderStatus.preparing: return AppChipStatus.neutral;
    case OrderStatus.ready:     return AppChipStatus.success;
    case OrderStatus.delivered: return AppChipStatus.success;
    case OrderStatus.cancelled: return AppChipStatus.neutral;
  }
}

// ─── Écran principal ─────────────────────────────────────────────────────────

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (label: 'Nouvelles', status: OrderStatus.pending),
    (label: 'En préparation', status: OrderStatus.preparing),
    (label: 'Prêtes', status: OrderStatus.ready),
    (label: 'Livrées', status: OrderStatus.delivered),
    (label: 'Annulées', status: OrderStatus.cancelled),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(orderSummaryProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête + KPIs ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(
                title: 'Commandes',
                subtitle: 'Gérez les commandes reçues par WhatsApp, téléphone ou en direct',
                icon: Icons.shopping_bag_outlined,
                gradientColors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                actions: [
                  FilledButton.icon(
                    onPressed: () => NewOrderDialog.show(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouvelle Commande'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // KPI Cards
              LayoutBuilder(builder: (ctx, c) {
                return Row(
                  children: [
                    _KpiTile(label: 'Aujourd\'hui', value: '${summary.totalToday}', icon: Icons.today_outlined, color: const Color(0xFF6366F1)),
                    SizedBox(width: AppSpacing.md),
                    _KpiTile(label: 'En attente', value: '${summary.pending}', icon: Icons.hourglass_top_outlined, color: const Color(0xFFF59E0B)),
                    SizedBox(width: AppSpacing.md),
                    _KpiTile(label: 'En préparation', value: '${summary.preparing}', icon: Icons.restaurant_outlined, color: const Color(0xFF3B82F6)),
                    SizedBox(width: AppSpacing.md),
                    _KpiTile(label: 'Prêtes', value: '${summary.ready}', icon: Icons.inventory_outlined, color: const Color(0xFF10B981)),
                  ].map((w) => Expanded(child: w)).toList(),
                );
              }),
            ],
          ),
        ),

        // ── Tabs Kanban ──────────────────────────────────────────────────────
        Container(
          color: context.colors.surfaceContainerLowest,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: context.colors.onSurfaceVariant,
            indicatorColor: const Color(0xFF6366F1),
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: _tabs.map((t) {
              return Tab(text: t.label);
            }).toList(),
          ),
        ),

        // ── Contenu des onglets ─────────────────────────────────────────────
        Expanded(
          child: ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (orders) => TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                final filtered = orders
                    .where((o) {
                      if (tab.status == OrderStatus.pending) {
                        // L'onglet "Nouvelles" regroupe pending + confirmed
                        return o.status == OrderStatus.pending ||
                            o.status == OrderStatus.confirmed;
                      }
                      return o.status == tab.status;
                    })
                    .toList();

                if (filtered.isEmpty) {
                  return _EmptyTab(status: tab.status);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _OrderCard(order: filtered[i]),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── KPI Tile ─────────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    )),
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte commande ───────────────────────────────────────────────────────────

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(order.status);
    final isTerminal = order.status == OrderStatus.delivered ||
        order.status == OrderStatus.cancelled;

    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Bande colorée gauche (inspirée StockFlow)
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête de la carte
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon(order.status), color: color, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                order.reference,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppChip(
                          label: order.status.label,
                          status: _chipStatus(order.status),
                        ),
                        const Spacer(),
                        Text(
                          formatRelativeDay(order.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Infos client
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 15, color: context.colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          order.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        if (order.customerPhone != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.phone_outlined, size: 13, color: context.colors.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            order.customerPhone!,
                            style: TextStyle(fontSize: 12, color: context.colors.onSurfaceVariant),
                          ),
                        ],
                        const Spacer(),
                        // Mode livraison
                        Icon(
                          order.deliveryType == DeliveryType.delivery
                              ? Icons.local_shipping_outlined
                              : Icons.storefront_outlined,
                          size: 14,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          order.deliveryType.label,
                          style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant),
                        ),
                      ],
                    ),

                    if (order.deliveryAddress != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: context.colors.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              order.deliveryAddress!,
                              style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (order.note != null && order.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                         child: Text(
                          order.note!,
                          style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),

                    // Pied de carte : montant + actions
                    Row(
                      children: [
                        Text(
                          formatGnf(order.totalAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (!isTerminal) ...[
                          // Annuler
                          TextButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AppFormDialog(
                                  title: 'Annuler la commande ?',
                                  subtitle: 'Cette action est irréversible.',
                                  icon: Icons.warning_amber_rounded,
                                  gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                                  width: 400,
                                  primaryLabel: 'Oui, annuler',
                                  primaryIcon: Icons.close,
                                  onPrimary: () => Navigator.pop(context, true),
                                  onCancel: () => Navigator.pop(context, false),
                                  body: const SizedBox.shrink(),
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(orderRepositoryProvider).cancelOrder(order.id);
                              }
                            },
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Annuler'),
                            style: TextButton.styleFrom(foregroundColor: context.colors.error),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Avancer au prochain statut
                          if (order.status.nextStatus != null)
                            FilledButton.icon(
                              onPressed: () {
                                if (order.status == OrderStatus.ready && order.deliveryType == DeliveryType.delivery) {
                                  AssignDeliveryDialog.show(context, order: order);
                                } else {
                                  ref.read(orderRepositoryProvider).advanceStatus(order.id);
                                }
                              },
                              icon: Icon(
                                order.status == OrderStatus.ready && order.deliveryType == DeliveryType.delivery 
                                    ? Icons.delivery_dining 
                                    : Icons.arrow_forward, 
                                size: 14
                              ),
                              label: Text(
                                order.status == OrderStatus.ready && order.deliveryType == DeliveryType.delivery 
                                    ? 'Assigner un livreur' 
                                    : (order.status.nextActionLabel ?? '')
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: color,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Onglet vide ─────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(_statusIcon(status), color: color, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune commande « ${status.label} »',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Les commandes apparaîtront ici quand elles seront dans cet état.',
            style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
