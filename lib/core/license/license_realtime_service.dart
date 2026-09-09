import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../config/neon_config.dart';

class LicenseRealtimeService {
  static const int p2pPort = 48500;
  static const String channelName = 'nmashop_license_events';

  RawDatagramSocket? _udpSocket;
  Connection? _pgConnection;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  final Future<String> Function() getHardwareId;
  final Future<String?> Function() getStoredKey;
  final void Function() onRevoked;
  final void Function(String key) onActivated;

  LicenseRealtimeService({
    required this.getHardwareId,
    required this.getStoredKey,
    required this.onRevoked,
    required this.onActivated,
  });

  /// Démarre l'écoute P2P local (LAN UDP) et Cloud Realtime (Neon LISTEN).
  void start() {
    _isDisposed = false;
    _startUdpListener();
    _startNeonRealtimeListener();
  }

  /// ── 1. Écoute P2P Réseau Local (LAN UDP Broadcast) ─────────────────────────
  Future<void> _startUdpListener() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        p2pPort,
        reuseAddress: true,
        reusePort: true,
      );
      _udpSocket?.broadcastEnabled = true;
      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            try {
              final raw = utf8.decode(datagram.data);
              final json = jsonDecode(raw) as Map<String, dynamic>;
              _handleIncomingEvent(json, source: 'P2P LAN');
            } catch (_) {}
          }
        }
      });
      debugPrint('[P2P] Écoute UDP locale active sur le port $p2pPort.');
    } catch (e) {
      debugPrint('[P2P] Port UDP indisponible ou erreur bind: $e');
    }
  }

  /// ── 2. Écoute Cloud Realtime (Neon PostgreSQL LISTEN) ──────────────────────
  Future<void> _startNeonRealtimeListener() async {
    if (_isDisposed) return;
    try {
      final config = NeonConfig.parseConnectionString();
      final directHost = (config['host'] as String).replaceAll('-pooler', '');

      _pgConnection = await Connection.open(
        Endpoint(
          host: directHost,
          port: config['port'],
          database: config['database'],
          username: config['username'],
          password: config['password'],
        ),
        settings: ConnectionSettings(
          sslMode: config['is_secure'] ? SslMode.require : SslMode.disable,
          connectTimeout: const Duration(seconds: 10),
        ),
      );

      _pgConnection?.channels[channelName].listen(
        (payload) {
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            _handleIncomingEvent(json, source: 'Neon Cloud Realtime');
          } catch (_) {}
        },
        onError: (err) {
          debugPrint('[Realtime] Erreur flux Neon: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[Realtime] Flux Neon terminé.');
          _scheduleReconnect();
        },
      );

      await _pgConnection?.execute('LISTEN $channelName;');
      debugPrint('[Realtime] Connecté avec succès au flux direct Neon.');
    } catch (e) {
      debugPrint('[Realtime] Connexion directe Neon échouée (reconnexion automatique): $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _startNeonRealtimeListener();
    });
  }

  /// ── 3. Traitement instantané de l'événement (P2P ou Cloud) ──────────────────
  Future<void> _handleIncomingEvent(Map<String, dynamic> data, {required String source}) async {
    final eventKey = (data['key'] as String? ?? '').trim().toUpperCase();
    final eventHwId = (data['hwId'] as String? ?? '').trim().toUpperCase();
    final isActive = data['isActive'] as bool? ?? true;

    final myHwId = (await getHardwareId()).trim().toUpperCase();
    final myKey = ((await getStoredKey()) ?? '').trim().toUpperCase();

    final matchesKey = eventKey.isNotEmpty && myKey.isNotEmpty && eventKey == myKey;
    final matchesHw = eventHwId.isNotEmpty && myHwId.isNotEmpty && eventHwId == myHwId;

    if (matchesKey || matchesHw) {
      debugPrint('[$source] Événement licence reçu instantanément : isActive = $isActive');
      if (!isActive) {
        onRevoked();
      } else if (isActive) {
        final keyToUse = eventKey.isNotEmpty ? eventKey : myKey;
        if (keyToUse.isNotEmpty) {
          onActivated(keyToUse);
        }
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _udpSocket?.close();
    try {
      _pgConnection?.close();
    } catch (_) {}
  }
}
