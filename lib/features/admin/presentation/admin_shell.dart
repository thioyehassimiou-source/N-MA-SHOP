import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/theme_provider.dart';
import '../application/admin_auth_provider.dart';
import '../application/admin_providers.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final licensesAsync = ref.watch(adminLicensesStreamProvider);
    final clientsAsync = ref.watch(adminClientsStreamProvider);

    final licenseCount = licensesAsync.value?.length ?? 0;
    final clientCount = clientsAsync.value?.length ?? 0;

    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.admin_panel_settings, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'N\'MaShop Admin',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Backoffice v1',
                            style: TextStyle(color: textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(color: borderColor),
                ),

                const SizedBox(height: 8),

                // Nav Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      _NavItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        isSelected: location == '/admin/dashboard',
                        onTap: () => context.go('/admin/dashboard'),
                        isDark: isDark,
                      ),
                      _NavItem(
                        icon: Icons.vpn_key_rounded,
                        label: 'Licences',
                        badge: licenseCount > 0 ? licenseCount.toString() : null,
                        isSelected: location.startsWith('/admin/licenses'),
                        onTap: () => context.go('/admin/licenses'),
                        isDark: isDark,
                      ),
                      _NavItem(
                        icon: Icons.people_rounded,
                        label: 'Clients',
                        badge: clientCount > 0 ? clientCount.toString() : null,
                        isSelected: location.startsWith('/admin/clients'),
                        onTap: () => context.go('/admin/clients'),
                        isDark: isDark,
                      ),
                      _NavItem(
                        icon: Icons.build_rounded,
                        label: 'Maintenance',
                        isSelected: location.startsWith('/admin/maintenance'),
                        onTap: () => context.go('/admin/maintenance'),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                // Retour boutique & Thème
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Divider(color: borderColor),
                      const SizedBox(height: 8),
                      // Thème Toggle
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => ref.read(themeProvider.notifier).toggle(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 16, color: textSecondary),
                                const SizedBox(width: 10),
                                Text(
                                  isDark ? 'Mode Clair' : 'Mode Sombre',
                                  style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            ref.read(adminAuthProvider.notifier).logout();
                            context.go('/');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_back_ios_rounded, size: 16, color: textSecondary),
                                const SizedBox(width: 10),
                                Text(
                                  'Retour à la boutique',
                                  style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: bgColor,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.4) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF818CF8) : textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? textPrimary : textSecondary,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
