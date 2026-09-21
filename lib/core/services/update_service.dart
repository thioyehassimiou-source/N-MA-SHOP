import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

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
  static const String currentVersion = '1.1.6';
  static const String buildNumber = '2026.1';
  static const String releaseDate = 'Septembre 2026';

  /// GitHub Repository API pour la détection dynamique des Releases
  static const String _releasesApiUrl =
      'https://api.github.com/repos/thioyehassimiou-source/N-MA-SHOP/releases/latest';

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
        final rawNotes = data['body'] as String? ?? 'Une nouvelle version de N\'MaShop est disponible.';
        final cleanNotes = formatCleanNotes(rawNotes);
        final htmlUrl = data['html_url'] as String? ??
            'https://github.com/thioyehassimiou-source/N-MA-SHOP/releases';
        String downloadUrl = htmlUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          for (final asset in assets) {
            final assetName = (asset['name'] as String? ?? '').toLowerCase();
            if (assetName.contains('installer') || assetName.contains('setup') || assetName.endsWith('.zip') || assetName.endsWith('.exe')) {
              downloadUrl = asset['browser_download_url'] as String? ?? htmlUrl;
              break;
            }
          }
        }

        final hasUpdate = _compareVersions(latestTag, currentVersion) > 0;

        return AppVersionInfo(
          currentVersion: currentVersion,
          buildNumber: buildNumber,
          latestVersion: latestTag,
          hasUpdate: hasUpdate,
          releaseNotes: cleanNotes,
          downloadUrl: downloadUrl,
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
      releaseNotes: '• Améliorations générales et optimisations de performances.\n'
          '• Fonctionnement 100% hors-ligne & Caisse POS.\n'
          '• Gestion des stocks, créances & rapports.',
      downloadUrl: 'https://github.com/thioyehassimiou-source/N-MA-SHOP/releases',
    );
  }

  /// Nettoie les notes de version brutes de GitHub pour afficher un texte simple et lisible pour le client commercial
  static String formatCleanNotes(String rawNotes) {
    if (rawNotes.isEmpty) return '• Nouveautés et améliorations de performances.';
    final lines = rawNotes.split('\n');
    final cleanLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#') ||
          trimmed.contains('github.com') ||
          trimmed.contains('http') ||
          trimmed.contains('AOT') ||
          trimmed.contains('SQLite') ||
          trimmed.contains('HMAC') ||
          trimmed.contains('Installeur') ||
          trimmed.contains('Archive') ||
          trimmed.contains('Développeur')) {
        continue;
      }
      var text = trimmed.replaceAll(RegExp(r'[\*\_\#\=\-\`]'), '').trim();
      if (text.isNotEmpty) {
        cleanLines.add('• $text');
      }
    }
    if (cleanLines.isEmpty) {
      return '• Améliorations de performances et corrections d\'erreurs.';
    }
    return cleanLines.take(4).join('\n');
  }

  /// Télécharge la mise à jour en arrière-plan avec suivi de la progression (0.0 à 1.0),
  /// puis exécute l'installeur automatiquement sans que le client n'ait à quitter son application ni voir de pages web.
  static Future<void> downloadAndInstallUpdate(
    String downloadUrl, {
    required void Function(double progress) onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Impossible de télécharger le fichier de mise à jour (code HTTP ${response.statusCode})');
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = Directory.systemTemp;
      final isZip = downloadUrl.toLowerCase().endsWith('.zip');
      final fileName = isZip ? 'NMaShop_Update.zip' : 'NMaShop_Setup.exe';
      final tempFile = File(p.join(tempDir.path, fileName));

      final sink = tempFile.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          onProgress(downloadedBytes / contentLength);
        }
      }
      await sink.close();

      File targetExe = tempFile;

      // Si le fichier téléchargé est une archive ZIP, décompresser l'installeur .exe
      if (isZip) {
        final bytes = await tempFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (file.isFile && (file.name.endsWith('.exe') || file.name.contains('Setup'))) {
            final exePath = p.join(tempDir.path, 'NMaShop_Setup_Extracted.exe');
            final extractedFile = File(exePath);
            await extractedFile.writeAsBytes(file.content as List<int>);
            targetExe = extractedFile;
            break;
          }
        }
      }

      // Lancement automatique et silencieux de l'installeur
      if (Platform.isWindows) {
        // Exécuter l'installeur Windows en mode silencieux (/VERYSILENT /SUPPRESSMSGBOXES /NORESTART)
        await Process.start(
          targetExe.path,
          ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
          mode: ProcessStartMode.detached,
        );
        // Fermer l'application Flutter pour libérer les exécutables et permettre leur remplacement transparent
        exit(0);
      } else if (Platform.isLinux) {
        await Process.start('chmod', ['+x', targetExe.path]);
        await Process.start(targetExe.path, [], mode: ProcessStartMode.detached);
        exit(0);
      }
    } finally {
      client.close();
    }
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
