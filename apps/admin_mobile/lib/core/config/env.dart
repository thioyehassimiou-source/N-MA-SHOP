import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'NEON_CONNECTION_STRING', obfuscate: true)
  static final String neonConnectionString = _Env.neonConnectionString;

  @EnviedField(varName: 'LICENSE_SECURITY_SALT', obfuscate: true)
  static final String licenseSecuritySalt = _Env.licenseSecuritySalt;

  @EnviedField(varName: 'LICENSE_SECRET_F1', obfuscate: true)
  static final String licenseSecretF1 = _Env.licenseSecretF1;

  @EnviedField(varName: 'LICENSE_SECRET_F2', obfuscate: true)
  static final String licenseSecretF2 = _Env.licenseSecretF2;

  @EnviedField(varName: 'LICENSE_SECRET_F3', obfuscate: true)
  static final String licenseSecretF3 = _Env.licenseSecretF3;

  @EnviedField(varName: 'LICENSE_SECRET_F4', obfuscate: true)
  static final String licenseSecretF4 = _Env.licenseSecretF4;

  @EnviedField(varName: 'LICENSE_SECRET_F5', obfuscate: true)
  static final String licenseSecretF5 = _Env.licenseSecretF5;
}
