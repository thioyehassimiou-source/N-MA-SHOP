import 'package:flutter_test/flutter_test.dart';
import 'package:customer_mobile/core/license/license_engine.dart';
import 'package:customer_mobile/core/license/license_model.dart';
import 'package:customer_mobile/features/settings/data/shop_profile_model.dart';

void main() {
  group('1. LicenseEngine Cryptography & Validation', () {
    const testDeviceId = 'mob-7a8b9c0d';

    test('generateHwHash produces consistent 4-char uppercase hex', () {
      final hash1 = LicenseEngine.generateHwHash(testDeviceId);
      final hash2 = LicenseEngine.generateHwHash('MOB-7A8B9C0D');
      expect(hash1.length, equals(4));
      expect(hash1, equals(hash2));
    });

    test('generateUniversalKey produces valid 3-part key that validates', () {
      final expiry = DateTime.now().add(const Duration(days: 60));
      final key = LicenseEngine.generateUniversalKey(expiry);

      expect(key.startsWith('NMAS-'), isTrue);
      final parts = key.split('-');
      expect(parts.length, equals(3));

      final validation = LicenseEngine.validateKey(key, deviceId: testDeviceId);
      expect(validation.isValid, isTrue);
      expect(validation.status, equals(LicenseStatus.commercialActive));
      expect(validation.type, equals(LicenseType.annual));
      expect(validation.daysLeft, greaterThan(50));
    });

    test('generateHardwareBoundKey binds strictly to deviceId', () {
      final expiry = DateTime.now().add(const Duration(days: 30));
      final boundKey = LicenseEngine.generateHardwareBoundKey(
        deviceId: testDeviceId,
        expiryDate: expiry,
      );

      final parts = boundKey.split('-');
      expect(parts.length, equals(4));
      expect(parts[1], equals(LicenseEngine.generateHwHash(testDeviceId)));

      // Valide sur le bon appareil
      final validOnDevice = LicenseEngine.validateKey(boundKey, deviceId: testDeviceId);
      expect(validOnDevice.isValid, isTrue);
      expect(validOnDevice.status, equals(LicenseStatus.commercialActive));

      // Rejeté sur un autre appareil
      final invalidOnOtherDevice = LicenseEngine.validateKey(boundKey, deviceId: 'mob-different-999');
      expect(invalidOnOtherDevice.isValid, isFalse);
      expect(invalidOnOtherDevice.errorMessage, contains('assignée à un autre appareil'));
    });

    test('generateLifetimeKey creates a lifetime license', () {
      final lifetimeKey = LicenseEngine.generateLifetimeKey(testDeviceId);
      final res = LicenseEngine.validateKey(lifetimeKey, deviceId: testDeviceId);

      expect(res.isValid, isTrue);
      expect(res.type, equals(LicenseType.lifetime));
      expect(res.status, equals(LicenseStatus.commercialActive));
    });

    test('tampered HMAC signature is rejected', () {
      final expiry = DateTime.now().add(const Duration(days: 30));
      final validKey = LicenseEngine.generateUniversalKey(expiry);
      final tamperedKey = '${validKey.substring(0, validKey.length - 2)}00';

      final res = LicenseEngine.validateKey(tamperedKey, deviceId: testDeviceId);
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Signature cryptographique'));
    });
  });

  group('2. Trial Period & POS Locking', () {
    const testDeviceId = 'mob-pos-trial-01';

    test('fresh installation has 14 days free trial and unlocked POS', () {
      final installNow = DateTime.now();
      final daysLeft = LicenseEngine.computeTrialDaysLeft(installNow);
      expect(daysLeft, equals(14));

      final license = LicenseEngine.resolveLicense(
        deviceId: testDeviceId,
        installationDate: installNow,
      );

      expect(license.status, equals(LicenseStatus.trial));
      expect(license.daysLeft, equals(14));
      expect(license.isPosUnlocked, isTrue);
      expect(license.bannerText, contains('14 jours restants'));
    });

    test('installation 10 days ago has 4 days free trial left', () {
      final install10DaysAgo = DateTime.now().subtract(const Duration(days: 10));
      final daysLeft = LicenseEngine.computeTrialDaysLeft(install10DaysAgo);
      expect(daysLeft, equals(4));

      final license = LicenseEngine.resolveLicense(
        deviceId: testDeviceId,
        installationDate: install10DaysAgo,
      );

      expect(license.status, equals(LicenseStatus.trial));
      expect(license.daysLeft, equals(4));
      expect(license.isPosUnlocked, isTrue);
    });

    test('installation 15 days ago has 0 days left and locks POS', () {
      final install15DaysAgo = DateTime.now().subtract(const Duration(days: 15));
      final daysLeft = LicenseEngine.computeTrialDaysLeft(install15DaysAgo);
      expect(daysLeft, equals(0));

      final license = LicenseEngine.resolveLicense(
        deviceId: testDeviceId,
        installationDate: install15DaysAgo,
      );

      expect(license.status, equals(LicenseStatus.trialExpired));
      expect(license.daysLeft, equals(0));
      expect(license.isPosUnlocked, isFalse);
      expect(license.bannerText, contains('Période d\'essai terminée (0 jour restant)'));
    });

    test('commercial license unlocks expired trial POS', () {
      final installExpired = DateTime.now().subtract(const Duration(days: 30));
      final validKey = LicenseEngine.generateHardwareBoundKey(
        deviceId: testDeviceId,
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );

      final license = LicenseEngine.resolveLicense(
        deviceId: testDeviceId,
        installationDate: installExpired,
        savedKey: validKey,
      );

      expect(license.status, equals(LicenseStatus.commercialActive));
      expect(license.isPosUnlocked, isTrue);
      expect(license.bannerText, contains('Licence Commerciale Active'));
    });
  });

  group('3. ShopProfile Model', () {
    test('instantiates with proper defaults', () {
      const profile = ShopProfile();
      expect(profile.shopName, equals('Ma Boutique'));
      expect(profile.managerName, equals('Administrateur'));
      expect(profile.currency, equals('GNF'));
      expect(profile.phoneNumber, isEmpty);
      expect(profile.address, isEmpty);
      expect(profile.logoPath, isNull);
    });

    test('copyWith updates all shop details cleanly', () {
      const initial = ShopProfile();
      final updated = initial.copyWith(
        shopName: 'Supermarché Madina Conakry',
        managerName: 'Ousmane Bah',
        phoneNumber: '+224 624 19 30 69',
        address: 'Madina Marché, Conakry',
        currency: 'USD',
        logoPath: '/data/user/0/shop_logo.png',
      );

      expect(updated.shopName, equals('Supermarché Madina Conakry'));
      expect(updated.managerName, equals('Ousmane Bah'));
      expect(updated.phoneNumber, equals('+224 624 19 30 69'));
      expect(updated.address, equals('Madina Marché, Conakry'));
      expect(updated.currency, equals('USD'));
      expect(updated.logoPath, equals('/data/user/0/shop_logo.png'));
    });
  });
}
