import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/license/license_model.dart';
import '../../core/license/license_provider.dart';
import '../../core/license/presentation/activate_license_dialog.dart';
import '../../core/license/presentation/pos_locked_screen.dart';
import '../../core/theme/app_colors.dart';
import '../alerts/presentation/alerts_screen.dart';
import '../auth/data/auth_service.dart';
import '../auth/presentation/auth_landing_screen.dart';
import '../backup/presentation/backup_restore_screen.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../onboarding/presentation/onboarding_screen.dart';
import '../receivables/presentation/receivables_screen.dart';
import '../sales/presentation/sales_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../settings/presentation/shop_profile_provider.dart';
import '../settings/presentation/widgets/edit_shop_profile_sheet.dart';
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
    final license = ref.watch(licenseInfoProvider);
    final profile = ref.watch(shopProfileProvider);

    final screens = [
      DashboardScreen(
        onNavigateToTab: _navigateToTab,
        onOpenDrawer: _openDrawer,
      ),
      // Si la période d'essai est expirée (0 jour), verrouiller la caisse POS
      license.isPosUnlocked ? const SalesScreen() : const PosLockedActivationScreen(),
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
            // ── HEADER N'MASHOP & BOUTIQUE DYNAMIQUE ──
            DrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(
                gradient: AppColors.heroNavyGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      EditShopProfileSheet.show(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        // Logo Boutique réel ou Icône Store
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.5)),
                            image: (profile.logoPath != null && File(profile.logoPath!).existsSync())
                                ? DecorationImage(
                                    image: FileImage(File(profile.logoPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (profile.logoPath == null || !File(profile.logoPath!).existsSync())
                              ? const Icon(Icons.storefront_rounded, color: AppColors.brandOrange, size: 26)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.shopName,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${profile.managerName}${profile.phoneNumber.isNotEmpty ? " • ${profile.phoneNumber}" : ""}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_outlined, color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── BANNIÈRE COMPTE À REBOURS DE LICENCE DYNAMIQUE ──
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      ActivateLicenseDialog.show(
                        context,
                        deviceId: license.deviceId,
                        shopName: profile.shopName,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: license.isPosUnlocked
                            ? (license.isCommercial
                                ? AppColors.brandEmerald.withValues(alpha: 0.25)
                                : const Color(0xFFFEF3C7).withValues(alpha: 0.95))
                            : AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: license.isPosUnlocked
                              ? (license.isCommercial ? AppColors.brandEmerald : const Color(0xFFF59E0B))
                              : AppColors.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            license.isPosUnlocked
                                ? (license.isCommercial ? Icons.verified_rounded : Icons.hourglass_top_rounded)
                                : Icons.lock_clock_rounded,
                            size: 13,
                            color: license.isPosUnlocked
                                ? (license.isCommercial ? Colors.white : const Color(0xFFB45309))
                                : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              license.bannerText,
                              style: TextStyle(
                                color: license.isPosUnlocked
                                    ? (license.isCommercial ? Colors.white : const Color(0xFF92400E))
                                    : AppColors.error,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
              subtitle: Text(
                license.isPosUnlocked ? 'Comptoir, factures & tickets de caisse' : 'Caisse verrouillée (Licence requise)',
                style: TextStyle(
                  fontSize: 11,
                  color: license.isPosUnlocked ? AppColors.onSurfaceVariant : AppColors.error,
                ),
              ),
              trailing: license.isPosUnlocked
                  ? null
                  : const Icon(Icons.lock_rounded, size: 16, color: AppColors.error),
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

            // SECTION 3 : SYSTÈME & CONFIGURATION
            _buildDrawerSectionHeader('SYSTÈME & CONFIGURATION'),
            ListTile(
              leading: const Icon(Icons.verified_user_rounded, color: AppColors.brandOrange),
              title: Text(
                license.isCommercial ? 'Licence Commerciale Active' : 'Activer ma Licence N\'MaShop',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                license.bannerText,
                style: TextStyle(
                  fontSize: 11,
                  color: license.isPosUnlocked ? AppColors.brandEmerald : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                ActivateLicenseDialog.show(
                  context,
                  deviceId: license.deviceId,
                  shopName: profile.shopName,
                );
              },
            ),
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
              subtitle: const Text('Profil, identité, devise & code PIN', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
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
