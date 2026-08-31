import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import 'app_settings_provider.dart';

/// Mode clair / sombre. Par défaut : mode clair.
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void setMode(ThemeMode mode) {
    state = mode;
  }

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

/// Template visuel courant, dérivé du choix enregistré à la configuration.
///
/// Changer le template dans les réglages met à jour [appSettingsProvider], ce
/// qui recolore l'application entière sans redémarrage.
final paletteProvider = Provider<AppPalette>((ref) {
  final id = ref.watch(appSettingsProvider.select((s) => s.paletteId));
  return AppPalette.fromId(id);
});
