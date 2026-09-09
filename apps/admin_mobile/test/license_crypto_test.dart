import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop_admin_mobile/core/license/license_crypto_engine.dart';

void main() {
  group('LicenseCryptoEngine Tests in Admin Mobile', () {
    test('generateUniversalKey produces valid 3-part key', () {
      final expiry = DateTime(2027, 5, 20);
      final key = LicenseCryptoEngine.generateUniversalKey(expiry);

      expect(key.startsWith('NMAS-'), isTrue);
      final parts = key.split('-');
      expect(parts.length, equals(3));
      expect(parts[0], equals('NMAS'));
      expect(parts[1], equals('20270520'));
      expect(parts[2].length, equals(8));
    });

    test('generateHardwareBoundKey produces valid 4-part key with hardware hash', () {
      const hwId = 'NMA-8F3A-92B1-4C07';
      final expiry = DateTime(2027, 5, 20);
      final key = LicenseCryptoEngine.generateHardwareBoundKey(
        hardwareId: hwId,
        expiryDate: expiry,
      );

      expect(key.startsWith('NMAS-'), isTrue);
      final parts = key.split('-');
      expect(parts.length, equals(4));
      expect(parts[0], equals('NMAS'));
      expect(parts[1], equals(LicenseCryptoEngine.generateHwHash(hwId)));
      expect(parts[2], equals('20270520'));
      expect(parts[3].length, equals(8));
    });

    test('generateHardwareBoundLifetimeKey produces 99991231 expiry', () {
      const hwId = 'NMA-1234-5678-9ABC';
      final key = LicenseCryptoEngine.generateHardwareBoundLifetimeKey(hwId);

      final parts = key.split('-');
      expect(parts.length, equals(4));
      expect(parts[2], equals('99991231'));
    });
  });
}
