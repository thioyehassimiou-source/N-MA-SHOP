/// Configuration et identifiants par défaut du compte Super Admin de secours N'MaShop.
///
/// Ce compte est créé automatiquement en arrière-plan lors de l'initialisation
/// de l'application sur n'importe quelle machine. Il permet l'accès de secours
/// en cas d'oubli des identifiants par le boutiquier sans aucune perte de données.
abstract final class SuperAdminConfig {
  static const defaultId = 'super-admin-default-id';
  static const defaultUsername = 'superadmin';
  static const defaultPassword = 'admin123';
  static const defaultRecoveryCode = '9999';
}
