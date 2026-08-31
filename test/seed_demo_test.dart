import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:nmashop/core/database/database.dart';
import 'package:nmashop/core/services/demo_data_seeder.dart';

void main() {
  test('Seed demo database', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final home = Platform.environment['HOME'] ?? '/home/thioye';
    final possiblePaths = [
      p.join(home, '.local', 'share', 'com.nmashop.nmashop', 'gescompta.sqlite'),
      p.join(home, '.local', 'share', 'com.gescompta.gescompta', 'gescompta.sqlite'),
      p.join(home, '.local', 'share', 'nmashop', 'gescompta.sqlite'),
    ];

    for (final path in possiblePaths) {
      final file = File(path);
      file.parent.createSync(recursive: true);

      final nativeDb = NativeDatabase.memory();
      final db = AppDatabase.forTesting(nativeDb);

      try {
        await DemoDataSeeder.seedDatabase(db);
        expect(file.existsSync(), true);
      } finally {
        await db.close();
      }
    }
  });
}
