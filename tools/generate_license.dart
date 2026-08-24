import 'dart:io';

import '../lib/core/license/license_core.dart';

void main(List<String> args) {
  print("=== Générateur de licences N'MaShop ===\n");

  if (args.isEmpty) {
    print('Utilisation :');
    print('  dart run tools/generate_license.dart annual <YYYY-MM-DD>');
    print('  dart run tools/generate_license.dart lifetime');
    exit(1);
  }

  final type = args[0];

  if (type == 'lifetime') {
    final key = LicenseCore.generateLifetimeKey();
    print('✅ Clé à vie générée :');
    print('\n\t$key\n');
    return;
  }

  if (type == 'annual' && args.length == 2) {
    final dateStr = args[1];
    final expiry = DateTime.tryParse(dateStr);
    if (expiry == null) {
      print('❌ Format de date invalide. Utilisez YYYY-MM-DD.');
      exit(1);
    }
    
    final key = LicenseCore.generateAnnualKey(expiry);
    print('✅ Clé annuelle (expire le $dateStr) générée :');
    print('\n\t$key\n');
    return;
  }

  print('❌ Commande invalide.');
}
