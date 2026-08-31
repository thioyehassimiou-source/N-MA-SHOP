import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/database/database.dart';
import 'core/license/license_service.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/providers/database_provider.dart';
import 'core/providers/startup_flags.dart';
import 'features/auth/application/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise les données de localisation FR (formats de dates/nombres).
  await initializeDateFormatting('fr', null);

  // Configuration des contraintes de fenêtre pour Desktop (Windows / Linux / macOS)
  try {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 768),
      minimumSize: Size(1024, 680),
      center: true,
      backgroundColor: Colors.white,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "N'MaShop - Gestion Commerciale & Caisse POS",
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(const Size(1024, 680));
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (_) {
    // Fallback si exécuté sur plateforme web/mobile
  }

  // Ouvre la base locale et SharedPreferences.
  final database = AppDatabase();
  final prefs = await SharedPreferences.getInstance();

  // Vérification de la licence (synchrone — prefs déjà en mémoire).
  // Résultat disponible avant le premier rendu pour éviter tout flash.
  LicenseService().check(prefs);

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  try {
    // Détecte la présence d'un compte en base AVANT le premier rendu : c'est ce
    // qui permet au routeur de mener directement au déverrouillage d'une boutique
    // déjà créée, plutôt que de forcer une nouvelle configuration.
    final hasAccount = !await container
        .read(authRepositoryProvider)
        .hasNoAccount();
    container.read(accountExistsProvider.notifier).set(hasAccount);

    // Des données métier (produits/ventes) peuvent exister sans compte : c'est le
    // cas d'une boutique dont le compte a été perdu. On le détecte pour proposer
    // « Reprendre ma boutique » au lieu de forcer une création.
    final productCount = await database.products.count().getSingle();
    final saleCount = await database.sales.count().getSingle();
    container
        .read(businessDataExistsProvider.notifier)
        .set(productCount > 0 || saleCount > 0);

    // Rouvre la session enregistrée avant le premier rendu : sans cela le
    // routeur afficherait brièvement l'écran de connexion à chaque démarrage.
    if (hasAccount) {
      if (prefs.getBool('is_setup_completed') != true) {
        await prefs.setBool('is_setup_completed', true);
      }
      await container.read(authProvider.notifier).restoreSession();
    }
  } catch (e, stack) {
    debugPrint("Erreur lors de l'initialisation au démarrage: $e\n$stack");
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GescomptaApp(),
    ),
  );
}
