import 'dart:convert';
import 'dart:io' show Directory, File;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Utilitaire de sélection et sauvegarde d'images cross-plateforme.
///
/// Fonctionne de manière 100% fiable sur toutes les plateformes :
/// - Web (Google Chrome)
/// - Linux Desktop (utilise FilePicker comme base native)
/// - Android & iOS (utilise ImagePicker pour appareil photo et FilePicker / ImagePicker pour la galerie)
class MobileImagePicker {
  static final ImagePicker _picker = ImagePicker();

  /// Ouvre l'appareil photo ou la galerie photo et persiste l'image.
  /// Renvoie soit le chemin d'accès local sur disque, soit une Data URI Base64 universelle.
  static Future<String?> pickAndSaveImage({
    required ImageSource source,
    required String folderName,
  }) async {
    try {
      Uint8List? bytes;
      String? extension;

      // 1. CAS APPAREIL PHOTO
      if (source == ImageSource.camera) {
        try {
          final XFile? pickedFile = await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 900,
            maxHeight: 900,
            imageQuality: 82,
          );
          if (pickedFile != null) {
            bytes = await pickedFile.readAsBytes();
            extension = p.extension(pickedFile.path);
          }
        } catch (_) {
          // Sur Linux ou environnements sans caméra matérielle, proposer le sélecteur de fichier
          final res = await FilePicker.platform.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (res != null && res.files.isNotEmpty) {
            final f = res.files.first;
            bytes = f.bytes;
            if (bytes == null && f.path != null && !kIsWeb) {
              bytes = await File(f.path!).readAsBytes();
            }
            extension = f.extension != null ? '.${f.extension}' : '.jpg';
          }
        }
      }
      // 2. CAS GALERIE / FICHIER
      else {
        // Tenter d'abord avec FilePicker (très stable sur Linux, macOS, Windows, Android, Web)
        try {
          final res = await FilePicker.platform.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (res != null && res.files.isNotEmpty) {
            final f = res.files.first;
            bytes = f.bytes;
            if (bytes == null && f.path != null && !kIsWeb) {
              bytes = await File(f.path!).readAsBytes();
            }
            extension = f.extension != null ? '.${f.extension}' : '.jpg';
          }
        } catch (_) {
          // Fallback avec ImagePicker
          try {
            final XFile? pickedFile = await _picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 900,
              maxHeight: 900,
              imageQuality: 82,
            );
            if (pickedFile != null) {
              bytes = await pickedFile.readAsBytes();
              extension = p.extension(pickedFile.path);
            }
          } catch (_) {}
        }
      }

      if (bytes == null || bytes.isEmpty) return null;

      // 3. PERSISTANCE SELON LA PLATEFORME

      // Sur Web (Chrome) : renvoyer directement une Data URI Base64 universelle
      if (kIsWeb) {
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      // Sur plateformes natives (Linux, Android, iOS) :
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final targetFolder = Directory(p.join(appDir.path, folderName));
        if (!await targetFolder.exists()) {
          await targetFolder.create(recursive: true);
        }

        final ext = (extension != null && extension.isNotEmpty) ? extension : '.jpg';
        final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';
        final targetFile = File(p.join(targetFolder.path, fileName));
        await targetFile.writeAsBytes(bytes);

        return targetFile.path;
      } catch (_) {
        // En cas d'inaccessibilité du système de fichiers, fallback vers la Data URI Base64
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    } catch (_) {
      return null;
    }
  }
}
