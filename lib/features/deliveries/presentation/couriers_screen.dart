import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../application/deliveries_providers.dart';
import 'new_courier_dialog.dart';
import '../../../core/database/tables/deliveries.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class CouriersScreen extends ConsumerWidget {
  const CouriersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCouriers = ref.watch(couriersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppPageHeader(
            title: 'Livreurs',
            subtitle: 'Gérez votre flotte de coursiers et livreurs',
            icon: Icons.sports_motorsports_outlined,
            gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            actions: [
              FilledButton.icon(
                onPressed: () => NewCourierDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau Livreur'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: asyncCouriers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (couriers) {
              if (couriers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_motorsports_outlined, size: 64, color: context.colors.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Aucun livreur enregistré', style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 16)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                itemCount: couriers.length,
                itemBuilder: (context, index) {
                  final c = couriers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: c.isActive ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : context.colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                c.vehicleType == VehicleType.moto ? Icons.motorcycle_rounded :
                                c.vehicleType == VehicleType.voiture ? Icons.directions_car_rounded :
                                Icons.delivery_dining_rounded,
                                color: c.isActive ? const Color(0xFFF59E0B) : context.colors.onSurfaceVariant,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16,
                                        color: c.isActive ? context.colors.onSurface : context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: c.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        c.isActive ? 'Actif' : 'Inactif',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: c.isActive ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (c.phone != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    c.phone!,
                                    style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (c.phone != null && c.isActive) ...[
                            IconButton(
                              tooltip: 'Appeler',
                              icon: const Icon(Icons.phone_outlined, color: Colors.green),
                              onPressed: () => launchUrl(Uri.parse('tel:${c.phone}')),
                            ),
                            IconButton(
                              tooltip: 'WhatsApp',
                              icon: const Icon(Icons.chat_outlined, color: Colors.teal),
                              onPressed: () => launchUrl(Uri.parse('https://wa.me/${c.phone}')),
                            ),
                          ],
                          IconButton(
                            tooltip: 'Modifier',
                            icon: Icon(Icons.edit_outlined, color: context.colors.onSurfaceVariant),
                            onPressed: () => NewCourierDialog.show(context, courier: c),
                          ),
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
}
