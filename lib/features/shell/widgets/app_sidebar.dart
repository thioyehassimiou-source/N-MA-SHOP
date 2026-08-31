import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/widgets/user_profile_dialog.dart';
import '../../stock/application/stock_providers.dart';


// ── Couleurs de marque et sous-éléments ──────────────────────────────
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
    final palette = ref.watch(paletteProvider);

    // Définition des couleurs thématiques selon la palette active
    final logoIcon = palette.highlightColor;
    const titleColor = Colors.white;
    const subtitleColor = _kBlueText;

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.darkSidebarTop, palette.darkSidebarBottom],
        ),
        boxShadow: const [
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
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppImage(
                    imagePath: settings.logoPath != null && settings.logoPath!.isNotEmpty
                        ? settings.logoPath
                        : 'assets/images/nmashop_logo_official.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.storefront_rounded,
                    fallbackColor: logoIcon,
                  ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: _kSectionLabel,
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
    final palette = ref.watch(paletteProvider);
    final highlight = palette.highlightColor;

    final bgColor = highlight.withValues(alpha: 0.2);
    final borderColor = highlight.withValues(alpha: 0.5);
    final initialColor = highlight == const Color(0xFF1E293B) ? const Color(0xFFFFDBC7) : highlight;
    const nameColor = Colors.white;
    const roleColor = _kBlueText;
    final logoutColor = Colors.white.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: () => UserProfileDialog.show(context),
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              UserAvatar(
                user: user,
                size: 36,
                backgroundColor: bgColor,
                foregroundColor: initialColor,
                borderRadius: BorderRadius.circular(10),
                borderColor: borderColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Boutiquier',
                      style: const TextStyle(
                        color: nameColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user?.role.name == 'admin' ? 'Administrateur' : 'Vendeur',
                      style: const TextStyle(
                        color: roleColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Se déconnecter',
                child: InkWell(
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
    final palette = ref.watch(paletteProvider);
    final highlight = palette.highlightColor;

    final hoverColor = Colors.white.withValues(alpha: 0.06);
    final splashColor = highlight.withValues(alpha: 0.15);
    final activeBgColor = highlight.withValues(alpha: 0.18);
    final activeBorderColor = highlight.withValues(alpha: 0.35);
    final indicatorColor = highlight;
    final iconColorActive = highlight;
    const iconColorInactive = Color(0xFF8899BB);
    const textColorActive = Colors.white;
    const textColorInactive = Color(0xFFAABBCC);

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
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
