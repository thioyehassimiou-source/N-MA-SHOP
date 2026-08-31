import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/client_model.dart';
import '../../core/providers/admin_providers.dart';
import '../../core/theme/app_theme.dart';

class ClientFormDialog extends ConsumerStatefulWidget {
  final ClientModel? client;

  const ClientFormDialog({super.key, this.client});

  @override
  ConsumerState<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _storeCtrl;
  late TextEditingController _ownerCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _storeCtrl = TextEditingController(text: widget.client?.storeName ?? '');
    _ownerCtrl = TextEditingController(text: widget.client?.ownerName ?? '');
    _phoneCtrl = TextEditingController(text: widget.client?.phone ?? '');
    _cityCtrl = TextEditingController(text: widget.client?.city ?? 'Conakry');
    _addressCtrl = TextEditingController(text: widget.client?.address ?? '');
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final client = ClientModel(
      id: widget.client?.id ?? const Uuid().v4(),
      storeName: _storeCtrl.text.trim(),
      ownerName: _ownerCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      hardwareId: widget.client?.hardwareId ?? '',
      createdAt: widget.client?.createdAt ?? DateTime.now(),
    );

    await ref.read(clientsProvider.notifier).addOrUpdateClient(client);
    if (mounted) Navigator.pop(context, client);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.client != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.primaryLightBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEdit ? Icons.edit_rounded : Icons.storefront_rounded,
              color: AppTheme.primaryIndigo,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEdit ? 'Modifier la Boutique' : 'Nouvelle Boutique',
              style: const TextStyle(color: AppTheme.textDark, fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _storeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom de la Boutique *',
                  prefixIcon: Icon(Icons.storefront_rounded, color: AppTheme.primaryIndigo),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du Gérant / Commerçant *',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primaryIndigo),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone WhatsApp *',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryIndigo),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Adresse / Quartier',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primaryIndigo),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ville *',
                  prefixIcon: Icon(Icons.location_city_rounded, color: AppTheme.primaryIndigo),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text(isEdit ? 'Mettre à jour' : 'Enregistrer'),
        ),
      ],
    );
  }
}
