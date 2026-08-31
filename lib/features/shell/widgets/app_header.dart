import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_model.dart';
import '../../../core/license/license_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/widgets/user_profile_dialog.dart';

class AppHeader extends ConsumerWidget {
  const AppHeader({super.key, this.isMobile = false});

  final bool isMobile;

  static const _titles = <String, String>{
    '/': 'Tableau de bord',
    '/vendre': 'Vente',
    '/commandes': 'Commandes',
    '/caisse': 'Caisse & Trésorerie',
    '/devis': 'Devis & Factures',
    '/produits': 'Stock & Produits',
    '/clients': 'Clients',
    '/credits': 'Crédits',
    '/livraisons': 'Livraisons',
    '/livreurs': 'Livreurs',
    '/fournisseurs': 'Fournisseurs',
    '/depenses': 'Dépenses',
    '/rapports': 'Rapports',
    '/equipe': 'Équipe',
    '/reglages': 'Paramètres',
  };

  String _getTitle(String location) {
    if (location == '/') return "Tableau de bord";
    for (final entry in _titles.entries) {
      if (entry.key != '/' && location.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return 'N\'MaShop';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final title = _getTitle(location);
    final user = ref.watch(authProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final license = ref.watch(licenseProvider);

    // Calcul des éléments visuels du badge de licence (Jours restants)
    String badgeText;
    Color badgeBg;
    Color badgeBorder;
    Color badgeTextCol;
    IconData badgeIcon;

    if (license.type == LicenseType.lifetime) {
      badgeText = 'Licence À Vie';
      badgeBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      badgeBorder = const Color(0xFF10B981);
      badgeTextCol = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
      badgeIcon = Icons.verified_rounded;
    } else if (license.daysLeft != null) {
      final days = license.daysLeft!;
      final isTrial = license.status == LicenseStatus.trial;
      badgeText = isTrial ? 'Essai : ${days}j restant${days > 1 ? 's' : ''}' : '${days}j restant${days > 1 ? 's' : ''}';
      if (days <= 3) {
        badgeBg = isDark ? const Color(0xFF881337) : const Color(0xFFFFE4E6);
        badgeBorder = const Color(0xFFF43F5E);
        badgeTextCol = isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239);
        badgeIcon = Icons.warning_amber_rounded;
      } else if (isTrial) {
        badgeBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
        badgeBorder = const Color(0xFFF59E0B);
        badgeTextCol = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
        badgeIcon = Icons.timer_outlined;
      } else {
        badgeBg = isDark ? AppColors.primaryContainer.withValues(alpha: 0.2) : AppColors.primaryContainer;
        badgeBorder = AppColors.primary;
        badgeTextCol = isDark ? AppColors.brandOrangeLight : AppColors.onPrimaryContainer;
        badgeIcon = Icons.vpn_key_rounded;
      }
    } else {
      badgeText = 'Licence Active';
      badgeBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      badgeBorder = AppColors.brandEmerald;
      badgeTextCol = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
      badgeIcon = Icons.check_circle_rounded;
    }

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.md : 28,
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              icon: Icon(Icons.menu_rounded, color: context.colors.onSurface),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          // Titre de la page
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),

          // Badge de Licence (Jours restants / Statut)
          InkWell(
            onTap: () => context.go('/reglages/securite'),
            borderRadius: BorderRadius.circular(12),
            child: Tooltip(
              message: 'Gérer la licence de l\'application',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeBorder.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeTextCol),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeTextCol,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Actions de droite
          if (!isMobile) ...[
            _HeaderAction(
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              tooltip: isDark ? 'Mode clair' : 'Mode sombre',
              onTap: () => ref.read(themeProvider.notifier).toggle(),
            ),
            const SizedBox(width: 4),
            _HeaderAction(
              icon: Icons.help_outline_rounded,
              tooltip: 'Aide',
              onTap: () {
                context.go('/aide');
              },
            ),
            const SizedBox(width: 4),
            _HeaderAction(
              icon: Icons.logout_rounded,
              tooltip: 'Se déconnecter',
              onTap: () => ref.read(authProvider.notifier).lock(),
            ),
            const SizedBox(width: 8),
          ] else ...[
            _HeaderAction(
              icon: Icons.search_rounded,
              tooltip: 'Rechercher',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recherche globale disponible prochainement')),
                );
              },
            ),
          ],
          // Avatar utilisateur avec Menu Profil
          PopupMenuButton<String>(
            tooltip: 'Mon Profil',
            onSelected: (value) {
              if (value == 'profile') {
                UserProfileDialog.show(context);
              } else if (value == 'settings') {
                context.go('/reglages');
              } else if (value == 'logout') {
                ref.read(authProvider.notifier).lock();
              }
            },
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    UserAvatar(
                      user: user,
                      size: 28,
                      fontSize: 11,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(user?.fullName ?? 'Mon Profil', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Text('Gérer mon compte & profil', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Paramètres boutique'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.brandRed),
                    SizedBox(width: 10),
                    Text('Se déconnecter', style: TextStyle(color: AppColors.brandRed)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    user: user,
                    size: 28,
                    fontSize: 11,
                  ),
                  if (!isMobile && user?.fullName != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      user!.fullName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: context.colors.onSurfaceVariant),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
