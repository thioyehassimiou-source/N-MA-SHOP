import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const _keyAccessToken = 'nmashop_access_token';
  static const _keyRefreshToken = 'nmashop_refresh_token';
  static const _keyDeviceId = 'nmashop_device_id';
  static const _keyShopId = 'nmashop_shop_id';
  static const _keyShopName = 'nmashop_shop_name';
  static const _keyCurrency = 'nmashop_currency';
  static const _keyPhone = 'nmashop_phone';
  static const _keyManagerName = 'nmashop_manager_name';
  static const _keyAddress = 'nmashop_address';
  static const _keyLogoPath = 'nmashop_logo_path';
  static const _keyInstallationDate = 'nmashop_installation_date';
  static const _keyLicenseKey = 'nmashop_license_key';
  static const _keyServerUrl = 'nmashop_server_url';
  static const _keyLastSync = 'nmashop_last_sync';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    webOptions: WebOptions(dbName: 'nmashop_secure', publicKey: 'nmashop_web_key'),
  );

  static String get defaultServerUrl {
    if (kIsWeb) return 'http://localhost:3000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    } catch (_) {}
    return 'http://localhost:3000';
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_keyDeviceId);
    if (id == null) {
      id = 'mob-${const Uuid().v4().substring(0, 8)}';
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String shopId,
    required String shopName,
    required String currency,
    required String serverUrl,
  }) async {
    try {
      await _secureStorage.write(key: _keyAccessToken, value: accessToken);
      await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, accessToken);
      await prefs.setString(_keyRefreshToken, refreshToken);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopId, shopId);
    await prefs.setString(_keyShopName, shopName);
    await prefs.setString(_keyCurrency, currency);
    await prefs.setString(_keyServerUrl, serverUrl);
  }

  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAccessToken);
    }
    try {
      return await _secureStorage.read(key: _keyAccessToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAccessToken);
    }
  }

  Future<String?> getRefreshToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRefreshToken);
    }
    try {
      return await _secureStorage.read(key: _keyRefreshToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRefreshToken);
    }
  }

  Future<void> saveAccessToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, token);
      return;
    }
    try {
      await _secureStorage.write(key: _keyAccessToken, value: token);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, token);
    }
  }

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl) ?? defaultServerUrl;
  }

  Future<String> getShopName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyShopName) ?? 'Ma Boutique';
  }

  Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrency) ?? 'GNF';
  }

  Future<String> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone) ?? '';
  }

  Future<String> getManagerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyManagerName) ?? 'Administrateur';
  }

  Future<String> getAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAddress) ?? '';
  }

  Future<String?> getLogoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLogoPath);
  }

  Future<void> saveShopProfile({
    String? shopName,
    String? phone,
    String? managerName,
    String? address,
    String? currency,
    String? logoPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (shopName != null) await prefs.setString(_keyShopName, shopName);
    if (phone != null) await prefs.setString(_keyPhone, phone);
    if (managerName != null) await prefs.setString(_keyManagerName, managerName);
    if (address != null) await prefs.setString(_keyAddress, address);
    if (currency != null) await prefs.setString(_keyCurrency, currency);
    if (logoPath != null) await prefs.setString(_keyLogoPath, logoPath);
  }

  Future<DateTime> getOrCreateInstallationDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyInstallationDate);
    if (str != null) {
      final parsed = DateTime.tryParse(str);
      if (parsed != null) return parsed;
    }
    final now = DateTime.now();
    await prefs.setString(_keyInstallationDate, now.toIso8601String());
    return now;
  }

  Future<void> setInstallationDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyInstallationDate, date.toIso8601String());
  }

  Future<String?> getLicenseKey() async {
    try {
      final key = await _secureStorage.read(key: _keyLicenseKey);
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLicenseKey);
  }

  Future<void> saveLicenseKey(String key) async {
    try {
      await _secureStorage.write(key: _keyLicenseKey, value: key);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLicenseKey, key);
  }

  Future<void> clearLicenseKey() async {
    try {
      await _secureStorage.delete(key: _keyLicenseKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLicenseKey);
  }

  Future<bool> isLoggedIn() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isPaired() async => isLoggedIn();

  static const _keyPin = 'nmashop_pin';

  Future<void> saveLocalPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPin, pin);
  }

  Future<String?> getLocalPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPin);
  }

  Future<bool> verifyLocalPin(String pin) async {
    final stored = await getLocalPin();
    if (stored == null || stored.isEmpty) return true;
    return stored == pin;
  }

  Future<void> saveLocalShop({
    required String shopName,
    required String currency,
    required String pin,
    String? phone,
    String? managerName,
    String? address,
    String? logoPath,
  }) async {
    final shopId = 'mob-shop-${DateTime.now().millisecondsSinceEpoch}';
    final accessToken = 'local-access-token-${DateTime.now().millisecondsSinceEpoch}';
    final refreshToken = 'local-refresh-token-${DateTime.now().millisecondsSinceEpoch}';
    final serverUrl = defaultServerUrl;

    await saveLocalPin(pin);
    await saveAuthData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      shopId: shopId,
      shopName: shopName,
      currency: currency,
      serverUrl: serverUrl,
    );
    await saveShopProfile(
      shopName: shopName,
      phone: phone,
      managerName: managerName,
      address: address,
      currency: currency,
      logoPath: logoPath,
    );
  }

  Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastSync);
    return str != null ? DateTime.tryParse(str) : null;
  }

  Future<void> updateLastSync(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, time.toIso8601String());
  }

  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyShopId);
    await prefs.remove(_keyShopName);
    await prefs.remove(_keyCurrency);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyManagerName);
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyLogoPath);
    await prefs.remove(_keyPin);
    await prefs.remove(_keyLastSync);
  }
}
