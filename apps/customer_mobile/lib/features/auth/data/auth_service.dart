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

    final dio = Dio(
      BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    try {
      final response = await dio.post(
        '/api/v1/auth/register',
        data: {
          'shopName': shopName.trim(),
          'currency': currency.trim().isEmpty ? 'GNF' : currency.trim(),
          'pin': pin,
          'deviceName': deviceName.trim().isEmpty ? 'Smartphone' : deviceName.trim(),
          'deviceId': deviceId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final accessToken = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final shop = data['shop'] as Map<String, dynamic>;

        await _storage.saveLocalPin(pin);
        await _storage.saveAuthData(
          accessToken: accessToken,
          refreshToken: refreshToken,
          shopId: shop['id'] as String,
          shopName: shop['name'] as String,
          currency: shop['currency'] as String,
          serverUrl: serverUrl,
        );

        return AuthResult.success();
      } else {
        await _storage.saveLocalShop(
          shopName: shopName.trim(),
          currency: currency.trim().isEmpty ? 'GNF' : currency.trim(),
          pin: pin,
        );
        return AuthResult.success();
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final respData = e.response?.data;
        if (respData is Map<String, dynamic> && respData['message'] != null) {
          final msg = respData['message'];
          final messageStr = msg is List ? msg.join(', ') : msg.toString();
          if (messageStr.contains('déjà enregistré') || messageStr.contains('deviceId')) {
            return AuthResult.failure('Cet appareil possède déjà un compte N’MaShop. Essayez de vous connecter.');
          }
        }
      }
      // Mode local-first : création immédiate de la boutique sur le téléphone
      await _storage.saveLocalShop(
        shopName: shopName.trim(),
        currency: currency.trim().isEmpty ? 'GNF' : currency.trim(),
        pin: pin,
      );
      return AuthResult.success();
    } catch (e) {
      await _storage.saveLocalShop(
        shopName: shopName.trim(),
        currency: currency.trim().isEmpty ? 'GNF' : currency.trim(),
        pin: pin,
      );
      return AuthResult.success();
    }
  }

  Future<AuthResult> loginWithPin(String pin) async {
    if (pin.length < 4 || pin.length > 8) {
      return AuthResult.failure('Le code PIN doit contenir entre 4 et 8 chiffres.');
    }

    final deviceId = await _storage.getOrCreateDeviceId();
    final serverUrl = await _storage.getServerUrl();

    final dio = Dio(
      BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
      if (data['success'] == true) {
        final accessToken = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final shop = data['shop'] as Map<String, dynamic>?;

        await _storage.saveLocalPin(pin);
        await _storage.saveAuthData(
          accessToken: accessToken,
          refreshToken: refreshToken,
          shopId: shop?['id'] ?? 'shop',
          shopName: shop?['name'] ?? (await _storage.getShopName()),
          currency: shop?['currency'] ?? (await _storage.getCurrency()),
          serverUrl: serverUrl,
        );

        return AuthResult.success();
      }
    } catch (_) {}

    // Fallback local-first : vérification du PIN en local
    final isLocalValid = await _storage.verifyLocalPin(pin);
    if (isLocalValid) {
      final shopName = await _storage.getShopName();
      final currency = await _storage.getCurrency();
      await _storage.saveLocalShop(
        shopName: shopName,
        currency: currency,
        pin: pin,
      );
      return AuthResult.success();
    }

    return AuthResult.failure('Code PIN incorrect.');
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
