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

void _displayResult({
  required String key,
  required String durationLabel,
  required String expiryStr,
  String? hwId,
  String? storeName,
}) {
  final targetDevice = (hwId != null && hwId.isNotEmpty)
      ? '$hwId (Verrouillée sur cet appareil)'
      : 'Universelle (toutes machines)';

  print('\n════════════════════════════════════════════════════════════════════');
  print("🌟 CLÉ D'ACTIVATION N'MASHOP GÉNÉRÉE AVEC SUCCÈS 🌟");
  print('════════════════════════════════════════════════════════════════════');
  print('🔑 Clé de licence : $key');
  print('💻 Machine cible  : $targetDevice');
  if (storeName != null && storeName.isNotEmpty) {
    print('🏪 Boutique       : $storeName');
  }
  print('⏱️  Validité       : $durationLabel ($expiryStr)');
  print('════════════════════════════════════════════════════════════════════\n');

  print('📱 MESSAGE WHATSAPP PRÊT À TRANSMETTRE AU CLIENT :');
  print('────────────────────────────────────────────────────────────────────');
  final greeting = (storeName != null && storeName.isNotEmpty)
      ? "Bonjour $storeName,"
      : "Bonjour,";
  print('$greeting voici votre clé d\'activation officielle N\'MaShop :\n');
  print('🔑 Clé : $key');
  if (hwId != null && hwId.isNotEmpty) {
    print('💻 Appareil : $hwId');
  }
  print('📅 Validité : $durationLabel ($expiryStr)\n');
  print('👉 Ouvrez N\'MaShop, collez cette clé dans l\'écran d\'activation et cliquez sur Valider.');
  print('Merci pour votre confiance !');
  print('────────────────────────────────────────────────────────────────────\n');
}

void _runInteractive() {
  print("=== 🔑 Générateur de Licences N'MaShop (Mode Interactif) ===\n");

  stdout.write("1️⃣  Entrez l'Hardware ID du client (ex: DSK-8F3A ou MOB-4C07, Entrée pour universelle) : ");
  final hwInput = stdin.readLineSync()?.trim().toUpperCase();
  final hwId = (hwInput != null && hwInput.isNotEmpty) ? hwInput : null;

  stdout.write("2️⃣  Nom de la boutique ou du client (optionnel) : ");
  final storeInput = stdin.readLineSync()?.trim();
  final storeName = (storeInput != null && storeInput.isNotEmpty) ? storeInput : null;

  print("\n3️⃣  Choisissez la durée de la licence :");
  print("    [1] 1 Mois (30 jours)");
  print("    [2] 3 Mois");
  print("    [3] 6 Mois");
  print("    [4] 1 An / 12 Mois (Recommandé)");
  print("    [5] À Vie (Permanente / Illimitée)");
  print("    [6] Date d'échéance personnalisée (YYYY-MM-DD)");
  stdout.write("👉 Votre choix [1-6] (Défaut: 4) : ");

  final choice = stdin.readLineSync()?.trim();
  final selected = (choice == null || choice.isEmpty) ? '4' : choice;

  final now = DateTime.now();

  switch (selected) {
    case '1':
      final expiry = _addMonths(now, 1);
      final expiryStr = '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
      final key = (hwId != null)
          ? LicenseCore.generateHardwareBoundKey(hardwareId: hwId, expiryDate: expiry)
          : LicenseCore.generateAnnualKey(expiry);
      _displayResult(
        key: key,
        durationLabel: '1 Mois',
        expiryStr: expiryStr,
        hwId: hwId,
        storeName: storeName,
      );
      break;

    case '2':
      final expiry = _addMonths(now, 3);
      final expiryStr = '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
      final key = (hwId != null)
          ? LicenseCore.generateHardwareBoundKey(hardwareId: hwId, expiryDate: expiry)
          : LicenseCore.generateAnnualKey(expiry);
      _displayResult(
        key: key,
        durationLabel: '3 Mois',
        expiryStr: expiryStr,
        hwId: hwId,
        storeName: storeName,
      );
      break;

    case '3':
      final expiry = _addMonths(now, 6);
      final expiryStr = '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
      final key = (hwId != null)
          ? LicenseCore.generateHardwareBoundKey(hardwareId: hwId, expiryDate: expiry)
          : LicenseCore.generateAnnualKey(expiry);
      _displayResult(
        key: key,
        durationLabel: '6 Mois',
        expiryStr: expiryStr,
        hwId: hwId,
        storeName: storeName,
      );
      break;

    case '4':
      final expiry = _addMonths(now, 12);
      final expiryStr = '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
      final key = (hwId != null)
          ? LicenseCore.generateHardwareBoundKey(hardwareId: hwId, expiryDate: expiry)
          : LicenseCore.generateAnnualKey(expiry);
      _displayResult(
        key: key,
        durationLabel: '1 An (12 Mois)',
        expiryStr: expiryStr,
        hwId: hwId,
        storeName: storeName,
      );
      break;

    case '5':
      final expiry = DateTime(9999, 12, 31);
      final key = (hwId != null)
          ? LicenseCore.generateHardwareBoundKey(hardwareId: hwId, expiryDate: expiry)
          : LicenseCore.generateLifetimeKey();
      _displayResult(
        key: key,
        durationLabel: 'À Vie (Illimitée)',
        expiryStr: 'Permanente',
        hwId: hwId,
        storeName: storeName,
      );
      break;

    case '6':
      stdout.write("Entrez la date d'expiration (YYYY-MM-DD) : ");
      final customDateStr = stdin.readLineSync()?.trim();
      final customExpiry = DateTime.tryParse(customDateStr ?? '');
      if (customExpiry == null) {
        print("❌ Date invalide. Format attendu : YYYY-MM-DD (ex: 2027-12-31)");
        exit(1);
      }
      final key = (hwId != null)
          ? LicenseCore.generateHardwareBoundKey(hardwareId: hwId, expiryDate: customExpiry)
          : LicenseCore.generateAnnualKey(customExpiry);
      _displayResult(
        key: key,
        durationLabel: 'Personnalisée',
        expiryStr: customDateStr!,
        hwId: hwId,
        storeName: storeName,
      );
      break;

    default:
      print("❌ Choix invalide.");
      exit(1);
  }
}

void main(List<String> args) {
  if (args.isEmpty) {
    _runInteractive();
    return;
  }

  final type = args[0].toLowerCase();
  final String? hwId = args.length >= 3
      ? args[2].toUpperCase()
      : (type == 'lifetime' && args.length >= 2 ? args[1].toUpperCase() : null);

  if (type == 'lifetime') {
    final key = hwId != null && hwId.isNotEmpty
        ? LicenseCore.generateHardwareBoundKey(
            hardwareId: hwId,
            expiryDate: DateTime(9999, 12, 31),
          )
        : LicenseCore.generateLifetimeKey();
    _displayResult(
      key: key,
      durationLabel: 'À Vie (Illimitée)',
      expiryStr: 'Permanente',
      hwId: hwId,
    );
    return;
  }

  if (type == 'months') {
    if (args.length < 2) {
      print('❌ Précisez le nombre de mois. Ex: dart run tools/generate_license.dart months 6 [hardware_id]');
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

    _displayResult(
      key: key,
      durationLabel: '$months Mois',
      expiryStr: dateStr,
      hwId: hwId,
    );
    return;
  }

  if (type == 'date' || type == 'annual') {
    if (args.length < 2) {
      print('❌ Précisez la date d\'expiration (YYYY-MM-DD). Ex: dart run tools/generate_license.dart date 2027-12-31 [hardware_id]');
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

    _displayResult(
      key: key,
      durationLabel: 'Jusqu\'au $dateStr',
      expiryStr: dateStr,
      hwId: hwId,
    );
    return;
  }

  print('❌ Commande inconnue : $type');
  print('Usage :');
  print('  dart run tools/generate_license.dart                      (Mode interactif)');
  print('  dart run tools/generate_license.dart months <nb> [hwId]   (Ex: months 12 DSK-8F3A)');
  print('  dart run tools/generate_license.dart lifetime [hwId]      (Ex: lifetime DSK-8F3A)');
  print('  dart run tools/generate_license.dart date <YYYY-MM-DD> [hwId]');
}
