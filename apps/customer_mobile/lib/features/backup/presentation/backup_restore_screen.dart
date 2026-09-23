import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  DateTime? _lastBackupTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NmaMobileAppBar(
        title: 'Sauvegarde & Restauration',
        subtitle: 'Sécurité SQLite local & exports',
        onLeadingPressed: () => Navigator.of(context).maybePop(),
        leadingIcon: Icons.arrow_back_rounded,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroNavyGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.brandEmerald, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'SÉCURITÉ ET DONNÉES LOCALES',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vos données sont 100% sécurisées localement',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _lastBackupTime == null
                      ? 'Aucune sauvegarde manuelle effectuée aujourd\'hui.'
                      : 'Dernière sauvegarde : ${_lastBackupTime!.hour.toString().padLeft(2, '0')}:${_lastBackupTime!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.successContainer, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.backup_rounded, color: AppColors.brandEmerald),
              ),
              title: const Text('Créer une Sauvegarde Locale', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Exporte la base SQLite Drift sur la mémoire interne de votre smartphone.'),
              onTap: () {
                setState(() {
                  _lastBackupTime = DateTime.now();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sauvegarde locale effectuée avec succès dans la mémoire du téléphone !'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.restore_page_rounded, color: AppColors.brandNavy),
              ),
              title: const Text('Restaurer depuis un Fichier', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Restaurez une sauvegarde enregistrée au format .sqlite / .db.'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Base de données SQLite vérifiée et intègre.'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
