import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Utilitaire de sélection d'images cross-plateforme (Desktop Linux/Windows/macOS & Mobile).
class AppImagePicker {
  /// Sélectionne une image (produit, logo, avatar) et la sauvegarde dans le stockage permanent.
  /// [folderName] définit le sous-dossier d'enregistrement (ex: 'product_images', 'logos').
  static Future<String?> pickAndSaveImage({
    required String folderName,
    String? filePrefix,
  }) async {
    try {
      String? sourcePath;

      // 1. Essayer avec FilePicker (extrêmement fiable sur Desktop Linux/Windows/macOS)
      try {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
        );
        if (result.isNotEmpty && result.first.path != null) {
          sourcePath = result.first.path;
        }
      } catch (_) {
        // Fallback sur ImagePicker si FilePicker échoue
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          sourcePath = picked.path;
        }
      }

      if (sourcePath == null || sourcePath.isEmpty) return null;

      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) return null;

      // 2. Préparer le dossier cible dans les documents de l'application
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(appDir.path, folderName));
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      // 3. Copier le fichier avec un nom unique
      final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.png';
      final prefix = filePrefix ?? folderName;
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destinationPath = p.join(targetDir.path, fileName);

      final savedFile = await sourceFile.copy(destinationPath);
      return savedFile.path;
    } catch (e) {
      rethrow;
    }
  }

  /// Alias spécifique pour les images de produits.
  static Future<String?> pickProductImage() {
    return pickAndSaveImage(
      folderName: 'product_images',
      filePrefix: 'product',
    );
  }

  /// Alias spécifique pour les logos de boutique.
  static Future<String?> pickLogoImage() {
    return pickAndSaveImage(
      folderName: 'logos',
      filePrefix: 'logo',
    );
  }

  /// Alias spécifique pour les photos de profil.
  static Future<String?> pickAvatarImage(String userId) {
    return pickAndSaveImage(
      folderName: 'avatars',
      filePrefix: 'avatar_$userId',
    );
  }
}
