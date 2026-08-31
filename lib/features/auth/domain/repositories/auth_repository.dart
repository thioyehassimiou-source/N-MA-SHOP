import '../../../../core/database/tables/users.dart';
import '../app_user.dart';

/// Cause d'échec de la définition, du déverrouillage ou du changement de mot
/// de passe.
enum AuthFailure {
  /// Le mot de passe saisi ne correspond pas.
  wrongPassword,
  
  /// Compte désactivé.
  accountDisabled,

  /// Un compte existe déjà : on ne peut pas en redéfinir un second.
  accountAlreadyExists,
  
  /// Action non autorisée (Rôle insuffisant).
  unauthorized;

  String get message => switch (this) {
    AuthFailure.wrongPassword => 'Nom ou mot de passe incorrect.',
    AuthFailure.accountDisabled => 'Ce compte a été désactivé par un administrateur.',
    AuthFailure.accountAlreadyExists => 'Un compte existe déjà.',
    AuthFailure.unauthorized => 'Action non autorisée. Réservée à l\'administrateur.',
  };
}

/// Erreur métier d'authentification.
class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  String get message => failure.message;

  @override
  String toString() => 'AuthException(${failure.name})';
}

/// Accès aux comptes utilisateurs.
abstract interface class AuthRepository {
  /// Crée le compte administrateur initial et le retourne.
  Future<AppUser> defineAccount({
    required String fullName,
    required String password,
  });

  /// Crée un nouvel utilisateur (Admin ou Vendeur).
  Future<AppUser> createUser({
    required String fullName,
    required String password,
    required UserRole role,
  });

  /// Liste tous les utilisateurs (pour le module Équipe).
  Future<List<AppUser>> getAllUsers();

  /// Active ou désactive un compte utilisateur.
  Future<void> toggleUserStatus(String id, bool isActive);

  /// Vérifie le nom complet et le mot de passe et met à jour la date de dernière ouverture.
  Future<AppUser> unlock({
    required String fullName,
    required String password,
  });

  /// Change le mot de passe après vérification de l'actuel.
  Future<void> changePassword(
    String userId, {
    required String currentPassword,
    required String newPassword,
  });

  /// Met à jour le nom du compte courant.
  Future<AppUser> updateName(String userId, String fullName);

  /// Met à jour la photo d'avatar du compte utilisateur.
  Future<AppUser> updateAvatar(String userId, String? avatarPath);

  /// Retrouve le compte par son identifiant, `null` s'il a été supprimé.
  Future<AppUser?> findById(String id);

  /// Le compte admin principal s'il existe (legacy fallback).
  Future<AppUser?> currentAccount();

  /// Vrai tant qu'aucun compte n'existe : l'application doit alors mener à la
  /// configuration.
  Future<bool> hasNoAccount();

  /// Supprime l'utilisateur par ID (ou tout si réinitialisation).
  Future<void> deleteAccount();
}
