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
  static const _keyServerUrl = 'nmashop_server_url';
  static const _keyLastSync = 'nmashop_last_sync';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopId, shopId);
    await prefs.setString(_keyShopName, shopName);
    await prefs.setString(_keyCurrency, currency);
    await prefs.setString(_keyServerUrl, serverUrl);
  }

  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _keyRefreshToken);
  }

  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _keyAccessToken, value: token);
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

  Future<bool> isPaired() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
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
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyShopId);
    await prefs.remove(_keyShopName);
    await prefs.remove(_keyCurrency);
    await prefs.remove(_keyLastSync);
  }
}
