import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../config/env.dart';
import 'mobile_license_model.dart';

/// Moteur cryptographique de validation de licence pour N'MaShop Mobile.
///
/// Implémente la validation stricte HMAC-SHA256 liée à l'empreinte unique
/// du smartphone (Device Binding), 100% hors-ligne.
abstract final class MobileLicenseCore {
  static String get localSecuritySalt => Env.licenseSecuritySalt;

  static String get _f1 => Env.licenseSecretF1;
  static String get _f2 => Env.licenseSecretF2;
  static String get _f3 => Env.licenseSecretF3;
  static String get _f4 => Env.licenseSecretF4;
  static String get _f5 => Env.licenseSecretF5;
  static String get secret => '$_f1$_f2$_f3$_f4$_f5#$localSecuritySalt';

  static const int trialDays = 7;
  static const int offlineGracePeriodDays = 5;

  /// Hash court (4 caractères) lié au Hardware ID du smartphone.
  static String generateHwHash(String hardwareId) {
    final cleanId = hardwareId.trim().toUpperCase();
    final bytes = utf8.encode('$cleanId#$localSecuritySalt');
    return sha256.convert(bytes).toString().substring(0, 4).toUpperCase();
  }

  /// Condensat HMAC-SHA256 (8 caractères).
  static String generateHmac(String payload) {
    final mac = Hmac(sha256, utf8.encode(secret));
    return mac.convert(utf8.encode(payload)).toString().substring(0, 8).toUpperCase();
  }

  /// Valide une clé de licence officielle générée par l'app admin.
  /// Format 1 : NMAS-[HW_HASH]-[YYYYMMDD]-[HMAC] (clé liée au smartphone)
  /// Format 2 : NMAS-[YYYYMMDD]-[HMAC] (clé universelle)
  static MobileLicenseInfo? validateKey(String raw, {required String hardwareId}) {
    final key = raw.trim().toUpperCase();
    final parts = key.split('-');
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

    // Vérification de la liaison matérielle au smartphone (Device Binding)
    if (keyHwIdHash != null) {
      final expectedHash = generateHwHash(hardwareId);
      if (keyHwIdHash != expectedHash) {
        return null; // Cette clé est liée à un autre appareil !
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
    final now = DateTime.now();

    final MobileLicenseType type;
    if (isLifetime) {
      type = MobileLicenseType.lifetime;
    } else {
      final daysDiff = expiry.difference(now).inDays;
      type = daysDiff <= 35 ? MobileLicenseType.monthly : MobileLicenseType.annual;
    }

    if (!isLifetime && now.isAfter(expiry)) {
      // Période de grâce hors-ligne (5 jours)
      final graceEnd = DateTime(expiry.year, expiry.month, expiry.day, 23, 59, 59)
          .add(const Duration(days: offlineGracePeriodDays));
      if (now.isBefore(graceEnd)) {
        final graceDays = graceEnd.difference(now).inDays + 1;
        return MobileLicenseInfo(
          status: MobileLicenseStatus.gracePeriod,
          type: type,
          key: key,
          expiryDate: expiry,
          daysLeft: 0,
          graceDaysLeft: graceDays,
          hardwareId: hardwareId,
        );
      } else {
        return MobileLicenseInfo(
          status: MobileLicenseStatus.expired,
          type: type,
          key: key,
          expiryDate: expiry,
          daysLeft: 0,
          graceDaysLeft: 0,
          hardwareId: hardwareId,
        );
      }
    }

    final daysLeft = isLifetime ? 99999 : expiry.difference(now).inDays + 1;
    return MobileLicenseInfo(
      status: MobileLicenseStatus.active,
      type: type,
      key: key,
      expiryDate: expiry,
      daysLeft: daysLeft,
      hardwareId: hardwareId,
    );
  }
}

