import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Service d'empreinte matérielle unique (Hardware Fingerprint / Machine ID).
///
/// Conçu principalement pour les postes de caisse et PC sous **Windows**
/// (avec fallback de compatibilité pour Linux/macOS).
///
/// Sous Windows, la clé d'identification est extraite directement depuis
/// `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography\MachineGuid`, qui est
/// un GUID immuable et persistant généré à l'installation du système,
/// complété par l'UUID matériel (BIOS/Carte mère) et les caractéristiques CPU.
abstract final class HardwareIdService {
  static String? _cachedHardwareId;

  /// Réinitialise le cache (utile pour les tests automatisés).
  static void resetCacheForTesting([String? mockId]) {
    _cachedHardwareId = mockId;
  }

  /// Renvoie l'identifiant matériel unique du poste (ex: NMA-8F3A-92B1-4C07).
  static Future<String> getHardwareId() async {
    if (_cachedHardwareId != null) return _cachedHardwareId!;

    String machineUniqueToken = '';

    // ── 1. Cible principale : Windows ──────────────────────────────────────────
    if (Platform.isWindows) {
      // Priorité 1 : MachineGuid depuis le Registre Windows (Immuable, unique par installation)
      try {
        final regResult = await Process.run(
          'reg',
          ['query', r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography', '/v', 'MachineGuid'],
          runInShell: true,
        );
        if (regResult.exitCode == 0) {
          final stdout = regResult.stdout.toString();
          final match = RegExp(r'MachineGuid\s+REG_\w+\s+([a-zA-Z0-9\-]+)').firstMatch(stdout);
          if (match != null && match.group(1) != null) {
            machineUniqueToken = match.group(1)!.trim();
          }
        }
      } catch (_) {}

      // Priorité 2 : UUID BIOS / Carte mère via WMIC si le registre est inaccessible
      if (machineUniqueToken.isEmpty) {
        try {
          final wmic = await Process.run('wmic', ['csproduct', 'get', 'uuid'], runInShell: true);
          if (wmic.exitCode == 0) {
            final lines = wmic.stdout.toString().split(RegExp(r'[\r\n]+'));
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && !trimmed.toLowerCase().contains('uuid')) {
                machineUniqueToken = trimmed;
                break;
              }
            }
          }
        } catch (_) {}
      }

      // Priorité 3 : PowerShell Get-CimInstance
      if (machineUniqueToken.isEmpty) {
        try {
          final ps = await Process.run(
            'powershell',
            ['-NoProfile', '-Command', r'(Get-CimInstance Win32_ComputerSystemProduct).UUID'],
            runInShell: true,
          );
          if (ps.exitCode == 0) {
            final out = ps.stdout.toString().trim();
            if (out.isNotEmpty && !out.contains('Error')) {
              machineUniqueToken = out;
            }
          }
        } catch (_) {}
      }
    }
    // ── 2. Environnement secondaire / Linux (Développement) ────────────────────
    else if (Platform.isLinux) {
      try {
        final f1 = File('/etc/machine-id');
        if (await f1.exists()) {
          machineUniqueToken = (await f1.readAsString()).trim();
        } else {
          final f2 = File('/var/lib/dbus/machine-id');
          if (await f2.exists()) {
            machineUniqueToken = (await f2.readAsString()).trim();
          }
        }
      } catch (_) {}
    }

    final hostname = Platform.environment['COMPUTERNAME'] ?? Platform.localHostname;
    final os = Platform.operatingSystem;
    final processors = Platform.numberOfProcessors;
    final procIdentifier = Platform.environment['PROCESSOR_IDENTIFIER'] ?? '';
    final userEnv = Platform.environment['USERNAME'] ??
        Platform.environment['USER'] ??
        Platform.environment['HOME'] ??
        'nmashop_client';

    final rawSeed = 'NMA_HW_BINDING_V1#$machineUniqueToken#$hostname#$os#$processors#$procIdentifier#$userEnv';
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
