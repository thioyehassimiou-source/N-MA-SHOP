part 'env.g.dart';

/// Configuration d'environnement et clés de sécurité cryptographiques N'MaShop.
abstract final class Env {
  static String get neonConnectionString => _Env.neonConnectionString;
  static String get licenseSecuritySalt => _Env.licenseSecuritySalt;
  static String get licenseSecretF1 => _Env.licenseSecretF1;
  static String get licenseSecretF2 => _Env.licenseSecretF2;
  static String get licenseSecretF3 => _Env.licenseSecretF3;
  static String get licenseSecretF4 => _Env.licenseSecretF4;
  static String get licenseSecretF5 => _Env.licenseSecretF5;
}

