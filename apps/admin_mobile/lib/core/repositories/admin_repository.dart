import 'package:shared_preferences/shared_preferences.dart';

import '../models/client_model.dart';
import '../models/license_record.dart';

class AdminRepository {
  static const String _keyClients = 'nma_admin_clients_v1';
  static const String _keyLicenses = 'nma_admin_licenses_v1';
  static const String _keyPin = 'nma_admin_security_pin';

  final SharedPreferences _prefs;

  AdminRepository(this._prefs);

  // ── PIN Auth ────────────────────────────────────────────────────────────────

  String getPin() {
    return _prefs.getString(_keyPin) ?? '1234';
  }

  Future<bool> setPin(String newPin) async {
    return await _prefs.setString(_keyPin, newPin);
  }

  // ── Reset ───────────────────────────────────────────────────────────────────

  Future<void> resetAllData() async {
    await _prefs.remove(_keyClients);
    await _prefs.remove(_keyLicenses);
    await _prefs.remove(_keyPin);
    await _prefs.remove(_keyDeletedLicenses);
    await _prefs.remove(_keyDeletedClients);
  }

  // ── Clients ─────────────────────────────────────────────────────────────────

  List<ClientModel> getClients() {
    final raw = _prefs.getStringList(_keyClients) ?? [];
    return raw.map((str) => ClientModel.fromJson(str)).toList();
  }

  Future<void> saveClient(ClientModel client) async {
    final clients = getClients();
    final index = clients.indexWhere((c) => c.id == client.id);
    if (index >= 0) {
      clients[index] = client;
    } else {
      clients.insert(0, client);
    }
    final raw = clients.map((c) => c.toJson()).toList();
    await _prefs.setStringList(_keyClients, raw);
  }

  static const String _keyDeletedLicenses = 'nma_admin_deleted_licenses_v1';
  static const String _keyDeletedClients = 'nma_admin_deleted_clients_v1';

  // ── Suppression & Tombstones ──────────────────────────────────────────────────

  List<String> getDeletedLicenseKeys() {
    return _prefs.getStringList(_keyDeletedLicenses) ?? [];
  }

  Future<void> addDeletedLicenseKey(String keyOrHwId) async {
    final clean = keyOrHwId.trim().toUpperCase();
    if (clean.isEmpty) return;
    final list = getDeletedLicenseKeys();
    if (!list.contains(clean)) {
      list.add(clean);
      await _prefs.setStringList(_keyDeletedLicenses, list);
    }
  }

  Future<void> removeDeletedLicenseKey(String keyOrHwId) async {
    final clean = keyOrHwId.trim().toUpperCase();
    if (clean.isEmpty) return;
    final list = getDeletedLicenseKeys();
    if (list.contains(clean)) {
      list.remove(clean);
      await _prefs.setStringList(_keyDeletedLicenses, list);
    }
  }

  List<String> getDeletedClientHwIds() {
    return _prefs.getStringList(_keyDeletedClients) ?? [];
  }

  Future<void> addDeletedClientHwId(String hwId) async {
    final clean = hwId.trim().toUpperCase();
    if (clean.isEmpty) return;
    final list = getDeletedClientHwIds();
    if (!list.contains(clean)) {
      list.add(clean);
      await _prefs.setStringList(_keyDeletedClients, list);
    }
  }

  Future<void> removeDeletedClientHwId(String hwId) async {
    final clean = hwId.trim().toUpperCase();
    if (clean.isEmpty) return;
    final list = getDeletedClientHwIds();
    if (list.contains(clean)) {
      list.remove(clean);
      await _prefs.setStringList(_keyDeletedClients, list);
    }
  }

  Future<void> deleteClient(String id) async {
    final clients = getClients();
    final target = clients.where((c) => c.id == id).firstOrNull;
    if (target != null && target.hardwareId.isNotEmpty) {
      await addDeletedClientHwId(target.hardwareId);
    }

    clients.removeWhere((c) => c.id == id);
    final raw = clients.map((c) => c.toJson()).toList();
    await _prefs.setStringList(_keyClients, raw);

    // Supprimer également les licences associées à ce client
    if (target != null) {
      final licenses = getLicenses();
      final targetHw = target.hardwareId.trim().toUpperCase();
      licenses.removeWhere((l) =>
          l.clientId == id ||
          (targetHw.isNotEmpty && l.hardwareId.trim().toUpperCase() == targetHw));
      final rawLic = licenses.map((l) => l.toJson()).toList();
      await _prefs.setStringList(_keyLicenses, rawLic);
    }
  }

  // ── Licences Générées ────────────────────────────────────────────────────────

  List<LicenseRecord> getLicenses() {
    final raw = _prefs.getStringList(_keyLicenses) ?? [];
    final list = raw.map((str) => LicenseRecord.fromJson(str)).toList();
    final deleted = getDeletedLicenseKeys();

    // Dédupliquer rigoureusement par Hardware ID et par Clé
    final Map<String, LicenseRecord> uniqueMap = {};
    for (final record in list) {
      final cleanHwId = record.hardwareId.trim().toUpperCase();
      final cleanKey = record.licenseKey.trim().toUpperCase();

      // Ignorer si supprimé
      if (deleted.contains(cleanKey) || (cleanHwId.isNotEmpty && deleted.contains(cleanHwId))) {
        continue;
      }

      // Utiliser l'empreinte matérielle si disponible comme identifiant unique de poste
      final mapKey = cleanHwId.isNotEmpty ? 'HW:$cleanHwId' : 'KEY:$cleanKey';

      if (!uniqueMap.containsKey(mapKey)) {
        uniqueMap[mapKey] = record;
      } else {
        final existing = uniqueMap[mapKey]!;
        final existingIsTrial = existing.type == AdminLicenseType.trial || existing.licenseKey.startsWith('TRIAL-');
        final recordIsTrial = record.type == AdminLicenseType.trial || record.licenseKey.startsWith('TRIAL-');

        final bool shouldReplace;
        if (existingIsTrial && !recordIsTrial) {
          shouldReplace = true;
        } else if (!existingIsTrial && recordIsTrial) {
          shouldReplace = false;
        } else {
          // Si l'un des deux a été explicitement désactivé, conserver la désactivation
          if (!existing.isActive && record.isActive) {
            shouldReplace = false; // Ne JAMAIS réactiver par écrasement d'un doublon
          } else if (existing.isActive && !record.isActive) {
            shouldReplace = true; // Appliquer la désactivation
          } else {
            shouldReplace = (existing.clientName == 'Boutique Client' && record.clientName != 'Boutique Client') ||
                record.createdAt.isAfter(existing.createdAt);
          }
        }

        if (shouldReplace) {
          uniqueMap[mapKey] = record;
        }
      }
    }
    return uniqueMap.values.toList();
  }

  Future<void> saveLicense(LicenseRecord record) async {
    final licenses = getLicenses();
    final cleanKey = record.licenseKey.trim().toUpperCase();
    final cleanHwId = record.hardwareId.trim().toUpperCase();

    // Recherche par ID, par clé de licence, ou par Hardware ID (si renseigné)
    final index = licenses.indexWhere(
      (l) {
        final sameId = l.id == record.id;
        final sameKey = l.licenseKey.trim().toUpperCase() == cleanKey;
        final sameHw = cleanHwId.isNotEmpty && l.hardwareId.trim().toUpperCase() == cleanHwId;
        return sameId || sameKey || sameHw;
      },
    );

    if (index >= 0) {
      // Conserver l'ID original pour préserver la cohérence des sélections UI
      licenses[index] = record.copyWith(id: licenses[index].id);
    } else {
      licenses.insert(0, record);
    }

    // Supprimer tout doublon résiduel pour cette machine
    if (cleanHwId.isNotEmpty) {
      final preservedId = index >= 0 ? licenses[index].id : record.id;
      licenses.removeWhere((l) =>
          l.id != preservedId &&
          l.hardwareId.trim().toUpperCase() == cleanHwId);
    }

    final raw = licenses.map((l) => l.toJson()).toList();
    await _prefs.setStringList(_keyLicenses, raw);
  }

  Future<void> deleteLicense(String id) async {
    final licenses = getLicenses();
    final target = licenses.where((l) => l.id == id).firstOrNull;
    final cleanKey = target?.licenseKey.trim().toUpperCase();
    final cleanHwId = target?.hardwareId.trim().toUpperCase();

    if (cleanKey != null && cleanKey.isNotEmpty) {
      await addDeletedLicenseKey(cleanKey);
    }
    if (cleanHwId != null && cleanHwId.isNotEmpty) {
      await addDeletedLicenseKey(cleanHwId);
    }

    licenses.removeWhere((l) =>
        l.id == id ||
        (cleanKey != null && cleanKey.isNotEmpty && l.licenseKey.trim().toUpperCase() == cleanKey) ||
        (cleanHwId != null && cleanHwId.isNotEmpty && l.hardwareId.trim().toUpperCase() == cleanHwId));
    final raw = licenses.map((l) => l.toJson()).toList();
    await _prefs.setStringList(_keyLicenses, raw);
  }
}
