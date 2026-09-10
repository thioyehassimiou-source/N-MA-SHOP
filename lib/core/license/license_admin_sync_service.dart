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
  final DateTime? activatedAt;
  final DateTime? serverTime;

  RemoteLicenseStatus({
    required this.isActive,
    required this.licenseKey,
    this.expiryDate,
    this.activatedAt,
    this.serverTime,
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

      await connection.execute('ALTER TABLE nmashop_activations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;');

      final cleanKey = payload.licenseKey.trim().toUpperCase();
      final cleanHwId = payload.hardwareId.trim().toUpperCase();

      // 1. Tenter d'abord de mettre à jour la pré-activation existante pour cette clé ou convertir un enregistrement d'essai existant
      final updateResult = await connection.execute(
        Sql.named('''
          UPDATE nmashop_activations 
          SET business_name = @businessName,
              owner_name = @ownerName,
              phone = @phone,
              address = @address,
              hardware_id = @hardwareId,
              license_key = @licenseKey,
              activated_at = @activatedAt,
              expires_at = @expiresAt,
              is_synced = false,
              is_active = true
          WHERE license_key = @licenseKey 
             OR (hardware_id = @hardwareId AND (license_key LIKE 'TRIAL-%' OR license_key = ''));
        '''),
        parameters: {
          'businessName': payload.businessName,
          'ownerName': payload.ownerName,
          'phone': payload.phone,
          'address': payload.address,
          'hardwareId': cleanHwId,
          'licenseKey': cleanKey,
          'activatedAt': payload.activatedAt,
          'expiresAt': payload.expiryDate,
        },
      );

      // 2. Si la licence n'avait pas été pré-enregistrée sur Neon, insérer une nouvelle ligne
      if (updateResult.affectedRows == 0) {
        await connection.execute(
          Sql.named('''
            INSERT INTO nmashop_activations (
              business_name, owner_name, phone, address, 
              hardware_id, license_key, activated_at, expires_at,
              is_synced, is_active
            ) VALUES (
              @businessName, @ownerName, @phone, @address, 
              @hardwareId, @licenseKey, @activatedAt, @expiresAt,
              false, true
            );
          '''),
          parameters: {
            'businessName': payload.businessName,
            'ownerName': payload.ownerName,
            'phone': payload.phone,
            'address': payload.address,
            'hardwareId': cleanHwId,
            'licenseKey': cleanKey,
            'activatedAt': payload.activatedAt,
            'expiresAt': payload.expiryDate,
          },
        );
      }

      await connection.close();
      debugPrint('Synchronisation activation réussie vers Neon PostgreSQL.');
    } catch (e) {
      debugPrint('Impossible de synchroniser l\'activation vers Neon (hors-ligne ou erreur): $e');
    }
  }

  /// Déclare automatiquement une nouvelle machine ou installation en période d'essai
  /// vers Neon PostgreSQL pour que l'administrateur la voie en temps réel sur l'application mobile.
  /// 100% silencieux et non-bloquant : n'interrompt jamais l'application si hors-ligne.
  static Future<void> reportTrialInstallation({
    required String hardwareId,
    required DateTime firstLaunch,
    required DateTime trialExpiry,
    String? businessName,
    String? ownerName,
    String? phone,
    String? osInfo,
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
          connectTimeout: const Duration(seconds: 8),
          queryTimeout: const Duration(seconds: 8),
        ),
      );

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
      await connection.execute('ALTER TABLE nmashop_activations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;');

      final cleanHwId = hardwareId.trim().toUpperCase();
      final defaultKey = 'TRIAL-${cleanHwId.replaceAll('NMA-', '').replaceAll('-', '')}';

      // 1. Vérifier si cette machine est déjà enregistrée
      final existing = await connection.execute(
        Sql.named('SELECT id, license_key, is_active FROM nmashop_activations WHERE hardware_id = @hwId ORDER BY id DESC LIMIT 1;'),
        parameters: {'hwId': cleanHwId},
      );

      if (existing.isEmpty) {
        // Nouvelle installation détectée : insertion d'interception
        await connection.execute(
          Sql.named('''
            INSERT INTO nmashop_activations (
              business_name, owner_name, phone, address,
              hardware_id, license_key, activated_at, expires_at,
              is_synced, is_active
            ) VALUES (
              @businessName, @ownerName, @phone, @address,
              @hardwareId, @licenseKey, @activatedAt, @expiresAt,
              false, true
            );
          '''),
          parameters: {
            'businessName': businessName ?? 'Poste $cleanHwId',
            'ownerName': ownerName ?? 'Utilisateur Essai',
            'phone': phone ?? '',
            'address': osInfo ?? '',
            'hardwareId': cleanHwId,
            'licenseKey': defaultKey,
            'activatedAt': firstLaunch,
            'expiresAt': trialExpiry,
          },
        );
        debugPrint('[TELEMETRY] Machine d\'essai $cleanHwId enregistrée sur Neon cloud.');
      } else {
        // Déjà existante : si c'est toujours une clé TRIAL, rafraîchir les métadonnées sans écraser is_active
        final row = existing.first;
        final currentKey = (row[1] as String?) ?? '';
        if (currentKey.startsWith('TRIAL-') || currentKey.isEmpty) {
          final isTrialStillValid = trialExpiry.isAfter(DateTime.now());
          await connection.execute(
            Sql.named('''
              UPDATE nmashop_activations 
              SET business_name = COALESCE(NULLIF(@businessName, ''), business_name),
                  owner_name = COALESCE(NULLIF(@ownerName, ''), owner_name),
                  phone = COALESCE(NULLIF(@phone, ''), phone),
                  address = COALESCE(NULLIF(@address, ''), address),
                  expires_at = @expiresAt,
                  is_active = CASE WHEN @isTrialValid THEN true ELSE is_active END
              WHERE hardware_id = @hwId AND (license_key LIKE 'TRIAL-%' OR license_key = '');
            '''),
            parameters: {
              'businessName': businessName ?? '',
              'ownerName': ownerName ?? '',
              'phone': phone ?? '',
              'address': osInfo ?? '',
              'expiresAt': trialExpiry,
              'isTrialValid': isTrialStillValid,
              'hwId': cleanHwId,
            },
          );
        }
      }

      await connection.close();
    } catch (e) {
      debugPrint('[TELEMETRY] Télémétrie essai différée (hors-ligne ou indisponible): $e');
    }
  }

  /// Notifie Neon qu'une licence officielle a été révoquée/réinitialisée.
  /// Sécurité : n'agit JAMAIS sur un poste d'essai ou sans clé payante explicite.
  static Future<void> notifyDeactivation(String hardwareId, {String? licenseKey}) async {
    final cleanKey = (licenseKey ?? '').trim().toUpperCase();
    if (cleanKey.isEmpty || cleanKey.startsWith('TRIAL-') || cleanKey == 'ESSAI-GRATUIT') {
      // Les postes en mode essai ne doivent JAMAIS se faire bannir du cloud par le client PC.
      return;
    }

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

      // Désactiver uniquement cette clé précise
      await connection.execute(
        Sql.named('''
          UPDATE nmashop_activations 
          SET is_active = false 
          WHERE license_key = @key;
        '''),
        parameters: {'key': cleanKey},
      );

      await connection.close();
      debugPrint('Désactivation transmise avec succès à Neon PostgreSQL.');
    } catch (e) {
      debugPrint('Erreur notification désactivation Neon (hors-ligne): $e');
    }
  }

  /// Interroge Neon PostgreSQL pour obtenir la licence associée au `hardwareId` ou à la `licenseKey`.
  /// - Si `licenseKey` est fournie : vérifie si cette licence précise a été révoquée par l'Admin.
  /// - Si `licenseKey` est absente (mode essai) : vérifie si une licence active a été attribuée à cet appareil.
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
      final cleanHwId = hardwareId.trim().toUpperCase();

      final Result result;
      if (key.isNotEmpty) {
        // 1. Poste sous licence : vérifier l'état le plus récent de cette clé ou machine
        result = await connection.execute(
          Sql.named('''
            SELECT is_active, license_key, expires_at, activated_at, (NOW() AT TIME ZONE 'UTC') as server_time 
            FROM nmashop_activations 
            WHERE license_key = @key OR (hardware_id = @hwId AND @hwId != '')
            ORDER BY id DESC LIMIT 1
          '''),
          parameters: {
            'key': key,
            'hwId': cleanHwId,
          },
        );
      } else if (cleanHwId.isNotEmpty) {
        // 2. Poste en essai : vérifier le statut le plus récent associé à cet appareil
        result = await connection.execute(
          Sql.named('''
            SELECT is_active, license_key, expires_at, activated_at, (NOW() AT TIME ZONE 'UTC') as server_time 
            FROM nmashop_activations 
            WHERE hardware_id = @hwId AND license_key != ''
            ORDER BY id DESC LIMIT 1
          '''),
          parameters: {'hwId': cleanHwId},
        );
      } else {
        await connection.close();
        return null;
      }

      await connection.close();

      if (result.isNotEmpty) {
        final row = result.first;
        final isActive = (row[0] as bool?) ?? true;
        final licKey = (row[1] as String?) ?? '';
        final expiresAt = row[2] as DateTime?;
        final activatedAt = row[3] as DateTime?;
        final serverTime = row[4] as DateTime?;

        return RemoteLicenseStatus(
          isActive: isActive,
          licenseKey: licKey,
          expiryDate: expiresAt,
          activatedAt: activatedAt,
          serverTime: serverTime,
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

