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
/// Utilise [AsyncNotifierProvider] pour garantir que [checkAsync] (qui lit
/// l'ID matériel et l'horloge système) est attendu AVANT le premier rendu.
/// Aucun flash d'état incorrect n'est possible avec cette approche.
final licenseProvider =
    AsyncNotifierProvider<LicenseNotifier, LicenseInfo>(LicenseNotifier.new);

/// Provider dérivé synchrone (rétro-compatibilité UI).
/// Expose directement un [LicenseInfo] sans avoir à gérer [AsyncValue] dans
/// chaque widget. Pendant le chargement initial, retourne un état trial neutre
/// afin de n'afficher aucun écran de blocage prématuré.
final licenseInfoProvider = Provider<LicenseInfo>((ref) {
  return ref.watch(licenseProvider).when(
    data: (info) => info,
    loading: () => const LicenseInfo(
      status: LicenseStatus.trial,
      type: LicenseType.trial,
      daysLeft: 7,
    ),
    error: (_, __) => const LicenseInfo(
      status: LicenseStatus.trial,
      type: LicenseType.trial,
      daysLeft: 7,
    ),
  );
});


class LicenseNotifier extends AsyncNotifier<LicenseInfo> {
  final _svc = LicenseService();
  Timer? _remoteCheckTimer;

  /// Premier build : attend la vérification complète (anti-tamper + device binding)
  /// avant que l'UI ne soit rendue. L'écran de démarrage reste affiché jusqu'ici.
  @override
  Future<LicenseInfo> build() async {
    ref.onDispose(() => _remoteCheckTimer?.cancel());

    final prefs = ref.read(sharedPreferencesProvider);

    // Vérification bloquante : anti-tamper + device binding + période d'essai
    final info = await _svc.checkAsync(prefs);

    // Démarre la surveillance de révocation à distance (toutes les 30 minutes)
    _startRemoteRevocationCheck();

    return info;
  }

  // ── Surveillance distante Neon PostgreSQL ──────────────────────────────────

  void _startRemoteRevocationCheck() {
    _remoteCheckTimer?.cancel();
    // Synchro immédiate en arrière-plan sans bloquer
    Future.microtask(() => _syncWithRemote());
    // Vérification périodique toutes les 5 minutes
    _remoteCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _syncWithRemote();
    });
    ref.onDispose(() {
      _remoteCheckTimer?.cancel();
    });
  }

  /// Vérification distante sans bloquer l'UI. Met à jour [state] uniquement
  /// si un changement réel est détecté depuis la dernière vérification.
  Future<void> _syncWithRemote() async {
    // Agit uniquement si un état valide est disponible (pas en loading/error)
    final current = state.maybeWhen(data: (v) => v, orElse: () => null);
    if (current == null) return;

    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final storedKey = prefs.getString('lic_key');
      final hwId = await HardwareIdService.getHardwareId();

      final remoteInfo = await LicenseAdminSyncService.checkRemoteLicenseInfo(
        hwId,
        licenseKey: storedKey,
      );

      if (remoteInfo == null) return; // Hors-ligne → état local conservé

      if (!remoteInfo.isActive) {
        // L'administrateur a révoqué cette licence depuis Mobile Admin.
        // IMPORTANT : Ne révoquer QUE si le poste utilise actuellement une licence active (avec clé enregistrée).
        // Un utilisateur en période d'essai ne doit JAMAIS être révoqué par la vérification distante.
        if (current.isLicensed && storedKey != null && storedKey.isNotEmpty) {
          await prefs.setBool('lic_was_revoked_by_admin', true);
          await _svc.revokeLicense(prefs);
          state = const AsyncData(LicenseInfo(
            status: LicenseStatus.expired,
            type: LicenseType.trial,
            expiryDate: null,
            daysLeft: 0,
          ));
        }
      } else if (remoteInfo.isActive && remoteInfo.licenseKey.isNotEmpty) {
        // L'administrateur a activé ou mis à jour la licence depuis Mobile Admin
        if (!current.isLicensed || storedKey != remoteInfo.licenseKey) {
          final res = await _svc.activateAsync(remoteInfo.licenseKey, prefs);
          if (res.result == LicenseActivationResult.success && res.info != null) {
            state = AsyncData(res.info!);
          }
        }
      }
    } catch (_) {
      // Vérification distante : échec silencieux (hors-ligne acceptable)
      // L'état local reste prioritaire
    }
  }

  // ── API publique ────────────────────────────────────────────────────────────

  /// Rafraîchit le statut complet (utile après un changement manuel).
  Future<void> refresh() async {
    state = const AsyncLoading();
    final prefs = ref.read(sharedPreferencesProvider);
    state = await AsyncValue.guard(() => _svc.checkAsync(prefs));
  }

  /// Tente d'activer la clé [rawKey].
  ///
  /// Flux :
  /// 1. Validation locale (HMAC + device binding) — bloquant
  /// 2. Persistance dans SharedPreferences — bloquant
  /// 3. Mise à jour de [state] → l'UI réagit immédiatement
  /// 4. Notification Neon en arrière-plan — non-bloquant intentionnellement
  Future<({LicenseActivationResult result, LicenseInfo? info})> activate(String rawKey) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final res = await _svc.activateAsync(rawKey, prefs);

    if (res.result == LicenseActivationResult.success && res.info != null) {
      // Mise à jour immédiate de l'état UI
      state = AsyncData(res.info!);

      // Notification arrière-plan vers Neon (non-bloquant)
      _notifyActivationAsync(rawKey, res.info!);
    }
    return res;
  }

  /// Notification asynchrone vers Neon PostgreSQL, exécutée en arrière-plan.
  /// Ne bloque jamais l'activation côté utilisateur.
  void _notifyActivationAsync(String rawKey, LicenseInfo info) {
    Future.microtask(() async {
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
          expiryDate: info.expiryDate,
        );
        await LicenseAdminSyncService.notifyActivation(payload);
      } catch (_) {
        // Ignorer silencieusement : l'activation locale est déjà confirmée
      }
    });
  }

  /// Efface la licence locale, réinitialise en mode essai et notifie Neon.
  Future<void> resetLicense() async {
    state = const AsyncLoading();
    final prefs = ref.read(sharedPreferencesProvider);
    await _svc.resetLicense(prefs); // notifie Neon en interne
    state = await AsyncValue.guard(() => _svc.checkAsync(prefs));
  }
}
