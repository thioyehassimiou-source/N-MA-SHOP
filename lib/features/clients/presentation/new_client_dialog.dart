import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class NewClientDialog extends ConsumerStatefulWidget {
  const NewClientDialog({super.key, this.existingClient});

  final Customer? existingClient;

  static Future<void> show(BuildContext context, {Customer? client}) {
    return showDialog(
      context: context,
      builder: (ctx) => NewClientDialog(existingClient: client),
    );
  }

  @override
  ConsumerState<NewClientDialog> createState() => _NewClientDialogState();
}

class _NewClientDialogState extends ConsumerState<NewClientDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _saving = false;

  bool get _isEdit => widget.existingClient != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingClient?.name);
    _phoneController = TextEditingController(text: widget.existingClient?.phone);
    _addressController = TextEditingController(text: widget.existingClient?.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    
    try {
      if (widget.existingClient == null) {
        // Create new
        await db.into(db.customers).insert(
              CustomersCompanion.insert(
                id: const Uuid().v4(),
                name: name,
                phone: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
                address: Value(_addressController.text.trim().isEmpty ? null : _addressController.text.trim()),
              ),
            );
      } else {
        // Update existing
        await (db.update(db.customers)..where((c) => c.id.equals(widget.existingClient!.id))).write(
          CustomersCompanion(
            name: Value(name),
            phone: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
            address: Value(_addressController.text.trim().isEmpty ? null : _addressController.text.trim()),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Client modifié' : 'Client ajouté')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: _isEdit ? 'Modifier le Client' : 'Nouveau Client',
      subtitle: _isEdit
          ? 'Mise à jour des informations client'
          : 'Ajouter un nouveau client à votre répertoire',
      icon: Icons.person_add_outlined,
      gradientColors: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
      primaryLabel: 'Enregistrer',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: _saving ? null : _save,
      isPrimaryLoading: _saving,
      sections: [
        FormSection(
          title: 'Informations Personnelles',
          icon: Icons.person_outline,
          child: Column(
            children: [
              AppFormField(
                label: 'Nom complet',
                hint: 'Ex: Mamadou Diallo',
                controller: _nameController,
                icon: Icons.person_outline,
                isRequired: true,
              ),
              const SizedBox(height: AppSpacing.md),
              FormFieldRow(
                left: AppFormField(
                  label: 'Téléphone',
                  hint: 'Ex: 621 00 00 00',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                right: AppFormField(
                  label: 'Adresse / Localisation',
                  hint: 'Ex: Kaloum, Conakry',
                  controller: _addressController,
                  icon: Icons.location_on_outlined,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
