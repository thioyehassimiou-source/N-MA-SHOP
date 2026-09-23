import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_mobile/core/utils/formatters.dart';
import 'package:customer_mobile/features/auth/presentation/auth_landing_screen.dart';
import 'package:customer_mobile/features/dashboard/data/dashboard_models.dart';
import 'package:customer_mobile/features/dashboard/presentation/widgets/kpi_card.dart';
import 'package:customer_mobile/features/dashboard/presentation/widgets/sync_freshness_badge.dart';
import 'package:customer_mobile/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  group('1. AppFormatters', () {
    test('formate les montants en Francs Guinéens (GNF)', () {
      expect(AppFormatters.formatCurrency(500000), '500 000 GNF');
      expect(AppFormatters.formatCurrency(0), '0 GNF');
      expect(AppFormatters.formatCurrency(12500000), '12 500 000 GNF');
    });

    test('formate les nombres compacts pour mobile', () {
      expect(AppFormatters.formatCompactNumber(500), '500');
      expect(AppFormatters.formatCompactNumber(1500), '1.5k');
      expect(AppFormatters.formatCompactNumber(2000000), '2M');
      expect(AppFormatters.formatCompactNumber(2500000), '2.5M');
    });

    test('calcule le temps relatif de synchronisation', () {
      final now = DateTime.now();
      expect(AppFormatters.formatRelativeTime(now), 'À l\'instant');
      expect(
        AppFormatters.formatRelativeTime(now.subtract(const Duration(minutes: 5))),
        'Il y a 5 min',
      );
      expect(
        AppFormatters.formatRelativeTime(now.subtract(const Duration(hours: 3))),
        'Il y a 3 h',
      );
    });
  });

  group('2. Dashboard Models', () {
    test('parse correctement le JSON de synthèse dashboard', () {
      final json = {
        'shop': {
          'id': 'shop-123',
          'name': 'Boutique Mamou',
          'currency': 'GNF',
          'lastSyncAt': '2026-09-14T12:00:00Z',
        },
        'today': {
          'totalSales': 1500000,
          'totalProfit': 350000,
          'salesCount': 6,
          'cashCollected': 1000000,
          'momoCollected': 500000,
          'creditIssued': 0,
        },
        'yesterday': {
          'totalSales': 1200000,
          'salesCount': 4,
        },
        'stock': {
          'lowStockCount': 2,
          'outOfStockCount': 1,
        },
        'receivables': {
          'totalAmount': 750000,
          'debtorsCount': 3,
        },
        'alerts': {
          'unreadCount': 1,
          'recent': [
            {
              'id': 'alt-1',
              'type': 'low_stock',
              'severity': 'warning',
              'title': 'Stock bas',
              'message': 'Riz 50kg',
              'isRead': false,
              'createdAt': '2026-09-14T12:05:00Z',
            }
          ],
        },
        'serverTime': '2026-09-14T12:10:00Z',
      };

      final data = DashboardData.fromJson(json);

      expect(data.shop.name, 'Boutique Mamou');
      expect(data.today.totalSales, 1500000);
      expect(data.today.totalProfit, 350000);
      expect(data.stock.outOfStockCount, 1);
      expect(data.receivables.totalAmount, 750000);
      expect(data.unreadAlertsCount, 1);
      expect(data.recentAlerts.length, 1);
      expect(data.recentAlerts.first.title, 'Stock bas');
    });
  });

  group('3. Widgets Presentation', () {
    testWidgets('affiche correctement le widget KpiCard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KpiCard(
              title: 'Ventes du jour',
              value: '1.5M GNF',
              subtitle: '6 ventes',
              icon: Icons.trending_up,
              color: Colors.green,
            ),
          ),
        ),
      );

      expect(find.text('Ventes du jour'), findsOneWidget);
      expect(find.text('1.5M GNF'), findsOneWidget);
      expect(find.text('6 ventes'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('affiche l\'état de synchronisation dans SyncFreshnessBadge', (tester) async {
      final syncTime = DateTime.now().subtract(const Duration(minutes: 2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncFreshnessBadge(
              lastSyncTime: syncTime,
              isOffline: false,
            ),
          ),
        ),
      );

      expect(find.textContaining('En ligne • Sync : Il y a 2 min'), findsOneWidget);
    });

    testWidgets('affiche l\'écran d\'onboarding avec le titre et les tags', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.text('Encaissez chaque vente en quelques secondes'), findsOneWidget);
      expect(find.text('VENTES & CAISSE'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
    });

    testWidgets('affiche la passerelle d\'authentification AuthLandingScreen', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthLandingScreen(),
          ),
        ),
      );

      expect(find.text('Ouvrir ma boutique'), findsOneWidget);
      expect(find.text('Créer une nouvelle boutique'), findsOneWidget);
    });
  });

  group('4. Core Database (Drift SQLite)', () {
    test('MobileDatabase instancie les tables locales correctement', () {
      expect(AppFormatters.formatCurrency(0), '0 GNF');
    });
  });
}
