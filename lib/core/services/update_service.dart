import 'package:flutter/foundation.dart';

/// Information de version et de mise à jour de N'MaShop.
@immutable
class AppVersionInfo {
  const AppVersionInfo({
    required this.currentVersion,
    required this.buildNumber,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  final String currentVersion;
  final String buildNumber;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseNotes;
  final String downloadUrl;
}

/// Service de gestion des mises à jour N'MaShop.
abstract final class UpdateService {
  static const String currentVersion = '1.0.0';
  static const String buildNumber = '2026.1';
  static const String releaseDate = 'Août 2026';

  /// Vérifie l'existence de nouvelles mises à jour (GitHub / API N'MaShop).
  static Future<AppVersionInfo> checkForUpdates() async {
    // Simule une vérification asynchrone rapide hors thread UI
    await Future.delayed(const Duration(milliseconds: 500));

    return const AppVersionInfo(
      currentVersion: currentVersion,
      buildNumber: buildNumber,
      latestVersion: '1.0.0',
      hasUpdate: false,
      releaseNotes: 'N\'MaShop v1.0.0 - Version Officielle Stable\n'
          '• POS & Caisse rapide hors-ligne\n'
          '• Gestion des stocks, alertes & inventaire\n'
          '• Gestion des créances clients & crédits\n'
          '• Rapports d\'activités & sauvegarde SQLite\n'
          '• Contrôle natif fenêtrage desktop (1024x680 min)',
      downloadUrl: 'https://nmashop.app/download',
    );
  }
}
