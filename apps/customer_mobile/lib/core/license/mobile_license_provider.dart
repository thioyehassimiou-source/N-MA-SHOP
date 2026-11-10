import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mobile_license_model.dart';
import 'mobile_license_service.dart';

final mobileLicenseServiceProvider = Provider<MobileLicenseService>((ref) {
  return MobileLicenseService();
});

final mobileLicenseProvider = StateNotifierProvider<MobileLicenseNotifier, AsyncValue<MobileLicenseInfo>>((ref) {
  final service = ref.watch(mobileLicenseServiceProvider);
  return MobileLicenseNotifier(service);
});

class MobileLicenseNotifier extends StateNotifier<AsyncValue<MobileLicenseInfo>> {
  final MobileLicenseService _service;

  MobileLicenseNotifier(this._service) : super(const AsyncValue.loading()) {
    checkLicense();
  }

  Future<void> checkLicense() async {
    try {
      final info = await _service.checkLicense();
      state = AsyncValue.data(info);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<MobileLicenseActivationResult> activate(String rawKey) async {
    final result = await _service.activateKey(rawKey);
    if (result.isSuccess && result.licenseInfo != null) {
      state = AsyncValue.data(result.licenseInfo!);
    }
    return result;
  }
}

