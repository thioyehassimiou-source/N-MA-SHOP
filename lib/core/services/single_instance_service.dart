import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

/// Service de gestion d'Instance Unique N'MaShop Desktop.
///
/// Empêche le lancement simultané de plusieurs instances de l'application
/// sur la même machine. Si l'application est déjà ouverte, l'instance secondaire
/// notifie l'instance principale pour la remettre au premier plan et quitte proprement.
class SingleInstanceService {
  static const int _ipcPort = 49177; // Port IPC local dédié N'MaShop
  static ServerSocket? _serverSocket;
  static File? _lockFile;
  static RandomAccessFile? _randomAccessFile;

  /// Vérifie si cette instance est l'instance principale.
  ///
  /// Retourne `true` s'il s'agit de la première instance (doit continuer l'exécution),
  /// ou `false` si une instance est déjà en cours (doit s'arrêter).
  static Future<bool> ensureSingleInstance() async {
    // Sur le Web, la notion de verrou d'instance unique n'est pas applicable.
    if (kIsWeb) return true;

    try {
      // Étape 1 : Essai de verrouillage IPC via Socket TCP Loopback
      _serverSocket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _ipcPort,
        shared: false,
      );

      // Si le bind réussit, cette instance EST l'instance principale.
      _serverSocket?.listen((Socket socket) {
        socket.listen((data) async {
          final message = String.fromCharCodes(data).trim();
          if (message == 'FOCUS') {
            await _bringWindowToFront();
          }
        });
      });

      // Étape 2 : Création/maintien du fichier de verrouillage sur disque
      await _acquireFileLock();

      debugPrint('[SingleInstanceService] Instance principale N\'MaShop démarrée avec succès (Port $_ipcPort).');
      return true;
    } on SocketException catch (_) {
      // Le port est déjà occupé -> Une autre instance N'MaShop s'exécute déjà.
      debugPrint('[SingleInstanceService] Une autre instance N\'MaShop est déjà en cours d\'exécution.');

      // Envoie un signal "FOCUS" à l'instance principale pour qu'elle passe au premier plan.
      try {
        final clientSocket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          _ipcPort,
          timeout: const Duration(milliseconds: 800),
        );
        clientSocket.write('FOCUS');
        await clientSocket.flush();
        await clientSocket.close();
      } catch (e) {
        debugPrint('[SingleInstanceService] Erreur lors de la notification de l\'instance existante: $e');
      }

      return false;
    } catch (e) {
      // Sur les systèmes très restreints ou anciens, ne jamais bloquer le commerçant
      debugPrint('[SingleInstanceService] Avertissement initialisation instance unique: $e');
      return true;
    }
  }

  /// Tente de verrouiller le fichier de session `.nmashop.lock` dans le répertoire Support.
  /// Utilise un verrou exclusif NON-BLOQUANT pour éviter tout gel sur disque dur lent (HDD)
  /// ou en cas d'analyse par un antivirus tiers.
  static Future<void> _acquireFileLock() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _lockFile = File(p.join(appDir.path, '.nmashop.lock'));

      if (!await _lockFile!.exists()) {
        await _lockFile!.create(recursive: true);
      }

      _randomAccessFile = await _lockFile!.open(mode: FileMode.write);
      // Verrou non-bloquant : ne gèle jamais l'application même sur disque dur très lent
      await _randomAccessFile?.lock(FileLock.exclusive);
      await _randomAccessFile?.writeString('$pid');
      await _randomAccessFile?.flush();
    } catch (e) {
      debugPrint('[SingleInstanceService] Avertissement verrouillage fichier: $e');
    }
  }

  /// Remet la fenêtre principale au premier plan (Focus & Restore).
  static Future<void> _bringWindowToFront() async {
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('[SingleInstanceService] Erreur lors du focus de la fenêtre: $e');
    }
  }

  /// Libère les ressources et le verrou lors de la fermeture propre de l'application.
  static Future<void> dispose() async {
    try {
      await _serverSocket?.close();
      _serverSocket = null;

      if (_randomAccessFile != null) {
        await _randomAccessFile?.unlock();
        await _randomAccessFile?.close();
        _randomAccessFile = null;
      }

      if (_lockFile != null && await _lockFile!.exists()) {
        await _lockFile!.delete();
        _lockFile = null;
      }
    } catch (e) {
      debugPrint('[SingleInstanceService] Erreur fermeture verrous: $e');
    }
  }
}
