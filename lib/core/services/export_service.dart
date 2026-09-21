import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import 'hardware_id_service.dart';

/// Service gérant les exports (CSV, Backup DB .nma)
class ExportService {
  static const String _nmaHeader = 'NMA_BACKUP_V2\n';
  static const String _nmaDelimiter = '\n---NMA_DATA---\n';

  /// Génère et téléverse la sauvegarde conteneur .nma directement sur le Cloud (Backblaze B2 via le serveur NestJS)
  static Future<Map<String, dynamic>> backupDatabaseToCloud({
    required String serverUrl,
    required String licenseKey,
    String? caisseSecret,
  }) async {
    try {
      final dir = await getApplicationSupportDirectory();
      var dbFile = File(p.join(dir.path, 'nmashop.sqlite'));

      if (!await dbFile.exists()) {
        final legacyFile = File(p.join(dir.path, 'gescompta.sqlite'));
        if (await legacyFile.exists()) {
          dbFile = legacyFile;
        } else {
          return {'success': false, 'error': 'Fichier base de données SQLite introuvable'};
        }
      }

      final rawBytes = await dbFile.readAsBytes();
      final checksum = sha256.convert(rawBytes).toString();
      final compressedBytes = gzip.encode(rawBytes);

      final metadata = {
        'app': "N'MaShop",
        'format': 'NMA_BACKUP_V2',
        'version': '1.0.0',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'checksum': checksum,
        'uncompressedSize': rawBytes.length,
      };

      final metaJson = jsonEncode(metadata);
      final headerBytes = utf8.encode('$_nmaHeader$metaJson$_nmaDelimiter');

      final builder = BytesBuilder();
      builder.add(headerBytes);
      builder.add(compressedBytes);
      final finalBytes = builder.toBytes();

      final String fileName = "sauvegarde_nmashop_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.nma";
      final base64Payload = base64Encode(finalBytes);

      final uri = Uri.parse('$serverUrl/api/v1/sync/backup/upload');
      final hwid = await HardwareIdService.getHardwareId();

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final bodyMap = {
        'licenseKey': licenseKey,
        'filename': fileName,
        'backupBase64': base64Payload,
      };
      final bodyStr = jsonEncode(bodyMap);

      String? signature;
      if (caisseSecret != null && caisseSecret.isNotEmpty) {
        final rawPayload = '$nowIso.$bodyStr';
        final hmac = Hmac(sha256, utf8.encode(caisseSecret));
        signature = hmac.convert(utf8.encode(rawPayload)).toString();
      }

      final headers = {
        HttpHeaders.contentTypeHeader: 'application/json',
        'X-Machine-Id': hwid,
        'X-License-Key': licenseKey,
        'X-Timestamp': nowIso,
        if (signature != null) 'X-Signature': signature,
      };

      final response = await http
          .post(
            uri,
            headers: headers,
            body: bodyStr,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': resData['message'] ?? 'Sauvegarde enregistrée dans le Cloud Backblaze B2.',
          'b2Storage': resData['b2Storage'],
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur serveur Cloud (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion Cloud: $e',
      };
    }
  }

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

  /// Exporte la base de données dans le format conteneur propriétaire .nma
  /// Sauvegarde automatiquement le fichier .nma en arrière-plan (sans ouvrir l'explorateur de fichiers).
  static Future<File?> backupDatabaseSilently() async {
    try {
      final dir = await getApplicationSupportDirectory();
      var dbFile = File(p.join(dir.path, 'nmashop.sqlite'));

      if (!await dbFile.exists()) {
        final legacyFile = File(p.join(dir.path, 'gescompta.sqlite'));
        if (await legacyFile.exists()) {
          dbFile = legacyFile;
        } else {
          return null;
        }
      }

      final rawBytes = await dbFile.readAsBytes();
      final checksum = sha256.convert(rawBytes).toString();
      final compressedBytes = gzip.encode(rawBytes);

      final metadata = {
        'app': "N'MaShop",
        'format': 'NMA_BACKUP_V2',
        'version': '1.0.0',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'checksum': checksum,
        'uncompressedSize': rawBytes.length,
      };

      final metaJson = jsonEncode(metadata);
      final headerBytes = utf8.encode('$_nmaHeader$metaJson$_nmaDelimiter');

      final builder = BytesBuilder();
      builder.add(headerBytes);
      builder.add(compressedBytes);
      final finalBytes = builder.toBytes();

      final backupsDir = Directory(p.join(dir.path, 'backups'));
      if (!await backupsDir.exists()) {
        await backupsDir.create(recursive: true);
      }

      final String fileName = "sauvegarde_nmashop_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.nma";
      final targetFile = File(p.join(backupsDir.path, fileName));
      await targetFile.writeAsBytes(finalBytes, flush: true);

      return targetFile;
    } catch (e) {
      // ignore: avoid_print
      print('Erreur sauvegarde silencieuse: $e');
      return null;
    }
  }

  /// Exporte la base de données dans le format conteneur propriétaire .nma
  /// avec ouverture de la boîte de dialogue d'enregistrement sur disque/clé USB.
  static Future<bool> backupDatabase() async {
    try {
      final dir = await getApplicationSupportDirectory();
      var dbFile = File(p.join(dir.path, 'nmashop.sqlite'));

      if (!await dbFile.exists()) {
        final legacyFile = File(p.join(dir.path, 'gescompta.sqlite'));
        if (await legacyFile.exists()) {
          dbFile = legacyFile;
        } else {
          return false;
        }
      }

      final rawBytes = await dbFile.readAsBytes();
      final checksum = sha256.convert(rawBytes).toString();
      final compressedBytes = gzip.encode(rawBytes);

      final metadata = {
        'app': "N'MaShop",
        'format': 'NMA_BACKUP_V2',
        'version': '1.0.0',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'checksum': checksum,
        'uncompressedSize': rawBytes.length,
      };

      final metaJson = jsonEncode(metadata);
      final headerBytes = utf8.encode('$_nmaHeader$metaJson$_nmaDelimiter');

      final builder = BytesBuilder();
      builder.add(headerBytes);
      builder.add(compressedBytes);
      final finalBytes = builder.toBytes();

      final String fileName = "sauvegarde_nmashop_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.nma";

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Sauvegarder les données N\'MaShop (.nma)',
        fileName: fileName,
        bytes: finalBytes,
        type: FileType.custom,
        allowedExtensions: ['nma'],
      );

      if (savedPath == null) return false;

      final filePath = savedPath.scheme == 'file' ? savedPath.toFilePath() : savedPath.path;
      final targetFile = File(p.normalize(p.absolute(filePath)));
      if (!await targetFile.exists() || await targetFile.length() == 0) {
        await targetFile.writeAsBytes(finalBytes, flush: true);
      }

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Erreur lors de la sauvegarde: $e');
      return false;
    }
  }

  /// Permet à l'utilisateur de sélectionner un fichier de sauvegarde (.nma propriétaire ou .sqlite historique) et de le restaurer.
  static Future<bool> restoreDatabase() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Sélectionner le fichier de sauvegarde (.nma, .sqlite)',
        type: FileType.custom,
        allowedExtensions: ['nma', 'nmabackup', 'sqlite', 'db'],
      );

      if (result.isEmpty || result.first.path == null) {
        return false;
      }

      final backupPath = p.normalize(p.absolute(result.first.path!));
      final backupFile = File(backupPath);

      if (!await backupFile.exists()) {
        return false;
      }

      final fileBytes = await backupFile.readAsBytes();
      Uint8List sqliteBytes;

      // 1. Détection du format conteneur propriétaire .nma
      final headerPrefix = utf8.encode(_nmaHeader);
      final isNmaContainer = fileBytes.length > headerPrefix.length &&
          listEquals(fileBytes.sublist(0, headerPrefix.length), headerPrefix);

      if (isNmaContainer) {
        // Recherche du délimiteur
        final delimBytes = utf8.encode(_nmaDelimiter);
        int delimIndex = -1;
        for (int i = 0; i < fileBytes.length - delimBytes.length; i++) {
          bool match = true;
          for (int j = 0; j < delimBytes.length; j++) {
            if (fileBytes[i + j] != delimBytes[j]) {
              match = false;
              break;
            }
          }
          if (match) {
            delimIndex = i;
            break;
          }
        }

        if (delimIndex == -1) {
          throw Exception('Format d\'archive N\'MaShop invalide ou corrompu.');
        }

        final metaRaw = utf8.decode(fileBytes.sublist(headerPrefix.length, delimIndex));
        final metaJson = jsonDecode(metaRaw) as Map<String, dynamic>;
        final expectedChecksum = metaJson['checksum'] as String?;

        final payload = fileBytes.sublist(delimIndex + delimBytes.length);
        final decompressed = Uint8List.fromList(gzip.decode(payload));

        if (expectedChecksum != null) {
          final actualChecksum = sha256.convert(decompressed).toString();
          if (actualChecksum != expectedChecksum) {
            throw Exception('Échec de validation de l\'empreinte de sécurité SHA-256.');
          }
        }
        sqliteBytes = decompressed;
      } else {
        // 2. Format brut hérité (.sqlite / .db)
        sqliteBytes = fileBytes;
      }

      // Vérification signature SQLite standard
      if (sqliteBytes.length < 16) {
        throw Exception('Le fichier restauré est trop court ou corrompu.');
      }
      final sqliteMagic = utf8.encode('SQLite format 3\x00');
      if (!listEquals(sqliteBytes.sublist(0, sqliteMagic.length), sqliteMagic)) {
        throw Exception('Le contenu ne correspond pas à une base SQLite valide.');
      }

      final dir = await getApplicationSupportDirectory();
      final targetFile = File(p.join(dir.path, 'nmashop.sqlite'));

      await targetFile.writeAsBytes(sqliteBytes, flush: true);
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
