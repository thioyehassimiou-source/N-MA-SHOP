import 'package:drift/drift.dart';

enum UserRole {
  admin,
  cashier,
}

/// Utilisateurs de l'application (Administrateurs et Vendeurs).
///
/// L'application supporte désormais plusieurs utilisateurs. Le compte par
/// défaut est un admin.
/// Le mot de passe n'est jamais stocké en clair : seul le condensat PBKDF2
/// ([passwordHash]) et son sel ([passwordSalt]) sont conservés.
class Users extends Table {
  TextColumn get id => text()();

  /// Nom du boutiquier/vendeur.
  TextColumn get fullName => text()();

  /// Condensat PBKDF2-HMAC-SHA256 du mot de passe, en hexadécimal.
  TextColumn get passwordHash => text()();

  /// Sel aléatoire, en hexadécimal.
  TextColumn get passwordSalt => text()();

  /// Rôle de l'utilisateur (0 = admin, 1 = cashier).
  IntColumn get role => intEnum<UserRole>().withDefault(const Constant(0))();

  /// Indique si le compte est actif. Un compte inactif ne peut pas se connecter.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Dernière ouverture réussie.
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  /// Chemin du fichier d'image d'avatar local.
  TextColumn get avatarPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
