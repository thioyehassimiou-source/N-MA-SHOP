import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/license/license_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licensesAsync = ref.watch(adminLicensesStreamProvider);
    final clientsAsync = ref.watch(adminClientsStreamProvider);
    final localLicense = ref.watch(licenseProvider);

    final licenses = licensesAsync.value ?? [];
    final clients = clientsAsync.value ?? [];

    final activeCount = licenses.where((l) => l.status == 'active').length;
    final expiredCount = licenses.where((l) => l.status == 'expired').length;
    final cancelledCount = licenses.where((l) => l.status == 'cancelled').length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B); // Slate 500
    final alertBgOrange = isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.08) : const Color(0xFFFEF3C7);
    final alertBorderOrange = isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.25) : const Color(0xFFFDE68A);
    final alertBgRed = isDark ? const Color(0xFFEF4444).withValues(alpha: 0.08) : const Color(0xFFFEE2E2);
    final alertBorderRed = isDark ? const Color(0xFFEF4444).withValues(alpha: 0.25) : const Color(0xFFFECACA);

    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by shell
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const _AdminPageHeader(
              title: 'Dashboard',
              subtitle: 'Vue globale de votre parc de licences N\'MaShop',
              icon: Icons.dashboard_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Metric cards
            Row(
              children: [
                _AdminMetricCard(
                  label: 'Clients',
                  value: clients.length.toString(),
                  icon: Icons.people_rounded,
                  gradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                const SizedBox(width: AppSpacing.md),
                _AdminMetricCard(
                  label: 'Licences Actives',
                  value: activeCount.toString(),
                  icon: Icons.check_circle_rounded,
                  gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                ),
                const SizedBox(width: AppSpacing.md),
                _AdminMetricCard(
                  label: 'Licences Expirées',
                  value: expiredCount.toString(),
                  icon: Icons.access_time_rounded,
                  gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                const SizedBox(width: AppSpacing.md),
                _AdminMetricCard(
                  label: 'Licences Annulées',
                  value: cancelledCount.toString(),
                  icon: Icons.cancel_rounded,
                  gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Statut de l'instance locale
            _AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.computer_rounded, size: 18, color: textPrimary),
                      const SizedBox(width: 10),
                      Text(
                        'Cette instance N\'MaShop (Locale)',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (localLicense.isLicensed ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          localLicense.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: localLicense.isLicensed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (localLicense.key != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Clé activée : ${localLicense.key}',
                      style: TextStyle(color: textSecondary, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Licences expirant bientôt
            _AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_rounded, size: 18, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 10),
                      Text(
                        'Licences expirant dans les 30 prochains jours',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  licensesAsync.when(
                    data: (_) {
                      final now = DateTime.now();
                      final soon = now.add(const Duration(days: 30));
                      final expiringSoon = licenses.where((l) =>
                        l.status == 'active' &&
                        l.expiresAt != null &&
                        l.expiresAt!.year < 9999 &&
                        l.expiresAt!.isBefore(soon) &&
                        l.expiresAt!.isAfter(now),
                      ).toList();

                      if (expiringSoon.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: Text(
                              '✅ Aucune licence n\'expire prochainement.',
                              style: TextStyle(color: textSecondary, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: expiringSoon.map((lic) {
                          final client = clients.where((c) => c.id == lic.adminClientId).firstOrNull;
                          final daysLeft = lic.expiresAt!.difference(now).inDays;
                          final isUrgent = daysLeft <= 7;
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isUrgent ? alertBgRed : alertBgOrange,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isUrgent ? alertBorderRed : alertBorderOrange,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isUrgent ? Icons.warning_rounded : Icons.access_time_rounded,
                                  size: 16,
                                  color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client?.name ?? 'Client inconnu',
                                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      Text(
                                        lic.licenseKey,
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isUrgent
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'J-$daysLeft',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets privés ────────────────────────────────────────────────────────────

class _AdminPageHeader extends StatelessWidget {
  const _AdminPageHeader({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.dashboard_rounded, color: Color(0xFF818CF8), size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                color: textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}
