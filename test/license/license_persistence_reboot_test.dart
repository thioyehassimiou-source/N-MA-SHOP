import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nmashop/core/license/license_core.dart';
import 'package:nmashop/core/license/license_model.dart';
import 'package:nmashop/core/license/license_service.dart';
import 'package:nmashop/core/services/hardware_id_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;

  setUp(() {
    testDir = Directory.systemTemp.createTempSync('nmashop_reboot_test_');
    LicenseService.setAppDirForTesting(testDir);
  });

  tearDown(() {
    LicenseService.setAppDirForTesting(null);
    HardwareIdService.resetCacheForTesting(null);
    try {
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('SCÉNARIO CLIENT : Licence 9 mois activée directement -> Reboot complet -> Survie et persistance garantie', () async {
    // 1. Détection du Hardware ID machine
    final realHwId = await HardwareIdService.getHardwareId();
    expect(realHwId, isNotEmpty);

    // Initialisation état vierge
    SharedPreferences.setMockInitialValues({});
    var prefs = await SharedPreferences.getInstance();

    final initialCheck = await LicenseService().checkAsync(prefs);
    expect(initialCheck.isLicensed, isFalse);

    // 2. Génération clé 9 mois (270 jours)
    final expiryDate = DateTime.now().add(const Duration(days: 270));
    final clientKey = LicenseCore.generateHardwareBoundKey(
      hardwareId: realHwId,
      expiryDate: expiryDate,
    );

    // Activation par le client
    final service = LicenseService();
    final activation = await service.activateAsync(clientKey, prefs);
    expect(activation.result, equals(LicenseActivationResult.success));
    expect(activation.info?.status, equals(LicenseStatus.licensed));
    expect(activation.info?.isLicensed, isTrue);
    expect(activation.info?.daysLeft, greaterThanOrEqualTo(269));

    // 3. Simulation fermeture complète de l'application (vidage RAM)
    HardwareIdService.resetCacheForTesting(null);

    // 4. Rallumage de l'application (comme si le client cliquait sur l'icône)
    final rebootedService = LicenseService();

    // A. Contrôle synchrone rapide au boot (main.dart)
    final syncCheck = rebootedService.check(prefs);
    expect(syncCheck.isLicensed, isTrue);
    expect(syncCheck.isExpired, isFalse);
    expect(syncCheck.status, equals(LicenseStatus.licensed));

    // B. Contrôle asynchrone (initialisation router / Riverpod)
    final asyncCheck = await rebootedService.checkAsync(prefs);
    expect(asyncCheck.isLicensed, isTrue);
    expect(asyncCheck.isExpired, isFalse);
    expect(asyncCheck.status, equals(LicenseStatus.licensed));
    expect(asyncCheck.key, equals(clientKey));
    expect(asyncCheck.daysLeft, greaterThanOrEqualTo(269));

    // 5. Crash-test : Si SharedPreferences est corrompu ou vidé lors d'un reboot Windows
    await prefs.clear();
    HardwareIdService.resetCacheForTesting(null);

    final recoveryService = LicenseService();
    final recoveryCheck = await recoveryService.checkAsync(prefs);
    expect(recoveryCheck.isLicensed, isTrue);
    expect(recoveryCheck.status, equals(LicenseStatus.licensed));
    expect(recoveryCheck.key, equals(clientKey));
    expect(recoveryCheck.daysLeft, greaterThanOrEqualTo(269));
  });
}
