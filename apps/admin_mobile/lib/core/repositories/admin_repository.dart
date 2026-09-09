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

  Future<void> deleteClient(String id) async {
    final clients = getClients()..removeWhere((c) => c.id == id);
    final raw = clients.map((c) => c.toJson()).toList();
    await _prefs.setStringList(_keyClients, raw);
  }

  // ── Licences Générées ────────────────────────────────────────────────────────

  List<LicenseRecord> getLicenses() {
    final raw = _prefs.getStringList(_keyLicenses) ?? [];
    final list = raw.map((str) => LicenseRecord.fromJson(str)).toList();

    // Dédupliquer automatiquement par clé de licence (insensible à la casse)
    final Map<String, LicenseRecord> uniqueMap = {};
    for (final record in list) {
      final key = record.licenseKey.trim().toUpperCase();
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = record;
      } else {
        // En cas de doublon, on conserve l'enregistrement le plus riche
        // (celui qui a le Hardware ID et qui est activé)
        final existing = uniqueMap[key]!;
        final bool shouldReplace = (existing.hardwareId.isEmpty && record.hardwareId.isNotEmpty) ||
            (!existing.isActive && record.isActive) ||
            (existing.clientName == 'Boutique Client' && record.clientName != 'Boutique Client');
        if (shouldReplace) {
          uniqueMap[key] = record;
        }
      }
    }
    return uniqueMap.values.toList();
  }

  Future<void> saveLicense(LicenseRecord record) async {
    final licenses = getLicenses();
    final cleanKey = record.licenseKey.trim().toUpperCase();

    // Recherche par ID ou par clé de licence
    final index = licenses.indexWhere(
      (l) => l.id == record.id || l.licenseKey.trim().toUpperCase() == cleanKey,
    );

    if (index >= 0) {
      licenses[index] = record;
    } else {
      licenses.insert(0, record);
    }
    final raw = licenses.map((l) => l.toJson()).toList();
    await _prefs.setStringList(_keyLicenses, raw);
  }

  Future<void> deleteLicense(String id) async {
    final licenses = getLicenses();
    final target = licenses.where((l) => l.id == id).firstOrNull;
    final cleanKey = target?.licenseKey.trim().toUpperCase();

    licenses.removeWhere((l) => l.id == id || (cleanKey != null && l.licenseKey.trim().toUpperCase() == cleanKey));
    final raw = licenses.map((l) => l.toJson()).toList();
    await _prefs.setStringList(_keyLicenses, raw);
  }
}
