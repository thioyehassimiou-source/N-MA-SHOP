import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/license_record.dart';
import '../../core/providers/admin_providers.dart';
import '../../core/theme/app_theme.dart';

class StatisticsDashboardView extends ConsumerWidget {
  const StatisticsDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final licenses = ref.watch(licensesProvider);

    final totalBoutiques = clients.length;
    final totalActive = licenses.where((l) => l.isActive).length;
    final trialCount = licenses.where((l) => l.type == AdminLicenseType.trial).length;
    final totalKeysGenerated = licenses.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Label
          const Text(
            'Statistiques N\'MaShop PC',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Aperçu global de votre parc de caisses et licences',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // 4 Simple KPI Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.05,
            children: [
              // Card 1: Total Boutiques
              _buildKpiCard(
                icon: Icons.storefront_rounded,
                iconColor: AppTheme.primaryIndigo,
                bgColor: AppTheme.primaryLightBg,
                count: '$totalBoutiques',
                label: 'Boutiques Clients',
              ),

              // Card 2: Licences Actives
              _buildKpiCard(
                icon: Icons.verified_rounded,
                iconColor: AppTheme.emeraldActive,
                bgColor: AppTheme.emeraldBg,
                count: '$totalActive',
                label: 'Licences Actives',
              ),

              // Card 3: Licences en Essai
              _buildKpiCard(
                icon: Icons.timer_outlined,
                iconColor: AppTheme.amberTrial,
                bgColor: AppTheme.amberBg,
                count: '$trialCount',
                label: 'En Mode Essai',
              ),

              // Card 4: Total Clés Générées
              _buildKpiCard(
                icon: Icons.key_rounded,
                iconColor: AppTheme.cyanSms,
                bgColor: AppTheme.cyanBg,
                count: '$totalKeysGenerated',
                label: 'Clés Générées',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Summary Info Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderSlate),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.primaryIndigo, size: 24),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Les licences d\'essai de 7 jours sont accordées automatiquement lors du premier lancement de N\'MaShop PC sur l\'ordinateur du client.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: iconColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
