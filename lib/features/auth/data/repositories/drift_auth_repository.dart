import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/tables/users.dart';
import '../../domain/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/password_hasher.dart';

class DriftAuthRepository implements AuthRepository {
  DriftAuthRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Future<AppUser> defineAccount({
    required String fullName,
    required String password,
  }) async {
    final salt = PasswordHasher.generateSalt();
    final passwordHash = await PasswordHasher.hashAsync(password, salt);

    return _db.transaction(() async {
      // Purge de tout compte existant pour la création/réinitialisation de la boutique
      await _db.delete(_db.users).go();

      final row = await _db
          .into(_db.users)
          .insertReturning(
            UsersCompanion.insert(
              id: _uuid.v4(),
              fullName: fullName.trim(),
              passwordHash: passwordHash,
              passwordSalt: salt,
              role: const Value(UserRole.admin),
              isActive: const Value(true),
            ),
          );
      return _toDomain(row);
    });
  }

  @override
  Future<AppUser> createUser({
    required String fullName,
    required String password,
    required UserRole role,
  }) async {
    final salt = PasswordHasher.generateSalt();
    final row = await _db
        .into(_db.users)
        .insertReturning(
          UsersCompanion.insert(
            id: _uuid.v4(),
            fullName: fullName.trim(),
            passwordHash: await PasswordHasher.hashAsync(password, salt),
            passwordSalt: salt,
            role: Value(role),
            isActive: const Value(true),
          ),
        );
    return _toDomain(row);
  }

  @override
  Future<List<AppUser>> getAllUsers() async {
    final rows = await (_db.select(_db.users)
          ..orderBy([(u) => OrderingTerm(expression: u.createdAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> toggleUserStatus(String id, bool isActive) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(isActive: Value(isActive)),
    );
  }

  @override
  Future<AppUser> unlock({
    required String fullName,
    required String password,
  }) async {
    final row = await (_db.select(_db.users)
          ..where((u) => u.fullName.lower().equals(fullName.trim().toLowerCase())))
        .getSingleOrNull();

    if (row == null) {
      throw const AuthException(AuthFailure.wrongPassword);
    }

    if (!row.isActive) {
      throw const AuthException(AuthFailure.accountDisabled);
    }

    final ok = await PasswordHasher.verifyAsync(
      password,
      row.passwordSalt,
      row.passwordHash,
    );
    if (!ok) {
      throw const AuthException(AuthFailure.wrongPassword);
    }

    final now = DateTime.now();
    await (_db.update(_db.users)..where((u) => u.id.equals(row.id))).write(
      UsersCompanion(lastLoginAt: Value(now)),
    );

    return _toDomain(row.copyWith(lastLoginAt: Value(now)));
  }

  @override
  Future<void> changePassword(
    String userId, {
    required String currentPassword,
    required String newPassword,
  }) async {
    final row = await (_db.select(_db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (row == null) {
      throw const AuthException(AuthFailure.wrongPassword);
    }
    final ok = await PasswordHasher.verifyAsync(
      currentPassword,
      row.passwordSalt,
      row.passwordHash,
    );
    if (!ok) {
      throw const AuthException(AuthFailure.wrongPassword);
    }

    final salt = PasswordHasher.generateSalt();
    await (_db.update(_db.users)..where((u) => u.id.equals(row.id))).write(
      UsersCompanion(
        passwordSalt: Value(salt),
        passwordHash: Value(await PasswordHasher.hashAsync(newPassword, salt)),
      ),
    );
  }

  @override
  Future<AppUser> updateName(String userId, String fullName) async {
    final row = await (_db.select(_db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (row == null) {
      throw const AuthException(AuthFailure.wrongPassword);
    }
    await (_db.update(_db.users)..where((u) => u.id.equals(row.id))).write(
      UsersCompanion(fullName: Value(fullName.trim())),
    );
    return _toDomain(row.copyWith(fullName: fullName.trim()));
  }

  @override
  Future<AppUser> updateAvatar(String userId, String? avatarPath) async {
    final row = await (_db.select(_db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (row == null) {
      throw const AuthException(AuthFailure.wrongPassword);
    }
    await (_db.update(_db.users)..where((u) => u.id.equals(row.id))).write(
      UsersCompanion(avatarPath: Value(avatarPath)),
    );
    return _toDomain(row.copyWith(avatarPath: Value(avatarPath)));
  }

  @override
  Future<AppUser?> findById(String id) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<AppUser?> currentAccount() async {
    // Return first admin account if needed (legacy), but usually we shouldn't use this anymore
    // except for checking if ANY account exists or maybe fallback.
    final row = await (_db.select(_db.users)..orderBy([(u) => OrderingTerm(expression: u.createdAt)]) ..limit(1)).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<bool> hasNoAccount() async {
    return await _db.users.count().getSingle() == 0;
  }

  @override
  Future<void> deleteAccount() async {
    await _db.delete(_db.users).go();
  }

  AppUser _toDomain(User row) => AppUser(
    id: row.id,
    fullName: row.fullName,
    createdAt: row.createdAt,
    lastLoginAt: row.lastLoginAt,
    role: row.role,
    isActive: row.isActive,
    avatarPath: row.avatarPath,
  );
}
