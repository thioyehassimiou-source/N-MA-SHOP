import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_page_header.dart';
import '../application/deliveries_providers.dart';
import '../../../core/database/tables/deliveries.dart';
import 'new_delivery_dialog.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class DeliveriesScreen extends ConsumerWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDeliveries = ref.watch(deliveriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppPageHeader(
            title: 'Livraisons en cours',
            subtitle: 'Suivez les colis assignés à vos livreurs',
            icon: Icons.local_shipping_outlined,
            gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            actions: [
              FilledButton.icon(
                onPressed: () => NewDeliveryDialog.show(context),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Nouvelle Assignation'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: asyncDeliveries.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (deliveries) {
              if (deliveries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 72, color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      const SizedBox(height: 24),
                      const Text(
                        'Aucune livraison en cours',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Suivez ces 2 étapes pour démarrer',
                        style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      // Step 1
                      _StepCard(
                        step: '1',
                        title: 'Enregistrez vos livreurs',
                        subtitle: 'Ajoutez vos coursiers dans l\'annuaire Livreurs',
                        icon: Icons.sports_motorsports_outlined,
                        color: const Color(0xFFF59E0B),
                        buttonLabel: 'Aller aux Livreurs',
                        onPressed: () => context.go('/livreurs'),
                      ),
                      const SizedBox(height: 16),
                      // Step 2
                      const _StepCard(
                        step: '2',
                        title: 'Assignez depuis les Commandes',
                        subtitle: 'Quand une commande est \'Prête\', cliquez \'Assigner un livreur\'',
                        icon: Icons.notifications_active_outlined,
                        color: Color(0xFF6366F1),
                      ),
                    ],
                  ),
                );
              }
              
              // Trier pour mettre les livraisons en transit en premier
              final sorted = List.of(deliveries);
              sorted.sort((a, b) {
                if (a.delivery.status == DeliveryStatus.transit && b.delivery.status != DeliveryStatus.transit) return -1;
                if (a.delivery.status != DeliveryStatus.transit && b.delivery.status == DeliveryStatus.transit) return 1;
                return b.delivery.assignedAt.compareTo(a.delivery.assignedAt);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final item = sorted[index];
                  final delivery = item.delivery;
                  final order = item.order;
                  final courier = item.courier;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                order.reference,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Spacer(),
                              AppChip(
                                label: delivery.status.label,
                                status: _getChipStatus(delivery.status),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info Client
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CLIENT', style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (order.customerPhone != null)
                                      Text(order.customerPhone!, style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant)),
                                    if (order.deliveryAddress != null)
                                      Text(order.deliveryAddress!, style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              
                              // Info Livreur
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('LIVREUR', style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          courier.vehicleType == VehicleType.moto ? Icons.motorcycle_rounded : Icons.directions_car_rounded,
                                          size: 16,
                                          color: context.colors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(courier.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    if (courier.phone != null)
                                      Text(courier.phone!, style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              
                              // Info Montants
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('MONTANT À ENCAISSER', style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(formatGnf(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6366F1))),
                                    const SizedBox(height: 4),
                                    Text('Frais livreur: ${formatGnf(delivery.deliveryFee)}', style: TextStyle(fontSize: 12, color: context.colors.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          if (delivery.status == DeliveryStatus.transit) ...[
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    ref.read(deliveriesServiceProvider).failDelivery(delivery.id);
                                  },
                                  icon: const Icon(Icons.close_rounded, color: Colors.red),
                                  label: const Text('Signaler Échec', style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 16),
                                FilledButton.icon(
                                  onPressed: () {
                                    ref.read(deliveriesServiceProvider).completeDelivery(delivery.id);
                                  },
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Marquer comme Livrée'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  AppChipStatus _getChipStatus(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return AppChipStatus.warning;
      case DeliveryStatus.transit:
        return AppChipStatus.neutral;
      case DeliveryStatus.delivered:
        return AppChipStatus.success;
      case DeliveryStatus.failed:
        return AppChipStatus.error;
    }
  }
}

// ─── Carte d'instruction pour l'état vide ────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.buttonLabel,
    this.onPressed,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(width: AppSpacing.md),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(buttonLabel!, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

