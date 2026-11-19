import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MobileImagePicker {
  static final ImagePicker _picker = ImagePicker();

  /// Ouvre la galerie photo ou l'appareil photo et copie l'image dans le dossier local de l'application.
  static Future<String?> pickAndSaveImage({
    required ImageSource source,
    String folderName = 'product_images',
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final targetFolder = Directory(p.join(appDir.path, folderName));
      if (!await targetFolder.exists()) {
        await targetFolder.create(recursive: true);
      }

      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
      final savedFile = await File(pickedFile.path).copy(p.join(targetFolder.path, fileName));

      return savedFile.path;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> pickFromCamera({String folderName = 'product_images'}) =>
      pickAndSaveImage(source: ImageSource.camera, folderName: folderName);

  static Future<String?> pickFromGallery({String folderName = 'product_images'}) =>
      pickAndSaveImage(source: ImageSource.gallery, folderName: folderName);
}

/// Helper pour la capture et sélection d'images (Appareil photo / Galerie)
class ImagePickerHelper {
  static Future<String?> pickAndSaveImage({
    required ImageSource source,
    String folderName = 'product_images',
  }) =>
      MobileImagePicker.pickAndSaveImage(source: source, folderName: folderName);

  static Future<String?> pickFromCamera({String folderName = 'product_images'}) =>
      MobileImagePicker.pickFromCamera(folderName: folderName);

  static Future<String?> pickFromGallery({String folderName = 'product_images'}) =>
      MobileImagePicker.pickFromGallery(folderName: folderName);
}

