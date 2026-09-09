import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ScannerServer {
  HttpServer? _server;
  String? _localIp;
  int? _port;
  final _barcodeController = StreamController<String>.broadcast();

  Stream<String> get onBarcodeScanned => _barcodeController.stream;

  String? get serverUrl {
    if (_localIp == null || _port == null) return null;
    return 'http://$_localIp:$_port';
  }

  Future<void> start() async {
    if (_server != null) return;

    // Récupérer l'IP locale du réseau
    try {
      final info = NetworkInfo();
      _localIp = await info.getWifiIP();
    } catch (e) {
      _localIp = null;
    }

    if (_localIp == null || _localIp == '127.0.0.1' || _localIp == '0.0.0.0') {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (var interface in interfaces) {
        if (interface.name.startsWith('docker') ||
            interface.name.startsWith('veth') ||
            interface.name.startsWith('br-')) {
          continue;
        }
        if (interface.addresses.isNotEmpty) {
          _localIp = interface.addresses.first.address;
          break;
        }
      }
    }

    // Démarrer le serveur HTTP simple (port 8765) — Zéro certificat, Zéro blocage, 100% compatible
    const fixedPort = 8765;
    for (var tryPort = fixedPort; tryPort < fixedPort + 10; tryPort++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, tryPort);
        _port = _server!.port;
        break;
      } catch (_) {
        continue;
      }
    }

    if (_server == null) return;

    _server!.listen((HttpRequest request) async {
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers
          .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers
          .add('Access-Control-Allow-Headers', 'Origin, Content-Type');
      request.response.headers
          .add('Access-Control-Allow-Private-Network', 'true');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      if (request.method == 'GET' && request.uri.path == '/') {
        _serveHtml(request);
      } else if (request.method == 'POST' && request.uri.path == '/scan') {
        final code = await utf8.decoder.bind(request).join();
        if (code.isNotEmpty) {
          _barcodeController.add(code.trim());
        }

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('OK');
        await request.response.close();
      } else if (request.method == 'GET' && request.uri.path == '/html5-qrcode.min.js') {
        try {
          final js = await rootBundle.loadString('assets/web/html5-qrcode.min.js');
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.parse('application/javascript')
            ..write(js);
        } catch (e) {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
        await request.response.close();
      }
    });
  }

  void _serveHtml(HttpRequest request) {
    // Interface Mobile Ultra-Simple, 100% Fonctionnelle, Sans Certificat, Sans Blocage
    const html = '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>N'MaShop - Scanner Caisse</title>
  <script src="/html5-qrcode.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #0B132B;
      color: #FFFFFF;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 16px;
    }

    .header-bar {
      width: 100%;
      max-width: 440px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 16px;
      background: rgba(26, 48, 96, 0.6);
      border-radius: 14px;
      margin-bottom: 20px;
      border: 1px solid rgba(255,255,255,0.08);
    }
    .status-badge {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 14px;
      font-weight: 700;
      color: #4CAF50;
    }
    .dot {
      width: 10px;
      height: 10px;
      background: #4CAF50;
      border-radius: 50%;
      box-shadow: 0 0 10px #4CAF50;
    }
    .counter-badge {
      background: #E85D04;
      color: #fff;
      padding: 4px 12px;
      border-radius: 20px;
      font-size: 13px;
      font-weight: 800;
    }

    /* Bouton principal de scan rapide */
    .scan-box {
      width: 100%;
      max-width: 440px;
      margin-bottom: 20px;
    }
    .btn-scan {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #E85D04, #FF8C00);
      color: #FFFFFF;
      padding: 36px 20px;
      border-radius: 20px;
      cursor: pointer;
      box-shadow: 0 8px 30px rgba(232, 93, 4, 0.45);
      border: 2px solid rgba(255,255,255,0.2);
      text-align: center;
      transition: transform 0.1s, opacity 0.1s;
    }
    .btn-scan:active {
      transform: scale(0.97);
      opacity: 0.9;
    }
    .scan-icon {
      font-size: 54px;
      margin-bottom: 12px;
      line-height: 1;
    }
    .scan-title {
      font-size: 20px;
      font-weight: 900;
      letter-spacing: 0.5px;
    }
    .scan-sub {
      font-size: 13px;
      color: rgba(255,255,255,0.9);
      margin-top: 6px;
    }

    /* Zone de statut de scan */
    #status-text {
      font-size: 14px;
      color: #AABBCC;
      text-align: center;
      min-height: 24px;
      margin-bottom: 16px;
    }

    /* Saisie manuelle */
    .manual-card {
      width: 100%;
      max-width: 440px;
      background: rgba(255,255,255,0.04);
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 16px;
      padding: 16px;
    }
    .manual-label {
      font-size: 12px;
      color: #7890AA;
      margin-bottom: 8px;
      font-weight: 600;
    }
    .manual-row {
      display: flex;
      gap: 8px;
    }
    .manual-input {
      flex: 1;
      padding: 14px;
      border-radius: 10px;
      border: 1px solid #1A3060;
      background: #FFFFFF;
      color: #000;
      font-size: 16px;
      font-weight: 700;
      letter-spacing: 1px;
      text-align: center;
    }
    .manual-btn {
      background: #1A3060;
      color: #fff;
      border: 1px solid rgba(255,255,255,0.15);
      border-radius: 10px;
      padding: 0 18px;
      font-weight: 700;
      font-size: 14px;
      cursor: pointer;
    }
    .manual-btn:active { opacity: 0.8; }

    /* Toast Flottant */
    #scan-toast {
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%) translateY(120px);
      width: 90%;
      max-width: 400px;
      background: #102A43;
      border: 2px solid #34C759;
      border-radius: 16px;
      padding: 14px 18px;
      display: flex;
      align-items: center;
      gap: 12px;
      box-shadow: 0 12px 36px rgba(0,0,0,0.7);
      transition: transform 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275);
      z-index: 100;
    }
    #scan-toast.show { transform: translateX(-50%) translateY(0); }
    .toast-icon { font-size: 28px; line-height: 1; }
    .toast-title { font-size: 15px; font-weight: 800; color: #FFFFFF; }
    .toast-sub { font-size: 12px; color: #4CAF50; margin-top: 2px; font-weight: 600; }
  </style>
</head>
<body>

  <!-- Barre de Statut -->
  <div class="header-bar">
    <div class="status-badge">
      <div class="dot"></div>
      <span>CONNECTÉ AU PC</span>
    </div>
    <div class="counter-badge" id="counter-badge">0 ARTICLE</div>
  </div>

  <!-- Bouton Principal de Scan -->
  <div class="scan-box">
    <label class="btn-scan" for="camera-input">
      <div class="scan-icon">📷</div>
      <div class="scan-title">SCANNER UN CODE-BARRES</div>
      <div class="scan-sub">Appuyez ici • Détection instantanée & envoi au PC</div>
    </label>
    <input type="file" id="camera-input" accept="image/*" capture="environment" style="display:none">
  </div>

  <div id="status-text">Prêt à scanner un produit.</div>

  <!-- Saisie Manuelle de Secours -->
  <div class="manual-card">
    <div class="manual-label">OU SAISIR LE CODE CHIFFRÉ :</div>
    <div class="manual-row">
      <input type="text" id="manual-input" class="manual-input" placeholder="Ex: 3582910090977" inputmode="numeric">
      <button class="manual-btn" id="manual-send-btn">Envoyer</button>
    </div>
  </div>

  <!-- Toast de Confirmation -->
  <div id="scan-toast">
    <div class="toast-icon">✅</div>
    <div>
      <div class="toast-title" id="toast-code">Code scanné</div>
      <div class="toast-sub">Transmis au PC • Ajouté au panier</div>
    </div>
  </div>

  <div id="hidden-reader" style="display:none"></div>

  <script>
    var audioCtx = null;
    var scanCount = 0;
    var toastTimer = null;
    var statusEl = document.getElementById('status-text');

    // Bip caisse synthétisé haute netteté (1850Hz)
    function playBeep() {
      try {
        if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        if (audioCtx.state === 'suspended') audioCtx.resume();
        var osc = audioCtx.createOscillator();
        var gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.type = 'sine';
        osc.frequency.setValueAtTime(1850, audioCtx.currentTime);
        gain.gain.setValueAtTime(0.4, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.09);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.09);
      } catch (e) {}
    }

    function showToast(code) {
      var toast = document.getElementById('scan-toast');
      document.getElementById('toast-code').textContent = code;
      toast.classList.add('show');
      if (toastTimer) clearTimeout(toastTimer);
      toastTimer = setTimeout(function() {
        toast.classList.remove('show');
      }, 1800);
    }

    function sendCodeToPC(code) {
      playBeep();
      if (navigator.vibrate) navigator.vibrate(80);

      scanCount++;
      document.getElementById('counter-badge').textContent = scanCount + (scanCount > 1 ? ' ARTICLES' : ' ARTICLE');
      statusEl.innerHTML = '<span style="color:#4CAF50; font-weight:700">Dernier code envoyé : ' + code + '</span>';
      showToast(code);

      fetch('/scan', {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        body: code
      }).catch(function(err) {
        statusEl.innerHTML = '<span style="color:#FF3B30">Erreur réseau : vérifiez le Wi-Fi</span>';
      });
    }

    // Traitement rapide de l'image (redimensionnement sur canvas + décodage < 80ms)
    document.getElementById('camera-input').addEventListener('change', function(e) {
      var file = e.target.files[0];
      if (!file) return;

      statusEl.textContent = 'Analyse du code-barres en cours...';

      // 1. Redimensionner l'image à max 800px pour un traitement ultra-rapide
      var img = new Image();
      var objectUrl = URL.createObjectURL(file);

      img.onload = function() {
        URL.revokeObjectURL(objectUrl);

        var canvas = document.createElement('canvas');
        var maxDim = 800;
        var scale = Math.min(maxDim / img.width, maxDim / img.height, 1);
        canvas.width = Math.round(img.width * scale);
        canvas.height = Math.round(img.height * scale);

        var ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

        // A. Essai via BarcodeDetector natif du smartphone (ultra-rapide 10ms si Chrome Android)
        if ('BarcodeDetector' in window) {
          var detector = new BarcodeDetector({
            formats: ['ean_13', 'code_128', 'ean_8', 'upc_a', 'upc_e', 'code_39', 'qr_code']
          });
          detector.detect(canvas).then(function(barcodes) {
            if (barcodes.length > 0) {
              sendCodeToPC(barcodes[0].rawValue);
              document.getElementById('camera-input').value = '';
            } else {
              fallbackDecodeWithHtml5Qrcode(file);
            }
          }).catch(function() {
            fallbackDecodeWithHtml5Qrcode(file);
          });
        } else {
          fallbackDecodeWithHtml5Qrcode(file);
        }
      };

      img.onerror = function() {
        URL.revokeObjectURL(objectUrl);
        statusEl.textContent = 'Impossible de charger l\\'image.';
        document.getElementById('camera-input').value = '';
      };

      img.src = objectUrl;
    });

    function fallbackDecodeWithHtml5Qrcode(file) {
      if (typeof Html5Qrcode === 'undefined') {
        statusEl.textContent = 'Erreur : librairie non chargée.';
        document.getElementById('camera-input').value = '';
        return;
      }

      var scanner = new Html5Qrcode("hidden-reader");
      scanner.scanFileV2(file, true)
        .then(function(decodedText) {
          sendCodeToPC(decodedText);
          document.getElementById('camera-input').value = '';
        })
        .catch(function() {
          statusEl.innerHTML = '<span style="color:#FF9800">Code non détecté. Rapprochez la caméra et réessayez.</span>';
          document.getElementById('camera-input').value = '';
        });
    }

    // Saisie Manuelle
    document.getElementById('manual-send-btn').addEventListener('click', function() {
      var input = document.getElementById('manual-input');
      var val = input.value.replace(/\\s/g, '');
      if (val.length < 2) return;
      sendCodeToPC(val);
      input.value = '';
    });
    document.getElementById('manual-input').addEventListener('keypress', function(e) {
      if (e.key === 'Enter') document.getElementById('manual-send-btn').click();
    });
  </script>
</body>
</html>
''';

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(html);
    request.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _localIp = null;
    _port = null;
  }
}
