// ignore_for_file: avoid_print
// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';

import '../lib/core/license/license_core.dart';

DateTime _addMonths(DateTime from, int months) {
  var year = from.year;
  var month = from.month + months;
  while (month > 12) {
    year += 1;
    month -= 12;
  }
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final day = from.day > daysInMonth ? daysInMonth : from.day;
  return DateTime(year, month, day);
}

void main(List<String> args) {
  print("=== Générateur de licences N'MaShop ===\n");

  if (args.isEmpty) {
    print('Utilisation :');
    print('  dart run tools/generate_license.dart months <nb_mois> [hardware_id]');
    print('    Exemple 5 mois universel : dart run tools/generate_license.dart months 5');
    print('    Exemple 5 mois lié au PC : dart run tools/generate_license.dart months 5 NMAS-A1B2');
    print('');
    print('  dart run tools/generate_license.dart date <YYYY-MM-DD> [hardware_id]');
    print('  dart run tools/generate_license.dart lifetime [hardware_id]');
    exit(1);
  }

  final type = args[0].toLowerCase();
  final String? hwId = args.length >= 3
      ? args[2]
      : (type == 'lifetime' && args.length >= 2 ? args[1] : null);

  if (type == 'lifetime') {
    final key = hwId != null && hwId.isNotEmpty
        ? LicenseCore.generateHardwareBoundKey(
            hardwareId: hwId,
            expiryDate: DateTime(9999, 12, 31),
          )
        : LicenseCore.generateLifetimeKey();
    print('✅ Clé à vie générée ${hwId != null ? "(liée au PC $hwId)" : "(universelle)"} :');
    print('\n\t$key\n');
    return;
  }

  if (type == 'months') {
    if (args.length < 2) {
      print('❌ Précisez le nombre de mois. Ex: dart run tools/generate_license.dart months 5');
      exit(1);
    }
    final months = int.tryParse(args[1]);
    if (months == null || months <= 0) {
      print('❌ Nombre de mois invalide.');
      exit(1);
    }

    final now = DateTime.now();
    final expiry = _addMonths(now, months);
    final dateStr = '${expiry.year.toString().padLeft(4, '0')}-'
        '${expiry.month.toString().padLeft(2, '0')}-'
        '${expiry.day.toString().padLeft(2, '0')}';

    final key = hwId != null && hwId.isNotEmpty
        ? LicenseCore.generateHardwareBoundKey(
            hardwareId: hwId,
            expiryDate: expiry,
          )
        : LicenseCore.generateAnnualKey(expiry);

    print('✅ Clé pour $months mois (valable jusqu\'au $dateStr) ${hwId != null ? "(liée au PC $hwId)" : "(universelle)"} :');
    print('\n\t$key\n');
    print('💡 Note : Le client l\'active une seule fois et reste tranquille pendant $months mois entiers !');
    return;
  }

  if (type == 'date' || type == 'annual') {
    if (args.length < 2) {
      print('❌ Précisez la date d\'expiration (YYYY-MM-DD).');
      exit(1);
    }
    final dateStr = args[1];
    final expiry = DateTime.tryParse(dateStr);
    if (expiry == null) {
      print('❌ Format de date invalide. Utilisez YYYY-MM-DD.');
      exit(1);
    }

    final key = hwId != null && hwId.isNotEmpty
        ? LicenseCore.generateHardwareBoundKey(
            hardwareId: hwId,
            expiryDate: expiry,
          )
        : LicenseCore.generateAnnualKey(expiry);

    print('✅ Clé valable jusqu\'au $dateStr ${hwId != null ? "(liée au PC $hwId)" : "(universelle)"} :');
    print('\n\t$key\n');
    return;
  }

  print('❌ Commande inconnue : $type');
}
