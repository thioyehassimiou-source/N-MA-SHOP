import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

final alertsDataProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final res = await apiClient.get('/api/v1/mobile/alerts');
    final map = res.data as Map<String, dynamic>;
    return (map['alerts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  Future<void> _ackAlert(WidgetRef ref, BuildContext context, String id) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.post('/api/v1/mobile/alerts/$id/ack');
    ref.invalidate(alertsDataProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NmaMobileAppBar(
        title: 'Notifications & Alertes',
        subtitle: 'Ruptures, échéances & système',
        onLeadingPressed: () => Navigator.of(context).maybePop(),
        leadingIcon: Icons.arrow_back_rounded,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(alertsDataProvider),
          ),
        ],
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Erreur de chargement ($err)', style: const TextStyle(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(alertsDataProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_none, size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('Aucune alerte enregistrée pour le moment.', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(alertsDataProvider),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final isRead = alert['isRead'] ?? false;
                final severity = alert['severity'] ?? 'info';
                final date = DateTime.tryParse(alert['createdAt'] ?? '') ?? DateTime.now();

                final iconColor = severity == 'critical'
                    ? AppColors.error
                    : severity == 'warning'
                        ? AppColors.warning
                        : Colors.blue;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? AppColors.surface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.5),
                      width: isRead ? 1 : 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        severity == 'critical'
                            ? Icons.error
                            : severity == 'warning'
                                ? Icons.warning_rounded
                                : Icons.info,
                        color: iconColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert['title'] ?? 'Alerte',
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alert['message'] ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppFormatters.formatRelativeTime(date),
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        TextButton(
                          onPressed: () => _ackAlert(ref, context, alert['id']),
                          child: const Text('Lu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
