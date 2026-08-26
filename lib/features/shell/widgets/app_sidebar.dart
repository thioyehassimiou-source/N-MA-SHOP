import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import '../../../core/providers/app_settings_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../stock/application/stock_providers.dart';


// ── Couleurs de marque N'MaShop (Sidebar fixes) ──────────────────────────────
const _kNavy = Color(0xFF0F1B3D);
const _kNavyDark = Color(0xFF0D1830);
const _kOrange = Color(0xFFE85D04);
const _kOrangeLight = Color(0xFFFF7A2A);
const _kBlueText = Color(0xFF8899BB);
const _kSectionLabel = Color(0xFF5570A0);

class NavDestination {
  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    this.iconSelected,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData? iconSelected;
}

const _mainDestinations = <NavDestination>[
  NavDestination(
    path: '/',
    label: 'Tableau de bord',
    icon: Icons.dashboard_outlined,
    iconSelected: Icons.dashboard_rounded,
  ),
  NavDestination(
    path: '/vendre',
    label: 'Vente',
    icon: Icons.shopping_cart_outlined,
    iconSelected: Icons.shopping_cart_rounded,
  ),
  NavDestination(
    path: '/commandes',
    label: 'Commandes',
    icon: Icons.notifications_none_rounded,
    iconSelected: Icons.notifications_rounded,
  ),
  NavDestination(
    path: '/caisse',
    label: 'Caisse',
    icon: Icons.account_balance_wallet_outlined,
    iconSelected: Icons.account_balance_wallet_rounded,
  ),
  NavDestination(
    path: '/devis',
    label: 'Devis & Factures',
    icon: Icons.receipt_long_outlined,
    iconSelected: Icons.receipt_long_rounded,
  ),
  NavDestination(
    path: '/produits',
    label: 'Stock',
    icon: Icons.inventory_2_outlined,
    iconSelected: Icons.inventory_2_rounded,
  ),
  NavDestination(
    path: '/clients',
    label: 'Clients',
    icon: Icons.people_outline_rounded,
    iconSelected: Icons.people_rounded,
  ),
  NavDestination(
    path: '/credits',
    label: 'Crédits',
    icon: Icons.credit_card_outlined,
    iconSelected: Icons.credit_card_rounded,
  ),
  NavDestination(
    path: '/livraisons',
    label: 'Livraisons',
    icon: Icons.local_shipping_outlined,
    iconSelected: Icons.local_shipping_rounded,
  ),
  NavDestination(
    path: '/livreurs',
    label: 'Livreurs',
    icon: Icons.sports_motorsports_outlined,
    iconSelected: Icons.sports_motorsports_rounded,
  ),
  NavDestination(
    path: '/fournisseurs',
    label: 'Fournisseurs',
    icon: Icons.storefront_outlined,
    iconSelected: Icons.storefront_rounded,
  ),
  NavDestination(
    path: '/depenses',
    label: 'Dépenses',
    icon: Icons.money_off_outlined,
    iconSelected: Icons.money_off_rounded,
  ),
  NavDestination(
    path: '/rapports',
    label: 'Rapports',
    icon: Icons.bar_chart_outlined,
    iconSelected: Icons.bar_chart_rounded,
  ),
  NavDestination(
    path: '/equipe',
    label: 'Équipe',
    icon: Icons.badge_outlined,
    iconSelected: Icons.badge_rounded,
  ),
  NavDestination(
    path: '/reglages',
    label: 'Paramètres',
    icon: Icons.settings_outlined,
    iconSelected: Icons.settings_rounded,
  ),
];

class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final settings = ref.watch(appSettingsProvider);
    final user = ref.watch(authProvider);
    final useCustom = settings.useCustomTheme;
    final colors = Theme.of(context).colorScheme;

    // Définition des couleurs selon le mode
    final sidebarBg = useCustom ? colors.surface : null;
    final sidebarBorder = useCustom ? colors.outlineVariant : Colors.white.withValues(alpha: 0.08);
    final logoBg = useCustom ? colors.primaryContainer : _kOrange;
    final logoShadow = useCustom ? colors.primary.withValues(alpha: 0.2) : _kOrange.withValues(alpha: 0.4);
    final logoIcon = useCustom ? colors.primary : Colors.white;
    final titleColor = useCustom ? colors.onSurface : Colors.white;
    final subtitleColor = useCustom ? colors.onSurfaceVariant : _kBlueText;

    bool isActive(String path) =>
        path == '/' ? location == '/' : location.startsWith(path);
        
    final destinations = _mainDestinations.where((d) {
      if (d.path == '/equipe' && user?.role.name == 'cashier') {
        return false;
      }
      return true;
    }).toList();

    return Container(
      width: 240,
      decoration: useCustom
          ? BoxDecoration(
              color: sidebarBg,
              border: Border(right: BorderSide(color: sidebarBorder, width: 1)),
            )
          : const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_kNavy, _kNavyDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x50000000),
                  blurRadius: 20,
                  offset: Offset(4, 0),
                ),
              ],
            ),
      child: Column(
        children: [
          // ── Logo & Marque ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: sidebarBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: settings.logoPath != null ? logoBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    image: settings.logoPath != null
                        ? DecorationImage(
                            image: FileImage(File(settings.logoPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: settings.logoPath != null
                        ? [
                            BoxShadow(
                              color: logoShadow,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: settings.logoPath == null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/nmashop_logo_official.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                color: logoIcon,
                                size: 22,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.businessName.isNotEmpty
                            ? settings.businessName
                            : "N'MA Shop",
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'GÉRER • VENDRE • GRANDIR',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Navigation ─────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: 'MENU PRINCIPAL'),
                  for (final d in _mainDestinations.take(5))
                    if (destinations.contains(d))
                      _NavItem(destination: d, active: isActive(d.path)),
                  const SizedBox(height: 4),
                  const _SectionLabel(label: 'GESTION'),
                  for (final d in _mainDestinations.skip(5).take(5))
                    if (destinations.contains(d))
                      _NavItem(destination: d, active: isActive(d.path)),
                  const SizedBox(height: 4),
                  const _SectionLabel(label: 'OUTILS'),
                  for (final d in _mainDestinations.skip(10))
                    if (destinations.contains(d))
                      _NavItem(destination: d, active: isActive(d.path)),
                ],
              ),
            ),
          ),
          // ── Profil ─────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: const _SidebarProfile(),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends ConsumerWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCustom = ref.watch(appSettingsProvider).useCustomTheme;
    final color = useCustom
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
        : _kSectionLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _SidebarProfile extends ConsumerWidget {
  const _SidebarProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final settings = ref.watch(appSettingsProvider);
    final useCustom = settings.useCustomTheme;
    final colors = Theme.of(context).colorScheme;

    final bgColor = useCustom ? colors.primaryContainer : _kOrange.withValues(alpha: 0.2);
    final borderColor = useCustom ? colors.primary.withValues(alpha: 0.3) : _kOrange.withValues(alpha: 0.5);
    final initialColor = useCustom ? colors.primary : _kOrangeLight;
    final nameColor = useCustom ? colors.onSurface : Colors.white;
    final roleColor = useCustom ? colors.onSurfaceVariant : _kBlueText;
    final logoutColor = useCustom ? colors.onSurfaceVariant : Colors.white.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: () => context.go('/reglages'),
        borderRadius: BorderRadius.circular(10),
        hoverColor: useCustom ? colors.onSurface.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    user?.initials ?? '?',
                    style: TextStyle(
                      color: initialColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Boutiquier',
                      style: TextStyle(
                        color: nameColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user?.role.name == 'admin' ? 'Administrateur' : 'Vendeur',
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => ref.read(authProvider.notifier).lock(),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.logout_rounded,
                    color: logoutColor,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({required this.destination, required this.active});

  final NavDestination destination;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final useCustom = settings.useCustomTheme;
    final colors = Theme.of(context).colorScheme;

    final hoverColor = useCustom ? colors.onSurface.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06);
    final splashColor = useCustom ? colors.primary.withValues(alpha: 0.1) : _kOrange.withValues(alpha: 0.15);
    final activeBgColor = useCustom ? colors.primaryContainer.withValues(alpha: 0.6) : _kOrange.withValues(alpha: 0.15);
    final activeBorderColor = useCustom ? colors.primary.withValues(alpha: 0.2) : _kOrange.withValues(alpha: 0.3);
    final indicatorColor = useCustom ? colors.primary : _kOrange;
    final iconColorActive = useCustom ? colors.primary : _kOrange;
    final iconColorInactive = useCustom ? colors.onSurfaceVariant : const Color(0xFF8899BB);
    final textColorActive = useCustom ? colors.primary : Colors.white;
    final textColorInactive = useCustom ? colors.onSurface : const Color(0xFFAABBCC);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => context.go(destination.path),
          borderRadius: BorderRadius.circular(8),
          hoverColor: hoverColor,
          splashColor: splashColor,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? activeBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: active
                  ? Border.all(
                      color: activeBorderColor,
                      width: 1,
                    )
                  : Border.all(color: Colors.transparent, width: 1),
            ),
            child: Row(
              children: [
                // Indicateur de barre active
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 3,
                  height: active ? 20 : 0,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: active ? 10 : 0),
                Icon(
                  active
                      ? (destination.iconSelected ?? destination.icon)
                      : destination.icon,
                  color: active ? iconColorActive : iconColorInactive,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w600 : (useCustom ? FontWeight.w500 : FontWeight.w400),
                      color: active ? textColorActive : textColorInactive,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Badge alerte stock bas
                if (destination.path == '/produits')
                  _LowStockBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Badge Alerte Stock ─────────────────────────────────────────────────────
class _LowStockBadge extends ConsumerWidget {
  const _LowStockBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(lowStockCountProvider);
    if (count == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
