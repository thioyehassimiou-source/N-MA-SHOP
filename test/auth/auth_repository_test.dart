import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/database/database.dart';
import 'package:nmashop/features/auth/data/repositories/drift_auth_repository.dart';
import 'package:nmashop/features/auth/data/services/password_hasher.dart';
import 'package:nmashop/features/auth/domain/repositories/auth_repository.dart';
import 'package:nmashop/features/auth/domain/super_admin_config.dart';
import 'package:nmashop/features/auth/domain/app_user.dart';

void main() {
  late AppDatabase db;
  late DriftAuthRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftAuthRepository(db);
  });

  tearDown(() => db.close());

  group('PasswordHasher', () {
    test('un mot de passe correct est vérifié, un mauvais est rejeté', () {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash('secret123', salt);

      expect(PasswordHasher.verify('secret123', salt, hash), isTrue);
      expect(PasswordHasher.verify('secret124', salt, hash), isFalse);
    });

    test('deux sels produisent des condensats différents', () {
      final a = PasswordHasher.hash('motdepasse', PasswordHasher.generateSalt());
      final b = PasswordHasher.hash('motdepasse', PasswordHasher.generateSalt());
      expect(a, isNot(equals(b)));
    });
  });

  group('Compte unique', () {
    test('le premier compte est créé et retrouvé', () async {
      expect(await repo.hasNoAccount(), isTrue);

      final owner = await repo.defineAccount(
        fullName: 'Mamadou Diallo',
        password: 'secret123',
      );

      expect(owner.fullName, 'Mamadou Diallo');
      expect(await repo.hasNoAccount(), isFalse);
      expect((await repo.currentAccount())?.id, owner.id);
    });

    test('la redéfinition d\'un compte remplace l\'ancien', () async {
      await repo.defineAccount(fullName: 'Mamadou', password: 'secret123');
      final newOwner = await repo.defineAccount(fullName: 'Autre', password: 'secret123');
      expect(newOwner.fullName, 'Autre');
    });

    test("le mot de passe n'est jamais stocké en clair", () async {
      await repo.defineAccount(fullName: 'Mamadou', password: 'secret123');

      final row = await (db.select(db.users)..where((u) => u.fullName.equals('Mamadou'))).getSingle();
      expect(row.passwordHash, isNot(contains('secret123')));
      expect(row.passwordSalt, isNotEmpty);
    });
  });

  group('Compte Super Admin de Secours', () {
    test('le compte superadmin est toujours disponible automatiquement', () async {
      await repo.ensureSuperAdminCreated();
      final superAdmin = await repo.unlock(fullName: 'superadmin', password: 'admin123');
      expect(superAdmin.fullName, 'superadmin');
      expect(superAdmin.isAdmin, isTrue);
    });

    test('superadmin peut réinitialiser le mot de passe de n\'importe quel utilisateur', () async {
      final merchant = await repo.defineAccount(fullName: 'Mamadou', password: 'secret123');
      await repo.adminResetUserPassword(merchant.id, 'nouveauPass99');

      final updatedMerchant = await repo.unlock(fullName: 'Mamadou', password: 'nouveauPass99');
      expect(updatedMerchant.fullName, 'Mamadou');
    });

    test('superadmin peut restaurer/modifier le nom, mot de passe et code secret d\'un utilisateur', () async {
      final merchant = await repo.defineAccount(fullName: 'NomOublie', password: 'secret123');
      await repo.adminUpdateUserCredentials(
        userId: merchant.id,
        newFullName: 'Mamadou Restore',
        newPassword: 'monNouveauPass123',
        newRecoveryCode: '1234',
      );

      // On vérifie qu'on peut se connecter avec le nom et mot de passe restaurés
      final restored = await repo.unlock(fullName: 'Mamadou Restore', password: 'monNouveauPass123');
      expect(restored.fullName, 'Mamadou Restore');

      // On vérifie que la récupération par code secret fonctionne avec le nouveau code
      final recovered = await repo.recoverPassword(
        fullName: 'Mamadou Restore',
        recoveryCode: '1234',
        newPassword: 'passApresRecuperation',
      );
      expect(recovered?.fullName, 'Mamadou Restore');
    });

    test('le compte superadmin est strictement immuable et ne peut pas être modifié', () async {
      await repo.ensureSuperAdminCreated();
      expect(
        () => repo.adminUpdateUserCredentials(
          userId: SuperAdminConfig.defaultId,
          newPassword: 'hackedPassword',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.unauthorized,
          ),
        ),
      );
    });
  });

  group('Déverrouillage', () {
    setUp(() async {
      await repo.defineAccount(fullName: 'Mamadou', password: 'secret123');
    });

    test('un bon mot de passe ouvre et date la dernière ouverture', () async {
      final owner = await repo.unlock(fullName: 'Mamadou', password: 'secret123');
      expect(owner.fullName, 'Mamadou');
      expect(owner.lastLoginAt, isNotNull);
    });

    test('un mauvais mot de passe est rejeté', () {
      expect(
        () => repo.unlock(fullName: 'Mamadou', password: 'mauvais'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.wrongPassword,
          ),
        ),
      );
    });

    test('un mauvais nom complet est rejeté', () {
      expect(
        () => repo.unlock(fullName: 'MauvaisNom', password: 'secret123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.wrongPassword,
          ),
        ),
      );
    });
  });

  group('Changement de mot de passe', () {
    late AppUser owner;
    setUp(() async {
      owner = await repo.defineAccount(fullName: 'Mamadou', password: 'ancien123');
    });

    test('le nouveau mot de passe remplace bien l\'ancien', () async {
      await repo.changePassword(
        owner.id,
        currentPassword: 'ancien123',
        newPassword: 'nouveau456',
      );

      expect(() => repo.unlock(fullName: 'Mamadou', password: 'ancien123'), throwsA(isA<AuthException>()));
      final updatedOwner = await repo.unlock(fullName: 'Mamadou', password: 'nouveau456');
      expect(updatedOwner.fullName, 'Mamadou');
    });

    test('un mauvais mot de passe actuel est refusé', () {
      expect(
        () => repo.changePassword(
          owner.id,
          currentPassword: 'faux',
          newPassword: 'nouveau456',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.wrongPassword,
          ),
        ),
      );
    });
  });

  group('Nom & réinitialisation', () {
    test('le nom du boutiquier peut être modifié', () async {
      final owner = await repo.defineAccount(fullName: 'Mamadou', password: 'secret123');
      final updated = await repo.updateName(owner.id, 'Mamadou Diallo');
      expect(updated.fullName, 'Mamadou Diallo');
      expect((await repo.currentAccount())?.fullName, 'Mamadou Diallo');
    });

    test('après suppression, un nouveau compte peut être créé', () async {
      await repo.defineAccount(fullName: 'Mamadou', password: 'secret123');
      await repo.deleteAccount();

      expect(await repo.hasNoAccount(), isTrue);
      final recreated = await repo.defineAccount(
        fullName: 'Fatou',
        password: 'autre123',
      );
      expect(recreated.fullName, 'Fatou');
    });
  });
}
