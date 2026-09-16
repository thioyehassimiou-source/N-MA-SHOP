import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../license/license_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/database_provider.dart';
import '../services/hardware_id_service.dart';
import 'models/sync_event_payloads.dart';
import 'sync_queue_service.dart';

class SyncState {
  final int pendingCount;
  final DateTime? lastSyncTime;
  final bool isSyncing;
  final String? lastError;

  const SyncState({
    this.pendingCount = 0,
    this.lastSyncTime,
    this.isSyncing = false,
    this.lastError,
  });

  SyncState copyWith({
    int? pendingCount,
    DateTime? lastSyncTime,
    bool? isSyncing,
    String? lastError,
  }) {
    return SyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: lastError,
    );
  }
}

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncQueueService(db);
});

final desktopSyncWorkerProvider = NotifierProvider<DesktopSyncWorker, SyncState>(
  DesktopSyncWorker.new,
);

/// Worker d'arrière-plan responsable du dépilage et de l'envoi des événements vers le Cloud.
class DesktopSyncWorker extends Notifier<SyncState> {
  Timer? _timer;
  http.Client _client = http.Client();
  String _serverUrl = 'https://api.nmashop.gn';
  String _licenseKey = 'TEST-LICENSE-KEY';
  String? _caisseSecret;
  bool _isDisposed = false;

  @override
  SyncState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _timer?.cancel();
      _client.close();
    });

    final license = ref.watch(licenseInfoProvider);
    if (license.key != null && license.key!.isNotEmpty) {
      _licenseKey = license.key!;
    }

    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final customUrl = prefs.getString('custom_server_url');
      if (customUrl != null && customUrl.trim().isNotEmpty) {
        _serverUrl = customUrl.trim();
      }
      final secret = prefs.getString('caisse_secret');
      if (secret != null && secret.trim().isNotEmpty) {
        _caisseSecret = secret.trim();
      }
    } catch (_) {
      // Ignoré si sharedPreferences n'est pas disponible en environnement de test
    }

    // Rafraîchir le compteur initial au démarrage
    Future.microtask(() => refreshPendingCount());

    // Démarrer la boucle de synchronisation toutes les 30 secondes
    _startPeriodicSync();

    return const SyncState();
  }

  /// Initialise ou configure l'URL du serveur et la clé de licence.
  void configure({required String serverUrl, required String licenseKey, String? caisseSecret, http.Client? client}) {
    _serverUrl = serverUrl;
    _licenseKey = licenseKey;
    if (caisseSecret != null) _caisseSecret = caisseSecret;
    if (client != null) _client = client;
  }

  void _startPeriodicSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncNow();
    });
  }

  /// Rafraîchit le nombre d'événements en attente dans la file locale.
  Future<void> refreshPendingCount() async {
    final queueService = ref.read(syncQueueServiceProvider);
    final count = await queueService.getPendingCount();
    state = state.copyWith(pendingCount: count);
  }

  /// Force une tentative de synchronisation immédiate.
  Future<bool> syncNow() async {
    if (state.isSyncing || _isDisposed) return false;

    final queueService = ref.read(syncQueueServiceProvider);
    final pending = await queueService.getPendingEvents(limit: 50);

    if (pending.isEmpty) {
      state = state.copyWith(pendingCount: 0, isSyncing: false);
      return true;
    }

    state = state.copyWith(isSyncing: true, pendingCount: pending.length);

    try {
      final hwid = await HardwareIdService.getHardwareId();
      final dtos = pending.map((row) {
        return SyncEventDto(
          eventId: row.eventId,
          entityType: row.entityType,
          entityId: row.entityId,
          action: row.action,
          timestamp: row.createdAt,
          sequenceNumber: row.id,
          schemaVersion: 1,
          data: (jsonDecode(row.payload) as Map).cast<String, dynamic>(),
        );
      }).toList();

      final requestBody = SyncBatchRequest(
        machineId: hwid,
        licenseKey: _licenseKey,
        sentAt: DateTime.now(),
        events: dtos,
      );

      final uri = Uri.parse('$_serverUrl/api/v1/sync/push');
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final bodyStr = jsonEncode(requestBody.toJson());

      String? signature;
      if (_caisseSecret != null && _caisseSecret!.isNotEmpty) {
        final rawPayload = '$nowIso.$bodyStr';
        final hmac = Hmac(sha256, utf8.encode(_caisseSecret!));
        signature = hmac.convert(utf8.encode(rawPayload)).toString();
      }

      final headers = {
        HttpHeaders.contentTypeHeader: 'application/json',
        'X-Machine-Id': hwid,
        'X-License-Key': _licenseKey,
        'X-Timestamp': nowIso,
        if (signature != null) 'X-Signature': signature,
      };

      final response = await _client
          .post(
            uri,
            headers: headers,
            body: bodyStr,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final ids = pending.map((e) => e.id).toList();
        await queueService.deleteEvents(ids);
        final remaining = await queueService.getPendingCount();

        state = state.copyWith(
          pendingCount: remaining,
          lastSyncTime: DateTime.now(),
          isSyncing: false,
          lastError: null,
        );
        return true;
      } else {
        final ids = pending.map((e) => e.id).toList();
        await queueService.markFailed(ids, 'HTTP ${response.statusCode}: ${response.body}');
        state = state.copyWith(
          isSyncing: false,
          lastError: 'Erreur serveur ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      final ids = pending.map((e) => e.id).toList();
      await queueService.markFailed(ids, e.toString());
      state = state.copyWith(
        isSyncing: false,
        lastError: 'Erreur de connexion : $e',
      );
      return false;
    }
  }
}
