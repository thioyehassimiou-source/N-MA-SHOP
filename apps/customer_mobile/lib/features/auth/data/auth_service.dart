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

    // Mode autonome smartphone : création immédiate de la boutique sur le téléphone (100% hors-ligne)
    await _storage.saveLocalShop(
      shopName: shopName.trim(),
      currency: currency.trim().isEmpty ? 'GNF' : currency.trim(),
      pin: pin,
    );
    return AuthResult.success();
  }

  Future<AuthResult> loginWithPin(String pin) async {
    if (pin.length < 4 || pin.length > 8) {
      return AuthResult.failure('Le code PIN doit contenir entre 4 et 8 chiffres.');
    }

    // Vérification du PIN en local (immédiat, zéro latence)
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
