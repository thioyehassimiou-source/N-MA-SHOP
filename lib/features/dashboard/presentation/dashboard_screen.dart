import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/database/tables/users.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_metric_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_button.dart';
import '../../sales/application/sales_providers.dart';
import '../application/dashboard_providers.dart';
import '../../../core/providers/app_settings_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardDataProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(28),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: Text('Erreur : $e')),
        ),
        data: (data) => _DashboardBody(data: data),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PageHeader(data: data),
        const SizedBox(height: 24),
        _MetricsGrid(data: data),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) {
            final chart = _RevenueChartCard(salesGrowth: data.salesGrowth);
            final payments = const _PaymentMethodsCard();
            final table = _RecentSalesCard(sales: data.recentSales);
            final alerts = _AlertsActionsCard(lowStockCount: data.lowStock.length);

            if (c.maxWidth < 1000) {
              return Column(
                children: [
                  chart,
                  const SizedBox(height: 20),
                  payments,
                  const SizedBox(height: 20),
                  table,
                  const SizedBox(height: 20),
                  alerts,
                ],
              );
            }
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: chart),
                    const SizedBox(width: 20),
                    Expanded(flex: 1, child: payments),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: table),
                    const SizedBox(width: 20),
                    Expanded(flex: 1, child: alerts),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────── Graphique Chiffre d'Affaires ───────────────────────────

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({this.salesGrowth});

  final double? salesGrowth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final growthText = salesGrowth == null
        ? '+0.0%'
        : '${salesGrowth! >= 0 ? '+' : ''}${salesGrowth!.toStringAsFixed(1)}%';

    return AppCard(
      height: 360,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chiffre d\'affaires',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          growthText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandEmerald,
                          ),
                        ),
                      ),
                      Text(
                        'vs période précédente',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '7 derniers jours',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lun', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('Mar', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('Mer', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('Jeu', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('Ven', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('Sam', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('Dim', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.context);
  final BuildContext context;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Theme.of(context).colorScheme.surfaceContainerLow
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    for (int i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Sample normalized data points [0..1] for 7 days
    final points = [
      Offset(0, size.height * 0.75),
      Offset(size.width * 0.16, size.height * 0.60),
      Offset(size.width * 0.33, size.height * 0.65),
      Offset(size.width * 0.50, size.height * 0.40),
      Offset(size.width * 0.66, size.height * 0.45),
      Offset(size.width * 0.83, size.height * 0.20),
      Offset(size.width, size.height * 0.10),
    ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p2.dx, p2.dy,
      );
    }

    // Fill under line gradient
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
      ],
    );

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw line
    final linePaint = Paint()
      ..color = Theme.of(context).colorScheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw active dot at the last point
    final lastPoint = points.last;
    canvas.drawCircle(
      lastPoint,
      6,
      Paint()..color = Theme.of(context).colorScheme.primary,
    );
    canvas.drawCircle(
      lastPoint,
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────── Carte Modes de Paiement ───────────────────────────

class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      height: 360,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modes de paiement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          const _PaymentItem(
            label: 'Espèces',
            percentage: 65,
            amount: '0 FCFA',
            color: AppColors.brandEmerald,
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 12),
          const _PaymentItem(
            label: 'Mobile Money',
            percentage: 25,
            amount: '0 FCFA',
            color: Color(0xFFF59E0B),
            icon: Icons.phone_android_outlined,
          ),
          const SizedBox(height: 12),
          _PaymentItem(
            label: 'Carte / Virement',
            percentage: 10,
            amount: '0 FCFA',
            color: Theme.of(context).colorScheme.primary,
            icon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 12),
          _PaymentItem(
            label: 'Crédit client',
            percentage: 0,
            amount: '0 FCFA',
            color: Theme.of(context).colorScheme.error,
            icon: Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  const _PaymentItem({
    required this.label,
    required this.percentage,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final int percentage;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Carte Alertes & Actions ───────────────────────────

class _AlertsActionsCard extends StatelessWidget {
  const _AlertsActionsCard({required this.lowStockCount});

  final int lowStockCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      height: 360,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alertes & actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (lowStockCount > 0)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.errorContainer),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$lowStockCount produit(s) en alerte de stock',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/stock'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Voir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.secondaryContainer),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.brandEmerald, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tout est en ordre ! Bonnes ventes 👍',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/vendre'),
                  icon: Icon(Icons.add_shopping_cart, size: 16),
                  label: Text('Vente'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/devis'),
                  icon: Icon(Icons.receipt_outlined, size: 16),
                  label: Text('Facture'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}




// ── En-tête de page (Bannière de bienvenue premium) ──────────────────────────

class _PageHeader extends ConsumerWidget {
  const _PageHeader({required this.data});
  final DashboardData data;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final settings = ref.watch(appSettingsProvider);
    final useCustom = settings.useCustomTheme;
    final colors = Theme.of(context).colorScheme;

    final firstName = user?.fullName.split(' ').first ?? 'Patron';
    final greeting = _getGreeting();

    final boxDecoration = useCustom
        ? BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          )
        : BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F1B3D),
                Color(0xFF1A2B52),
                Color(0xFF1E3A6E),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F1B3D).withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          );

    final onlineBadgeColor = useCustom ? colors.primary : const Color(0xFFE85D04);
    final onlineBadgeBg = useCustom ? colors.primary.withValues(alpha: 0.1) : const Color(0xFFE85D04).withValues(alpha: 0.2);
    final onlineBadgeBorder = useCustom ? colors.primary.withValues(alpha: 0.3) : const Color(0xFFE85D04).withValues(alpha: 0.5);
    final textColor = useCustom ? colors.onPrimaryContainer : Colors.white;
    final textSubColor = useCustom ? colors.onPrimaryContainer.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.65);

    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: onlineBadgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: onlineBadgeBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'EN LIGNE',
                        style: TextStyle(
                          color: onlineBadgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$greeting, $firstName ! 👋',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Voici le résumé de votre commerce aujourd'hui",
                  style: TextStyle(
                    color: textSubColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _BannerButton(
                      label: 'Exporter',
                      icon: Icons.download_outlined,
                      onTap: () => context.go('/rapports'),
                      outlined: true,
                    ),
                    const SizedBox(width: 10),
                    _BannerButton(
                      label: 'Actualiser',
                      icon: Icons.refresh_rounded,
                      onTap: () => ref.invalidate(dashboardDataProvider),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _BannerStat(
                  label: 'CA du jour',
                  value: formatGnfCompact(data.todaySales),
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 16),
                _BannerStat(
                  label: 'En caisse',
                  value: formatGnfCompact(data.cashAvailable),
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFFE85D04),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerButton extends ConsumerWidget {
  const _BannerButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCustom = ref.watch(appSettingsProvider).useCustomTheme;
    final colors = Theme.of(context).colorScheme;

    final primaryColor = useCustom ? colors.primary : const Color(0xFFE85D04);
    final textColor = useCustom ? (outlined ? colors.primary : colors.onPrimary) : Colors.white;
    final bgColor = outlined ? Colors.transparent : primaryColor;
    final borderColor = outlined
        ? (useCustom ? colors.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.3))
        : primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerStat extends ConsumerWidget {
  const _BannerStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCustom = ref.watch(appSettingsProvider).useCustomTheme;
    final colors = Theme.of(context).colorScheme;

    final bgColor = useCustom ? colors.surface.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08);
    final borderColor = useCustom ? colors.outline.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.12);
    final textColor = useCustom ? colors.onPrimaryContainer : Colors.white;
    final textSubColor = useCustom ? colors.onPrimaryContainer.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.7);
    final iconColor = useCustom ? colors.primary : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textSubColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────── Grille des indicateurs ───────────────────────────

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.data});

  final DashboardData data;

  String _pct(double? v) =>
      v == null ? '+0%' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int count;
        if (constraints.maxWidth < 600) {
          count = 1;
        } else if (constraints.maxWidth < 900) {
          count = 2;
        } else {
          count = 4;
        }

        final cards = [
          AppMetricCard(
            title: 'Ventes du jour',
            value: formatGnfCompact(data.todaySales),
            badgeText: _pct(data.salesGrowth),
            badgeColor: AppColors.brandEmerald,
            icon: Icons.shopping_cart_rounded,
            iconColor: AppColors.iconPurple,
            iconBackgroundColor: AppColors.iconPurpleBg,
          ),
          AppMetricCard(
            title: 'Solde de caisse',
            value: formatGnfCompact(data.cashAvailable),
            badgeText: 'Trésorerie Act...',
            badgeColor: AppColors.brandEmerald,
            icon: Icons.account_balance_rounded,
            iconColor: AppColors.iconGreen,
            iconBackgroundColor: AppColors.iconGreenBg,
          ),
          AppMetricCard(
            title: 'Crédits à recouvrer',
            value: formatGnfCompact(data.owed),
            badgeText: '${data.owedCount} clients',
            icon: Icons.credit_card_rounded,
            iconColor: AppColors.iconOrange,
            iconBackgroundColor: AppColors.iconOrangeBg,
          ),
          AppMetricCard(
            title: 'Produits en alerte',
            value: '${data.lowStock.length}',
            badgeText: data.lowStock.isEmpty ? 'Stock OK' : 'À réappro...',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.iconRed,
            iconBackgroundColor: AppColors.iconRedBg,
          ),
          AppMetricCard(
            title: 'Fournisseurs actifs',
            value: formatGnfCompact(data.supplierDebt),
            badgeText: 'Dettes fournisseurs',
            icon: Icons.storefront_rounded,
            iconColor: AppColors.iconNavy,
            iconBackgroundColor: AppColors.iconNavyBg,
          ),
          AppMetricCard(
            title: 'Ticket moyen',
            value: formatGnfCompact(data.avgTicket?.round() ?? 0),
            badgeText: 'Par transaction',
            badgeColor: AppColors.brandEmerald,
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.iconTeal,
            iconBackgroundColor: AppColors.iconTealBg,
          ),
          AppMetricCard(
            title: 'Taux de crédit',
            value: '${data.creditRate?.toStringAsFixed(1) ?? '0.0'}%',
            badgeText: 'Ventes à crédit',
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.iconCyan,
            iconBackgroundColor: AppColors.iconCyanBg,
            progressValue: (data.creditRate ?? 0) / 100,
            progressColor: AppColors.iconCyan,
          ),
          AppMetricCard(
            title: 'Croissance',
            value: _pct(data.salesGrowth),
            badgeText: 'vs mois dernier',
            badgeColor: AppColors.brandEmerald,
            icon: Icons.show_chart_rounded,
            iconColor: AppColors.iconBlue,
            iconBackgroundColor: AppColors.iconBlueBg,
            progressValue: ((data.salesGrowth ?? 0).clamp(-100, 100) + 100) / 200,
            progressColor: AppColors.iconBlue,
          ),
        ];

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 180,
          ),
          children: cards,
        );
      },
    );
  }
}

// ─────────────────────────── Ventes récentes ───────────────────────────

class _RecentSalesCard extends ConsumerWidget {
  const _RecentSalesCard({required this.sales});

  final List<RecentSaleView> sales;

  void _confirmCancel(BuildContext context, WidgetRef ref, RecentSaleView sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Annuler la vente ?'),
        content: Text(
          'Attention : Le stock sera restauré et les paiements associés seront effacés.\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(saleServiceProvider).cancel(sale.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vente annulée avec succès.')),
                  );
                  ref.invalidate(dashboardDataProvider);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')),
                  );
                }
              }
            },
            child: Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == UserRole.admin;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ventes récentes', style: theme.textTheme.titleMedium),
                AppButton.secondary(
                  onPressed: () => context.go('/mon-commerce'),
                  label: 'Voir tout',
                ),
              ],
            ),
          ),
          if (sales.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Aucune vente pour le moment.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            AppTable(
              columns: const [
                DataColumn(label: Text('CLIENT / ARTICLE')),
                DataColumn(label: Text('HEURE')),
                DataColumn(label: Text('MONTANT')),
                DataColumn(label: Text('STATUT')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: sales
                  .map(
                    (sale) => DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                                child: sale.imageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(AppRadius.lg),
                                        child: Image.file(
                                          File(sale.imageUrl!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            sale.icon,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        sale.icon,
                                        color: theme.colorScheme.primary,
                                        size: 20,
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    sale.title,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    sale.subtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            formatRelativeDay(sale.date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            formatGnf(sale.amount),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataCell(
                          sale.isCancelled
                              ? const AppChip(
                                  label: 'Annulé',
                                  status: AppChipStatus.error,
                                )
                              : (sale.paid
                                  ? const AppChip(
                                      label: 'Payé',
                                      status: AppChipStatus.success,
                                    )
                                  : const AppChip(
                                      label: 'Crédit',
                                      status: AppChipStatus.warning,
                                    )),
                        ),
                        DataCell(
                          sale.isCancelled || !isAdmin
                              ? const SizedBox()
                              : PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                                  onSelected: (value) {
                                    if (value == 'cancel') {
                                      _confirmCancel(context, ref, sale);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'cancel',
                                      child: Row(
                                        children: [
                                          Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                          Text('Annuler', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
