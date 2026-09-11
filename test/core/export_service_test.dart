import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportService .nma Archive Security', () {
    test('.nma container encodes metadata, checksum and gzip compressed payload', () {
      // Simulate raw SQLite bytes
      final rawSqlite = Uint8List.fromList(utf8.encode('SQLite format 3\x00_test_data_payload_nmashop'));
      final expectedChecksum = sha256.convert(rawSqlite).toString();
      final compressed = gzip.encode(rawSqlite);

      final metadata = {
        'app': "N'MaShop",
        'format': 'NMA_BACKUP_V2',
        'version': '1.0.0',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'checksum': expectedChecksum,
        'uncompressedSize': rawSqlite.length,
      };

      const header = 'NMA_BACKUP_V2\n';
      const delim = '\n---NMA_DATA---\n';

      final metaJson = jsonEncode(metadata);
      final headerBytes = utf8.encode('$header$metaJson$delim');

      final builder = BytesBuilder();
      builder.add(headerBytes);
      builder.add(compressed);
      final fileBytes = builder.toBytes();

      // Verify decoding
      final headerPrefix = utf8.encode(header);
      expect(fileBytes.sublist(0, headerPrefix.length), headerPrefix);

      final delimBytes = utf8.encode(delim);
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
      expect(delimIndex, isNot(-1));

      final extractedMeta = jsonDecode(utf8.decode(fileBytes.sublist(headerPrefix.length, delimIndex)));
      expect(extractedMeta['app'], "N'MaShop");
      expect(extractedMeta['checksum'], expectedChecksum);

      final payload = fileBytes.sublist(delimIndex + delimBytes.length);
      final decompressed = Uint8List.fromList(gzip.decode(payload));
      expect(decompressed, rawSqlite);
      expect(sha256.convert(decompressed).toString(), expectedChecksum);
    });
  });
}
