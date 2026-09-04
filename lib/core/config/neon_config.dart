import 'env.dart';

class NeonConfig {
  /// URL de connexion Neon PostgreSQL (Obfusquée via Envied).
  static String get connectionString => Env.neonConnectionString;

  /// Extrait les paramètres de connexion depuis la chaîne.
  static Map<String, dynamic> parseConnectionString() {
    final uri = Uri.parse(connectionString);
    return {
      'host': uri.host,
      'port': uri.hasPort ? uri.port : 5432,
      'database': uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb',
      'username': uri.userInfo.split(':').first,
      'password': uri.userInfo.contains(':') ? uri.userInfo.split(':').last : '',
      'is_secure': connectionString.contains('sslmode=require'),
    };
  }
}
