import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

class SyncFreshnessBadge extends StatelessWidget {
  final DateTime? lastSyncTime;
  final bool isOffline;
  final VoidCallback? onRefresh;

  const SyncFreshnessBadge({
    super.key,
    required this.lastSyncTime,
    required this.isOffline,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isOffline ? AppColors.warning : AppColors.success;
    final statusBg = isOffline ? AppColors.warningContainer : AppColors.successContainer;
    final text = isOffline
        ? 'Hors-ligne • Dernier sync : ${AppFormatters.formatRelativeTime(lastSyncTime)}'
        : 'En ligne • Sync : ${AppFormatters.formatRelativeTime(lastSyncTime)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOffline ? Colors.orange.shade900 : Colors.green.shade900,
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onRefresh,
              child: Icon(
                Icons.refresh_rounded,
                size: 14,
                color: isOffline ? Colors.orange.shade900 : Colors.green.shade900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
