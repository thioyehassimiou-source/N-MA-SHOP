import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../theme/app_colors.dart';
import '../utils/print_file_utils.dart';

/// Service d'impression et d'export PDF unifié et sécurisé pour N'MaShop.
///
/// Résout définitivement le problème GTK Linux où l'imprimante virtuelle
/// « Imprimer dans un fichier » force le nom « sortie.pdf » et bloque avec
/// « Un fichier nommé sortie.pdf existe déjà ».
class AppPrintService {
  /// Nettoie les fichiers temporaires par défaut de GTK sous Linux avant l'impression.
  static void _cleanGtkDefaultOutputFiles() {
    if (!Platform.isLinux) return;
    try {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return;
      final candidates = [
        '$home/Documents/sortie.pdf',
        '$home/Documents/output.pdf',
        '$home/sortie.pdf',
        '$home/output.pdf',
      ];
      for (final path in candidates) {
        final f = File(path);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    } catch (_) {
      // Ignorer silencieusement si inaccessible
    }
  }

  /// Si l'utilisateur a choisi « Imprimer dans un fichier » sous Linux, GTK
  /// aura écrit dans ~/Documents/sortie.pdf. Cette méthode le détecte et le
  /// renomme avec le nom officiel du document (ex. Recu_V-2026-000001.pdf).
  static File? _renameGtkDefaultOutputFile(String targetName) {
    if (!Platform.isLinux) return null;
    try {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return null;
      final candidates = [
        '$home/Documents/sortie.pdf',
        '$home/Documents/output.pdf',
        '$home/sortie.pdf',
        '$home/output.pdf',
      ];
      for (final path in candidates) {
        final f = File(path);
        if (f.existsSync()) {
          final safeName = targetName.endsWith('.pdf') ? targetName : '$targetName.pdf';
          final dir = f.parent.path;
          var destPath = '$dir/$safeName';
          if (File(destPath).existsSync()) {
            final now = DateTime.now();
            final ts =
                '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
                '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
            final base = safeName.replaceAll('.pdf', '');
            destPath = '$dir/${base}_$ts.pdf';
          }
          return f.renameSync(destPath);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Ouvre le document PDF dans la visionneuse par défaut du système.
  static Future<void> openPdfFile(String filePath) async {
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      }
    } catch (_) {}
  }

  /// Imprime un document via le gestionnaire d'impression en prévenant les
  /// conflits GTK Linux.
  static Future<bool> printDocument({
    BuildContext? context,
    required Future<Uint8List> Function(PdfPageFormat format) onLayout,
    required String documentName,
  }) async {
    // 1. Nettoyage préventif
    _cleanGtkDefaultOutputFiles();

    // 2. Impression native
    final result = await Printing.layoutPdf(
      onLayout: onLayout,
      name: safePrintFileName(documentName),
    );

    // 3. Post-traitement : si GTK a généré sortie.pdf, on le renomme proprement
    final renamed = _renameGtkDefaultOutputFile(documentName);
    if (renamed != null && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document enregistré : ${renamed.path}'),
          backgroundColor: AppColors.brandEmerald,
          action: SnackBarAction(
            label: 'Ouvrir',
            textColor: Colors.white,
            onPressed: () => openPdfFile(renamed.path),
          ),
        ),
      );
    }

    return result;
  }

  /// Enregistre un document PDF directement via une boîte de dialogue de sauvegarde.
  static Future<File?> savePdfWithDialog({
    required BuildContext context,
    required Uint8List bytes,
    required String defaultFileName,
  }) async {
    final cleanName =
        defaultFileName.endsWith('.pdf') ? defaultFileName : '$defaultFileName.pdf';

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Enregistrer le document PDF',
      fileName: cleanName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (savedUri == null) return null;

    final file = File.fromUri(savedUri);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Enregistré : ${file.path}'),
          backgroundColor: AppColors.brandEmerald,
          action: SnackBarAction(
            label: 'Ouvrir',
            textColor: Colors.white,
            onPressed: () => openPdfFile(file.path),
          ),
        ),
      );
    }

    return file;
  }
}
