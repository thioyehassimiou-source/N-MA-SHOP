import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider gérant l'état de la session de l'administrateur (vrai si connecté).
final adminAuthProvider = NotifierProvider<AdminAuthNotifier, bool>(AdminAuthNotifier.new);

class AdminAuthNotifier extends Notifier<bool> {
  static const _adminPrefKey = 'admin_master_pwd';

  @override
  bool build() => false; // Non connecté par défaut

  String _hashPassword(String password) {
    final bytes = utf8.encode('${password}nma_admin_salt_789');
    return sha256.convert(bytes).toString();
  }

  Future<bool> hasPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_adminPrefKey);
  }

  Future<bool> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminPrefKey, _hashPassword(password));
    state = true;
    return true;
  }

  Future<bool> login(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_adminPrefKey);
    if (stored == _hashPassword(password)) {
      state = true;
      return true;
    }
    return false;
  }

  void logout() => state = false;
}
