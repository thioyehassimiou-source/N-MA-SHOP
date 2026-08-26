import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_providers.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';

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
              tooltip: 'Déconnexion',
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
          // Avatar utilisateur
          InkWell(
            onTap: () => context.go('/reglages'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  user?.initials ?? '?',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
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
