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
    return raw.map((str) => LicenseRecord.fromJson(str)).toList();
  }

  Future<void> saveLicense(LicenseRecord record) async {
    final licenses = getLicenses();
    final index = licenses.indexWhere((l) => l.id == record.id);
    if (index >= 0) {
      licenses[index] = record;
    } else {
      licenses.insert(0, record);
    }
    final raw = licenses.map((l) => l.toJson()).toList();
    await _prefs.setStringList(_keyLicenses, raw);
  }

  Future<void> deleteLicense(String id) async {
    final licenses = getLicenses()..removeWhere((l) => l.id == id);
    final raw = licenses.map((l) => l.toJson()).toList();
    await _prefs.setStringList(_keyLicenses, raw);
  }
}
