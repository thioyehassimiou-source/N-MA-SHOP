import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MobileImagePicker {
  static final ImagePicker _picker = ImagePicker();

  /// Ouvre la galerie photo ou l'appareil photo et copie l'image dans le dossier local de l'application.
  static Future<String?> pickAndSaveImage({
    required ImageSource source,
    required String folderName,
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
}
