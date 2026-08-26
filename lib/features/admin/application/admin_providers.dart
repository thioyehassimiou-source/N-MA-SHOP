import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

final adminClientsStreamProvider = StreamProvider<List<AdminClient>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.adminClients).watch();
});

final adminLicensesStreamProvider = StreamProvider<List<AdminLicense>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.adminLicenses).watch();
});
