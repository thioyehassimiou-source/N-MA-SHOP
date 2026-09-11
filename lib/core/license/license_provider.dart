import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../providers/app_settings_provider.dart';
import '../services/hardware_id_service.dart';
import 'license_admin_sync_service.dart';
import 'license_model.dart';
import 'license_realtime_service.dart';
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
  LicenseRealtimeService? _realtimeService;

  /// Premier build : attend la vérification complète (anti-tamper + device binding)
  /// avant que l'UI ne soit rendue. L'écran de démarrage reste affiché jusqu'ici.
  @override
  Future<LicenseInfo> build() async {
    ref.onDispose(() {
      _remoteCheckTimer?.cancel();
      _realtimeService?.dispose();
    });

    final prefs = ref.read(sharedPreferencesProvider);

    // Vérification bloquante : anti-tamper + device binding + période d'essai
    final info = await _svc.checkAsync(prefs);

    // Si la machine démarre en mode essai, enregistrement silencieux sur Neon Cloud (non bloquant)
    if (info.isTrial) {
      _reportTrialInstallationAsync(info);
    }

    // Démarre l'écoute instantanée P2P (LAN UDP) et Cloud Realtime (Neon LISTEN)
    _startRealtimeListener();

    // Démarre la surveillance de sécurité en arrière-plan
    _startRemoteRevocationCheck();

    return info;
  }

  // ── Écoute instantanée P2P et Cloud Realtime (< 50ms) ────────────────────────

  void _startRealtimeListener() {
    _realtimeService?.dispose();
    _realtimeService = LicenseRealtimeService(
      getHardwareId: () => HardwareIdService.getHardwareId(),
      getStoredKey: () async {
        final prefs = ref.read(sharedPreferencesProvider);
        return prefs.getString('lic_key');
      },
      onRevoked: () async {
        final prefs = ref.read(sharedPreferencesProvider);
        await _svc.revokeLicense(prefs);
        await ref.read(authProvider.notifier).lock();
        state = const AsyncData(LicenseInfo(
          status: LicenseStatus.expired,
          type: LicenseType.trial,
          expiryDate: null,
          daysLeft: 0,
        ));
      },
      onActivated: (key) async {
        final prefs = ref.read(sharedPreferencesProvider);
        await _svc.unrevokeLicense(prefs);
        if (key.isNotEmpty && !key.startsWith('TRIAL-')) {
          final res = await _svc.activateAsync(key, prefs);
          if (res.result == LicenseActivationResult.success && res.info != null) {
            state = AsyncData(res.info!);
            return;
          }
        }
        state = AsyncData(await _svc.checkAsync(prefs));
      },
    )..start();
  }

  // ── Surveillance distante Neon PostgreSQL ──────────────────────────────────

  void _startRemoteRevocationCheck() {
    _remoteCheckTimer?.cancel();
    // Synchro immédiate en arrière-plan sans bloquer
    Future.microtask(() => _syncWithRemote());
    // Vérification toutes les 10 secondes pour une réaction quasi-instantanée aux révocations/activations distantes
    _remoteCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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

      // ── 1. Contrôle local strict (100% Hors-Ligne) ─────────────────────────
      // Si la période d'essai ou la licence arrive à échéance pendant l'utilisation,
      // l'application déconnecte et verrouille immédiatement la session sans Internet.
      final localCheck = await _svc.checkAsync(prefs);
      if (localCheck.isExpired) {
        if (!current.isExpired) {
          await ref.read(authProvider.notifier).lock();
        }
        state = AsyncData(localCheck);
        return;
      } else if (current.isTrial) {
        // En mode essai : actualiser l'état dès qu'une minute ou un jour s'écoule
        // pour animer le décompte en temps réel à l'écran sans redémarrage.
        final oldDur = current.remainingDuration;
        final newDur = localCheck.remainingDuration;
        if (oldDur?.inMinutes != newDur?.inMinutes || localCheck.daysLeft != current.daysLeft) {
          state = AsyncData(localCheck);
        }
      }

      final storedKey = prefs.getString('lic_key');
      final hwId = await HardwareIdService.getHardwareId();

      final remoteInfo = await LicenseAdminSyncService.checkRemoteLicenseInfo(
        hwId,
        licenseKey: storedKey,
      );

      if (remoteInfo == null) {
        if (current.isTrial) {
          _reportTrialInstallationAsync(current);
        }
        return; // Hors-ligne → état local conservé
      }

      // ── A. Contrôle d'horloge absolue contre l'heure atomique du serveur Neon ──
      if (remoteInfo.serverTime != null) {
        final diffHours = DateTime.now().toUtc().difference(remoteInfo.serverTime!).inHours.abs();
        if (diffHours > 24) {
          // Altération majeure détectée : l'horloge système a été décalée pour contourner les délais
          await _svc.revokeLicense(prefs);
          if (!current.isExpired) {
            await ref.read(authProvider.notifier).lock();
          }
          state = const AsyncData(LicenseInfo(
            status: LicenseStatus.tampered,
            type: LicenseType.trial,
            expiryDate: null,
            daysLeft: 0,
          ));
          return;
        }
      }

      // ── B. Contrôle d'expiration d'essai Cloud (Anti-Réinitialisation par effacement de cache) ──
      if (current.isTrial && remoteInfo.expiryDate != null && DateTime.now().isAfter(remoteInfo.expiryDate!)) {
        if (remoteInfo.activatedAt != null) {
          await prefs.setString('lic_first_launch', remoteInfo.activatedAt!.toIso8601String());
        }
        await ref.read(authProvider.notifier).lock();
        state = AsyncData(LicenseInfo(
          status: LicenseStatus.expired,
          type: LicenseType.trial,
          expiryDate: remoteInfo.expiryDate,
          daysLeft: 0,
        ));
        return;
      }

      if (!remoteInfo.isActive) {
        // L'administrateur a révoqué ou désactivé cette machine (en essai ou sous licence) depuis Mobile Admin.
        await _svc.revokeLicense(prefs);
        if (!current.isExpired) {
          await ref.read(authProvider.notifier).lock();
        }
        state = const AsyncData(LicenseInfo(
          status: LicenseStatus.expired,
          type: LicenseType.trial,
          expiryDate: null,
          daysLeft: 0,
        ));
      } else if (remoteInfo.isActive) {
        // Si la machine avait été marquée révoquée localement mais est active sur le cloud :
        final wasRevoked = prefs.getBool('lic_was_revoked_by_admin') ?? false;
        if (wasRevoked || current.isExpired) {
          await _svc.unrevokeLicense(prefs);
        }

        // L'administrateur a activé ou attribué une licence officielle depuis Mobile Admin
        final keyToUse = remoteInfo.licenseKey.isNotEmpty ? remoteInfo.licenseKey : storedKey;
        if (keyToUse != null && keyToUse.isNotEmpty && !keyToUse.startsWith('TRIAL-')) {
          if (!current.isLicensed || current.isExpired || storedKey != keyToUse) {
            final res = await _svc.activateAsync(keyToUse, prefs);
            if (res.result == LicenseActivationResult.success && res.info != null) {
              state = AsyncData(res.info!);
            } else {
              state = AsyncData(await _svc.checkAsync(prefs));
            }
          }
        } else if (current.isExpired) {
          state = AsyncData(await _svc.checkAsync(prefs));
        }
      }
    } catch (_) {
      // Vérification distante : échec silencieux (hors-ligne acceptable)
      // L'état local reste prioritaire
    }
  }

  /// Enregistrement silencieux et non-bloquant de la machine en essai sur Neon PostgreSQL.
  void _reportTrialInstallationAsync(LicenseInfo info) {
    Future.microtask(() async {
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        final firstLaunchStr = prefs.getString('lic_first_launch');
        final firstLaunch = firstLaunchStr != null
            ? (DateTime.tryParse(firstLaunchStr) ?? DateTime.now())
            : DateTime.now();
        final expiry = info.expiryDate ?? firstLaunch.add(const Duration(days: 7));

        final settings = ref.read(appSettingsProvider);
        final user = ref.read(authProvider);
        final hwId = await HardwareIdService.getHardwareId();

        final os = Platform.operatingSystem.toUpperCase();
        final hostname = Platform.environment['COMPUTERNAME'] ?? Platform.localHostname;
        final osUser = Platform.environment['USERNAME'] ??
            Platform.environment['USER'] ??
            '';
        final cores = Platform.numberOfProcessors;
        final osInfo = '$os ($cores cœurs) - Hôte: $hostname';

        final storeName = (settings.businessName.isNotEmpty && settings.businessName != 'N\'MaShop')
            ? settings.businessName
            : 'Poste $hostname ($os)';

        final owner = (user != null && user.fullName.isNotEmpty)
            ? user.fullName
            : (osUser.isNotEmpty ? osUser : 'Utilisateur Essai');

        await LicenseAdminSyncService.reportTrialInstallation(
          hardwareId: hwId,
          firstLaunch: firstLaunch,
          trialExpiry: expiry,
          businessName: storeName,
          ownerName: owner,
          phone: settings.businessPhone,
          osInfo: osInfo,
        );
      } catch (_) {
        // Hors-ligne ou erreur réseau : échec silencieux, l'essai continue en local sans interruption
      }
    });
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
