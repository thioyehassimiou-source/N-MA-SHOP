import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Service d'empreinte matérielle unique (Hardware Fingerprint / Machine ID).
///
/// Génère un identifiant unique basé sur la machine hôte pour lier la licence
/// de manière strictement univoque au PC du client.
abstract final class HardwareIdService {
  static String? _cachedHardwareId;

  /// Renvoie l'identifiant matériel unique du poste (ex: NMA-8F3A-92B1-4C07).
  static Future<String> getHardwareId() async {
    if (_cachedHardwareId != null) return _cachedHardwareId!;

    final hostname = Platform.localHostname;
    final os = Platform.operatingSystem;
    final processors = Platform.numberOfProcessors;
    final userEnv = Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        Platform.environment['HOME'] ??
        'nmashop_client';

    final rawSeed = 'NMA_HW_BINDING_V1#$hostname#$os#$processors#$userEnv';
    final bytes = utf8.encode(rawSeed);
    final digest = sha256.convert(bytes).toString().toUpperCase();

    final formatted =
        'NMA-${digest.substring(0, 4)}-${digest.substring(4, 8)}-${digest.substring(8, 12)}';
    _cachedHardwareId = formatted;
    return formatted;
  }

  /// Vérifie si une clé de licence enregistrée correspond au Hardware ID courant.
  static Future<bool> verifyLicenseKeyForDevice(String licenseKey) async {
    final deviceId = await getHardwareId();
    final deviceHash = sha256.convert(utf8.encode(deviceId)).toString().toUpperCase().substring(0, 8);
    return licenseKey.contains(deviceHash);
  }
}
