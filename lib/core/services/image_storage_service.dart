import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';

/// Service centralisé de gestion du stockage des images de l'application.
///
/// Garantit que toutes les images (produits, logos, avatars) sont
/// physiquement copiées et gérées dans un répertoire dédié au sein
/// des données de l'application (`getApplicationSupportDirectory()`),
/// évitant toute dépendance à des fichiers externes volatiles (Téléchargements, USB, etc.).
abstract final class ImageStorageService {
  static const String productImagesFolder = 'product_images';
  static const String logosFolder = 'logos';
  static const String avatarsFolder = 'avatars';

  static Directory? _cachedAppDir;

  /// Récupère le répertoire de base des données de l'application.
  static Future<Directory> getAppDirectory() async {
    if (_cachedAppDir != null && _cachedAppDir!.existsSync()) {
      return _cachedAppDir!;
    }
    try {
      _cachedAppDir = await getApplicationSupportDirectory();
    } catch (_) {
      _cachedAppDir = await getApplicationDocumentsDirectory();
    }
    return _cachedAppDir!;
  }

  /// Répertoire dédié aux images de produits (`com.nmashop.nmashop/product_images`).
  static Future<Directory> getProductImagesDirectory() async {
    final appDir = await getAppDirectory();
    final dir = Directory(p.join(appDir.path, productImagesFolder));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Répertoire dédié aux logos de boutique (`com.nmashop.nmashop/logos`).
  static Future<Directory> getLogosDirectory() async {
    final appDir = await getAppDirectory();
    final dir = Directory(p.join(appDir.path, logosFolder));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Répertoire dédié aux avatars utilisateurs (`com.nmashop.nmashop/avatars`).
  static Future<Directory> getAvatarsDirectory() async {
    final appDir = await getAppDirectory();
    final dir = Directory(p.join(appDir.path, avatarsFolder));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Initialise tous les dossiers d'images au démarrage de l'application
  /// et migre automatiquement les anciennes images externes vers le dossier interne.
  static Future<void> initializeStorage({AppDatabase? db}) async {
    try {
      final productDir = await getProductImagesDirectory();
      await getLogosDirectory();
      await getAvatarsDirectory();

      // Migration 1 : Récupérer les images qui étaient dans ~/Documents/product_images/
      await _migrateLegacyDocumentsFolder(productDir);

      // Migration 2 : Mettre à jour la base de données si fournie
      if (db != null) {
        await migrateDatabaseImages(db);
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Erreur initialisation stockage images: $e');
      }
    }
  }

  /// Migre les fichiers de l'ancien dossier `~/Documents/product_images/` vers le dossier interne.
  static Future<void> _migrateLegacyDocumentsFolder(Directory targetDir) async {
    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home == null || home.isEmpty) return;

      final legacyDir = Directory(p.join(home, 'Documents', productImagesFolder));
      if (!legacyDir.existsSync()) return;

      final entities = legacyDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final dest = File(p.join(targetDir.path, p.basename(entity.path)));
          if (!dest.existsSync()) {
            await entity.copy(dest.path);
          }
        }
      }
    } catch (_) {}
  }

  /// Met à jour les chemins des produits en base de données pour qu'ils pointent
  /// tous vers les images copiées dans le dossier officiel de l'application.
  static Future<void> migrateDatabaseImages(AppDatabase db) async {
    try {
      final productDir = await getProductImagesDirectory();
      final allProducts = await db.select(db.products).get();

      for (final product in allProducts) {
        if (product.imageUrl == null || product.imageUrl!.trim().isEmpty) continue;

        final currentPath = product.imageUrl!.trim();
        final fileName = p.basename(currentPath);
        final targetPath = p.join(productDir.path, fileName);
        final targetFile = File(targetPath);

        // Si l'image n'est pas encore dans le dossier officiel
        if (p.normalize(currentPath) != p.normalize(targetPath)) {
          // Si le fichier source d'origine existe, le copier
          final sourceFile = File(currentPath);
          if (sourceFile.existsSync()) {
            if (!targetFile.existsSync()) {
              await sourceFile.copy(targetPath);
            }
            await (db.update(db.products)..where((tbl) => tbl.id.equals(product.id))).write(
              ProductsCompanion(imageUrl: Value(targetPath)),
            );
          } else if (targetFile.existsSync()) {
            // Le fichier cible existe déjà dans product_images, mettre à jour la DB
            await (db.update(db.products)..where((tbl) => tbl.id.equals(product.id))).write(
              ProductsCompanion(imageUrl: Value(targetPath)),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Erreur migration DB images: $e');
      }
    }
  }

  /// Copie n'importe quel fichier source (sélectionné ou importé) directement dans le stockage interne.
  static Future<String> copyImageToAppStorage({
    required File sourceFile,
    required String folderName,
    String? filePrefix,
  }) async {
    final appDir = await getAppDirectory();
    final targetDir = Directory(p.join(appDir.path, folderName));
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    final ext = p.extension(sourceFile.path).isNotEmpty ? p.extension(sourceFile.path) : '.jpg';
    final prefix = filePrefix ?? folderName;
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destinationPath = p.join(targetDir.path, fileName);

    final savedFile = await sourceFile.copy(destinationPath);
    return savedFile.path;
  }

  /// Résout l'accès à un fichier image local, qu'il soit absolu, relatif ou ancien.
  static File? resolveImageFile(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final cleanPath = path.trim();

    // 1. Chemin direct existant
    try {
      final directFile = File(cleanPath);
      if (directFile.existsSync()) {
        return directFile;
      }
    } catch (_) {}

    // 2. Recherche dans les dossiers de l'application via le nom du fichier
    try {
      final fileName = p.basename(cleanPath);
      if (_cachedAppDir != null) {
        // Dans product_images
        final productFile = File(p.join(_cachedAppDir!.path, productImagesFolder, fileName));
        if (productFile.existsSync()) return productFile;

        // Dans logos
        final logoFile = File(p.join(_cachedAppDir!.path, logosFolder, fileName));
        if (logoFile.existsSync()) return logoFile;

        // Dans avatars
        final avatarFile = File(p.join(_cachedAppDir!.path, avatarsFolder, fileName));
        if (avatarFile.existsSync()) return avatarFile;

        // Relatif direct à l'app dir
        final relativeFile = File(p.join(_cachedAppDir!.path, cleanPath));
        if (relativeFile.existsSync()) return relativeFile;
      }
    } catch (_) {}

    // 3. Fallback dossier Documents de l'utilisateur (rétro-compatibilité)
    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        final legacyFile = File(p.join(home, 'Documents', productImagesFolder, p.basename(cleanPath)));
        if (legacyFile.existsSync()) return legacyFile;
      }
    } catch (_) {}

    return null;
  }
}
