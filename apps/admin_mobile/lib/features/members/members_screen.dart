import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/admin_providers.dart';
import '../../core/theme/app_theme.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {

  void _showChangePinDialog() {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.security_rounded, color: AppTheme.primaryIndigo),
                SizedBox(width: 10),
                Text('Changer le Code PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'PIN Actuel (Ex: 1234)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nouveau PIN (4 chiffres)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmer le PIN'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppTheme.roseAlert, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary))),
              ElevatedButton(
                onPressed: () {
                  final repo = ref.read(adminRepositoryProvider);
                  if (oldPinCtrl.text != repo.getPin()) {
                    setDialogState(() => error = 'PIN actuel incorrect');
                    return;
                  }
                  if (newPinCtrl.text.length != 4) {
                    setDialogState(() => error = 'Le PIN doit comporter 4 chiffres');
                    return;
                  }
                  if (newPinCtrl.text != confirmPinCtrl.text) {
                    setDialogState(() => error = 'Les nouveaux PIN ne correspondent pas');
                    return;
                  }

                  repo.setPin(newPinCtrl.text);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🎉 Code PIN mis à jour avec succès !'), behavior: SnackBarBehavior.floating),
                  );
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetAppDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Réinitialiser l\'application ?'),
        content: const Text('Cela réinitialisera le cache local et remettra le code PIN par défaut (1234).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.roseAlert),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(adminRepositoryProvider).resetAllData();
              ref.read(clientsProvider.notifier).refresh();
              ref.read(licensesProvider.notifier).refresh();
              ref.read(isAuthenticatedProvider.notifier).logout();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Application réinitialisée ! PIN par défaut : 1234'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSlate,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Super Admin N\'MaShop',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Éditeur Officiel de Licences',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Sécurité du Compte',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryIndigo),
                  title: const Text('Changer le code PIN'),
                  subtitle: const Text('Modifier la clé d\'accès rapide'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showChangePinDialog,
                ),
                const Divider(height: 1, color: AppTheme.borderSlate),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppTheme.amberTrial),
                  title: const Text('Se déconnecter'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ref.read(isAuthenticatedProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Options Avancées',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.restart_alt_rounded, color: AppTheme.roseAlert),
              title: const Text('Réinitialiser l\'application'),
              subtitle: const Text('Vider le cache et remettre les valeurs par défaut'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showResetAppDialog,
            ),
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text(
              'N\'MaShop Admin Mobile v2.0 (Build 2026)\nBusiness Licensing Suite',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
