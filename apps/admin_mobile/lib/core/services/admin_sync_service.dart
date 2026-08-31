import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../config/neon_config.dart';
import '../models/client_model.dart';
import '../models/license_record.dart';
import '../repositories/admin_repository.dart';

class AdminSyncService {
  final AdminRepository _repository;

  AdminSyncService(this._repository);

  /// Vérifie s'il y a de nouvelles activations sur la base Neon et les enregistre.
  Future<void> fetchAndApplyPendingActivations() async {
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

      // S'assure que la table existe
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

      // Récupérer les activations non synchronisées
      final result = await connection.execute('''
        SELECT id, business_name, owner_name, phone, address, 
               hardware_id, license_key, activated_at, expires_at 
        FROM nmashop_activations 
        WHERE is_synced = false
      ''');

      final syncedIds = <int>[];

      for (final row in result) {
        final id = row[0] as int;
        final businessName = row[1] as String;
        final ownerName = row[2] as String;
        final phone = row[3] as String;
        final address = row[4] as String?;
        final hardwareId = row[5] as String;
        final licenseKey = row[6] as String;
        final activatedAt = row[7] as DateTime;
        final expiresAt = row[8] as DateTime?;

        final payload = {
          'businessName': businessName,
          'ownerName': ownerName,
          'phone': phone,
          'address': address,
          'hardwareId': hardwareId,
          'licenseKey': licenseKey,
          'activatedAt': activatedAt.toIso8601String(),
          'expiryDate': expiresAt?.toIso8601String(),
        };

        await _processActivationPayload(payload);
        syncedIds.add(id);
      }

      // Synchroniser les révocations / désactivations (is_active = false) depuis Neon
      await connection.execute('ALTER TABLE nmashop_activations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;');
      final deactivatedResult = await connection.execute('''
        SELECT hardware_id, license_key 
        FROM nmashop_activations 
        WHERE is_active = false
      ''');

      for (final row in deactivatedResult) {
        final hwId = row[0] as String;
        final key = row[1] as String;

        final licenses = _repository.getLicenses();
        for (var lic in licenses) {
          if ((hwId.isNotEmpty && lic.hardwareId == hwId) || (key.isNotEmpty && lic.licenseKey == key)) {
            if (lic.isActive) {
              await _repository.saveLicense(lic.copyWith(isActive: false));
            }
          }
        }
      }

      await connection.close();
      if (syncedIds.isNotEmpty) {
        debugPrint('${syncedIds.length} activations synchronisées avec succès !');
      }
    } catch (e) {
      debugPrint('Impossible de récupérer les activations (hors-ligne ou erreur): $e');
    }
  }

  /// Traite un payload d'activation (provenant de Neon ou d'un scan QR)
  Future<void> _processActivationPayload(Map<String, dynamic> payload) async {
    try {
      final businessName = payload['businessName'] ?? 'Boutique Inconnue';
      final ownerName = payload['ownerName'] ?? 'Gérant Inconnu';
      final phone = payload['phone'] ?? '';
      final address = payload['address'] ?? '';
      final hardwareId = payload['hardwareId'] ?? '';
      final licenseKey = payload['licenseKey'] ?? '';
      
      final activatedAtStr = payload['activatedAt'];
      final expiryDateStr = payload['expiryDate'];
      
      final activatedAt = activatedAtStr != null ? DateTime.parse(activatedAtStr) : DateTime.now();
      final expiryDate = expiryDateStr != null ? DateTime.parse(expiryDateStr) : null;

      // Vérifier si le client existe déjà via son hardwareId
      final clients = _repository.getClients();
      ClientModel? existingClient;
      try {
        existingClient = clients.firstWhere((c) => c.hardwareId == hardwareId);
      } catch (_) {
        existingClient = null;
      }

      final clientId = existingClient?.id ?? const Uuid().v4();
      
      // 1. Créer ou Mettre à jour le Client
      final client = ClientModel(
        id: clientId,
        storeName: businessName,
        ownerName: ownerName,
        phone: phone,
        city: address, // Map address to city field or store it if modified
        address: address,
        hardwareId: hardwareId,
        createdAt: existingClient?.createdAt ?? activatedAt,
      );
      
      await _repository.saveClient(client);

      // 2. Vérifier si la licence existe déjà
      final licenses = _repository.getLicenses();
      final licenseExists = licenses.any((l) => l.licenseKey == licenseKey);

      if (!licenseExists) {
        // Déduire le type de licence
        AdminLicenseType type = AdminLicenseType.annual;
        if (expiryDate == null || expiryDate.year >= 9999) {
          type = AdminLicenseType.lifetime;
        } else {
          final diff = expiryDate.difference(activatedAt).inDays;
          if (diff <= 35) {
            type = AdminLicenseType.days30;
          } else if (diff <= 95) {
            type = AdminLicenseType.days90;
          } else if (diff <= 370) {
            type = AdminLicenseType.annual;
          }
        }

        final record = LicenseRecord(
          id: const Uuid().v4(),
          clientId: clientId,
          clientName: businessName,
          hardwareId: hardwareId,
          licenseKey: licenseKey,
          type: type,
          createdAt: activatedAt,
          expiresAt: expiryDate,
          amountPaid: 0.0, // Montant par défaut pour la synchro auto
          isActive: true,
        );
        
        await _repository.saveLicense(record);
      }
    } catch (e) {
      debugPrint('Erreur de traitement du payload d\'activation: $e');
    }
  }

  /// Traitement manuel d'un code QR ou texte copié
  Future<void> importManualPayload(String jsonString) async {
    // Reste identique pour le support 100% hors-ligne (QR Code)
    try {
      final data = jsonDecode(jsonString);
      if (data is Map<String, dynamic>) {
        await _processActivationPayload(data);
      } else if (data is List) {
        for (var item in data) {
          await _processActivationPayload(item);
        }
      }
    } catch (e) {
      throw Exception('Format de données invalide. Assurez-vous que c\'est un JSON valide.');
    }
  }

  /// Met à jour à distance l'état d'activation de la licence (is_active) sur Neon PostgreSQL
  Future<void> updateLicenseRemoteStatus(String licenseKey, bool isActive) async {
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

      // S'assurer que la table et la colonne is_active existent
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
          is_synced BOOLEAN DEFAULT false,
          is_active BOOLEAN DEFAULT true
        );
      ''');

      await connection.execute('ALTER TABLE nmashop_activations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;');

      await connection.execute(
        Sql.named('UPDATE nmashop_activations SET is_active = @isActive WHERE license_key = @key OR hardware_id = @key'),
        parameters: {
          'isActive': isActive,
          'key': licenseKey.trim().toUpperCase(),
        },
      );

      await connection.close();
      debugPrint('Statut de licence $licenseKey mis à jour sur Neon PostgreSQL: is_active = $isActive');
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du statut distant de la licence: $e');
    }
  }
}
