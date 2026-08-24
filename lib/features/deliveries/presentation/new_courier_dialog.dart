import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../../core/database/tables/deliveries.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class NewCourierDialog extends ConsumerStatefulWidget {
  const NewCourierDialog({super.key, this.existingCourier});

  final Courier? existingCourier;

  static Future<void> show(BuildContext context, {Courier? courier}) {
    return showDialog(
      context: context,
      builder: (ctx) => NewCourierDialog(existingCourier: courier),
    );
  }

  @override
  ConsumerState<NewCourierDialog> createState() => _NewCourierDialogState();
}

class _NewCourierDialogState extends ConsumerState<NewCourierDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  VehicleType _selectedType = VehicleType.moto;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingCourier?.name);
    _phoneController = TextEditingController(text: widget.existingCourier?.phone);
    if (widget.existingCourier != null) {
      _selectedType = widget.existingCourier!.vehicleType;
      _isActive = widget.existingCourier!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final db = ref.read(databaseProvider);
    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    
    if (widget.existingCourier == null) {
      // Create new
      await db.into(db.couriers).insert(
            CouriersCompanion.insert(
              id: const Uuid().v4(),
              name: name,
              phone: Value(phone),
              vehicleType: Value(_selectedType),
              isActive: Value(_isActive),
            ),
          );
    } else {
      // Update existing
      await (db.update(db.couriers)..where((c) => c.id.equals(widget.existingCourier!.id))).write(
        CouriersCompanion(
          name: Value(name),
          phone: Value(phone),
          vehicleType: Value(_selectedType),
          isActive: Value(_isActive),
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.existingCourier == null ? 'Livreur ajouté ✓' : 'Livreur modifié ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: widget.existingCourier == null ? 'Nouveau Livreur' : 'Modifier Livreur',
      subtitle: 'Informations du livreur pour les expéditions',
      icon: Icons.sports_motorsports_outlined,
      gradientColors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
      width: 420,
      primaryLabel: 'Enregistrer',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: _save,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFormField(
            label: 'Nom complet',
            controller: _nameController,
            icon: Icons.person_outline,
            isRequired: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppFormField(
            label: 'Téléphone',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          AppFormDropdown<VehicleType>(
            label: 'Véhicule',
            value: _selectedType,
            icon: Icons.directions_bike_outlined,
            items: VehicleType.values.map((v) {
              return DropdownMenuItem(
                value: v,
                child: Text(v.label),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedType = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text('Actif (disponible)', style: TextStyle(color: context.colors.onSurface)),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeThumbColor: context.colors.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
