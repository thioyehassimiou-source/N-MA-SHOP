import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../config/env.dart';

/// Moteur cryptographique de génération de clés de licence N'MaShop.
///
/// Produit des clés de licence liées de façon univoque au Hardware ID
/// du PC du client (ou des clés universelles) avec signature HMAC-SHA256.
abstract final class LicenseCryptoEngine {
  static String get localSecuritySalt => Env.licenseSecuritySalt;

  static String get _f1 => Env.licenseSecretF1;
  static String get _f2 => Env.licenseSecretF2;
  static String get _f3 => Env.licenseSecretF3;
  static String get _f4 => Env.licenseSecretF4;
  static String get _f5 => Env.licenseSecretF5;
  static String get secret => '$_f1$_f2$_f3$_f4$_f5#$localSecuritySalt';

  /// Calcule l'empreinte courte (4 caractères) du Hardware ID PC.
  static String generateHwHash(String hardwareId) {
    final cleanId = hardwareId.trim().toUpperCase();
    final bytes = utf8.encode('$cleanId#$localSecuritySalt');
    return sha256.convert(bytes).toString().substring(0, 4).toUpperCase();
  }

  /// Génère le condensat HMAC-SHA256 (8 caractères).
  static String generateHmac(String payload) {
    final mac = Hmac(sha256, utf8.encode(secret));
    return mac.convert(utf8.encode(payload)).toString().substring(0, 8).toUpperCase();
  }

  /// Génère une clé liée au Hardware ID du PC du client.
  /// Format: NMAS-[HW_HASH]-[YYYYMMDD]-[HMAC]
  static String generateHardwareBoundKey({
    required String hardwareId,
    required DateTime expiryDate,
  }) {
    final hwHash = generateHwHash(hardwareId);
    final dateStr = '${expiryDate.year.toString().padLeft(4, '0')}'
        '${expiryDate.month.toString().padLeft(2, '0')}'
        '${expiryDate.day.toString().padLeft(2, '0')}';
    final payload = 'NMAS-$hwHash-$dateStr';
    final hmac = generateHmac(payload);
    return 'NMAS-$hwHash-$dateStr-$hmac';
  }

  /// Génère une clé liée au Hardware ID pour une licence À VIE (expiration 9999-12-31).
  static String generateHardwareBoundLifetimeKey(String hardwareId) {
    return generateHardwareBoundKey(
      hardwareId: hardwareId,
      expiryDate: DateTime(9999, 12, 31),
    );
  }

  /// Génère une clé universelle (non liée à un PC spécifique).
  static String generateUniversalKey(DateTime expiryDate) {
    final dateStr = '${expiryDate.year.toString().padLeft(4, '0')}'
        '${expiryDate.month.toString().padLeft(2, '0')}'
        '${expiryDate.day.toString().padLeft(2, '0')}';
    final payload = 'NMAS-$dateStr';
    final hmac = generateHmac(payload);
    return 'NMAS-$dateStr-$hmac';
  }
}
