import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      // Fallback robuste pour Linux/Windows — ignorer les interfaces virtuelles
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

    // Démarrer le serveur HTTP sur un port fixe
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

    if (_server == null) return; // Aucun port disponible

    _server!.listen((HttpRequest request) async {
      // Headers CORS universels
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
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
        await request.response.close();
      }
    });
  }

  void _serveHtml(HttpRequest request) {
    // ZERO external dependencies — works fully offline on local Wi-Fi.
    // Uses native BarcodeDetector (Android Chrome 83+) for photo scanning.
    const html = '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>N'MaShop Scanner</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: sans-serif;
      background: #0F1B3D;
      color: #fff;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      text-align: center;
    }
    h2 { color: #E85D04; font-size: 22px; margin-bottom: 8px; }
    .sub { color: #AABBCC; font-size: 13px; margin-bottom: 24px; line-height: 1.5; }
    .btn {
      display: block;
      width: 100%;
      max-width: 320px;
      margin: 10px auto 0;
      padding: 16px;
      background: #E85D04;
      color: #fff;
      font-size: 17px;
      font-weight: bold;
      border: none;
      border-radius: 12px;
      cursor: pointer;
      text-align: center;
    }
    .btn-secondary { background: #1A3060; }
    .btn:active { opacity: 0.8; }
    .divider {
      width: 100%;
      max-width: 320px;
      margin: 28px auto 0;
      border-top: 1px solid rgba(255,255,255,0.12);
      padding-top: 20px;
    }
    .divider-label { color: #7890AA; font-size: 12px; margin-bottom: 12px; }
    #manual-input {
      display: block;
      width: 100%;
      max-width: 320px;
      margin: 0 auto;
      padding: 14px;
      font-size: 20px;
      border-radius: 10px;
      border: 2px solid #1A3060;
      background: #fff;
      color: #000;
      text-align: center;
      letter-spacing: 2px;
    }
    #manual-input:focus { border-color: #E85D04; outline: none; }
    #status {
      margin-top: 18px;
      font-size: 14px;
      color: #E85D04;
      min-height: 22px;
      line-height: 1.4;
    }
    #success-view {
      display: none;
      flex-direction: column;
      align-items: center;
    }
    .ok-icon { font-size: 80px; color: #4CAF50; }
    .ok-text { font-size: 22px; font-weight: bold; margin: 14px 0 8px; }
    .ok-sub { color: #AABBCC; font-size: 14px; margin-bottom: 24px; }
  </style>
</head>
<body>

  <div id="main-view">
    <h2>N'MaShop Scanner</h2>
    <p class="sub">Assurez-vous que votre telephone<br>est sur le même Wi-Fi que le PC.</p>

    <label class="btn" for="photo-input">Prendre une photo du code-barres</label>
    <input type="file" id="photo-input" accept="image/*" capture="environment" style="display:none">

    <div class="divider">
      <p class="divider-label">OU saisissez le code manuellement</p>
      <input type="text" id="manual-input" placeholder="Ex: 3582910090977" inputmode="numeric">
      <button class="btn btn-secondary" id="send-btn" style="margin-top:12px">Envoyer ce code</button>
    </div>

    <div id="status"></div>
  </div>

  <div id="success-view">
    <div class="ok-icon">&#10003;</div>
    <p class="ok-text">Code transmis au PC !</p>
    <p class="ok-sub">Le produit a été ajouté.</p>
    <button class="btn" id="reset-btn">Scanner un autre produit</button>
  </div>

  <script>
    var statusEl = document.getElementById('status');

    function setStatus(msg) {
      statusEl.textContent = msg;
    }

    function showSuccess() {
      document.getElementById('main-view').style.display = 'none';
      document.getElementById('success-view').style.display = 'flex';
    }

    function reset() {
      document.getElementById('manual-input').value = '';
      document.getElementById('photo-input').value = '';
      setStatus('');
      document.getElementById('success-view').style.display = 'none';
      document.getElementById('main-view').style.display = 'block';
    }

    function sendToPC(code) {
      setStatus('Envoi en cours...');
      var xhr = new XMLHttpRequest();
      xhr.open('POST', '/scan', true);
      xhr.onload = function() {
        if (xhr.status === 200) {
          showSuccess();
        } else {
          setStatus('Erreur serveur (' + xhr.status + '). Réessayez.');
        }
      };
      xhr.onerror = function() {
        setStatus('Impossible de joindre le PC. Vérifiez que vous êtes sur le même Wi-Fi.');
      };
      xhr.send(code);
    }

    // Bouton envoyer
    document.getElementById('send-btn').addEventListener('click', function() {
      var val = document.getElementById('manual-input').value.replace(/\\s/g, '');
      if (val.length === 0) {
        setStatus('Saisissez un code avant d\\'envoyer.');
        return;
      }
      sendToPC(val);
    });

    // Touche Entrée sur le champ
    document.getElementById('manual-input').addEventListener('keypress', function(e) {
      if (e.key === 'Enter' || e.keyCode === 13) {
        document.getElementById('send-btn').click();
      }
    });

    // Bouton reset
    document.getElementById('reset-btn').addEventListener('click', reset);

    // Photo avec BarcodeDetector natif (Android Chrome 83+)
    document.getElementById('photo-input').addEventListener('change', function(e) {
      var file = e.target.files[0];
      if (!file) return;

      if (typeof BarcodeDetector === 'undefined') {
        setStatus('Détection photo non disponible. Saisissez le code manuellement.');
        e.target.value = '';
        return;
      }

      setStatus('Analyse de la photo en cours...');
      
      // Redimensionner l'image pour éviter les problèmes mémoire sur mobile
      var img = new Image();
      var objectUrl = URL.createObjectURL(file);
      img.onload = function() {
        URL.revokeObjectURL(objectUrl);
        
        // Limiter à 1280px max pour économiser la mémoire
        var maxDim = 1280;
        var w = img.width, h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) { h = Math.round(h * maxDim / w); w = maxDim; }
          else { w = Math.round(w * maxDim / h); h = maxDim; }
        }
        
        var canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        var ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, w, h);
        
        var detector = new BarcodeDetector({
          formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'itf', 'codabar']
        });
        detector.detect(canvas).then(function(codes) {
          document.getElementById('photo-input').value = '';
          if (codes.length === 0) {
            setStatus('Aucun code détecté. Rapprochez-vous et re-prenez la photo, ou saisissez manuellement.');
          } else {
            sendToPC(codes[0].rawValue);
          }
        }).catch(function() {
          document.getElementById('photo-input').value = '';
          setStatus('Erreur d\'analyse. Saisissez le code manuellement.');
        });
      };
      img.onerror = function() {
        URL.revokeObjectURL(objectUrl);
        setStatus('Impossible de lire la photo.');
        e.target.value = '';
      };
      img.src = objectUrl;
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
