import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../application/deliveries_providers.dart';
import '../../../core/database/tables/deliveries.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class AssignDeliveryDialog extends ConsumerStatefulWidget {
  const AssignDeliveryDialog({super.key, required this.order});

  final Order order;

  static Future<void> show(BuildContext context, {required Order order}) {
    return showDialog(
      context: context,
      builder: (ctx) => AssignDeliveryDialog(order: order),
    );
  }

  @override
  ConsumerState<AssignDeliveryDialog> createState() => _AssignDeliveryDialogState();
}

class _AssignDeliveryDialogState extends ConsumerState<AssignDeliveryDialog> {
  String? _selectedCourierId;
  final TextEditingController _feeController = TextEditingController(text: '0');
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_selectedCourierId == null) return;
    final fee = int.tryParse(_feeController.text.trim()) ?? 0;

    await ref.read(deliveriesServiceProvider).assignDelivery(
      orderId: widget.order.id,
      courierId: _selectedCourierId!,
      deliveryFee: fee,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livreur assigné et expédition créée')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final couriersAsync = ref.watch(couriersProvider);

    return AppFormDialog(
      title: 'Assigner un Livreur',
      subtitle: 'Commande : ${widget.order.reference}',
      icon: Icons.delivery_dining_outlined,
      gradientColors: const [Color(0xFFEAB308), Color(0xFFF59E0B)],
      width: 450,
      primaryLabel: 'Confirmer l\'expédition',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: _selectedCourierId == null ? null : _assign,
      body: couriersAsync.when(
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(height: 100, child: Center(child: Text('Erreur: $e'))),
        data: (couriers) {
          final activeCouriers = couriers.where((c) => c.isActive).toList();
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client : ${widget.order.customerName}', style: TextStyle(color: context.colors.onSurfaceVariant)),
              if (widget.order.deliveryAddress != null)
                Text('Adresse : ${widget.order.deliveryAddress}', style: TextStyle(color: context.colors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xl),
              
              if (activeCouriers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Aucun livreur actif disponible. Veuillez en ajouter un dans l\'onglet Livreurs.', style: TextStyle(color: Colors.red)),
                )
              else ...[
                AppFormDropdown<String>(
                  label: 'Choisir le Livreur',
                  value: _selectedCourierId,
                  icon: Icons.sports_motorsports_outlined,
                  isRequired: true,
                  items: activeCouriers.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.name} (${c.vehicleType == VehicleType.moto ? 'Moto' : 'Véhicule'})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCourierId = val);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppFormField(
                  label: 'Frais dus au livreur (GNF)',
                  controller: _feeController,
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                AppFormField(
                  label: 'Instructions spéciales',
                  controller: _noteController,
                  icon: Icons.note_alt_outlined,
                  maxLines: 2,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
