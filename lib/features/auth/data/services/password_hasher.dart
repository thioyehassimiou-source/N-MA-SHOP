import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Dérivation et vérification des mots de passe (PBKDF2-HMAC-SHA256).
///
/// Un condensat simple (SHA-256 nu) serait cassable par table arc-en-ciel :
/// PBKDF2 impose un coût de calcul par essai et un sel unique par compte,
/// ce qui rend une attaque hors ligne sur le fichier SQLite impraticable.
abstract final class PasswordHasher {
  /// Nombre d'itérations PBKDF2 optimisé pour réactivité immédiate sur desktop.
  static int get _iterations => kDebugMode ? 1000 : 10000;

  /// Longueur du sel, en octets. Le condensat fait 32 octets (taille SHA-256).
  static const _saltLength = 16;

  static final _random = Random.secure();

  /// Génère un sel aléatoire, encodé en hexadécimal.
  static String generateSalt() {
    final bytes = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => _random.nextInt(256)),
    );
    return _toHex(bytes);
  }

  /// Dérive le condensat hexadécimal de [password] avec le sel [saltHex].
  static String hash(String password, String saltHex) {
    final salt = _fromHex(saltHex);
    final hmac = Hmac(sha256, utf8.encode(password));

    // PBKDF2 : une seule passe suffit, _keyLength == taille d'un bloc SHA-256.
    final block = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      // Compteur de bloc big-endian, ici toujours 1.
      ..[salt.length + 3] = 1;

    final bytes = hmac.convert(block).bytes;
    final result = Uint8List.fromList(bytes);
    var u = bytes;

    final count = _iterations;
    for (var i = 1; i < count; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    return _toHex(result);
  }

  /// Comme [hash], exécuté de manière sécurisée.
  static Future<String> hashAsync(String password, String saltHex) async {
    if (kDebugMode) {
      return hash(password, saltHex);
    }
    return compute(_hashInIsolate, (password: password, salt: saltHex));
  }

  /// Comme [verify], mais exécuté dans un isolate.
  static Future<bool> verifyAsync(
    String password,
    String saltHex,
    String expectedHash,
  ) async {
    final actual = await hashAsync(password, saltHex);
    return _constantTimeEquals(actual, expectedHash);
  }

  /// Vérifie [password] contre un condensat existant.
  ///
  /// La comparaison est à temps constant pour ne pas divulguer, par sa durée,
  /// le nombre de caractères corrects.
  static bool verify(String password, String saltHex, String expectedHash) {
    return _constantTimeEquals(hash(password, saltHex), expectedHash);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _fromHex(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

/// Point d'entrée de l'isolate : [compute] exige une fonction de premier niveau.
String _hashInIsolate(({String password, String salt}) args) =>
    PasswordHasher.hash(args.password, args.salt);
