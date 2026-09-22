import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AuthService(storage);
});

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;

  AuthResult._({required this.isSuccess, this.errorMessage});

  factory AuthResult.success() => AuthResult._(isSuccess: true);
  factory AuthResult.failure(String message) => AuthResult._(isSuccess: false, errorMessage: message);
}

class AuthService {
  final StorageService _storage;

  AuthService(this._storage);

  Future<AuthResult> registerShop({
    required String shopName,
    String currency = 'GNF',
    required String pin,
    required String deviceName,
  }) async {
    if (shopName.trim().isEmpty) {
      return AuthResult.failure('Veuillez saisir un nom de boutique valide.');
    }
    if (pin.length < 4 || pin.length > 8) {
      return AuthResult.failure('Le code PIN doit contenir entre 4 et 8 chiffres.');
    }

    final deviceId = await _storage.getOrCreateDeviceId();
    final serverUrl = await _storage.getServerUrl();
    final cleanShopName = shopName.trim();
    final cleanCurrency = currency.trim().isEmpty ? 'GNF' : currency.trim();

    // Toujours enregistrer le code PIN et les données de la boutique en local (0% blocage hors-ligne)
    await _storage.savePin(pin);
    await _storage.saveAuthData(
      accessToken: 'local_mobile_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'local_mobile_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
      shopId: 'shop_${deviceId.substring(0, 8)}',
      shopName: cleanShopName,
      currency: cleanCurrency,
      serverUrl: serverUrl,
    );

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: serverUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dio.post(
        '/api/v1/auth/register',
        data: {
          'shopName': cleanShopName,
          'currency': cleanCurrency,
          'pin': pin,
          'deviceName': deviceName.trim().isEmpty ? 'Smartphone Patron' : deviceName.trim(),
          'deviceId': deviceId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final accessToken = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final shop = data['shop'] as Map<String, dynamic>;

        await _storage.saveAuthData(
          accessToken: accessToken,
          refreshToken: refreshToken,
          shopId: shop['id'] as String,
          shopName: shop['name'] as String,
          currency: shop['currency'] as String,
          serverUrl: serverUrl,
        );
      }
    } catch (_) {
      // Ignorer l'erreur réseau : la création locale a réussi
    }

    return AuthResult.success();
  }

  Future<AuthResult> loginWithPin(String pin) async {
    if (pin.length < 4 || pin.length > 8) {
      return AuthResult.failure('Le code PIN doit contenir entre 4 et 8 chiffres.');
    }

    final savedPin = await _storage.getSavedPin();
    if (savedPin != null && savedPin.isNotEmpty) {
      if (savedPin == pin) {
        // Validation PIN locale instantanée
        final currentToken = await _storage.getAccessToken();
        if (currentToken == null || currentToken.isEmpty) {
          final deviceId = await _storage.getOrCreateDeviceId();
          await _storage.saveAccessToken('local_mobile_access_token_${DateTime.now().millisecondsSinceEpoch}');
        }
        return AuthResult.success();
      } else {
        return AuthResult.failure('Code PIN secret incorrect.');
      }
    }

    final deviceId = await _storage.getOrCreateDeviceId();
    final serverUrl = await _storage.getServerUrl();

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: serverUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dio.post(
        '/api/v1/auth/login',
        data: {
          'deviceId': deviceId,
          'pin': pin,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final accessToken = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final shop = data['shop'] as Map<String, dynamic>?;

        await _storage.savePin(pin);
        await _storage.saveAuthData(
          accessToken: accessToken,
          refreshToken: refreshToken,
          shopId: shop?['id'] ?? 'shop',
          shopName: shop?['name'] ?? (await _storage.getShopName()),
          currency: shop?['currency'] ?? (await _storage.getCurrency()),
          serverUrl: serverUrl,
        );

        return AuthResult.success();
      } else {
        return AuthResult.failure('Identifiants incorrects.');
      }
    } catch (_) {
      // Fallback mode local si aucune donnée sauvegardée
      await _storage.savePin(pin);
      await _storage.saveAccessToken('local_mobile_access_token_${DateTime.now().millisecondsSinceEpoch}');
      return AuthResult.success();
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
