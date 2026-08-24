import 'package:shared_preferences/shared_preferences.dart';

import 'license_core.dart';
import 'license_model.dart';

/// Service de vérification et d'activation des licences N'MaShop.
///
/// Toutes les opérations sont **synchrones** (SharedPreferences est déjà
/// chargé en mémoire au démarrage) et **hors-ligne** : aucun appel réseau.
///
/// L'essentiel de la logique cryptographique est dans [LicenseCore].
class LicenseService {
  // ── Paramètres ─────────────────────────────────────────────────────────────
  static const String _prefFirstLaunch = 'lic_first_launch';
  static const String _prefKey = 'lic_key';

  // ── Vérification au démarrage ───────────────────────────────────────────────

  /// Calcule le statut courant de la licence.
  /// Appelée à chaque démarrage de l'application.
  LicenseInfo check(SharedPreferences prefs) {
    // 1. Clé activée présente ?
    final stored = prefs.getString(_prefKey);
    if (stored != null) {
      final info = LicenseCore.validateKey(stored);
      if (info != null) return info;
      // Clé corrompue → on l'efface silencieusement (async fire-and-forget)
      prefs.remove(_prefKey);
    }

    // 2. Période d'essai
    final now = DateTime.now();
    final firstLaunchStr = prefs.getString(_prefFirstLaunch);

    if (firstLaunchStr == null) {
      // Premier lancement
      prefs.setString(_prefFirstLaunch, now.toIso8601String());
      final expiry = LicenseCore.computeTrialExpiry(now);
      return LicenseInfo(
        status: LicenseStatus.trial,
        type: LicenseType.trial,
        expiryDate: expiry,
        daysLeft: LicenseCore.trialDays,
      );
    }

    final firstLaunch = DateTime.tryParse(firstLaunchStr) ?? now;
    final expiry = LicenseCore.computeTrialExpiry(firstLaunch);

    if (now.isBefore(expiry)) {
      final days = expiry.difference(now).inDays + 1; // +1 = jour en cours
      return LicenseInfo(
        status: LicenseStatus.trial,
        type: LicenseType.trial,
        expiryDate: expiry,
        daysLeft: days.clamp(0, LicenseCore.trialDays),
      );
    }

    // Essai expiré
    return LicenseInfo(
      status: LicenseStatus.expired,
      type: LicenseType.trial,
      expiryDate: expiry,
      daysLeft: 0,
    );
  }

  // ── Activation ──────────────────────────────────────────────────────────────

  /// Tente d'activer une clé saisie par l'utilisateur.
  /// Retourne le résultat d'activation et, en cas de succès, met à jour prefs.
  ({LicenseActivationResult result, LicenseInfo? info}) activate(
    String rawKey,
    SharedPreferences prefs,
  ) {
    final info = LicenseCore.validateKey(rawKey);
    if (info == null) {
      return (result: LicenseActivationResult.invalidKey, info: null);
    }
    if (info.isExpired) {
      return (result: LicenseActivationResult.expiredKey, info: info);
    }
    prefs.setString(_prefKey, rawKey.trim().toUpperCase());
    return (result: LicenseActivationResult.success, info: info);
  }
}
