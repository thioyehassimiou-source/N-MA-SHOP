import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/tables/audit_logs.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../application/security_providers.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.containerMax,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: 'Journal d\'Activité',
                  subtitle: 'Historique des actions critiques (Réservé aux administrateurs)',
                  icon: Icons.security_outlined,
                  gradientColors: const [Color(0xFF0F1B3D), Color(0xFF1A2B52)],
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.invalidate(auditLogsProvider),
                      tooltip: 'Rafraîchir',
                    )
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                logsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Text('Erreur : $e', style: TextStyle(color: context.colors.error)),
                    ),
                  ),
                  data: (logs) => _buildLogsTable(context, logs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogsTable(BuildContext context, List<AuditLog> logs) {
    if (logs.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(64),
        child: const Center(child: Text('Aucune action critique enregistrée.')),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('DATE & HEURE')),
            DataColumn(label: Text('UTILISATEUR')),
            DataColumn(label: Text('ACTION')),
            DataColumn(label: Text('DÉTAILS')),
          ],
          rows: logs.map((log) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    formatDateTime(log.date),
                    style: AppTypography.bodySm,
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                        child: Text(
                          log.userName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        log.userName,
                        style: AppTypography.labelMd,
                      ),
                    ],
                  ),
                ),
                DataCell(
                  _buildActionChip(log.actionType),
                ),
                DataCell(
                  Text(
                    log.details,
                    style: AppTypography.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionChip(AuditActionType type) {
    Color color;
    String label;
    IconData icon;

    switch (type) {
      case AuditActionType.saleCancelled:
        color = Colors.red;
        label = 'Annulation Vente';
        icon = Icons.cancel_outlined;
        break;
      case AuditActionType.productDeleted:
      case AuditActionType.expenseDeleted:
      case AuditActionType.purchaseDeleted:
        color = Colors.deepOrange;
        label = 'Suppression';
        icon = Icons.delete_outline;
        break;
      case AuditActionType.productPriceChanged:
        color = Colors.orange;
        label = 'Modification Prix';
        icon = Icons.price_change_outlined;
        break;
      case AuditActionType.cashClosed:
        color = Colors.purple;
        label = 'Clôture Caisse';
        icon = Icons.lock_outline;
        break;
      case AuditActionType.userManaged:
        color = Colors.indigo;
        label = 'Gestion Équipe';
        icon = Icons.manage_accounts_outlined;
        break;
      case AuditActionType.settingsChanged:
        color = Colors.teal;
        label = 'Paramètres Modifiés';
        icon = Icons.settings_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
