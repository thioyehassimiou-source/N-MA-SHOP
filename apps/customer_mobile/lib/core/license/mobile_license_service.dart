import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'mobile_license_core.dart';
import 'mobile_license_model.dart';

/// Service de gestion du cycle de vie de la licence sur smartphone.
class MobileLicenseService {
  static const _prefFirstLaunch = 'nmashop_mob_first_launch';
  static const _prefLicenseKey = 'nmashop_mob_lic_key';
  static const _prefHardwareId = 'nmashop_mob_hardware_id';
  static const _prefLastKnownTime = 'nmashop_mob_last_known_time';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Récupère ou génère un identifiant matériel (Hardware ID) unique et pérenne pour ce smartphone.
  /// Format standardisé lisible : NMA-MOB-XXXX-XXXX
  Future<String> getOrCreateHardwareId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_prefHardwareId);

    if (id == null || id.isEmpty) {
      try {
        id = await _secureStorage.read(key: _prefHardwareId);
      } catch (_) {}
    }

    if (id == null || id.isEmpty) {
      // Générer une empreinte stable de 8 caractères hexadécimaux
      final rawUuid = const Uuid().v4().replaceAll('-', '').toUpperCase();
      final p1 = rawUuid.substring(0, 4);
      final p2 = rawUuid.substring(4, 8);
      id = 'NMA-MOB-$p1-$p2';

      await prefs.setString(_prefHardwareId, id);
      try {
        await _secureStorage.write(key: _prefHardwareId, value: id);
      } catch (_) {}
    }

    return id;
  }

  /// Évalue l'état actuel de la licence sur le smartphone.
  Future<MobileLicenseInfo> checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final hwId = await getOrCreateHardwareId();

    // ── 1. Protection Anti-Triche de la Date (Anti-Tamper) ──
    final lastTimeStr = prefs.getString(_prefLastKnownTime);
    if (lastTimeStr != null) {
      final lastTime = DateTime.tryParse(lastTimeStr);
      if (lastTime != null && now.isBefore(lastTime.subtract(const Duration(minutes: 5)))) {
        return MobileLicenseInfo(
          status: MobileLicenseStatus.tampered,
          type: MobileLicenseType.trial,
          daysLeft: 0,
          hardwareId: hwId,
        );
      }
    }
    await prefs.setString(_prefLastKnownTime, now.toIso8601String());

    // ── 2. Vérification d'une clé payée enregistrée ──
    String? storedKey = prefs.getString(_prefLicenseKey);
    if (storedKey == null || storedKey.isEmpty) {
      try {
        storedKey = await _secureStorage.read(key: _prefLicenseKey);
      } catch (_) {}
    }

    if (storedKey != null && storedKey.isNotEmpty) {
      final info = MobileLicenseCore.validateKey(storedKey, hardwareId: hwId);
      if (info != null) {
        return info;
      }
    }

    // ── 3. Gestion de la Période d'Essai Gratuite de 7 Jours ──
    String? firstLaunchStr = prefs.getString(_prefFirstLaunch);
    if (firstLaunchStr == null) {
      firstLaunchStr = now.toIso8601String();
      await prefs.setString(_prefFirstLaunch, firstLaunchStr);
      try {
        await _secureStorage.write(key: _prefFirstLaunch, value: firstLaunchStr);
      } catch (_) {}
    }

    final firstLaunch = DateTime.tryParse(firstLaunchStr) ?? now;
    final trialEnd = firstLaunch.add(const Duration(days: MobileLicenseCore.trialDays));

    if (now.isBefore(trialEnd)) {
      final daysLeft = trialEnd.difference(now).inDays + 1;
      return MobileLicenseInfo(
        status: MobileLicenseStatus.trial,
        type: MobileLicenseType.trial,
        expiryDate: trialEnd,
        daysLeft: daysLeft,
        hardwareId: hwId,
      );
    } else {
      // Période d'essai terminée -> Verrouillage
      return MobileLicenseInfo(
        status: MobileLicenseStatus.expired,
        type: MobileLicenseType.trial,
        expiryDate: trialEnd,
        daysLeft: 0,
        hardwareId: hwId,
      );
    }
  }

  /// Active une clé de licence officielle.
  Future<MobileLicenseActivationResult> activateKey(String rawKey) async {
    final cleanKey = rawKey.trim().toUpperCase();
    if (cleanKey.isEmpty) {
      return MobileLicenseActivationResult(
        isSuccess: false,
        errorMessage: 'Veuillez coller une clé de licence valide.',
      );
    }

    final hwId = await getOrCreateHardwareId();
    final info = MobileLicenseCore.validateKey(cleanKey, hardwareId: hwId);

    if (info == null) {
      // Analyser la cause exacte du rejet pour orienter le boutiquier
      final parts = cleanKey.split('-');
      if (parts.length == 4) {
        final expectedHash = MobileLicenseCore.generateHwHash(hwId);
        if (parts[1] != expectedHash) {
          return MobileLicenseActivationResult(
            isSuccess: false,
            errorMessage: 'Cette clé de licence est enregistrée pour un autre smartphone (ID différent).',
          );
        }
      }
      return MobileLicenseActivationResult(
        isSuccess: false,
        errorMessage: 'Clé de licence invalide ou signature altérée.',
      );
    }

    if (info.status == MobileLicenseStatus.expired) {
      return MobileLicenseActivationResult(
        isSuccess: false,
        errorMessage: 'Cette clé de licence est déjà expirée.',
      );
    }

    // Sauvegarde pérenne de la clé activée
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLicenseKey, cleanKey);
    try {
      await _secureStorage.write(key: _prefLicenseKey, value: cleanKey);
    } catch (_) {}

    return MobileLicenseActivationResult(
      isSuccess: true,
      licenseInfo: info,
    );
  }

  /// Réinitialise la licence enregistrée (pour tests ou changement de propriétaire).
  Future<void> removeLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLicenseKey);
    try {
      await _secureStorage.delete(key: _prefLicenseKey);
    } catch (_) {}
  }
}

class MobileLicenseActivationResult {
  final bool isSuccess;
  final String? errorMessage;
  final MobileLicenseInfo? licenseInfo;

  MobileLicenseActivationResult({
    required this.isSuccess,
    this.errorMessage,
    this.licenseInfo,
  });
}

