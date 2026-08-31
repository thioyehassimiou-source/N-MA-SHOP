import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/admin_providers.dart';
import '../../core/theme/app_theme.dart';
import '../clients/client_list_view.dart';
import '../generator/license_list_view.dart';
import '../settings/change_pin_dialog.dart';
import '../statistics/statistics_dashboard_view.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentIndex = 0;
  Timer? _syncTimer;

  final List<Widget> _pages = const [
    ClientListView(),
    LicenseListView(),
    StatisticsDashboardView(),
  ];

  @override
  void initState() {
    super.initState();
    // Synchroniser automatiquement au lancement de l'application admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onRefresh(showToast: false);
    });

    // Synchroniser automatiquement en arrière-plan toutes les 5 secondes pour recevoir instantanément les boutiques activées
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _onRefresh(showToast: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh({bool showToast = true}) async {
    // 1. Lancer la synchronisation avec le relais API Neon
    await ref.read(adminSyncServiceProvider).fetchAndApplyPendingActivations();
    
    // 2. Rafraîchir les listes locales
    ref.read(clientsProvider.notifier).refresh();
    ref.read(licensesProvider.notifier).refresh();
    
    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Données N\'MaShop synchronisées !'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.borderSlate, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Paramètres Administrateur',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryIndigo),
              title: const Text('Changer le code PIN'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(context: context, builder: (_) => const ChangePinDialog());
              },
            ),
            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.orange),
              title: const Text('Réinitialiser les données', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
              subtitle: const Text('Purger les boutiques, licences et réinitialiser le PIN'),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.orange),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Purger toutes les données ?'),
                    content: const Text(
                      'Attention, cette action va effacer l\'ensemble des boutiques enregistrées, l\'historique des clés générées et réinitialiser le code PIN par défaut (1234).\n\nCette action est irréversible.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.roseAlert),
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('Confirmer la purge'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final repo = ref.read(adminRepositoryProvider);
                  await repo.resetAllData();
                  ref.read(clientsProvider.notifier).refresh();
                  ref.read(licensesProvider.notifier).refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Toutes les données ont été réinitialisées avec succès !'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.roseAlert),
              title: const Text('Se Déconnecter', style: TextStyle(color: AppTheme.roseAlert, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.roseAlert),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(isAuthenticatedProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSlate,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/admin_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'N\'MaShop Admin',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                ),
                Text(
                  'Gestionnaire de Licences PC',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 22, color: AppTheme.primaryIndigo),
            onPressed: _onRefresh,
            tooltip: 'Synchroniser',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22, color: AppTheme.textDark),
            onPressed: _showSettingsMenu,
            tooltip: 'Paramètres PIN',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderSlate),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textDark.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.storefront_rounded, Icons.storefront_outlined, 'Boutiques'),
              _buildNavItem(1, Icons.vpn_key_rounded, Icons.vpn_key_outlined, 'Licences'),
              _buildNavItem(2, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Statistiques'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLightBg : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppTheme.primaryIndigo : AppTheme.textSecondary,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryIndigo,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
