import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
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

    final wasRevokedByAdmin = prefs.getBool('lic_was_revoked_by_admin') ?? false;
    if (firstLaunch != null && firstLaunch.year <= 2020 && !wasRevokedByAdmin) {
      firstLaunch = null;
      await prefs.remove(_prefFirstLaunch);
    }

    // Protection anti-réinitialisation avancée : collecter toutes les sources locales
    if (!wasRevokedByAdmin) {
      final List<DateTime> candidates = [];
      if (firstLaunch != null) candidates.add(firstLaunch);

      final primaryAnchor = await _readSecurityAnchor(hwId);
      if (primaryAnchor != null) candidates.add(primaryAnchor);

      final secondaryAnchor = await _readSecondaryAnchor(hwId);
      if (secondaryAnchor != null) candidates.add(secondaryAnchor);

      final dbAnchor = await _readDatabaseTrialAnchor();
      if (dbAnchor != null) candidates.add(dbAnchor);

      if (candidates.isNotEmpty) {
        // La date retenue est obligatoirement la PLUS ANCIENNE parmi toutes les sources
        firstLaunch = candidates.reduce((a, b) => a.isBefore(b) ? a : b);
      }
      await _cleanUpLegacyFiles();
    }

    if (firstLaunch == null) {
      // Premier lancement légitime absolu
      await prefs.setString(_prefFirstLaunch, now.toIso8601String());
      await _writeSecurityAnchor(now.toIso8601String(), hwId);
      await _writeSecondaryAnchor(now.toIso8601String(), hwId);
      await _writeDatabaseTrialAnchor(now.toIso8601String());
      final expiry = LicenseCore.computeTrialExpiry(now);
      return LicenseInfo(
        status: LicenseStatus.trial,
        type: LicenseType.trial,
        expiryDate: expiry,
        daysLeft: LicenseCore.trialDays,
      );
    } else {
      // Maintenir toutes les ancres synchronisées avec la date la plus ancienne
      final dateStr = firstLaunch.toIso8601String();
      await prefs.setString(_prefFirstLaunch, dateStr);
      await _writeSecurityAnchor(dateStr, hwId);
      await _writeSecondaryAnchor(dateStr, hwId);
      await _writeDatabaseTrialAnchor(dateStr);
    }

    final expiry = LicenseCore.computeTrialExpiry(firstLaunch);

    if (now.isBefore(expiry)) {
      final diff = expiry.difference(now);
      final days = diff.inDays;
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
        daysLeft: expiry.difference(now).inDays.clamp(0, LicenseCore.trialDays),
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

    if (info.isExpired || info.isGracePeriod) {
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
    if (info.isExpired || info.isGracePeriod) {
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
    _cachedDbTrialAnchor = null;

    try {
      final file = await _getSecurityAnchorFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
      final secFile = _getSecondaryMirrorAnchorFile();
      if (secFile != null && await secFile.exists()) {
        await secFile.delete();
      }
      final appDir = await getApplicationSupportDirectory();
      final legacy = File(p.join(appDir.path, '.nma_sys_sec'));
      if (await legacy.exists()) {
        await legacy.delete();
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
    await _writeSecondaryAnchor(pastDate, hwId);
    await _writeDatabaseTrialAnchor(pastDate);
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
        await _writeSecondaryAnchor(nowStr, hwId);
        await _writeDatabaseTrialAnchor(nowStr);
      }
    }
  }

  // ── Ancre de sécurité système furtive (Totalement hors du dossier boutique) ────

  static Future<File?> _getSecurityAnchorFile() async {
    try {
      // 1. Emplacement furtif au niveau du cache OS (totalement hors du dossier boutique)
      if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          final cacheDir = Directory(p.join(home, '.cache'));
          if (cacheDir.existsSync()) {
            return File(p.join(cacheDir.path, '.sys_font_registry.bin'));
          }
          return File(p.join(home, '.sys_font_registry.bin'));
        }
      } else if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'];
        if (localAppData != null && localAppData.isNotEmpty) {
          return File(p.join(localAppData, '.sys_device_meta.bin'));
        }
      }
      final appDir = await getApplicationSupportDirectory();
      return File(p.join(appDir.path, '.sys_font_registry.bin'));
    } catch (_) {
      return null;
    }
  }

  static File? _getSecondaryMirrorAnchorFile() {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          final configDir = Directory(p.join(home, '.config'));
          if (configDir.existsSync()) {
            return File(p.join(configDir.path, '.device_profile_cache'));
          }
          return File(p.join(home, '.device_profile_cache'));
        }
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'] ?? Platform.environment['USERPROFILE'];
        if (appData != null && appData.isNotEmpty) {
          return File(p.join(appData, '.user_state_cache'));
        }
      }
    } catch (_) {}
    return null;
  }

  static String _generateAnchorChecksum(String firstLaunch, String hwId) {
    return LicenseCore.generateHmac('ANCHOR-$firstLaunch-$hwId');
  }

  /// Nettoie et supprime définitivement tous les dossiers et fichiers de sécurité
  /// visibles ou suspects qui se trouvaient dans le dossier de la boutique.
  static Future<void> _cleanUpLegacyFiles() async {
    try {
      final appDir = await getApplicationSupportDirectory();

      // 1. Supprimer l'ancien dossier .sys_cache dans le dossier de la boutique
      final stealthDir = Directory(p.join(appDir.path, '.sys_cache'));
      if (await stealthDir.exists()) {
        try {
          await stealthDir.delete(recursive: true);
        } catch (_) {}
      }

      // 2. Supprimer l'ancien fichier .nma_sys_sec dans le dossier de la boutique
      final legacyAppFile = File(p.join(appDir.path, '.nma_sys_sec'));
      if (await legacyAppFile.exists()) {
        try {
          await legacyAppFile.delete();
        } catch (_) {}
      }

      // 3. Supprimer les anciens fichiers résiduels gescompta
      for (final name in ['gescompta.sqlite', 'gescompta.sqlite-wal', 'gescompta.sqlite-shm']) {
        final f = File(p.join(appDir.path, name));
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }

      // 4. Supprimer les anciens fichiers évidents dans le profil OS
      if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          final oldConfig = File(p.join(home, '.config', '.nma_hw_sec'));
          if (await oldConfig.exists()) {
            try {
              await oldConfig.delete();
            } catch (_) {}
          }
          final oldHome = File(p.join(home, '.nma_hw_sec'));
          if (await oldHome.exists()) {
            try {
              await oldHome.delete();
            } catch (_) {}
          }
        }
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'] ?? Platform.environment['USERPROFILE'];
        if (appData != null && appData.isNotEmpty) {
          final oldWin = File(p.join(appData, '.nma_hw_sec'));
          if (await oldWin.exists()) {
            try {
              await oldWin.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> _writeSecurityAnchor(String firstLaunch, String hwId) async {
    try {
      final file = await _getSecurityAnchorFile();
      if (file == null) return;
      final checksum = _generateAnchorChecksum(firstLaunch, hwId);
      final content = '$firstLaunch#$hwId#$checksum';
      await file.writeAsString(base64Encode(utf8.encode(content)));

      // Nettoyer définitivement les anciens fichiers et dossiers dans le dossier boutique
      await _cleanUpLegacyFiles();
    } catch (_) {}
  }

  static Future<DateTime?> _readSecurityAnchor(String hwId) async {
    try {
      final file = await _getSecurityAnchorFile();
      File? target = file;
      if (target == null || !await target.exists()) {
        // Migration rétro-compatible : vérifier les anciens emplacements
        final appDir = await getApplicationSupportDirectory();
        final legacyCache = File(p.join(appDir.path, '.sys_cache', '.hw_device_blob.bin'));
        final legacyFile = File(p.join(appDir.path, '.nma_sys_sec'));
        if (await legacyCache.exists()) {
          target = legacyCache;
        } else if (await legacyFile.exists()) {
          target = legacyFile;
        } else {
          return null;
        }
      }

      final raw = await target.readAsString();
      final decoded = utf8.decode(base64Decode(raw.trim()));
      final parts = decoded.split('#');
      if (parts.length == 3) {
        final dateStr = parts[0];
        final fileHwId = parts[1];
        final checksum = parts[2];
        if (fileHwId == hwId && checksum == _generateAnchorChecksum(dateStr, fileHwId)) {
          // Si lu depuis un ancien emplacement : migrer vers le nouveau fichier OS et supprimer l'ancien
          if (file != null && target.path != file.path) {
            await _writeSecurityAnchor(dateStr, hwId);
            await _cleanUpLegacyFiles();
          }
          return DateTime.tryParse(dateStr);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _writeSecondaryAnchor(String firstLaunch, String hwId) async {
    try {
      final file = _getSecondaryMirrorAnchorFile();
      if (file == null) return;
      final checksum = _generateAnchorChecksum(firstLaunch, hwId);
      final content = '$firstLaunch#$hwId#$checksum';
      await file.writeAsString(base64Encode(utf8.encode(content)));
    } catch (_) {}
  }

  static Future<DateTime?> _readSecondaryAnchor(String hwId) async {
    try {
      final file = _getSecondaryMirrorAnchorFile();
      File? target = file;
      if (target == null || !await target.exists()) {
        // Migration rétro-compatible : vérifier l'ancien .nma_hw_sec
        if (Platform.isLinux || Platform.isMacOS) {
          final home = Platform.environment['HOME'];
          if (home != null && home.isNotEmpty) {
            final old = File(p.join(home, '.config', '.nma_hw_sec'));
            if (await old.exists()) {
              target = old;
            }
          }
        }
        if (target == null || !await target.exists()) return null;
      }

      final raw = await target.readAsString();
      final decoded = utf8.decode(base64Decode(raw.trim()));
      final parts = decoded.split('#');
      if (parts.length == 3) {
        final dateStr = parts[0];
        final fileHwId = parts[1];
        final checksum = parts[2];
        if (fileHwId == hwId && checksum == _generateAnchorChecksum(dateStr, fileHwId)) {
          if (file != null && target.path != file.path) {
            await _writeSecondaryAnchor(dateStr, hwId);
            try {
              await target.delete();
            } catch (_) {}
          }
          return DateTime.tryParse(dateStr);
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Ancre de sécurité dans la base SQLite locale (Anti-réinitialisation) ─────

  static DateTime? _cachedDbTrialAnchor;

  static Future<DateTime?> _readDatabaseTrialAnchor() async {
    if (_cachedDbTrialAnchor != null) {
      return _cachedDbTrialAnchor;
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      var dbFile = File(p.join(appDir.path, 'nmashop.sqlite'));
      if (!await dbFile.exists()) {
        final legacy = File(p.join(appDir.path, 'gescompta.sqlite'));
        if (await legacy.exists()) {
          dbFile = legacy;
        } else {
          return null;
        }
      }

      final db = sqlite3.sqlite3.open(dbFile.path);
      try {
        DateTime? earliestDate;

        // 1. Lire la table système interne si déjà créée
        try {
          final res = db.select("SELECT name FROM sqlite_master WHERE type='table' AND name='_system_meta'");
          if (res.isNotEmpty) {
            final valRes = db.select("SELECT value FROM _system_meta WHERE key = 'trial_start'");
            if (valRes.isNotEmpty && valRes.first['value'] != null) {
              earliestDate = DateTime.tryParse(valRes.first['value'].toString());
            }
          }
        } catch (_) {}

        // 2. Contrôle d'antériorité heuristique sur les données métier existantes
        final checkTables = ['sales', 'products', 'users', 'audit_logs'];
        for (final tbl in checkTables) {
          try {
            final tableExists = db.select("SELECT name FROM sqlite_master WHERE type='table' AND name='$tbl'");
            if (tableExists.isNotEmpty) {
              final minRes = db.select("SELECT MIN(created_at) as min_dt FROM $tbl");
              if (minRes.isNotEmpty && minRes.first['min_dt'] != null) {
                final d = DateTime.tryParse(minRes.first['min_dt'].toString());
                if (d != null) {
                  if (earliestDate == null || d.isBefore(earliestDate)) {
                    earliestDate = d;
                  }
                }
              }
            }
          } catch (_) {}
        }

        _cachedDbTrialAnchor = earliestDate;
        return earliestDate;
      } finally {
        db.close();
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeDatabaseTrialAnchor(String dateStr) async {
    _cachedDbTrialAnchor = DateTime.tryParse(dateStr);
    try {
      final appDir = await getApplicationSupportDirectory();
      var dbFile = File(p.join(appDir.path, 'nmashop.sqlite'));
      if (!await dbFile.exists()) return;

      final db = sqlite3.sqlite3.open(dbFile.path);
      try {
        db.execute('''
          CREATE TABLE IF NOT EXISTS _system_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          );
        ''');
        db.execute(
          "INSERT OR REPLACE INTO _system_meta (key, value) VALUES ('trial_start', ?)",
          [dateStr],
        );
      } finally {
        db.close();
      }
    } catch (_) {}
  }
}
