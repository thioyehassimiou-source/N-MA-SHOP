import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import 'license_model.dart';
import 'license_service.dart';

// ── Provider principal ──────────────────────────────────────────────────────

/// Expose l'état courant de la licence à toute l'application.
///
/// Initialisé de façon **synchrone** dans `main.dart` via un override du
/// container Riverpod, de sorte que le routeur dispose du statut dès le
/// premier rendu (aucun flash d'écran non protégé).
final licenseProvider =
    NotifierProvider<LicenseNotifier, LicenseInfo>(LicenseNotifier.new);

// ── Notifier ────────────────────────────────────────────────────────────────

class LicenseNotifier extends Notifier<LicenseInfo> {
  final _svc = LicenseService();

  @override
  LicenseInfo build() {
    // État initial fourni par l'override dans main.dart.
    // Si pas d'override, on calcule à la volée (ne devrait pas arriver).
    final prefs = ref.read(sharedPreferencesProvider);
    return _svc.check(prefs);
  }

  /// Rafraîchit le statut (utile après activation d'une clé).
  void refresh() {
    final prefs = ref.read(sharedPreferencesProvider);
    state = _svc.check(prefs);
  }

  /// Tente d'activer la clé [rawKey].
  /// Retourne le résultat d'activation ; met à jour l'état si succès.
  ({LicenseActivationResult result, LicenseInfo? info}) activate(String rawKey) {
    final prefs = ref.read(sharedPreferencesProvider);
    final res = _svc.activate(rawKey, prefs);
    if (res.result == LicenseActivationResult.success && res.info != null) {
      state = res.info!;
    }
    return res;
  }
}
