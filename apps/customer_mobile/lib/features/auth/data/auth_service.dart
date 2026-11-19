import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/mobile_database.dart';
import '../../../core/license/license_engine.dart';
import '../../../core/license/license_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final db = ref.watch(mobileDatabaseProvider);
  return AuthService(storage, db, ref);
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
  final MobileDatabase _db;
  final Ref _ref;

  AuthService(this._storage, this._db, this._ref);

  Future<AuthResult> registerShop({
    required String shopName,
    String currency = 'GNF',
    required String pin,
    required String deviceName,
    String? phone,
    String? managerName,
    String? address,
    String? licenseKey,
  }) async {
    if (shopName.trim().isEmpty) {
      return AuthResult.failure('Veuillez saisir un nom de boutique valide.');
    }
    if (pin.length < 4 || pin.length > 8) {
      return AuthResult.failure('Le code PIN doit contenir entre 4 et 8 chiffres.');
    }

    // 1. Initialisation de la date d'installation pour la période d'essai de 14 jours
    await _storage.getOrCreateInstallationDate();

    // 2. Si une clé de licence a été saisie, la valider cryptographiquement
    final deviceId = await _storage.getOrCreateDeviceId();
    if (licenseKey != null && licenseKey.trim().isNotEmpty) {
      final validation = LicenseEngine.validateKey(licenseKey.trim(), deviceId: deviceId);
      if (validation.isValid) {
        await _storage.saveLicenseKey(licenseKey.trim().toUpperCase());
      } else {
        return AuthResult.failure(validation.errorMessage ?? 'Clé de licence invalide.');
      }
    }

    final cleanName = shopName.trim();
    final cleanCurrency = currency.trim().isEmpty ? 'GNF' : currency.trim();
    final cleanPhone = phone?.trim() ?? '';
    final cleanManager = (managerName != null && managerName.trim().isNotEmpty) ? managerName.trim() : 'Administrateur';
    final cleanAddress = address?.trim() ?? '';

    // 3. Sauvegarde dans SecureStorage & SharedPreferences
    await _storage.saveLocalShop(
      shopName: cleanName,
      currency: cleanCurrency,
      pin: pin,
      phone: cleanPhone,
      managerName: cleanManager,
      address: cleanAddress,
    );

    // 4. Enregistrement dans SQLite MobileShops & MobileUsers
    try {
      final shops = await _db.select(_db.mobileShops).get();
      if (shops.isEmpty) {
        await _db.into(_db.mobileShops).insert(
              MobileShopsCompanion.insert(
                id: 'local-shop',
                name: cleanName,
                currency: drift.Value(cleanCurrency),
                phone: drift.Value(cleanPhone.isNotEmpty ? cleanPhone : null),
                address: drift.Value(cleanAddress.isNotEmpty ? cleanAddress : null),
              ),
            );
      } else {
        final existing = shops.first;
        await (_db.update(_db.mobileShops)..where((tbl) => tbl.id.equals(existing.id))).write(
          MobileShopsCompanion(
            name: drift.Value(cleanName),
            currency: drift.Value(cleanCurrency),
            phone: drift.Value(cleanPhone.isNotEmpty ? cleanPhone : null),
            address: drift.Value(cleanAddress.isNotEmpty ? cleanAddress : null),
          ),
        );
      }

      final users = await _db.select(_db.mobileUsers).get();
      if (users.isEmpty) {
        await _db.into(_db.mobileUsers).insert(
              MobileUsersCompanion.insert(
                id: 'admin-user',
                fullName: cleanManager,
                role: const drift.Value('admin'),
              ),
            );
      } else {
        final existingUser = users.first;
        await (_db.update(_db.mobileUsers)..where((tbl) => tbl.id.equals(existingUser.id))).write(
          MobileUsersCompanion(
            fullName: drift.Value(cleanManager),
          ),
        );
      }
    } catch (_) {}

    // Rafraîchir l'état de la licence
    _ref.read(licenseProvider.notifier).refresh();

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
      final phone = await _storage.getPhone();
      final manager = await _storage.getManagerName();
      final address = await _storage.getAddress();

      await _storage.saveLocalShop(
        shopName: shopName,
        currency: currency,
        pin: pin,
        phone: phone,
        managerName: manager,
        address: address,
      );
      return AuthResult.success();
    }

    return AuthResult.failure('Code PIN incorrect.');
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
