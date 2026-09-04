import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../config/env.dart';
import 'license_model.dart';

/// Cœur de la logique cryptographique de licence N'MaShop.
///
/// Implémente la validation HMAC-SHA256, le Device Binding (empreinte unique),
/// et la vérification de péremption des clés.
class LicenseCore {
  // ── Sel de Sécurité Local & Clé secrète ─────────────────────────────────────
  static String get localSecuritySalt => Env.licenseSecuritySalt;
  
  static String get _f1 => Env.licenseSecretF1;
  static String get _f2 => Env.licenseSecretF2;
  static String get _f3 => Env.licenseSecretF3;
  static String get _f4 => Env.licenseSecretF4;
  static String get _f5 => Env.licenseSecretF5;
  static String get secret => '$_f1$_f2$_f3$_f4$_f5#$localSecuritySalt';

  // ── Paramètres ─────────────────────────────────────────────────────────────
  static const int trialDays = 7; // 7 jours d'essai gratuit au premier lancement

  // ── Validation interne ──────────────────────────────────────────────────────

  /// Valide la clé de licence [raw] pour un identifiant matériel donné [deviceHwId].
  static LicenseInfo? validateKey(String raw, {String? deviceHwId}) {
    final key = raw.trim().toUpperCase();
    final parts = key.split('-');
    
    // Format 1 : NMAS-HWID-YYYYMMDD-HMAC (Clé liée au matériel - 4 parties)
    // Format 2 : NMAS-YYYYMMDD-HMAC (Clé universelle - 3 parties)
    if (parts.isEmpty || parts[0] != 'NMAS') return null;

    String? keyHwIdHash;
    String expiryStr;
    String providedHmac;

    if (parts.length == 4) {
      keyHwIdHash = parts[1];
      expiryStr = parts[2];
      providedHmac = parts[3];
    } else if (parts.length == 3) {
      expiryStr = parts[1];
      providedHmac = parts[2];
    } else {
      return null;
    }

    if (expiryStr.length != 8) return null;

    // Vérification du Device Binding si la clé contient un Hardware ID Hash
    if (keyHwIdHash != null && deviceHwId != null) {
      final expectedHwHash = generateHwHash(deviceHwId);
      if (keyHwIdHash != expectedHwHash) {
        return null; // La licence appartient à une autre machine !
      }
    }

    final year = int.tryParse(expiryStr.substring(0, 4));
    final month = int.tryParse(expiryStr.substring(4, 6));
    final day = int.tryParse(expiryStr.substring(6, 8));
    if (year == null || month == null || day == null) return null;

    // Vérification HMAC-SHA256
    final payload = keyHwIdHash != null ? 'NMAS-$keyHwIdHash-$expiryStr' : 'NMAS-$expiryStr';
    final expectedHmac = generateHmac(payload);
    if (providedHmac != expectedHmac) return null;

    final expiry = DateTime(year, month, day, 23, 59, 59);
    final isLifetime = year >= 9999;
    final type = isLifetime ? LicenseType.lifetime : LicenseType.annual;
    final now = DateTime.now();

    if (!isLifetime && now.isAfter(expiry)) {
      return LicenseInfo(
        status: LicenseStatus.expired,
        type: type,
        expiryDate: expiry,
        daysLeft: 0,
        key: key,
      );
    }

    return LicenseInfo(
      status: LicenseStatus.licensed,
      type: type,
      expiryDate: isLifetime ? null : expiry,
      daysLeft: isLifetime ? null : expiry.difference(now).inDays + 1,
      key: key,
    );
  }

  /// Génère un condensat HMAC-SHA256 pour sécuriser la charge utile.
  static String generateHmac(String payload) {
    final mac = Hmac(sha256, utf8.encode(secret));
    return mac.convert(utf8.encode(payload)).toString().substring(0, 8).toUpperCase();
  }

  /// Extrait le Hash court à 4 caractères de l'Hardware ID pour lier la clé à la machine.
  static String generateHwHash(String hardwareId) {
    final bytes = utf8.encode('$hardwareId#$localSecuritySalt');
    return sha256.convert(bytes).toString().substring(0, 4).toUpperCase();
  }

  static DateTime computeTrialExpiry(DateTime from) =>
      DateTime(from.year, from.month, from.day).add(const Duration(days: trialDays));

  // ── Génération de clés liée à l'Hardware ID (Pour App Admin Mobile) ─────────

  /// Génère une clé liée au Hardware ID du PC d'un client.
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

  /// Génère une clé mensuelle expirant dans 30 jours à partir de [from].
  static String generateMonthlyKey([DateTime? from]) {
    final expiry = (from ?? DateTime.now()).add(const Duration(days: 30));
    return generateAnnualKey(expiry);
  }

  /// Génère une clé annuelle universelle expirant à [expiry].
  static String generateAnnualKey(DateTime expiry) {
    final str = '${expiry.year.toString().padLeft(4, '0')}'
        '${expiry.month.toString().padLeft(2, '0')}'
        '${expiry.day.toString().padLeft(2, '0')}';
    final h = generateHmac('NMAS-$str');
    return 'NMAS-$str-$h';
  }

  /// Génère une clé à vie (ne s'expire jamais).
  static String generateLifetimeKey() =>
      generateAnnualKey(DateTime(9999, 12, 31));
}
