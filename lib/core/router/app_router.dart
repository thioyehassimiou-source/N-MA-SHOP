import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/license/license_provider.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/business/presentation/business_summary_screen.dart';
import '../../features/caisse/presentation/caisse_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/devis/presentation/devis_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/setup_screen.dart';
import '../../features/receivables/presentation/credits_screen.dart';
import '../../features/clients/presentation/clients_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/stock/presentation/products_screen.dart';
import '../../features/suppliers/presentation/purchase_screen.dart';
import '../../features/suppliers/presentation/suppliers_screen.dart';
import '../../features/deliveries/presentation/couriers_screen.dart';
import '../../features/deliveries/presentation/deliveries_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/equipe/presentation/equipe_screen.dart';
import '../../features/security/presentation/audit_logs_screen.dart';
import '../../features/help/presentation/help_screen.dart';
import '../../features/license/presentation/license_gate_screen.dart';
import '../../features/first_run/presentation/first_run_wizard_screen.dart';
import '../providers/app_settings_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Le routeur se rafraîchit à chaque changement de configuration boutique
  // ou de session (connexion / déconnexion).
  final notifier = ValueNotifier<bool>(false);
  ref.listen(appSettingsProvider, (previous, next) {
    notifier.value = !notifier.value;
  });
  ref.listen(authProvider, (previous, next) {
    notifier.value = !notifier.value;
  });
  ref.listen(accountExistsProvider, (previous, next) {
    notifier.value = !notifier.value;
  });
  ref.listen(licenseProvider, (previous, next) {
    notifier.value = !notifier.value;
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final settings = ref.read(appSettingsProvider);

      // ── 0. Premier démarrage : Séquence Onboarding -> Assistant de Configuration ──
      if (!settings.isSetupCompleted) {
        if (location == '/onboarding' || location == '/setup' || location == '/connexion') {
          return null;
        }
        return '/onboarding';
      }

      // Si le paramétrage est déjà complété et qu'on essaie d'accéder à /first-run ou /onboarding
      if (location == '/first-run') {
        return settings.isSetupCompleted ? '/' : '/onboarding';
      }

      // ── 2. Aucune boutique configurée ─────────────────────────────────────
      final shopExists =
          ref.read(accountExistsProvider) ||
          settings.isSetupCompleted;
      final isSignedIn = ref.read(authProvider) != null;

      if (!shopExists) {
        const allowedRoutes = {'/onboarding', '/setup', '/connexion'};
        return allowedRoutes.contains(location) ? null : '/onboarding';
      }

      // ── 3. Boutique existante mais verrouillée ────────────────────────────
      if (!isSignedIn) {
        const allowedUnauth = {'/connexion', '/onboarding', '/setup'};
        return allowedUnauth.contains(location) ? null : '/connexion';
      }

      // ── 4. Déverrouillé : écran de connexion et first-run inutiles ──────
      if (location == '/connexion' || location == '/first-run') {
        return '/';
      }

      // ── 5. Bloquer l'accès à l'équipe pour les vendeurs ───────────────────
      final user = ref.read(authProvider);
      if (user != null && user.role.name == 'cashier' && location == '/equipe') {
        return '/';
      }

      return null;
    },
    routes: [
      // ── Main App Routes ────────────────────────────────────────
      GoRoute(
        path: '/first-run',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: FirstRunWizardScreen()),
      ),
      GoRoute(
        path: '/licence',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LicenseGateScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: OnboardingScreen()),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SetupScreen()),
      ),
      GoRoute(
        path: '/connexion',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/vendre',
            pageBuilder: (c, s) => const NoTransitionPage(child: SalesScreen()),
          ),
          GoRoute(
            path: '/caisse',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: CaisseScreen()),
          ),
          GoRoute(
            path: '/devis',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: DevisScreen()),
          ),
          GoRoute(
            path: '/produits',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: ProductsScreen()),
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: ClientsScreen()),
          ),
          GoRoute(
            path: '/credits',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: CreditsScreen()),
          ),
          GoRoute(
            path: '/commandes',
            pageBuilder: (c, s) => const NoTransitionPage(
              child: OrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/livraisons',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: DeliveriesScreen()),
          ),
          GoRoute(
            path: '/livreurs',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: CouriersScreen()),
          ),
          GoRoute(
            path: '/depenses',
            pageBuilder: (c, s) => const NoTransitionPage(
              child: ExpensesScreen(),
            ),
          ),
          GoRoute(
            path: '/rapports',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: '/equipe',
            pageBuilder: (c, s) => const NoTransitionPage(
              child: EquipeScreen(),
            ),
          ),
          GoRoute(
            path: '/fournisseurs',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: SuppliersScreen()),
          ),
          GoRoute(
            path: '/nouvel-achat',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: PurchaseScreen()),
          ),
          GoRoute(
            path: '/mon-commerce',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: BusinessSummaryScreen()),
          ),
          GoRoute(
            path: '/reglages',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: SettingsScreen(initialTabIndex: 0)),
          ),
          GoRoute(
            path: '/reglages/securite',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: SettingsScreen(initialTabIndex: 2)),
          ),
          GoRoute(
            path: '/settings/audit',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: AuditLogsScreen()),
          ),
          GoRoute(
            path: '/aide',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: HelpScreen()),
          ),
        ],
      ),
    ],
  );
});
