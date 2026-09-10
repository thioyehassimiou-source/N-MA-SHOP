import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/hardware_id_service.dart';
import 'license_admin_sync_service.dart';
import 'license_core.dart';
import 'license_model.dart';

/// Service complet de gestion, vérification et activation des licences N'MaShop.
///
/// Intègre :
/// 1. Stockage sécurisé des préférences de licence.
/// 2. Validation hybride (signature HMAC localement & extensible à distance).
/// 3. Empreinte unique de l'appareil (Device Binding via HardwareIdService).
/// 4. Protection anti-triche de la date (Anti-Tamper / Uptime Checkpoint).
/// 5. Période d'essai gratuite de 7 jours & Verrouillage instantané.
class LicenseService {
  // ── Paramètres ─────────────────────────────────────────────────────────────
  static const String _prefFirstLaunch = 'lic_first_launch';
  static const String _prefKey = 'lic_key';
  static const String _prefBoundHwId = 'lic_bound_hw_id';
  static const String _prefLastKnownTime = 'lic_last_known_time';

  // ── Vérification au démarrage & contrôle anti-triche ──────────────────────

  /// Calcule le statut courant de la licence avec contrôle de triche de date et empreinte matérielle.
  Future<LicenseInfo> checkAsync(SharedPreferences prefs) async {
    final now = DateTime.now();

    // ── 1. Protection Anti-Triche de la Date (Anti-Tamper) ───────────────────
    final lastTimeStr = prefs.getString(_prefLastKnownTime);
    if (lastTimeStr != null) {
      final lastTime = DateTime.tryParse(lastTimeStr);
      if (lastTime != null && now.isBefore(lastTime.subtract(const Duration(minutes: 5)))) {
        // L'utilisateur a reculé la date de son ordinateur !
        return const LicenseInfo(
          status: LicenseStatus.tampered,
          type: LicenseType.trial,
          daysLeft: 0,
        );
      }
    }

    // Mettre à jour le point de contrôle de date
    await prefs.setString(_prefLastKnownTime, now.toIso8601String());

    // ── 2. Récupération de l'ID Matériel du PC (Device Binding) ─────────────
    final hwId = await HardwareIdService.getHardwareId();

    // ── 3. Clé activée présente ? ────────────────────────────────────────────
    final stored = prefs.getString(_prefKey);
    if (stored != null) {
      final wasRevokedByAdmin = prefs.getBool('lic_was_revoked_by_admin') ?? false;
      if (wasRevokedByAdmin) {
        return const LicenseInfo(
          status: LicenseStatus.expired,
          type: LicenseType.trial,
          daysLeft: 0,
        );
      }

      final boundHwId = prefs.getString(_prefBoundHwId);
      if (boundHwId != null && boundHwId != hwId) {
        // La licence / fichier de config a été copié sur une autre machine !
        return const LicenseInfo(
          status: LicenseStatus.deviceMismatch,
          type: LicenseType.trial,
          daysLeft: 0,
        );
      }

      final info = LicenseCore.validateKey(stored, deviceHwId: hwId);
      if (info != null) return info;

      // Vérifier si la clé enregistrée est authentique mais dédiée à un autre appareil
      final parts = stored.trim().toUpperCase().split('-');
      if (parts.length == 4 && parts[0] == 'NMAS') {
        final keyHwHash = parts[1];
        final expiryStr = parts[2];
        final hmac = parts[3];
        final expectedHmac = LicenseCore.generateHmac('NMAS-$keyHwHash-$expiryStr');
        if (hmac == expectedHmac) {
          return const LicenseInfo(
            status: LicenseStatus.deviceMismatch,
            type: LicenseType.trial,
            daysLeft: 0,
          );
        }
      }

      // Clé invalide ou falsifiée → suppression
      await prefs.remove(_prefKey);
      await prefs.remove(_prefBoundHwId);
    }

    // ── 4. Période d'Essai (7 Jours) ─────────────────────────────────────────
    final firstLaunchStr = prefs.getString(_prefFirstLaunch);
    DateTime? firstLaunch = firstLaunchStr != null ? DateTime.tryParse(firstLaunchStr) : null;

    // Récupération automatique si la date d'essai a été corrompue à 2020 par le bug précédent
    // sans qu'aucune clé n'ait réellement été révoquée par l'administrateur
    final wasRevokedByAdmin = prefs.getBool('lic_was_revoked_by_admin') ?? false;
    if (firstLaunch != null && firstLaunch.year <= 2020 && !wasRevokedByAdmin) {
      firstLaunch = null;
      await prefs.remove(_prefFirstLaunch);
    }

    // Protection anti-réinitialisation hors-ligne : vérifier l'ancre de sécurité locale
    if (firstLaunch == null && !wasRevokedByAdmin) {
      final anchorDate = await _readSecurityAnchor(hwId);
      if (anchorDate != null) {
        firstLaunch = anchorDate;
        await prefs.setString(_prefFirstLaunch, firstLaunch.toIso8601String());
      }
    }

    if (firstLaunch == null) {
      // Premier lancement légitime
      await prefs.setString(_prefFirstLaunch, now.toIso8601String());
      await _writeSecurityAnchor(now.toIso8601String(), hwId);
      final expiry = LicenseCore.computeTrialExpiry(now);
      return LicenseInfo(
        status: LicenseStatus.trial,
        type: LicenseType.trial,
        expiryDate: expiry,
        daysLeft: LicenseCore.trialDays,
      );
    } else {
      // Maintenir l'ancre synchronisée
      await _writeSecurityAnchor(firstLaunch.toIso8601String(), hwId);
    }

    final expiry = LicenseCore.computeTrialExpiry(firstLaunch);

    if (now.isBefore(expiry)) {
      final days = expiry.difference(now).inDays + 1;
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

  /// Version synchrone de démarrage rapide (fallback).
  LicenseInfo check(SharedPreferences prefs) {
    final stored = prefs.getString(_prefKey);
    if (stored != null) {
      final wasRevokedByAdmin = prefs.getBool('lic_was_revoked_by_admin') ?? false;
      if (wasRevokedByAdmin) {
        return const LicenseInfo(
          status: LicenseStatus.expired,
          type: LicenseType.trial,
          daysLeft: 0,
        );
      }
      final info = LicenseCore.validateKey(stored);
      if (info != null) return info;
    }

    final firstLaunchStr = prefs.getString(_prefFirstLaunch);
    final now = DateTime.now();
    DateTime? firstLaunch = firstLaunchStr != null ? DateTime.tryParse(firstLaunchStr) : null;

    final wasRevokedByAdmin = prefs.getBool('lic_was_revoked_by_admin') ?? false;
    if (firstLaunch != null && firstLaunch.year <= 2020 && !wasRevokedByAdmin) {
      firstLaunch = null;
    }

    if (firstLaunch == null) {
      return LicenseInfo(
        status: LicenseStatus.trial,
        type: LicenseType.trial,
        expiryDate: LicenseCore.computeTrialExpiry(now),
        daysLeft: LicenseCore.trialDays,
      );
    }

    final expiry = LicenseCore.computeTrialExpiry(firstLaunch);

    if (now.isBefore(expiry)) {
      return LicenseInfo(
        status: LicenseStatus.trial,
        type: LicenseType.trial,
        expiryDate: expiry,
        daysLeft: (expiry.difference(now).inDays + 1).clamp(0, LicenseCore.trialDays),
      );
    }

    return LicenseInfo(
      status: LicenseStatus.expired,
      type: LicenseType.trial,
      expiryDate: expiry,
      daysLeft: 0,
    );
  }

  // ── Activation avec validation d'appareil ──────────────────────────────────

  /// Tente d'activer une clé saisie par l'utilisateur.
  Future<({LicenseActivationResult result, LicenseInfo? info})> activateAsync(
    String rawKey,
    SharedPreferences prefs,
  ) async {
    final hwId = await HardwareIdService.getHardwareId();
    final info = LicenseCore.validateKey(rawKey, deviceHwId: hwId);

    if (info == null) {
      // Vérifier si la clé est authentique mais générée pour un autre ordinateur
      final parts = rawKey.trim().toUpperCase().split('-');
      if (parts.length == 4 && parts[0] == 'NMAS') {
        final keyHwHash = parts[1];
        final expiryStr = parts[2];
        final hmac = parts[3];
        final expectedHmac = LicenseCore.generateHmac('NMAS-$keyHwHash-$expiryStr');
        if (hmac == expectedHmac) {
          return (result: LicenseActivationResult.deviceMismatch, info: null);
        }
      }
      return (result: LicenseActivationResult.invalidKey, info: null);
    }

    if (info.isExpired) {
      return (result: LicenseActivationResult.expiredKey, info: info);
    }

    await prefs.setString(_prefKey, rawKey.trim().toUpperCase());
    await prefs.setString(_prefBoundHwId, hwId);
    await prefs.remove('lic_was_revoked_by_admin');
    return (result: LicenseActivationResult.success, info: info);
  }

  /// Wrapper synchrone pour la transition.
  ({LicenseActivationResult result, LicenseInfo? info}) activate(
    String rawKey,
    SharedPreferences prefs,
  ) {
    final info = LicenseCore.validateKey(rawKey);
    if (info == null) {
      final parts = rawKey.trim().toUpperCase().split('-');
      if (parts.length == 4 && parts[0] == 'NMAS') {
        final keyHwHash = parts[1];
        final expiryStr = parts[2];
        final hmac = parts[3];
        final expectedHmac = LicenseCore.generateHmac('NMAS-$keyHwHash-$expiryStr');
        if (hmac == expectedHmac) {
          return (result: LicenseActivationResult.deviceMismatch, info: null);
        }
      }
      return (result: LicenseActivationResult.invalidKey, info: null);
    }
    if (info.isExpired) {
      return (result: LicenseActivationResult.expiredKey, info: info);
    }
    prefs.setString(_prefKey, rawKey.trim().toUpperCase());
    prefs.remove('lic_was_revoked_by_admin');
    return (result: LicenseActivationResult.success, info: info);
  }

  /// Efface la clé enregistrée et réinitialise l'état de la licence PC.
  Future<void> resetLicense(SharedPreferences prefs) async {
    final hwId = await HardwareIdService.getHardwareId();
    final storedKey = prefs.getString(_prefKey);

    await prefs.remove(_prefKey);
    await prefs.remove(_prefBoundHwId);
    await prefs.remove(_prefFirstLaunch);
    await prefs.remove(_prefLastKnownTime);
    await prefs.remove('lic_was_revoked_by_admin');

    try {
      final file = await _getSecurityAnchorFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    // Notifier la désactivation uniquement si une vraie clé payante était présente
    if (storedKey != null && storedKey.isNotEmpty && !storedKey.startsWith('TRIAL-')) {
      LicenseAdminSyncService.notifyDeactivation(hwId, licenseKey: storedKey);
    }
  }

  /// Révoque la licence à la demande de l'administrateur (désactivation à distance depuis Mobile Admin).
  /// Verrouille l'application en état expiré mais CONSERVE la clé pour permettre la réactivation distante ultérieure.
  Future<void> revokeLicense(SharedPreferences prefs) async {
    await prefs.setBool('lic_was_revoked_by_admin', true);
    final pastDate = DateTime(2020, 1, 1).toIso8601String();
    await prefs.setString(_prefFirstLaunch, pastDate);
    final hwId = await HardwareIdService.getHardwareId();
    await _writeSecurityAnchor(pastDate, hwId);
  }

  /// Réactive la licence locale suite à la réactivation par l'administrateur.
  Future<void> unrevokeLicense(SharedPreferences prefs) async {
    await prefs.remove('lic_was_revoked_by_admin');
    final firstLaunchStr = prefs.getString(_prefFirstLaunch);
    final hwId = await HardwareIdService.getHardwareId();
    if (firstLaunchStr != null) {
      final parsed = DateTime.tryParse(firstLaunchStr);
      if (parsed != null && parsed.year <= 2020) {
        final nowStr = DateTime.now().toIso8601String();
        await prefs.setString(_prefFirstLaunch, nowStr);
        await _writeSecurityAnchor(nowStr, hwId);
      }
    }
  }

  // ── Ancre de sécurité locale (Anti-réinitialisation hors-ligne) ─────────────

  static Future<File?> _getSecurityAnchorFile() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      return File('${appDir.path}/.nma_sys_sec');
    } catch (_) {
      return null;
    }
  }

  static String _generateAnchorChecksum(String firstLaunch, String hwId) {
    return LicenseCore.generateHmac('ANCHOR-$firstLaunch-$hwId');
  }

  static Future<void> _writeSecurityAnchor(String firstLaunch, String hwId) async {
    try {
      final file = await _getSecurityAnchorFile();
      if (file == null) return;
      final checksum = _generateAnchorChecksum(firstLaunch, hwId);
      final content = '$firstLaunch#$hwId#$checksum';
      await file.writeAsString(base64Encode(utf8.encode(content)));
    } catch (_) {}
  }

  static Future<DateTime?> _readSecurityAnchor(String hwId) async {
    try {
      final file = await _getSecurityAnchorFile();
      if (file == null || !await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = utf8.decode(base64Decode(raw.trim()));
      final parts = decoded.split('#');
      if (parts.length == 3) {
        final dateStr = parts[0];
        final fileHwId = parts[1];
        final checksum = parts[2];
        if (fileHwId == hwId && checksum == _generateAnchorChecksum(dateStr, fileHwId)) {
          return DateTime.tryParse(dateStr);
        }
      }
    } catch (_) {}
    return null;
  }
}
