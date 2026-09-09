import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

/// Utilitaire pour ouvrir des URLs de manière fiable sur Desktop (particulièrement Windows)
/// ainsi que sur les plateformes mobiles et web.
abstract final class UrlLauncherHelper {
  /// Ouvre [urlStr] dans le navigateur ou gestionnaire d'application externe.
  ///
  /// Sous **Windows**, utilise `cmd /c start "" <url>` pour garantir l'ouverture
  /// directe sans dépendance sur les canaux Pigeon de Flutter Desktop.
  static Future<bool> openUrl(String urlStr) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('cmd', ['/c', 'start', '', urlStr], runInShell: true);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [urlStr]);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        final result = await Process.run('open', [urlStr]);
        return result.exitCode == 0;
      } else {
        final uri = Uri.parse(urlStr);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        final uri = Uri.parse(urlStr);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }
}
