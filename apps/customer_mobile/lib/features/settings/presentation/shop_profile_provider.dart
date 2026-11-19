import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/mobile_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../data/shop_profile_model.dart';

final shopProfileProvider = StateNotifierProvider<ShopProfileNotifier, ShopProfile>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final db = ref.watch(mobileDatabaseProvider);
  return ShopProfileNotifier(storage, db, ref);
});

class ShopProfileNotifier extends StateNotifier<ShopProfile> {
  final StorageService _storage;
  final MobileDatabase _db;
  final Ref _ref;

  ShopProfileNotifier(this._storage, this._db, this._ref) : super(const ShopProfile()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    final shopName = await _storage.getShopName();
    final phone = await _storage.getPhone();
    final managerName = await _storage.getManagerName();
    final address = await _storage.getAddress();
    final currency = await _storage.getCurrency();
    final logoPath = await _storage.getLogoPath();

    // Vérifier ou synchroniser avec SQLite
    try {
      final shops = await _db.select(_db.mobileShops).get();
      if (shops.isNotEmpty) {
        final s = shops.first;
        // Priorité aux données persistantes
        final effectiveName = shopName.isNotEmpty ? shopName : s.name;
        final effectivePhone = phone.isNotEmpty ? phone : (s.phone ?? '');
        final effectiveAddress = address.isNotEmpty ? address : (s.address ?? '');
        final effectiveCurrency = currency.isNotEmpty ? currency : s.currency;

        state = ShopProfile(
          shopName: effectiveName,
          phoneNumber: effectivePhone,
          managerName: managerName.isNotEmpty ? managerName : 'Administrateur',
          address: effectiveAddress,
          currency: effectiveCurrency,
          logoPath: logoPath,
        );
        return;
      }
    } catch (_) {}

    state = ShopProfile(
      shopName: shopName.isNotEmpty ? shopName : 'Ma Boutique',
      phoneNumber: phone,
      managerName: managerName.isNotEmpty ? managerName : 'Administrateur',
      address: address,
      currency: currency.isNotEmpty ? currency : 'GNF',
      logoPath: logoPath,
    );
  }

  Future<void> updateProfile({
    required String shopName,
    required String phoneNumber,
    required String managerName,
    required String address,
    required String currency,
    String? logoPath,
  }) async {
    final cleanName = shopName.trim().isEmpty ? 'Ma Boutique' : shopName.trim();
    final cleanPhone = phoneNumber.trim();
    final cleanManager = managerName.trim().isEmpty ? 'Administrateur' : managerName.trim();
    final cleanAddress = address.trim();
    final cleanCurrency = currency.trim().isEmpty ? 'GNF' : currency.trim();

    // 1. Sauvegarde dans SharedPreferences & Secure Storage
    await _storage.saveShopProfile(
      shopName: cleanName,
      phone: cleanPhone,
      managerName: cleanManager,
      address: cleanAddress,
      currency: cleanCurrency,
      logoPath: logoPath,
    );

    // 2. Sauvegarde dans SQLite MobileShops
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

      // 3. Sauvegarde dans SQLite MobileUsers (pour le gestionnaire / manager)
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

    // 4. Mise à jour immédiate de l'état local Riverpod
    state = ShopProfile(
      shopName: cleanName,
      phoneNumber: cleanPhone,
      managerName: cleanManager,
      address: cleanAddress,
      currency: cleanCurrency,
      logoPath: logoPath,
    );

    // 5. Rafraîchissement du Dashboard pour propagation instantanée
    _ref.read(dashboardControllerProvider.notifier).refresh();
  }
}
