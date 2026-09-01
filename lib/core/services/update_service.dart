import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Provider vérifiant automatiquement la version au lancement / ouverture de session
final appVersionCheckProvider = FutureProvider<AppVersionInfo>((ref) async {
  return UpdateService.checkForUpdates();
});

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

  /// GitHub Repository API pour la détection dynamique des Releases
  static const String _releasesApiUrl =
      'https://api.github.com/repos/thioyehassimiou-source/GESCOMPTA/releases/latest';

  /// Vérifie l'existence de nouvelles mises à jour (API GitHub / N'MaShop).
  static Future<AppVersionInfo> checkForUpdates() async {
    try {
      final response = await http
          .get(Uri.parse(_releasesApiUrl))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawTag = data['tag_name'] as String? ?? '1.0.0';
        final latestTag = rawTag.replaceAll(RegExp(r'[^0-9.]'), '');
        final notes = data['body'] as String? ?? 'Une nouvelle version de N\'MaShop est disponible.';
        final htmlUrl = data['html_url'] as String? ??
            'https://github.com/thioyehassimiou-source/GESCOMPTA/releases';

        final hasUpdate = _compareVersions(latestTag, currentVersion) > 0;

        return AppVersionInfo(
          currentVersion: currentVersion,
          buildNumber: buildNumber,
          latestVersion: latestTag,
          hasUpdate: hasUpdate,
          releaseNotes: notes,
          downloadUrl: htmlUrl,
        );
      }
    } catch (_) {
      // Ignorer l'erreur réseau et consommer le statut hors-ligne
    }

    return const AppVersionInfo(
      currentVersion: currentVersion,
      buildNumber: buildNumber,
      latestVersion: currentVersion,
      hasUpdate: false,
      releaseNotes: 'N\'MaShop v1.0.0 - Version Officielle Stable\n'
          '• POS & Caisse rapide hors-ligne\n'
          '• Gestion des stocks, alertes & inventaire\n'
          '• Gestion des créances clients & crédits\n'
          '• Rapports d\'activités & sauvegarde SQLite\n'
          '• Contrôle natif fenêtrage desktop (1024x680 min)',
      downloadUrl: 'https://github.com/thioyehassimiou-source/GESCOMPTA/releases',
    );
  }

  /// Compare deux chaînes de version sémantique (ex: "1.0.1" vs "1.0.0").
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < parts1.length && i < parts2.length; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return parts1.length.compareTo(parts2.length);
  }
}
