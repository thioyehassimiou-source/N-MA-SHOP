import 'dart:convert';
import 'dart:io';
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

      // S'assure que la table et la colonne is_active existent
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

      // Récupérer toutes les activations enregistrées sur Neon
      final result = await connection.execute('''
        SELECT id, business_name, owner_name, phone, address, 
               hardware_id, license_key, activated_at, expires_at, is_active, is_synced 
        FROM nmashop_activations 
        ORDER BY id ASC
      ''');

      final unSyncedIds = <int>[];

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
        final isActive = (row[9] as bool?) ?? true;
        final isAlreadySynced = (row[10] as bool?) ?? false;

        final payload = {
          'businessName': businessName,
          'ownerName': ownerName,
          'phone': phone,
          'address': address,
          'hardwareId': hardwareId,
          'licenseKey': licenseKey,
          'activatedAt': activatedAt.toIso8601String(),
          'expiryDate': expiresAt?.toIso8601String(),
          'isActive': isActive,
        };

        await _processActivationPayload(payload);
        if (!isAlreadySynced) {
          unSyncedIds.add(id);
        }
      }

      // Marquer les activations non encore flaggées comme synchronisées
      if (unSyncedIds.isNotEmpty) {
        for (final id in unSyncedIds) {
          await connection.execute(
            Sql.named('UPDATE nmashop_activations SET is_synced = true WHERE id = @id'),
            parameters: {'id': id},
          );
        }
      }

      // Synchroniser les révocations / désactivations (is_active = false) depuis Neon
      final deactivatedResult = await connection.execute('''
        SELECT hardware_id, license_key 
        FROM nmashop_activations 
        WHERE is_active = false
      ''');

      for (final row in deactivatedResult) {
        final hwId = (row[0] as String).trim();
        final key = (row[1] as String).trim().toUpperCase();

        final licenses = _repository.getLicenses();
        for (var lic in licenses) {
          final isMatch = key.isNotEmpty
              ? (lic.licenseKey.trim().toUpperCase() == key)
              : (hwId.isNotEmpty && lic.hardwareId.trim() == hwId);
          if (isMatch && lic.isActive) {
            await _repository.saveLicense(lic.copyWith(isActive: false));
          }
        }
      }

      await connection.close();
      if (unSyncedIds.isNotEmpty) {
        debugPrint('${unSyncedIds.length} nouvelles machines/activations synchronisées !');
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
      final hardwareId = (payload['hardwareId'] ?? '').toString().trim().toUpperCase();
      final licenseKey = (payload['licenseKey'] ?? '').toString().trim().toUpperCase();
      final isActive = (payload['isActive'] as bool?) ?? true;
      
      final activatedAtStr = payload['activatedAt'];
      final expiryDateStr = payload['expiryDate'];
      
      final activatedAt = activatedAtStr != null ? DateTime.parse(activatedAtStr) : DateTime.now();
      final expiryDate = expiryDateStr != null ? DateTime.parse(expiryDateStr) : null;

      // Vérifier si le client existe déjà via son hardwareId
      final clients = _repository.getClients();
      ClientModel? existingClient;
      try {
        existingClient = clients.firstWhere((c) => c.hardwareId.trim().toUpperCase() == hardwareId);
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
        city: address,
        address: address,
        hardwareId: hardwareId,
        createdAt: existingClient?.createdAt ?? activatedAt,
      );
      
      await _repository.saveClient(client);

      // 2. Déduire le type de licence
      AdminLicenseType type = AdminLicenseType.annual;
      if (licenseKey.startsWith('TRIAL-') || licenseKey == 'ESSAI-GRATUIT') {
        type = AdminLicenseType.trial;
      } else if (expiryDate == null || expiryDate.year >= 9999) {
        type = AdminLicenseType.lifetime;
      } else {
        final diff = expiryDate.difference(activatedAt).inDays;
        if (diff <= 10) {
          type = AdminLicenseType.trial;
        } else if (diff <= 35) {
          type = AdminLicenseType.days30;
        } else if (diff <= 95) {
          type = AdminLicenseType.days90;
        } else if (diff <= 370) {
          type = AdminLicenseType.annual;
        }
      }

      // 3. Vérifier si la licence existe déjà (par clé ou par machine en mode essai)
      final licenses = _repository.getLicenses();
      final existingIndex = licenses.indexWhere((l) {
        final sameKey = l.licenseKey.trim().toUpperCase() == licenseKey;
        final sameMachineTrial = hardwareId.isNotEmpty &&
            l.hardwareId.trim().toUpperCase() == hardwareId &&
            (l.type == AdminLicenseType.trial || l.licenseKey.startsWith('TRIAL-'));
        return sameKey || sameMachineTrial;
      });

      if (existingIndex < 0) {
        final record = LicenseRecord(
          id: const Uuid().v4(),
          clientId: clientId,
          clientName: businessName,
          hardwareId: hardwareId,
          licenseKey: licenseKey,
          type: type,
          createdAt: activatedAt,
          expiresAt: expiryDate,
          amountPaid: 0.0,
          isActive: isActive,
        );
        
        await _repository.saveLicense(record);
      } else {
        // Enrichir le record existant (ex: mise à niveau d'un essai vers une clé payante ou MAJ statut)
        final existing = licenses[existingIndex];
        final updated = existing.copyWith(
          hardwareId: hardwareId.isNotEmpty ? hardwareId : existing.hardwareId,
          clientName: businessName != 'Boutique Inconnue' ? businessName : existing.clientName,
          clientId: clientId.isNotEmpty ? clientId : existing.clientId,
          licenseKey: licenseKey.isNotEmpty ? licenseKey : existing.licenseKey,
          type: type,
          expiresAt: expiryDate ?? existing.expiresAt,
          isActive: isActive,
        );
        await _repository.saveLicense(updated);
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
  Future<void> updateLicenseRemoteStatus(
    String licenseKey,
    bool isActive, {
    String? hardwareId,
    String? storeName,
    DateTime? expiresAt,
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

      final cleanKey = licenseKey.trim().toUpperCase();
      final cleanHwId = (hardwareId ?? '').trim().toUpperCase();

      final int affectedRows;
      if (cleanKey.isNotEmpty && cleanHwId.isNotEmpty) {
        final res = await connection.execute(
          Sql.named('UPDATE nmashop_activations SET is_active = @isActive WHERE license_key = @key OR hardware_id = @hwId'),
          parameters: {
            'isActive': isActive,
            'key': cleanKey,
            'hwId': cleanHwId,
          },
        );
        affectedRows = res.affectedRows;
      } else if (cleanKey.isNotEmpty) {
        final res = await connection.execute(
          Sql.named('UPDATE nmashop_activations SET is_active = @isActive WHERE license_key = @key'),
          parameters: {
            'isActive': isActive,
            'key': cleanKey,
          },
        );
        affectedRows = res.affectedRows;
      } else if (cleanHwId.isNotEmpty) {
        final res = await connection.execute(
          Sql.named('UPDATE nmashop_activations SET is_active = @isActive WHERE hardware_id = @hwId'),
          parameters: {
            'isActive': isActive,
            'hwId': cleanHwId,
          },
        );
        affectedRows = res.affectedRows;
      } else {
        affectedRows = 0;
      }

      // Si la ligne n'existait pas encore sur Neon, on l'insère immédiatement avec son statut (actif OU inactif)
      if (affectedRows == 0 && (cleanKey.isNotEmpty || cleanHwId.isNotEmpty)) {
        await connection.execute(
          Sql.named('''
            INSERT INTO nmashop_activations (
              business_name, owner_name, phone, address, hardware_id, license_key, activated_at, expires_at, is_synced, is_active
            ) VALUES (
              @businessName, @ownerName, '', '', @hwId, @key, @activatedAt, @expiresAt, true, @isActive
            )
          '''),
          parameters: {
            'businessName': storeName ?? 'Boutique Client',
            'ownerName': 'Client',
            'hwId': cleanHwId,
            'key': cleanKey,
            'activatedAt': DateTime.now(),
            'expiresAt': expiresAt,
            'isActive': isActive,
          },
        );
      }

      // Diffusion instantanée Cloud (PostgreSQL NOTIFY stream < 50ms)
      try {
        final payload = jsonEncode({
          'key': cleanKey,
          'hwId': cleanHwId,
          'isActive': isActive,
        });
        await connection.execute(
          Sql.named("SELECT pg_notify('nmashop_license_events', @payload);"),
          parameters: {'payload': payload},
        );
      } catch (e) {
        debugPrint('Erreur pg_notify: $e');
      }

      await connection.close();

      // Diffusion instantanée P2P Réseau Local (LAN UDP Broadcast 0ms)
      _broadcastP2PStatus(cleanKey, cleanHwId, isActive);

      debugPrint('Statut de licence $cleanKey synchronisé sur Neon PostgreSQL: is_active = $isActive');
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du statut distant de la licence: $e');
    }
  }

  /// Diffuse le statut en P2P local (LAN UDP Broadcast) sur le port 48500.
  void _broadcastP2PStatus(String cleanKey, String cleanHwId, bool isActive) {
    Future.microtask(() async {
      try {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        socket.broadcastEnabled = true;
        final data = utf8.encode(jsonEncode({
          'event': 'license_status',
          'key': cleanKey,
          'hwId': cleanHwId,
          'isActive': isActive,
        }));
        socket.send(data, InternetAddress('255.255.255.255'), 48500);
        socket.close();
        debugPrint('[P2P] Broadcast UDP local envoyé sur 255.255.255.255:48500');
      } catch (e) {
        debugPrint('[P2P] Erreur broadcast UDP local: $e');
      }
    });
  }

  /// Efface toutes les activations enregistrées sur Neon PostgreSQL lors d'une réinitialisation complète
  Future<void> purgeRemoteActivations() async {
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

      await connection.execute('DELETE FROM nmashop_activations;');
      await connection.close();
      debugPrint('Purge des activations sur Neon PostgreSQL réalisée avec succès.');
    } catch (e) {
      debugPrint('Erreur purge distante Neon: $e');
    }
  }
}
