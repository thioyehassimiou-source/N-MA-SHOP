import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/license/license_provider.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/admin/application/admin_auth_provider.dart';
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
import '../providers/app_settings_provider.dart';

// Imports Admin
import '../../features/admin/presentation/admin_login_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/dashboard/admin_dashboard_screen.dart';
import '../../features/admin/presentation/clients/admin_clients_screen.dart';
import '../../features/admin/presentation/licenses/admin_licenses_screen.dart';
import '../../features/admin/presentation/maintenance/admin_maintenance_screen.dart';

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
  ref.listen(adminAuthProvider, (previous, next) {
    notifier.value = !notifier.value;
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // ── 0. Priorité absolue : vérification de la licence ──────────────────
      final license = ref.read(licenseProvider);
      if (license.isExpired && !location.startsWith('/admin')) {
        return location == '/licence' ? null : '/licence';
      }
      // Si la licence est OK et qu'on est sur /licence, rediriger
      if (location == '/licence' && !license.isExpired) return '/';
      
      // ── Admin Routes Protection ──────────────────────────────────────────
      if (location.startsWith('/admin')) {
        final isAdminAuth = ref.read(adminAuthProvider);
        if (!isAdminAuth) {
          return location == '/admin/login' ? null : '/admin/login';
        } else if (location == '/admin/login') {
          return '/admin/dashboard';
        }
        return null;
      }

      // ── DEMO OVERRIDE: Forcer l'onboarding si isSetupCompleted = false ──
      if (!ref.read(appSettingsProvider).isSetupCompleted) {
        if (location == '/onboarding') return null;
        if (location == '/connexion') return null;
        return '/onboarding';
      }

      // ── 1. Aucune boutique configurée ─────────────────────────────────────
      final shopExists =
          ref.read(accountExistsProvider) ||
          ref.read(appSettingsProvider).isSetupCompleted;
      final isSignedIn = ref.read(authProvider) != null;

      if (!shopExists) {
        const allowedRoutes = {'/onboarding', '/setup', '/connexion'};
        return allowedRoutes.contains(location) ? null : '/onboarding';
      }

      // ── 2. Boutique existante mais verrouillée ────────────────────────────
      if (!isSignedIn) {
        const allowedUnauth = {'/connexion', '/onboarding', '/setup'};
        return allowedUnauth.contains(location) ? null : '/connexion';
      }

      // ── 3. Déverrouillé : écran de connexion inutile ──────────────────────
      if (location == '/connexion') {
        return '/';
      }

      // ── 4. Bloquer l'accès à l'équipe pour les vendeurs ───────────────────
      final user = ref.read(authProvider);
      if (user != null && user.role.name == 'cashier' && location == '/equipe') {
        return '/';
      }

      return null;
    },
    routes: [
      // ── Admin Routes ──────────────────────────────────────────
      GoRoute(
        path: '/admin/login',
        pageBuilder: (context, state) => const NoTransitionPage(child: AdminLoginScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            pageBuilder: (c, s) => const NoTransitionPage(child: AdminDashboardScreen()),
          ),
          GoRoute(
            path: '/admin/clients',
            pageBuilder: (c, s) => const NoTransitionPage(child: AdminClientsScreen()),
          ),
          GoRoute(
            path: '/admin/licenses',
            pageBuilder: (c, s) => const NoTransitionPage(child: AdminLicensesScreen()),
          ),
          GoRoute(
            path: '/admin/maintenance',
            pageBuilder: (c, s) => const NoTransitionPage(child: AdminMaintenanceScreen()),
          ),
        ],
      ),
      // ── Main App Routes ────────────────────────────────────────
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
                const NoTransitionPage(child: SettingsScreen()),
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
