import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../data/repositories/drift_auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DriftAuthRepository(ref.watch(databaseProvider));
});

/// Présence d'un compte boutiquier en base, lue une fois au démarrage
/// (`main.dart`) pour que le routeur y accède de façon synchrone.
///
/// C'est l'invariant qui garantit qu'une boutique déjà créée mène toujours au
/// déverrouillage, même si le drapeau de configuration des préférences était
/// perdu. Mis à `false` lors d'une réinitialisation.
final accountExistsProvider =
    NotifierProvider<AccountExistsNotifier, bool>(AccountExistsNotifier.new);

class AccountExistsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: avoid_positional_boolean_parameters
  void set(bool exists) => state = exists;
}

/// Session courante : `null` lorsque l'application est verrouillée.
///
/// L'application est mono-utilisateur : cet état porte l'unique boutiquier
/// lorsqu'il a déverrouillé l'application.
final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

class AuthNotifier extends Notifier<AppUser?> {
  /// Marque une session ouverte, pour rouvrir sans redemander le mot de passe
  /// au prochain démarrage.
  static const _kSessionUserId = 'session_user_id';

  @override
  AppUser? build() => null;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Restaure la session enregistrée au démarrage de l'application.
  ///
  /// Restaure l'utilisateur via son ID de session ou, à défaut (ex. si les préférences
  /// ont été réinitialisées), via le compte principal existant en base de données.
  Future<bool> restoreSession() async {
    final prefs = ref.read(sharedPreferencesProvider);
    var id = prefs.getString(_kSessionUserId);
    AppUser? user;

    if (id != null) {
      user = await _repo.findById(id);
    }

    // Fallback : si aucun ID de session n'est enregistré ou valide, mais qu'un compte
    // existe en base de données (mono-utilisateur/admin), on restaure la session.
    if (user == null) {
      user = await _repo.currentAccount();
      if (user != null && user.isActive) {
        await prefs.setString(_kSessionUserId, user.id);
      }
    }

    if (user == null || !user.isActive) {
      await prefs.remove(_kSessionUserId);
      state = null;
      return false;
    }

    state = user;
    return true;
  }

  /// Crée le compte du boutiquier et ouvre immédiatement la session.
  ///
  /// Lève [AuthException] si un compte existe déjà.
  Future<AppUser> defineAccount({
    required String fullName,
    required String password,
  }) async {
    final user = await _repo.defineAccount(
      fullName: fullName,
      password: password,
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kSessionUserId, user.id);
    ref.read(accountExistsProvider.notifier).set(true);
    state = user;
    return user;
  }

  /// Déverrouille l'application. Lève [AuthException] si les identifiants sont faux.
  Future<AppUser> unlock({
    required String fullName,
    required String password,
  }) async {
    final user = await _repo.unlock(fullName: fullName, password: password);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kSessionUserId, user.id);
    state = user;
    return user;
  }

  /// Change le mot de passe. Lève [AuthException] si l'actuel est faux.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    if (state == null) throw StateError('Not logged in');
    return _repo.changePassword(
      state!.id,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Met à jour le nom du boutiquier et rafraîchit la session.
  Future<void> updateName(String fullName) async {
    if (state == null) throw StateError('Not logged in');
    state = await _repo.updateName(state!.id, fullName);
  }

  /// Met à jour l'avatar du boutiquier et rafraîchit la session.
  Future<void> updateAvatar(String? avatarPath) async {
    if (state == null) throw StateError('Not logged in');
    state = await _repo.updateAvatar(state!.id, avatarPath);
  }

  /// Verrouille l'application. La boutique reste configurée.
  Future<void> lock() async {
    await ref.read(sharedPreferencesProvider).remove(_kSessionUserId);
    state = null;
  }

  /// Verrouille et supprime le compte (réinitialisation de la configuration).
  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    await lock();
    ref.read(accountExistsProvider.notifier).set(false);
  }
}
