import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'license_model.dart';

/// Cœur de la logique de licence N'MaShop.
///
/// Séparé de `license_service.dart` pour pouvoir être exécuté dans un
/// environnement Dart pur (sans Flutter), par exemple pour le script de
/// génération de clés.
class LicenseCore {
  // ── Clé secrète (fragmentée) ───────────────────────────────────────────────
  static const _f1 = 'Nm4';
  static const _f2 = 'Sh0';
  static const _f3 = 'pGN';
  static const _f4 = '3e!';
  static const _f5 = '2025';
  static String get secret => _f1 + _f2 + _f3 + _f4 + _f5;

  // ── Paramètres ─────────────────────────────────────────────────────────────
  static const int trialDays = 7;

  // ── Validation interne ──────────────────────────────────────────────────────

  static LicenseInfo? validateKey(String raw) {
    final key = raw.trim().toUpperCase();
    final parts = key.split('-');
    if (parts.length != 3 || parts[0] != 'NMAS') return null;

    final expiryStr = parts[1]; // YYYYMMDD
    final providedHmac = parts[2];

    if (expiryStr.length != 8) return null;

    final year = int.tryParse(expiryStr.substring(0, 4));
    final month = int.tryParse(expiryStr.substring(4, 6));
    final day = int.tryParse(expiryStr.substring(6, 8));
    if (year == null || month == null || day == null) return null;

    // Vérification HMAC
    final expected = generateHmac('NMAS-$expiryStr');
    if (providedHmac != expected) return null;

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

  static String generateHmac(String payload) {
    final mac = Hmac(sha256, utf8.encode(secret));
    return mac.convert(utf8.encode(payload)).toString().substring(0, 8).toUpperCase();
  }

  static DateTime computeTrialExpiry(DateTime from) =>
      DateTime(from.year, from.month, from.day).add(const Duration(days: trialDays));

  // ── Génération de clés (usage admin uniquement) ─────────────────────────────

  /// Génère une clé annuelle expirant à [expiry].
  static String generateAnnualKey(DateTime expiry) {
    final str = '${expiry.year.toString().padLeft(4, '0')}'
        '${expiry.month.toString().padLeft(2, '0')}'
        '${expiry.day.toString().padLeft(2, '0')}';
    final h = generateHmac('NMAS-$str');
    return 'NMAS-$str-$h';
  }

  /// Génère une clé mensuelle expirant dans 30 jours à partir de [from].
  static String generateMonthlyKey([DateTime? from]) {
    final expiry = (from ?? DateTime.now()).add(const Duration(days: 30));
    return generateAnnualKey(expiry);
  }

  /// Génère une clé à vie (ne s'expire jamais).
  static String generateLifetimeKey() =>
      generateAnnualKey(DateTime(9999, 12, 31));
}
