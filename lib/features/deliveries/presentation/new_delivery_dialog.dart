import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/orders.dart';
import '../../../core/database/database.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../application/deliveries_providers.dart';

import 'package:nmashop/core/theme/app_theme.dart';

/// Provider for orders that are "ready" and not yet dispatched.
final readyOrdersProvider = StreamProvider<List<Order>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.orders)
        ..where(
          (o) => o.status.equals(OrderStatus.ready.index),
        )
        ..orderBy([(o) => drift.OrderingTerm(expression: o.createdAt, mode: drift.OrderingMode.desc)]))
      .watch();
});

/// Dialog pour assigner une livraison à un livreur.
class NewDeliveryDialog extends ConsumerStatefulWidget {
  const NewDeliveryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NewDeliveryDialog(),
    );
  }

  @override
  ConsumerState<NewDeliveryDialog> createState() => _NewDeliveryDialogState();
}

class _NewDeliveryDialogState extends ConsumerState<NewDeliveryDialog> {
  String? _selectedOrderId;
  String? _selectedCourierId;
  final _feeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _feeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une commande')),
      );
      return;
    }
    if (_selectedCourierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un livreur')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(deliveriesServiceProvider).assignDelivery(
            orderId: _selectedOrderId!,
            courierId: _selectedCourierId!,
            deliveryFee: int.tryParse(_feeCtrl.text.trim()) ?? 0,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      ref.invalidate(deliveriesProvider);
      ref.invalidate(readyOrdersProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livraison assignée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(readyOrdersProvider);
    final couriersAsync = ref.watch(couriersProvider);

    return AppFormDialog(
      title: 'Nouvelle Livraison',
      subtitle: 'Assignez une commande prête à un livreur',
      icon: Icons.local_shipping_outlined,
      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      width: 520,
      primaryLabel: 'Assigner',
      primaryIcon: Icons.check_circle_outline,
      onCancel: () => Navigator.of(context).pop(),
      onPrimary: _saving ? null : _assign,
      isPrimaryLoading: _saving,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Sélecteur Commande ────────────────────────────────
          _Label(label: 'Commande à livrer', icon: Icons.receipt_long_outlined),
          const SizedBox(height: AppSpacing.sm),
          ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur: $e'),
            data: (orders) {
              if (orders.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: context.colors.onSurfaceVariant, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aucune commande "Prête" disponible. Marquez une commande comme prête dans le module Commandes.',
                          style: AppTypography.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: _selectedOrderId,
                decoration: InputDecoration(
                  hintText: 'Sélectionner une commande…',
                  prefixIcon: Icon(Icons.receipt_outlined, size: 20, color: context.colors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: orders
                    .map(
                      (o) => DropdownMenuItem(
                        value: o.id,
                        child: Text(
                          '${o.reference} — ${o.customerName} (${formatGnf(o.totalAmount)})',
                          style: AppTypography.bodySm,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedOrderId = v),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Sélecteur Livreur ──────────────────────────────────
          _Label(label: 'Livreur', icon: Icons.sports_motorsports_outlined),
          const SizedBox(height: AppSpacing.sm),
          couriersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur: $e'),
            data: (couriers) {
              if (couriers.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Aucun livreur. Allez dans Livreurs pour en enregistrer.',
                    style: AppTypography.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: _selectedCourierId,
                decoration: InputDecoration(
                  hintText: 'Sélectionner un livreur…',
                  prefixIcon: Icon(Icons.person_outline, size: 20, color: context.colors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: couriers
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.name}${c.phone != null ? " — ${c.phone}" : ""}',
                          style: AppTypography.bodySm,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedCourierId = v),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Frais de livraison ────────────────────────────────
          AppFormField(
            label: 'Frais de livraison (GNF)',
            controller: _feeCtrl,
            icon: Icons.payments_outlined,
            hint: 'Ex: 50 000 (0 si gratuit)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          AppFormField(
            label: 'Note (optionnel)',
            controller: _noteCtrl,
            icon: Icons.notes_outlined,
            hint: 'Instructions spéciales pour le livreur…',
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: context.colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
