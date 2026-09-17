import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../alerts/presentation/alerts_screen.dart';
import '../auth/data/auth_service.dart';
import '../auth/presentation/auth_landing_screen.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../onboarding/presentation/onboarding_screen.dart';
import '../receivables/presentation/receivables_screen.dart';
import '../sales/presentation/sales_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../stock/presentation/stock_screen.dart';
import '../treasury/presentation/treasury_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const SalesScreen(),
      const TreasuryScreen(),
      const StockScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surfaceContainerLowest,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: AppColors.heroNavyGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'N\'MaShop Mobile',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Gestion Commerciale & Caisse POS',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined, color: AppColors.brandOrange),
              title: const Text('Centre d\'alertes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Ruptures de stock & alertes caisse', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined, color: AppColors.brandNavy),
              title: const Text('Créances & Débiteurs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Suivi des clients à crédit', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceivablesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded, color: AppColors.brandEmerald),
              title: const Text('Guide de bienvenue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Présentation des fonctionnalités', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
              },
            ),
            const Divider(color: AppColors.outline),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: AppColors.onSurface),
              title: const Text('Paramètres de l\'application', style: TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _currentIndex = 4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Dissocier cette boutique', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authServiceProvider).logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthLandingScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 6),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Accueil'),
                _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Ventes'),
                _buildNavItem(2, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Caisse'),
                _buildNavItem(3, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Stocks'),
                _buildNavItem(4, Icons.settings_outlined, Icons.settings_rounded, 'Paramètres'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _navigateToTab(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.brandOrange : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.brandOrange : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
