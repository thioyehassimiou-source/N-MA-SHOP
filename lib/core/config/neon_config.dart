class NeonConfig {
  /// URL de connexion Neon PostgreSQL.
  /// Remplacer par la véritable Connection String avant la compilation.
  /// Format attendu : postgresql://[user]:[password]@[host]/[dbname]?sslmode=require
  static const String connectionString = 'postgresql://neondb_owner:npg_bY9MjSynWF4N@ep-long-scene-aeya27z7-pooler.c-2.us-east-2.aws.neon.tech/neondb?sslmode=require';

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
