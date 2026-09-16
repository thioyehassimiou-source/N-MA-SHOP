import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AuthService(storage);
});

class AuthService {
  final StorageService _storage;

  AuthService(this._storage);

  Future<Map<String, dynamic>> claimPairing({
    required String serverUrl,
    required String token,
    required String pin,
    required String shopName,
    required String currency,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final dio = Dio(
      BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final response = await dio.post(
      '/api/v1/auth/pair/claim',
      data: {
        'token': token,
        'deviceId': deviceId,
        'deviceName': 'Smartphone Patron ($deviceId)',
        'pin': pin,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final shop = data['shop'] as Map<String, dynamic>?;

    await _storage.saveAuthData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      shopId: shop?['id'] ?? 'default-shop',
      shopName: shop?['name'] ?? shopName,
      currency: shop?['currency'] ?? currency,
      serverUrl: serverUrl,
    );

    return data;
  }

  Future<bool> loginWithPin(String pin) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final serverUrl = await _storage.getServerUrl();

    final dio = Dio(
      BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      final response = await dio.post(
        '/api/v1/auth/login',
        data: {
          'deviceId': deviceId,
          'pin': pin,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final shop = data['shop'] as Map<String, dynamic>?;

      await _storage.saveAuthData(
        accessToken: accessToken,
        refreshToken: refreshToken,
        shopId: shop?['id'] ?? 'shop',
        shopName: shop?['name'] ?? (await _storage.getShopName()),
        currency: shop?['currency'] ?? (await _storage.getCurrency()),
        serverUrl: serverUrl,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> autoPairDemoDevice() async {
    final serverUrl = await _storage.getServerUrl();
    final deviceId = await _storage.getOrCreateDeviceId();
    final dio = Dio(
      BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      // 1. Init pairing token on server
      await dio.post(
        '/api/v1/auth/pair/init',
        data: {
          'token': 'auto-demo-token',
          'machineId': 'desktop-mac-auto',
          'shopName': 'Boutique N\'MaShop Guinée',
          'licenseKey': 'NMA-2026-GUINEE-001',
        },
      );

      // 2. Claim pairing to obtain JWT
      final claimRes = await dio.post(
        '/api/v1/auth/pair/claim',
        data: {
          'token': 'auto-demo-token',
          'deviceId': deviceId,
          'deviceName': 'Mobile Patron ($deviceId)',
          'pin': '1234',
        },
      );

      final data = claimRes.data as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final shop = data['shop'] as Map<String, dynamic>?;

      await _storage.saveAuthData(
        accessToken: accessToken,
        refreshToken: refreshToken,
        shopId: shop?['id'] ?? 'shop-auto',
        shopName: shop?['name'] ?? 'Boutique N\'MaShop Guinée',
        currency: shop?['currency'] ?? 'GNF',
        serverUrl: serverUrl,
      );

      return accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
