import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nmashop/core/license/license_core.dart';
import 'package:nmashop/core/license/license_model.dart';
import 'package:nmashop/core/license/license_service.dart';
import 'package:nmashop/core/services/hardware_id_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LicenseCore - Cryptographic Validation', () {
    test('generateAnnualKey generates a valid 3-segment key', () {
      final expiry = DateTime.now().add(const Duration(days: 365));
      final key = LicenseCore.generateAnnualKey(expiry);

      expect(key.startsWith('NMAS-'), isTrue);
      final parts = key.split('-');
      expect(parts.length, 3);

      final info = LicenseCore.validateKey(key);
      expect(info, isNotNull);
      expect(info!.status, LicenseStatus.licensed);
      expect(info.type, LicenseType.annual);
      expect(info.isLicensed, isTrue);
      expect(info.isExpired, isFalse);
    });

    test('generateMonthlyKey generates a valid 30-day key', () {
      final key = LicenseCore.generateMonthlyKey();
      final info = LicenseCore.validateKey(key);

      expect(info, isNotNull);
      expect(info!.status, LicenseStatus.licensed);
      expect(info.daysLeft, inInclusiveRange(29, 31));
    });

    test('generateLifetimeKey generates a perpetual key', () {
      final key = LicenseCore.generateLifetimeKey();
      final parts = key.split('-');
      expect(parts[1], '99991231');

      final info = LicenseCore.validateKey(key);
      expect(info, isNotNull);
      expect(info!.status, LicenseStatus.licensed);
      expect(info.type, LicenseType.lifetime);
      expect(info.expiryDate, isNull);
      expect(info.daysLeft, isNull);
    });

    test('Expired key is rejected with expired status', () {
      final pastExpiry = DateTime.now().subtract(const Duration(days: 10));
      final key = LicenseCore.generateAnnualKey(pastExpiry);

      final info = LicenseCore.validateKey(key);
      expect(info, isNotNull);
      expect(info!.status, LicenseStatus.expired);
      expect(info.isExpired, isTrue);
      expect(info.daysLeft, 0);
    });

    test('Tampered HMAC or corrupted payload returns null', () {
      final key = LicenseCore.generateAnnualKey(DateTime.now().add(const Duration(days: 30)));
      
      // Corrupt last character
      final corruptedHmac = '${key.substring(0, key.length - 1)}X';
      expect(LicenseCore.validateKey(corruptedHmac), isNull);

      // Corrupt date
      final parts = key.split('-');
      final corruptedDate = 'NMAS-20299999-${parts[2]}';
      expect(LicenseCore.validateKey(corruptedDate), isNull);

      // Random string
      expect(LicenseCore.validateKey('INVALID-KEY-1234'), isNull);
      expect(LicenseCore.validateKey(''), isNull);
    });
  });

  group('LicenseCore - Hardware Binding (Device Binding)', () {
    const hwIdA = 'NMAS-A1B2-C3D4';
    const hwIdB = 'NMAS-E5F6-G7H8';

    test('generateHardwareBoundKey generates a 4-segment key', () {
      final expiry = DateTime.now().add(const Duration(days: 90));
      final key = LicenseCore.generateHardwareBoundKey(
        hardwareId: hwIdA,
        expiryDate: expiry,
      );

      final parts = key.split('-');
      expect(parts.length, 4);
      expect(parts[0], 'NMAS');
      expect(parts[1].length, 4); // 4-char short hash
    });

    test('Hardware-bound key validates on matching machine', () {
      final expiry = DateTime.now().add(const Duration(days: 90));
      final key = LicenseCore.generateHardwareBoundKey(
        hardwareId: hwIdA,
        expiryDate: expiry,
      );

      final info = LicenseCore.validateKey(key, deviceHwId: hwIdA);
      expect(info, isNotNull);
      expect(info!.status, LicenseStatus.licensed);
      expect(info.isLicensed, isTrue);
    });

    test('Hardware-bound key is rejected on mismatched machine', () {
      final expiry = DateTime.now().add(const Duration(days: 90));
      final key = LicenseCore.generateHardwareBoundKey(
        hardwareId: hwIdA,
        expiryDate: expiry,
      );

      // Attempt to validate key of machine A on machine B
      final info = LicenseCore.validateKey(key, deviceHwId: hwIdB);
      expect(info, isNull);
    });

    test('Hardware-bound key is rejected if no deviceHwId is provided', () {
      final expiry = DateTime.now().add(const Duration(days: 90));
      final key = LicenseCore.generateHardwareBoundKey(
        hardwareId: hwIdA,
        expiryDate: expiry,
      );

      // Attempt to validate without hardware ID
      final info = LicenseCore.validateKey(key);
      expect(info, isNull);
    });

    test('generateBoundKeyFromHash preserves the exact hardware hash', () {
      final originalKey = LicenseCore.generateHardwareBoundKey(
        hardwareId: hwIdA,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );
      final hash = originalKey.split('-')[1];

      final renewedKey = LicenseCore.generateBoundKeyFromHash(
        hwHash: hash,
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );

      expect(renewedKey.split('-')[1], hash);
      final info = LicenseCore.validateKey(renewedKey, deviceHwId: hwIdA);
      expect(info, isNotNull);
      expect(info!.isLicensed, isTrue);
    });
  });

  group('LicenseService - Full Lifecycle & Security', () {
    late LicenseService service;
    const testHwId = 'NMAS-TEST-MACHINE-01';

    setUp(() {
      service = LicenseService();
      HardwareIdService.resetCacheForTesting(testHwId);
    });

    tearDown(() {
      HardwareIdService.resetCacheForTesting(null);
    });

    test('First launch initializes 7-day trial', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final info = await service.checkAsync(prefs);

      expect(info.status, LicenseStatus.trial);
      expect(info.daysLeft, LicenseCore.trialDays);
      expect(info.isLicensed, isFalse);
      expect(info.isTrial, isTrue);
      expect(info.isExpired, isFalse);

      expect(prefs.getString('lic_first_launch'), isNotNull);
      expect(prefs.getString('lic_last_known_time'), isNotNull);
    });

    test('Subsequent launch inside trial period preserves remaining days', () async {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      SharedPreferences.setMockInitialValues({
        'lic_first_launch': threeDaysAgo.toIso8601String(),
        'lic_last_known_time': threeDaysAgo.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final info = await service.checkAsync(prefs);

      expect(info.status, LicenseStatus.trial);
      expect(info.isTrial, isTrue);
      expect(info.daysLeft, inInclusiveRange(3, 5));
    });

    test('Expired trial locks the user to expired state', () async {
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      SharedPreferences.setMockInitialValues({
        'lic_first_launch': tenDaysAgo.toIso8601String(),
        'lic_last_known_time': tenDaysAgo.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final info = await service.checkAsync(prefs);

      expect(info.status, LicenseStatus.expired);
      expect(info.isExpired, isTrue);
      expect(info.daysLeft, 0);
    });

    test('Anti-tamper: rolling back clock by more than 5 minutes triggers tampered', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 2));
      SharedPreferences.setMockInitialValues({
        'lic_first_launch': DateTime.now().toIso8601String(),
        'lic_last_known_time': futureTime.toIso8601String(), // Clock was in the future
      });
      final prefs = await SharedPreferences.getInstance();

      final info = await service.checkAsync(prefs);

      expect(info.status, LicenseStatus.tampered);
      expect(info.isExpired, isTrue);
    });

    test('Device mismatch: copied preferences file on another machine triggers deviceMismatch', () async {
      final validKey = LicenseCore.generateAnnualKey(DateTime.now().add(const Duration(days: 100)));
      SharedPreferences.setMockInitialValues({
        'lic_key': validKey,
        'lic_bound_hw_id': 'NMAS-ANOTHER-MACHINE',
        'lic_last_known_time': DateTime.now().toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final info = await service.checkAsync(prefs);

      expect(info.status, LicenseStatus.deviceMismatch);
      expect(info.isExpired, isTrue);
    });

    test('Activation with valid universal key succeeds and stores binding', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final validKey = LicenseCore.generateAnnualKey(DateTime.now().add(const Duration(days: 180)));
      final res = await service.activateAsync(validKey, prefs);

      expect(res.result, LicenseActivationResult.success);
      expect(res.info, isNotNull);
      expect(res.info!.isLicensed, isTrue);
      expect(prefs.getString('lic_key'), validKey);
      expect(prefs.getString('lic_bound_hw_id'), testHwId);

      // Verify checkAsync now returns licensed
      final checkInfo = await service.checkAsync(prefs);
      expect(checkInfo.isLicensed, isTrue);
    });

    test('Activation with valid hardware-bound key succeeds for this machine', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final boundKey = LicenseCore.generateHardwareBoundKey(
        hardwareId: testHwId,
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );
      final res = await service.activateAsync(boundKey, prefs);

      expect(res.result, LicenseActivationResult.success);
      expect(res.info, isNotNull);
      expect(res.info!.isLicensed, isTrue);
    });

    test('Activation with hardware-bound key for another machine fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final foreignKey = LicenseCore.generateHardwareBoundKey(
        hardwareId: 'NMAS-DIFFERENT-PC',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );
      final res = await service.activateAsync(foreignKey, prefs);

      expect(res.result, LicenseActivationResult.invalidKey);
      expect(prefs.getString('lic_key'), isNull);
    });

    test('Activation with expired key returns expiredKey result', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final expiredKey = LicenseCore.generateAnnualKey(DateTime.now().subtract(const Duration(days: 1)));
      final res = await service.activateAsync(expiredKey, prefs);

      expect(res.result, LicenseActivationResult.expiredKey);
    });

    test('resetLicense clears all stored license data', () async {
      final validKey = LicenseCore.generateAnnualKey(DateTime.now().add(const Duration(days: 100)));
      SharedPreferences.setMockInitialValues({
        'lic_key': validKey,
        'lic_bound_hw_id': testHwId,
        'lic_first_launch': DateTime.now().toIso8601String(),
        'lic_last_known_time': DateTime.now().toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      await service.resetLicense(prefs);

      expect(prefs.getString('lic_key'), isNull);
      expect(prefs.getString('lic_bound_hw_id'), isNull);
      expect(prefs.getString('lic_first_launch'), isNull);
      expect(prefs.getString('lic_last_known_time'), isNull);
    });

    test('Corrupted 2020 first_launch automatically heals to active trial when not revoked by admin', () async {
      SharedPreferences.setMockInitialValues({
        'lic_first_launch': DateTime(2020, 1, 1).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final info = await service.checkAsync(prefs);
      expect(info.isTrial, isTrue);
      expect(info.daysLeft, 7);
      expect(info.isExpired, isFalse);
    });

    test('First launch in 2020 remains expired if legitimately revoked by admin', () async {
      SharedPreferences.setMockInitialValues({
        'lic_first_launch': DateTime(2020, 1, 1).toIso8601String(),
        'lic_was_revoked_by_admin': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final info = await service.checkAsync(prefs);
      expect(info.isExpired, isTrue);
      expect(info.daysLeft, 0);
    });
  });
}
