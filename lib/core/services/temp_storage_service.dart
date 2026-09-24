import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service de gestion centralisée des Fichiers Temporaires N'MaShop.
///
/// Garantit un espace temporaire ultra-léger et non-volumineux grâce à :
/// 1. Un quota strict de taille maximale (10 Mo max par défaut).
/// 2. Une purge automatique des fichiers obsolètes (> 2 heures).
/// 3. Une éviction FIFO (suppression des plus anciens) si le quota est approché.
/// 4. Des utilitaires pour supprimer immédiatement un fichier après usage.
class TempStorageService {
  static const String _tempFolderName = '.nmashop_tmp';
  
  /// Plafond de taille maximal strict autorisé pour tout le dossier temporaire (10 Mo).
  static const int maxFolderSizeBytes = 10 * 1024 * 1024; // 10 Mo max
  
  /// Durée de rétention maximale par défaut (2 heures pour éviter toute accumulation).
  static const Duration defaultMaxAge = Duration(hours: 2);

  static Directory? _tempDir;
  static final Set<String> _trackedTempFiles = {};

  /// Initialise le dossier temporaire et purge immédiatement tout fichier
  /// temporaire résiduel ou dépassant le quota.
  static Future<void> initializeAndClean({Duration maxAge = defaultMaxAge}) async {
    if (kIsWeb) return;

    try {
      final appDir = await getApplicationSupportDirectory();
      _tempDir = Directory(p.join(appDir.path, _tempFolderName));

      if (!await _tempDir!.exists()) {
        await _tempDir!.create(recursive: true);
      }

      // Purge des fichiers obsolètes (> 2h)
      await cleanObsoleteTempFiles(maxAge: maxAge);

      // Contrôle strict du quota de taille totale
      await enforceMaxQuota();

      final currentSize = await getTotalTempSize();
      debugPrint('[TempStorageService] Dossier temporaire prêt: ${_tempDir!.path} (Taille: ${(currentSize / 1024).toStringAsFixed(1)} Ko)');
    } catch (e) {
      debugPrint('[TempStorageService] Erreur lors de l\'initialisation du dossier temporaire: $e');
    }
  }

  /// Retourne le dossier temporaire isolé de N'MaShop.
  static Future<Directory> getTempDirectory() async {
    if (_tempDir != null && await _tempDir!.exists()) {
      return _tempDir!;
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      _tempDir = Directory(p.join(appDir.path, _tempFolderName));
      if (!await _tempDir!.exists()) {
        await _tempDir!.create(recursive: true);
      }
      return _tempDir!;
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Calcule la taille totale actuelle en octets du dossier temporaire.
  static Future<int> getTotalTempSize() async {
    try {
      final dir = await getTempDirectory();
      if (!await dir.exists()) return 0;

      int totalBytes = 0;
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          try {
            totalBytes += await entity.length();
          } catch (_) {}
        }
      }
      return totalBytes;
    } catch (_) {
      return 0;
    }
  }

  /// Crée un nouveau fichier temporaire garanti unique avec l'extension spécifiée.
  /// Vérifie et applique immédiatement le quota de taille avant création.
  static Future<File> createTempFile(String extension, {String prefix = 'temp'}) async {
    // Si l'espace temporaire approche du quota, libère de l'espace en amont
    await enforceMaxQuota();

    final dir = await getTempDirectory();
    final cleanExt = extension.startsWith('.') ? extension : '.$extension';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();
    final fileName = '${prefix}_${timestamp}_$randomSuffix$cleanExt';

    final tempFile = File(p.join(dir.path, fileName));
    _trackedTempFiles.add(tempFile.path);
    return tempFile;
  }

  /// Supprime immédiatement et en toute sécurité un fichier temporaire après usage.
  static Future<void> safeDeleteTempFile(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
      _trackedTempFiles.remove(file.path);
    } catch (_) {}
  }

  /// Enregistre un fichier temporaire externe à suivre pour nettoyage.
  static void registerTempFile(String filePath) {
    _trackedTempFiles.add(filePath);
  }

  /// Applique le quota maximal strict de taille.
  /// Si la taille dépasse [maxBytes], les fichiers les plus anciens sont supprimés.
  static Future<void> enforceMaxQuota({int maxBytes = maxFolderSizeBytes}) async {
    try {
      final dir = await getTempDirectory();
      if (!await dir.exists()) return;

      final List<File> files = [];
      int totalSize = 0;

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          try {
            final len = await entity.length();
            totalSize += len;
            files.add(entity);
          } catch (_) {}
        }
      }

      // Si le dossier dépasse le quota autorisé, suppression par ancienneté (FIFO)
      if (totalSize > maxBytes) {
        // Trie par date de modification croissante (plus ancien en premier)
        files.sort((a, b) {
          final statA = a.statSync();
          final statB = b.statSync();
          return statA.modified.compareTo(statB.modified);
        });

        int prunedBytes = 0;
        for (final file in files) {
          try {
            final len = await file.length();
            await file.delete();
            _trackedTempFiles.remove(file.path);
            totalSize -= len;
            prunedBytes += len;

            // Arrête dès qu'on est repassé sous 70% du quota maximal
            if (totalSize <= (maxBytes * 0.7).toInt()) {
              break;
            }
          } catch (_) {}
        }

        if (prunedBytes > 0) {
          debugPrint('[TempStorageService] Quota dépassé : ${(prunedBytes / 1024).toStringAsFixed(1)} Ko purgés automatiquement.');
        }
      }
    } catch (e) {
      debugPrint('[TempStorageService] Erreur lors du contrôle du quota: $e');
    }
  }

  /// Supprime les fichiers temporaires obsolètes plus anciens que [maxAge].
  static Future<void> cleanObsoleteTempFiles({Duration maxAge = defaultMaxAge}) async {
    try {
      final dir = await getTempDirectory();
      if (!await dir.exists()) return;

      final now = DateTime.now();
      int deletedCount = 0;

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > maxAge) {
              await entity.delete();
              _trackedTempFiles.remove(entity.path);
              deletedCount++;
            }
          } catch (_) {}
        }
      }

      if (deletedCount > 0) {
        debugPrint('[TempStorageService] Nettoyé $deletedCount fichier(s) temporaire(s) obsolète(s).');
      }
    } catch (e) {
      debugPrint('[TempStorageService] Erreur lors du nettoyage des fichiers obsolètes: $e');
    }
  }

  /// Vide immédiatement l'intégralité du dossier temporaire N'MaShop.
  static Future<void> clearAllTempFiles() async {
    try {
      final dir = await getTempDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      }
      _trackedTempFiles.clear();
      debugPrint('[TempStorageService] Dossier temporaire entièrement purgé.');
    } catch (e) {
      debugPrint('[TempStorageService] Erreur vidage du dossier temporaire: $e');
    }
  }
}
