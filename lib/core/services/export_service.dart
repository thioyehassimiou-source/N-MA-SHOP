import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';

/// Service gérant les exports (CSV, Backup DB)
class ExportService {
  /// Exporte la liste des ventes au format CSV et demande à l'utilisateur où l'enregistrer.
  static Future<bool> exportSalesToCsv(AppDatabase db) async {
    try {
      final sales = await db.select(db.sales).get();
      if (sales.isEmpty) return false;

      List<List<dynamic>> rows = [];
      rows.add([
        "ID",
        "Référence",
        "Date",
        "Montant Total (GNF)",
        "Montant Payé (GNF)",
        "Méthode Paiement",
        "Statut Annulé"
      ]);

      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      for (final sale in sales) {
        rows.add([
          sale.id,
          sale.reference,
          dateFormat.format(sale.createdAt),
          sale.totalAmount,
          sale.amountPaid,
          sale.paymentMethod,
          sale.isCancelled ? 'Oui' : 'Non'
        ]);
      }

      final bytes = await compute(_buildCsvBytes, rows);

      final String fileName = "export_ventes_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Exporter les ventes (CSV)',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      return savedUri != null;

    } catch (e) {
      // ignore: avoid_print
      print('Erreur lors de l\'export CSV: $e');
      return false;
    }
  }

  /// Exporte la base de données SQLite en copiant le fichier.
  static Future<bool> backupDatabase() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final dbFile = File(p.join(dir.path, 'gescompta.sqlite'));

      if (!await dbFile.exists()) {
        return false;
      }

      final bytes = await dbFile.readAsBytes();
      final String fileName = "backup_gescompta_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.sqlite";
      
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Sauvegarder la base de données',
        fileName: fileName,
        bytes: bytes,
      );

      return savedUri != null;

    } catch (e) {
      // ignore: avoid_print
      print('Erreur lors de la sauvegarde: $e');
      return false;
    }
  }

  /// Permet à l'utilisateur de sélectionner un fichier de sauvegarde (.sqlite) et de le restaurer.
  static Future<bool> restoreDatabase() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Sélectionner le fichier de sauvegarde à restaurer (.sqlite)',
        type: FileType.custom,
        allowedExtensions: ['sqlite', 'db'],
      );

      if (result.isEmpty || result.first.path == null) {
        return false;
      }

      final backupPath = result.first.path!;
      final backupFile = File(backupPath);

      if (!await backupFile.exists()) {
        return false;
      }

      final dir = await getApplicationSupportDirectory();
      final targetFile = File(p.join(dir.path, 'gescompta.sqlite'));

      final bytes = await backupFile.readAsBytes();
      await targetFile.writeAsBytes(bytes, flush: true);

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Erreur lors de la restauration: $e');
      return false;
    }
  }
}

/// Fonction de conversion CSV exécutée hors du thread UI (dans un Isolate)
Uint8List _buildCsvBytes(List<List<dynamic>> rows) {
  final csvData = const ListToCsvConverter().convert(rows);
  return Uint8List.fromList(utf8.encode(csvData));
}
