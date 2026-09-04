import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../providers/app_settings_provider.dart';
import '../services/hardware_id_service.dart';
import 'license_admin_sync_service.dart';
import 'license_model.dart';
import 'license_service.dart';

// ── Provider principal ──────────────────────────────────────────────────────

/// Expose l'état courant de la licence à toute l'application.
final licenseProvider =
    NotifierProvider<LicenseNotifier, LicenseInfo>(LicenseNotifier.new);

// ── Notifier ────────────────────────────────────────────────────────────────

class LicenseNotifier extends Notifier<LicenseInfo> {
  final _svc = LicenseService();
  Timer? _remoteCheckTimer;

  @override
  LicenseInfo build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final initialInfo = _svc.check(prefs);
    _checkAsync(prefs);
    _startRemoteRevocationCheck();

    ref.onDispose(() {
      _remoteCheckTimer?.cancel();
    });

    return initialInfo;
  }

  void _startRemoteRevocationCheck() {
    _remoteCheckTimer?.cancel();
    // Interroger Neon PostgreSQL toutes les 5 secondes pour synchroniser l'état (activation / désactivation)
    _remoteCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final prefs = ref.read(sharedPreferencesProvider);
      final storedKey = prefs.getString('lic_key');
      final hwId = await HardwareIdService.getHardwareId();

      final remoteInfo = await LicenseAdminSyncService.checkRemoteLicenseInfo(
        hwId,
        licenseKey: storedKey,
      );

      if (remoteInfo != null) {
        if (!remoteInfo.isActive) {
          // L'administrateur a désactivé cette licence depuis Mobile Admin !
          if (state.status != LicenseStatus.expired) {
            await _svc.resetLicense(prefs);
            state = const LicenseInfo(
              status: LicenseStatus.expired,
              type: LicenseType.trial,
              expiryDate: null,
              daysLeft: 0,
            );
          }
        } else if (remoteInfo.isActive && remoteInfo.licenseKey.isNotEmpty) {
          // L'administrateur a activé une licence depuis Mobile Admin !
          // Si l'application locale n'est pas encore activée ou possède une clé différente,
          // on active automatiquement la licence en local.
          if (!state.isLicensed || storedKey != remoteInfo.licenseKey) {
            final res = await _svc.activateAsync(remoteInfo.licenseKey, prefs);
            if (res.result == LicenseActivationResult.success && res.info != null) {
              state = res.info!;
            }
          }
        }
      }
    });
  }


  Future<void> _checkAsync(dynamic prefs) async {
    final updated = await _svc.checkAsync(prefs);
    state = updated;
  }

  /// Rafraîchit le statut (utile après activation d'une clé).
  Future<void> refresh() async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = await _svc.checkAsync(prefs);
  }

  /// Tente d'activer la clé [rawKey].
  Future<({LicenseActivationResult result, LicenseInfo? info})> activate(String rawKey) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final res = await _svc.activateAsync(rawKey, prefs);
    if (res.result == LicenseActivationResult.success && res.info != null) {
      state = res.info!;
      
      // -- Synchronisation Arrière-Plan avec l'Admin (Option 2) --
      try {
        final settings = ref.read(appSettingsProvider);
        final user = ref.read(authProvider);
        final hwId = await HardwareIdService.getHardwareId();
        
        final payload = LicenseSyncPayload(
          businessName: settings.businessName,
          ownerName: user?.fullName ?? 'Boutiquier',
          phone: settings.businessPhone,
          address: settings.businessAddress,
          hardwareId: hwId,
          licenseKey: rawKey.trim().toUpperCase(),
          activatedAt: DateTime.now(),
          expiryDate: res.info!.expiryDate,
        );
        // Exécution non-bloquante en arrière-plan
        LicenseAdminSyncService.notifyActivation(payload);
      } catch (e) {
        // Ignorer silencieusement pour ne pas bloquer l'activation locale
      }
    }
    return res;
  }

  /// Efface la licence locale et remet l'application en mode essai (7 jours).
  Future<void> resetLicense() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await _svc.resetLicense(prefs);
    state = await _svc.checkAsync(prefs);
  }
}
