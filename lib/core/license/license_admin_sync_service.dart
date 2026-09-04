import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../config/neon_config.dart';

class LicenseSyncPayload {
  final String businessName;
  final String ownerName;
  final String phone;
  final String address;
  final String hardwareId;
  final String licenseKey;
  final DateTime activatedAt;
  final DateTime? expiryDate;

  LicenseSyncPayload({
    required this.businessName,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.hardwareId,
    required this.licenseKey,
    required this.activatedAt,
    this.expiryDate,
  });
}

class RemoteLicenseStatus {
  final bool isActive;
  final String licenseKey;
  final DateTime? expiryDate;

  RemoteLicenseStatus({
    required this.isActive,
    required this.licenseKey,
    this.expiryDate,
  });
}

class LicenseAdminSyncService {
  /// Envoie la notification d'activation en se connectant directement à Neon PostgreSQL.
  /// Nécessite une connexion Internet. Échoue silencieusement si hors-ligne.
  static Future<void> notifyActivation(LicenseSyncPayload payload) async {
    try {
      final config = NeonConfig.parseConnectionString();
      
      final connection = await Connection.open(
        Endpoint(
          host: config['host'],
          port: config['port'],
          database: config['database'],
          username: config['username'],
          password: config['password'],
        ),
        settings: ConnectionSettings(
          sslMode: config['is_secure'] ? SslMode.require : SslMode.disable,
          connectTimeout: const Duration(seconds: 15),
          queryTimeout: const Duration(seconds: 15),
        ),
      );

      // S'assure que la table existe (Idéalement ceci est fait en amont par l'Admin, 
      // mais on le met en `IF NOT EXISTS` pour être résilient).
      await connection.execute('''
        CREATE TABLE IF NOT EXISTS nmashop_activations (
          id SERIAL PRIMARY KEY,
          business_name TEXT NOT NULL,
          owner_name TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT,
          hardware_id TEXT NOT NULL,
          license_key TEXT NOT NULL,
          activated_at TIMESTAMP NOT NULL,
          expires_at TIMESTAMP,
          is_synced BOOLEAN DEFAULT false
        );
      ''');

      // Insertion sécurisée de l'activation
      await connection.execute(
        Sql.named('''
          INSERT INTO nmashop_activations (
            business_name, owner_name, phone, address, 
            hardware_id, license_key, activated_at, expires_at
          ) VALUES (
            @businessName, @ownerName, @phone, @address, 
            @hardwareId, @licenseKey, @activatedAt, @expiresAt
          );
        '''),
        parameters: {
          'businessName': payload.businessName,
          'ownerName': payload.ownerName,
          'phone': payload.phone,
          'address': payload.address,
          'hardwareId': payload.hardwareId,
          'licenseKey': payload.licenseKey,
          'activatedAt': payload.activatedAt,
          'expiresAt': payload.expiryDate,
        },
      );

      await connection.close();
      debugPrint('Synchronisation activation réussie vers Neon PostgreSQL.');
    } catch (e) {
      debugPrint('Impossible de synchroniser l\'activation vers Neon (hors-ligne ou erreur): $e');
    }
  }

  /// Notifie Neon qu'une licence a été désactivée ou révoquée sur le PC client (retour en mode essai).
  static Future<void> notifyDeactivation(String hardwareId, {String? licenseKey}) async {
    try {
      final config = NeonConfig.parseConnectionString();

      final connection = await Connection.open(
        Endpoint(
          host: config['host'],
          port: config['port'],
          database: config['database'],
          username: config['username'],
          password: config['password'],
        ),
        settings: ConnectionSettings(
          sslMode: config['is_secure'] ? SslMode.require : SslMode.disable,
          connectTimeout: const Duration(seconds: 10),
          queryTimeout: const Duration(seconds: 10),
        ),
      );

      await connection.execute('ALTER TABLE nmashop_activations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;');

      await connection.execute(
        Sql.named('''
          UPDATE nmashop_activations 
          SET is_active = false 
          WHERE hardware_id = @hwId OR (license_key = @key AND @key != '');
        '''),
        parameters: {
          'hwId': hardwareId,
          'key': licenseKey ?? '',
        },
      );

      await connection.close();
      debugPrint('Désactivation transmise avec succès à Neon PostgreSQL.');
    } catch (e) {
      debugPrint('Erreur notification désactivation Neon (hors-ligne): $e');
    }
  }

  /// Interroge Neon PostgreSQL pour obtenir la toute dernière licence associée
  /// au `hardwareId` (ou à la `licenseKey`).
  static Future<RemoteLicenseStatus?> checkRemoteLicenseInfo(
    String hardwareId, {
    String? licenseKey,
  }) async {
    try {
      final config = NeonConfig.parseConnectionString();

      final connection = await Connection.open(
        Endpoint(
          host: config['host'],
          port: config['port'],
          database: config['database'],
          username: config['username'],
          password: config['password'],
        ),
        settings: ConnectionSettings(
          sslMode: config['is_secure'] ? SslMode.require : SslMode.disable,
          connectTimeout: const Duration(seconds: 10),
          queryTimeout: const Duration(seconds: 10),
        ),
      );

      await connection.execute('ALTER TABLE nmashop_activations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;');

      final key = (licenseKey ?? '').trim().toUpperCase();
      final result = await connection.execute(
        Sql.named('''
          SELECT is_active, license_key, expires_at FROM nmashop_activations 
          WHERE (hardware_id = @hwId AND @hwId != '') OR (license_key = @key AND @key != '')
          ORDER BY id DESC LIMIT 1
        '''),
        parameters: {
          'key': key,
          'hwId': hardwareId,
        },
      );

      await connection.close();

      if (result.isNotEmpty) {
        final row = result.first;
        final isActive = (row[0] as bool?) ?? true;
        final licKey = (row[1] as String?) ?? '';
        final expiresAt = row[2] as DateTime?;

        return RemoteLicenseStatus(
          isActive: isActive,
          licenseKey: licKey,
          expiryDate: expiresAt,
        );
      }
    } catch (e) {
      debugPrint('Vérification à distance licence Neon (offline ou indisponible): $e');
    }
    return null;
  }

  /// Vérifie si la licence a été désactivée ou révoquée par l'Admin sur Neon PostgreSQL.
  static Future<bool?> checkRemoteStatus(String licenseKey, String hardwareId) async {
    final info = await checkRemoteLicenseInfo(hardwareId, licenseKey: licenseKey);
    return info?.isActive;
  }
}

