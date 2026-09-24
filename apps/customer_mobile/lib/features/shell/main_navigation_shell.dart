import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../alerts/presentation/alerts_screen.dart';
import '../auth/data/auth_service.dart';
import '../auth/presentation/auth_landing_screen.dart';
import '../backup/presentation/backup_restore_screen.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../onboarding/presentation/onboarding_screen.dart';
import '../receivables/presentation/receivables_screen.dart';
import '../sales/presentation/sales_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../stock/presentation/stock_screen.dart';
import '../suppliers/presentation/suppliers_screen.dart';
import '../treasury/presentation/treasury_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onNavigateToTab: _navigateToTab,
        onOpenDrawer: _openDrawer,
      ),
      const SalesScreen(),
      const TreasuryScreen(),
      const StockScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header Patron & Boutique
            DrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(
                gradient: AppColors.heroNavyGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: AppColors.brandOrange, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'N\'MaShop Mobile',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Écosystème Commercial Local',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandEmerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: AppColors.brandEmerald),
                        SizedBox(width: 6),
                        Text(
                          'MODE 100% AUTONOME LOCAL',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // SECTION 1 : GESTION COMMERCIALE
            _buildDrawerSectionHeader('GESTION COMMERCIALE'),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: AppColors.brandOrange),
              title: const Text('Ventes & Encaissement POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Comptoir, factures & tickets de caisse', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToTab(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_rounded, color: AppColors.brandEmerald),
              title: const Text('Catalogue & Stocks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Articles, prix & mouvements d\'inventaire', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToTab(3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded, color: AppColors.warning),
              title: const Text('Créances & Clients Débiteurs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Argent dehors & relances règlements', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceivablesScreen()));
              },
            ),

            const Divider(color: AppColors.border, height: 24),

            // SECTION 2 : FINANCES & LOGISTIQUE
            _buildDrawerSectionHeader('FINANCES & LOGISTIQUE'),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.brandNavy),
              title: const Text('Caisse & Trésorerie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Solde théorique & saisie des dépenses', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToTab(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_rounded, color: Color(0xFF6366F1)),
              title: const Text('Fournisseurs & Achats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Approvisionnements & dettes grossistes', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuppliersScreen()));
              },
            ),

            const Divider(color: AppColors.border, height: 24),

            // SECTION 3 : SYSTÈME & OUTILS PATRON
            _buildDrawerSectionHeader('SYSTÈME & CONFIGURATION'),
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded, color: AppColors.error),
              title: const Text('Centre d\'Alertes & Ruptures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Notifications de stock min & caisse', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup_rounded, color: Color(0xFF0EA5E9)),
              title: const Text('Sauvegarde & Restauration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Exportation SQLite locale sécurisée', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupRestoreScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded, color: Color(0xFF64748B)),
              title: const Text('Paramètres de la boutique', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Informations, devise & code PIN', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToTab(4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded, color: AppColors.brandEmerald),
              title: const Text('Guide Commercial Onboarding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Présentation des 5 piliers N\'MaShop', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
              },
            ),

            const Divider(color: AppColors.border, height: 24),

            // Déconnexion
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Se déconnecter de la boutique', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
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
            const SizedBox(height: 16),
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

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _navigateToTab(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandOrange.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.brandOrange : const Color(0xFF64748B),
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.brandOrange : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
