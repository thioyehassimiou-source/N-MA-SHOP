import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/admin_providers.dart';
import '../../core/theme/app_theme.dart';

class ChangePinDialog extends ConsumerStatefulWidget {
  const ChangePinDialog({super.key});

  @override
  ConsumerState<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends ConsumerState<ChangePinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  String? _errorMsg;

  @override
  void dispose() {
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(adminRepositoryProvider);
    final currentPin = repo.getPin();

    if (_currentPinCtrl.text.trim() != currentPin) {
      setState(() => _errorMsg = 'L\'ancien code PIN est incorrect');
      return;
    }

    if (_newPinCtrl.text.trim() != _confirmPinCtrl.text.trim()) {
      setState(() => _errorMsg = 'Les nouveaux codes PIN ne correspondent pas');
      return;
    }

    await repo.setPin(_newPinCtrl.text.trim());

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Code PIN modifié avec succès !'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: AppTheme.primaryIndigo),
          SizedBox(width: 10),
          Text(
            'Changer le Code PIN',
            style: TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.roseBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(color: AppTheme.roseAlert, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _currentPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Code PIN Actuel (Ex: 1234)',
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
                ),
                validator: (v) => v == null || v.trim().length != 4 ? '4 chiffres requis' : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _newPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Nouveau Code PIN (4 chiffres)',
                  prefixIcon: Icon(Icons.key_rounded, color: AppTheme.textSecondary),
                ),
                validator: (v) => v == null || v.trim().length != 4 ? '4 chiffres requis' : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _confirmPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Confirmer Nouveau Code PIN',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded, color: AppTheme.textSecondary),
                ),
                validator: (v) => v == null || v.trim().length != 4 ? '4 chiffres requis' : null,
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
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
