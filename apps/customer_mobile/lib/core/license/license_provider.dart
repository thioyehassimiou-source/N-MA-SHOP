import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';
import 'license_engine.dart';
import 'license_model.dart';

final licenseProvider = StateNotifierProvider<LicenseNotifier, AsyncValue<LicenseInfo>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return LicenseNotifier(storage);
});

final licenseInfoProvider = Provider<LicenseInfo>((ref) {
  final asyncVal = ref.watch(licenseProvider);
  return asyncVal.when(
    data: (info) => info,
    loading: () => LicenseInfo(
      status: LicenseStatus.trial,
      type: LicenseType.trial,
      daysLeft: 14,
      deviceId: '...',
      installationDate: DateTime.now(),
    ),
    error: (_, __) => LicenseInfo(
      status: LicenseStatus.trial,
      type: LicenseType.trial,
      daysLeft: 14,
      deviceId: '...',
      installationDate: DateTime.now(),
    ),
  );
});

class LicenseNotifier extends StateNotifier<AsyncValue<LicenseInfo>> {
  final StorageService _storage;

  LicenseNotifier(this._storage) : super(const AsyncValue.loading()) {
    loadLicense();
  }

  Future<void> loadLicense() async {
    try {
      final deviceId = await _storage.getOrCreateDeviceId();
      final installationDate = await _storage.getOrCreateInstallationDate();
      final savedKey = await _storage.getLicenseKey();

      final info = LicenseEngine.resolveLicense(
        deviceId: deviceId,
        installationDate: installationDate,
        savedKey: savedKey,
      );

      state = AsyncValue.data(info);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Tente d'activer une clé de licence saisie par le commerçant.
  Future<({bool success, String? message})> activateKey(String rawKey) async {
    final currentInfo = state.valueOrNull;
    final deviceId = currentInfo?.deviceId ?? await _storage.getOrCreateDeviceId();

    final validation = LicenseEngine.validateKey(rawKey, deviceId: deviceId);
    if (!validation.isValid) {
      return (
        success: false,
        message: validation.errorMessage ?? 'Clé de licence invalide.',
      );
    }

    final cleanKey = rawKey.trim().toUpperCase();
    await _storage.saveLicenseKey(cleanKey);
    await loadLicense();

    return (
      success: true,
      message: 'Félicitations ! Votre licence N\'MaShop a été activée avec succès.',
    );
  }

  Future<void> refresh() async {
    await loadLicense();
  }
}
