import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'license_model.dart';

class LicenseValidationResult {
  final bool isValid;
  final LicenseStatus status;
  final LicenseType type;
  final DateTime? expiryDate;
  final int daysLeft;
  final String? errorMessage;

  const LicenseValidationResult({
    required this.isValid,
    required this.status,
    required this.type,
    this.expiryDate,
    required this.daysLeft,
    this.errorMessage,
  });
}

abstract final class LicenseEngine {
  static const String securitySalt = r'\ωaShop_security_salt_2026';
  static const String secret = r'Nm4Sh0pGN3e!2026#\ωaShop_security_salt_2026';

  static const int trialDays = 14;
  static const int offlineGracePeriodDays = 5;

  /// Calcule l'empreinte de 4 caractères pour le Device / Hardware ID.
  static String generateHwHash(String hardwareId) {
    final cleanId = hardwareId.trim().toUpperCase();
    final bytes = utf8.encode('$cleanId#$securitySalt');
    return sha256.convert(bytes).toString().substring(0, 4).toUpperCase();
  }

  /// Génère le condensat HMAC-SHA256 (8 caractères).
  static String generateHmac(String payload) {
    final mac = Hmac(sha256, utf8.encode(secret));
    return mac.convert(utf8.encode(payload)).toString().substring(0, 8).toUpperCase();
  }

  /// Calcule les jours d'essai gratuits restants (sur 14 jours).
  static int computeTrialDaysLeft(DateTime installationDate) {
    final now = DateTime.now();
    final installStart = DateTime(installationDate.year, installationDate.month, installationDate.day);
    final trialEnd = DateTime(installStart.year, installStart.month, installStart.day, 23, 59, 59)
        .add(const Duration(days: trialDays - 1));

    if (now.isAfter(trialEnd)) {
      return 0;
    }

    final diffSeconds = trialEnd.difference(now).inSeconds;
    final days = (diffSeconds / 86400).ceil();
    return days.clamp(0, trialDays);
  }

  /// Valide une clé de licence officielle N'MaShop (NMAS-...).
  static LicenseValidationResult validateKey(String rawKey, {required String deviceId}) {
    final key = rawKey.trim().toUpperCase();
    final parts = key.split('-');

    if (parts.isEmpty || parts[0] != 'NMAS') {
      return const LicenseValidationResult(
        isValid: false,
        status: LicenseStatus.trialExpired,
        type: LicenseType.trial,
        daysLeft: 0,
        errorMessage: 'Format de clé invalide. La clé doit commencer par NMAS-',
      );
    }

    String? keyHwHash;
    String expiryStr;
    String providedHmac;

    if (parts.length == 4) {
      keyHwHash = parts[1];
      expiryStr = parts[2];
      providedHmac = parts[3];
    } else if (parts.length == 3) {
      expiryStr = parts[1];
      providedHmac = parts[2];
    } else {
      return const LicenseValidationResult(
        isValid: false,
        status: LicenseStatus.trialExpired,
        type: LicenseType.trial,
        daysLeft: 0,
        errorMessage: 'Format de clé incomplet ou incorrect.',
      );
    }

    if (expiryStr.length != 8) {
      return const LicenseValidationResult(
        isValid: false,
        status: LicenseStatus.trialExpired,
        type: LicenseType.trial,
        daysLeft: 0,
        errorMessage: 'Date d\'expiration invalide dans la clé.',
      );
    }

    // Vérification de liaison au matériel si la clé est liée
    if (keyHwHash != null) {
      final expectedHash = generateHwHash(deviceId);
      if (keyHwHash != expectedHash) {
        return const LicenseValidationResult(
          isValid: false,
          status: LicenseStatus.trialExpired,
          type: LicenseType.trial,
          daysLeft: 0,
          errorMessage: 'Cette clé de licence est assignée à un autre appareil.',
        );
      }
    }

    final year = int.tryParse(expiryStr.substring(0, 4));
    final month = int.tryParse(expiryStr.substring(4, 6));
    final day = int.tryParse(expiryStr.substring(6, 8));
    if (year == null || month == null || day == null) {
      return const LicenseValidationResult(
        isValid: false,
        status: LicenseStatus.trialExpired,
        type: LicenseType.trial,
        daysLeft: 0,
        errorMessage: 'Date illisible dans la clé.',
      );
    }

    // Vérification de la signature HMAC-SHA256
    final payload = keyHwHash != null ? 'NMAS-$keyHwHash-$expiryStr' : 'NMAS-$expiryStr';
    final expectedHmac = generateHmac(payload);
    if (providedHmac != expectedHmac) {
      return const LicenseValidationResult(
        isValid: false,
        status: LicenseStatus.trialExpired,
        type: LicenseType.trial,
        daysLeft: 0,
        errorMessage: 'Signature cryptographique de licence invalide.',
      );
    }

    final isLifetime = year >= 9999;
    final expiry = DateTime(year, month, day, 23, 59, 59);
    final now = DateTime.now();

    final LicenseType type;
    if (isLifetime) {
      type = LicenseType.lifetime;
    } else {
      final daysFromNow = expiry.difference(now).inDays;
      type = daysFromNow <= 35 ? LicenseType.monthly : LicenseType.annual;
    }

    if (!isLifetime && now.isAfter(expiry)) {
      final graceEnd = DateTime(expiry.year, expiry.month, expiry.day, 23, 59, 59)
          .add(const Duration(days: offlineGracePeriodDays));
      if (now.isBefore(graceEnd)) {
        final graceDaysLeft = graceEnd.difference(now).inDays + 1;
        return LicenseValidationResult(
          isValid: true,
          status: LicenseStatus.commercialGrace,
          type: type,
          expiryDate: expiry,
          daysLeft: graceDaysLeft,
          errorMessage: null,
        );
      }

      return LicenseValidationResult(
        isValid: false,
        status: LicenseStatus.commercialExpired,
        type: type,
        expiryDate: expiry,
        daysLeft: 0,
        errorMessage: 'Cette licence commerciale a expiré.',
      );
    }

    final daysLeft = isLifetime ? 99999 : expiry.difference(now).inDays + 1;
    return LicenseValidationResult(
      isValid: true,
      status: LicenseStatus.commercialActive,
      type: type,
      expiryDate: isLifetime ? null : expiry,
      daysLeft: daysLeft,
      errorMessage: null,
    );
  }

  /// Résout l'état complet de la licence en fonction de la clé enregistrée ou de l'essai gratuit.
  static LicenseInfo resolveLicense({
    required String deviceId,
    required DateTime installationDate,
    String? savedKey,
  }) {
    if (savedKey != null && savedKey.trim().isNotEmpty) {
      final result = validateKey(savedKey, deviceId: deviceId);
      if (result.isValid) {
        return LicenseInfo(
          status: result.status,
          type: result.type,
          expiryDate: result.expiryDate,
          daysLeft: result.daysLeft,
          key: savedKey.trim().toUpperCase(),
          deviceId: deviceId,
          installationDate: installationDate,
        );
      } else if (result.status == LicenseStatus.commercialExpired) {
        return LicenseInfo(
          status: LicenseStatus.commercialExpired,
          type: result.type,
          expiryDate: result.expiryDate,
          daysLeft: 0,
          key: savedKey.trim().toUpperCase(),
          deviceId: deviceId,
          installationDate: installationDate,
        );
      }
    }

    // Calcul de la période d'essai de 14 jours
    final trialDaysLeft = computeTrialDaysLeft(installationDate);
    final isTrialActive = trialDaysLeft > 0;
    final trialEnd = DateTime(installationDate.year, installationDate.month, installationDate.day, 23, 59, 59)
        .add(const Duration(days: trialDays - 1));

    return LicenseInfo(
      status: isTrialActive ? LicenseStatus.trial : LicenseStatus.trialExpired,
      type: LicenseType.trial,
      expiryDate: trialEnd,
      daysLeft: trialDaysLeft,
      key: null,
      deviceId: deviceId,
      installationDate: installationDate,
    );
  }

  /// Génère une clé liée au Hardware ID (utilisable pour tests et validation).
  static String generateHardwareBoundKey({
    required String deviceId,
    required DateTime expiryDate,
  }) {
    final hwHash = generateHwHash(deviceId);
    final dateStr = '${expiryDate.year.toString().padLeft(4, '0')}'
        '${expiryDate.month.toString().padLeft(2, '0')}'
        '${expiryDate.day.toString().padLeft(2, '0')}';
    final payload = 'NMAS-$hwHash-$dateStr';
    final hmac = generateHmac(payload);
    return 'NMAS-$hwHash-$dateStr-$hmac';
  }

  /// Génère une clé universelle (non liée).
  static String generateUniversalKey(DateTime expiryDate) {
    final dateStr = '${expiryDate.year.toString().padLeft(4, '0')}'
        '${expiryDate.month.toString().padLeft(2, '0')}'
        '${expiryDate.day.toString().padLeft(2, '0')}';
    final payload = 'NMAS-$dateStr';
    final hmac = generateHmac(payload);
    return 'NMAS-$dateStr-$hmac';
  }

  /// Génère une clé à vie liée au Device ID.
  static String generateLifetimeKey(String deviceId) {
    return generateHardwareBoundKey(
      deviceId: deviceId,
      expiryDate: DateTime(9999, 12, 31),
    );
  }
}
