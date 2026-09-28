import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/domain/payment_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/database/tables/users.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';

import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_button.dart';
import '../application/dashboard_providers.dart';
import '../../../core/providers/theme_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardDataProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Stack(
      children: [
        // Premium Mesh Gradient Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.8, -0.6),
                radius: 1.5,
                colors: isDark
                    ? [
                        const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFFEEF2FF),
                        const Color(0xFFF8FAFC),
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark ? const Color(0xFF4338CA) : const Color(0xFF818CF8)).withValues(alpha: 0.15),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scaleXY(end: 1.2, duration: 4.seconds, curve: Curves.easeInOut),
        ),
        Positioned(
          bottom: 100,
          left: -100,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark ? const Color(0xFF047857) : const Color(0xFF34D399)).withValues(alpha: 0.1),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scaleXY(end: 1.3, duration: 5.seconds, curve: Curves.easeInOut),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: const SizedBox(),
          ),
        ),
        // Content
        SingleChildScrollView(
          padding: const EdgeInsets.all(28),
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
        ),
      ],
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
            final chart = _RevenueChartCard(
              dailySales: data.dailySales,
              salesGrowth: data.salesGrowth,
            );
            final payments = _PaymentMethodsCard(
              paymentBreakdown: data.paymentBreakdown,
            );
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
  const _RevenueChartCard({
    required this.dailySales,
    this.salesGrowth,
  });

  final List<DailySalesPoint> dailySales;
  final double? salesGrowth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSales = dailySales.isNotEmpty && dailySales.any((p) => p.total > 0);
    final total7d = dailySales.fold<int>(0, (s, p) => s + p.total);

    final String badgeText;
    final Color badgeBg;
    final Color badgeFg;

    if (!hasSales) {
      badgeText = '0 GNF';
      badgeBg = theme.colorScheme.surfaceContainerHighest;
      badgeFg = theme.colorScheme.onSurfaceVariant;
    } else if (salesGrowth == null) {
      badgeText = formatGnf(total7d);
      badgeBg = theme.colorScheme.secondaryContainer;
      badgeFg = AppColors.brandEmerald;
    } else {
      final isPos = salesGrowth! >= 0;
      badgeText = '${isPos ? '+' : ''}${salesGrowth!.toStringAsFixed(1)}%';
      badgeBg = isPos
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.errorContainer;
      badgeFg = isPos
          ? AppColors.brandEmerald
          : theme.colorScheme.error;
    }

    return _GlassCard(
      height: 360,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: badgeFg,
                          ),
                        ),
                      ),
                      Text(
                        hasSales ? 'vs période précédente' : 'aucune vente enregistrée',
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            child: hasSales
                ? CustomPaint(
                    size: Size.infinite,
                    painter: _LineChartPainter(context, dailySales),
                  )
                : Stack(
                    children: [
                      CustomPaint(
                        size: Size.infinite,
                        painter: _EmptyLineChartPainter(context),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.show_chart_rounded,
                              size: 32,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Aucune vente sur les 7 derniers jours',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'La courbe d\'activité s\'affichera dès vos premiers encaissements.',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: (dailySales.isEmpty
                    ? List.generate(7, (i) => 'J-${6 - i}')
                    : dailySales.map((point) {
                        const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                        final now = DateTime.now();
                        final isToday = point.date.year == now.year &&
                            point.date.month == now.month &&
                            point.date.day == now.day;
                        return isToday ? 'Auj.' : days[point.date.weekday - 1];
                      }).toList())
                .asMap()
                .entries
                .map((entry) {
              final isLast = entry.key == (dailySales.isEmpty ? 6 : dailySales.length - 1);
              return Text(
                entry.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                  color: isLast
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _EmptyLineChartPainter extends CustomPainter {
  _EmptyLineChartPainter(this.context);
  final BuildContext context;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Theme.of(context).colorScheme.surfaceContainerLow
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final basePaint = Paint()
      ..color = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height - 4), Offset(size.width, size.height - 4), basePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.context, this.dailySales);
  final BuildContext context;
  final List<DailySalesPoint> dailySales;

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

    if (dailySales.isEmpty) return;

    final maxVal = math.max(
      1,
      dailySales.map((p) => p.total).reduce(math.max),
    );

    final points = <Offset>[];
    final count = dailySales.length;
    for (int i = 0; i < count; i++) {
      final x = count == 1 ? size.width / 2 : size.width * (i / (count - 1));
      final ratio = (dailySales[i].total / maxVal).clamp(0.0, 1.0);
      final y = size.height * (0.90 - (ratio * 0.75));
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p2.dx,
        p2.dy,
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
        ..shader = fillGradient.createShader(
            Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw line
    final linePaint = Paint()
      ..color = Theme.of(context).colorScheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw dots for days with sales
    for (int i = 0; i < points.length; i++) {
      if (dailySales[i].total > 0) {
        canvas.drawCircle(
          points[i],
          4,
          Paint()..color = Theme.of(context).colorScheme.primary,
        );
        canvas.drawCircle(
          points[i],
          2,
          Paint()..color = Colors.white,
        );
      }
    }

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
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.dailySales != dailySales;
}

// ─────────────────────────── Carte Modes de Paiement ───────────────────────────

class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard({required this.paymentBreakdown});

  final List<PaymentBreakdownItem> paymentBreakdown;

  int _amountFor(PaymentMethod method) {
    for (final item in paymentBreakdown) {
      if (item.method == method) return item.amount;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cashAmount = _amountFor(PaymentMethod.cash);
    final mobileMoneyAmount = _amountFor(PaymentMethod.mobileMoney);
    final bankAmount = _amountFor(PaymentMethod.bank);
    final creditAmount = _amountFor(PaymentMethod.credit);
    final total = cashAmount + mobileMoneyAmount + bankAmount + creditAmount;

    int pct(int amount) => total > 0 ? ((amount / total) * 100).round() : 0;

    return _GlassCard(
      height: 360,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Modes de paiement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (total > 0)
                Text(
                  formatGnf(total),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Text(
                  '0 GNF encaissé',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _PaymentItem(
            label: 'Espèces',
            percentage: pct(cashAmount),
            amount: formatGnf(cashAmount),
            color: AppColors.brandEmerald,
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 12),
          _PaymentItem(
            label: 'Mobile Money',
            percentage: pct(mobileMoneyAmount),
            amount: formatGnf(mobileMoneyAmount),
            color: const Color(0xFFF59E0B),
            icon: Icons.phone_android_outlined,
          ),
          const SizedBox(height: 12),
          _PaymentItem(
            label: 'Carte / Virement',
            percentage: pct(bankAmount),
            amount: formatGnf(bankAmount),
            color: theme.colorScheme.primary,
            icon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 12),
          _PaymentItem(
            label: 'Crédit client',
            percentage: pct(creditAmount),
            amount: formatGnf(creditAmount),
            color: theme.colorScheme.error,
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
    final theme = Theme.of(context);
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
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              amount,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
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
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Carte Alertes & Actions ───────────────────────────

class _AlertsActionsCard extends ConsumerWidget {
  const _AlertsActionsCard({required this.lowStockCount});

  final int lowStockCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == UserRole.admin;

    return _GlassCard(
      height: 360,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              padding: const EdgeInsets.all(12),
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
                    onPressed: () => context.go('/produits'),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.secondaryContainer),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.brandEmerald, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tout est en ordre ! Bonnes ventes.',
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
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Vente'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(isAdmin ? '/equipe' : '/devis'),
                  icon: Icon(isAdmin ? Icons.people_outline : Icons.receipt_outlined, size: 16),
                  label: Text(isAdmin ? 'Équipe' : 'Facture'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
    final palette = ref.watch(paletteProvider);

    final firstName = user?.fullName.split(' ').first ?? 'Administrateur';
    final greeting = _getGreeting();

    final boxDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.darkSidebarTop,
          Color.alphaBlend(palette.highlightColor.withValues(alpha: 0.3), palette.darkSidebarTop),
          palette.darkSidebarBottom,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: palette.darkSidebarTop.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );

    final onlineBadgeColor = palette.highlightColor;
    final onlineBadgeBg = palette.highlightColor.withValues(alpha: 0.2);
    final onlineBadgeBorder = palette.highlightColor.withValues(alpha: 0.5);
    const textColor = Colors.white;
    final textSubColor = Colors.white.withValues(alpha: 0.7);

    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 950;

          final mainInfo = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: onlineBadgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: onlineBadgeBorder),
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
                '$greeting, $firstName !',
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _BannerButton(
                    label: 'Exporter',
                    icon: Icons.download_outlined,
                    onTap: () => context.go('/rapports'),
                    outlined: true,
                  ),
                  _BannerButton(
                    label: 'Actualiser',
                    icon: Icons.refresh_rounded,
                    onTap: () => ref.invalidate(dashboardDataProvider),
                  ),
                ],
              ),
            ],
          );

          final statsInfo = Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _BannerStat(
                label: 'CA du jour',
                value: formatGnfCompact(data.todaySales),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF10B981),
              ),
              _BannerStat(
                label: 'En caisse',
                value: formatGnfCompact(data.cashAvailable),
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFFE85D04),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                mainInfo,
                const SizedBox(height: 24),
                statsInfo,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: mainInfo),
              const SizedBox(width: 16),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: statsInfo,
                  ),
                ),
              ),
            ],
          );
        },
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
    final palette = ref.watch(paletteProvider);
    final primaryColor = palette.highlightColor;
    const textColor = Colors.white;
    final bgColor = outlined ? Colors.transparent : primaryColor;
    final borderColor = outlined ? Colors.white.withValues(alpha: 0.3) : primaryColor;

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
    final palette = ref.watch(paletteProvider);

    final bgColor = Colors.white.withValues(alpha: 0.08);
    final borderColor = Colors.white.withValues(alpha: 0.12);
    const textColor = Colors.white;
    final textSubColor = Colors.white.withValues(alpha: 0.7);
    final iconColor = palette.highlightColor;

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

class _MetricsGrid extends ConsumerWidget {
  const _MetricsGrid({required this.data});

  final DashboardData data;

  String _pct(double? v) =>
      v == null ? '+0%' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isAdmin = user?.isAdmin ?? false;

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
          _GlassMetricCard(
            title: 'Ventes du jour',
            value: formatGnfCompact(data.todaySales),
            badgeText: _pct(data.salesGrowth),
            badgeColor: AppColors.brandEmerald,
            icon: Icons.shopping_cart_rounded,
            iconColor: AppColors.iconPurple,
            iconBackgroundColor: AppColors.iconPurpleBg,
          ),
          _GlassMetricCard(
            title: 'Solde de caisse',
            value: formatGnfCompact(data.cashAvailable),
            badgeText: 'En caisse disponible',
            badgeColor: AppColors.brandEmerald,
            icon: Icons.account_balance_rounded,
            iconColor: AppColors.iconGreen,
            iconBackgroundColor: AppColors.iconGreenBg,
          ),
          _GlassMetricCard(
            title: 'Argent dehors (Crédits)',
            value: formatGnfCompact(data.owed),
            badgeText: '${data.owedCount} clients à encaisser',
            icon: Icons.credit_card_rounded,
            iconColor: AppColors.iconOrange,
            iconBackgroundColor: AppColors.iconOrangeBg,
          ),
          _GlassMetricCard(
            title: 'Produits en alerte',
            value: '${data.lowStock.length}',
            badgeText: data.lowStock.isEmpty ? 'Stock optimal' : 'Stock faible (À commander)',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.iconRed,
            iconBackgroundColor: AppColors.iconRedBg,
          ),
          if (isAdmin)
            _GlassMetricCard(
              title: 'Dettes à payer',
              value: formatGnfCompact(data.supplierDebt),
              badgeText: 'Aux fournisseurs',
              icon: Icons.storefront_rounded,
              iconColor: AppColors.iconNavy,
              iconBackgroundColor: AppColors.iconNavyBg,
            ),
          _GlassMetricCard(
            title: 'Ticket moyen',
            value: formatGnfCompact(data.avgTicket?.round() ?? 0),
            badgeText: 'Par transaction',
            badgeColor: AppColors.brandEmerald,
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.iconTeal,
            iconBackgroundColor: AppColors.iconTealBg,
          ),
          _GlassMetricCard(
            title: 'Taux de crédit',
            value: '${data.creditRate?.toStringAsFixed(1) ?? '0.0'}%',
            badgeText: 'Ventes à crédit',
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.iconCyan,
            iconBackgroundColor: AppColors.iconCyanBg,
            progressValue: (data.creditRate ?? 0) / 100,
            progressColor: AppColors.iconCyan,
          ),
          _GlassMetricCard(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == UserRole.admin;

    return _GlassCard(
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
                if (isAdmin)
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
                DataColumn(label: Text('VENDEUR')),
                DataColumn(label: Text('HEURE')),
                DataColumn(label: Text('MONTANT')),
                DataColumn(label: Text('STATUT')),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      sale.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      sale.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            sale.sellerName ?? 'Non attribué',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
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


// ─────────────────────────── Composants Premium (Glassmorphism) ───────────────────────────

class _GlassCard extends StatefulWidget {
  const _GlassCard({required this.child, this.padding, this.height});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;

  @override
  State<_GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<_GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: widget.height,
        transform: _isHovered ? Matrix4.translationValues(0.0, -4.0, 0.0) : Matrix4.identity(),
        padding: widget.padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1E293B).withValues(alpha: _isHovered ? 0.8 : 0.6)
                : Colors.white.withValues(alpha: _isHovered ? 0.9 : 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? Colors.black.withValues(alpha: _isHovered ? 0.3 : 0.1)
                    : const Color(0xFF94A3B8).withValues(alpha: _isHovered ? 0.15 : 0.05),
                blurRadius: _isHovered ? 24 : 12,
                offset: _isHovered ? const Offset(0, 12) : const Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.05, end: 0);
  }
}

class _GlassMetricCard extends StatelessWidget {
  const _GlassMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.badgeText,
    this.badgeColor,
    this.iconColor,
    this.iconBackgroundColor,
    this.progressValue,
    this.progressColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? badgeText;
  final Color? badgeColor;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final double? progressValue;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackColor = iconColor ?? Theme.of(context).colorScheme.primary;
    final fallbackBg = iconBackgroundColor ?? fallbackColor.withValues(alpha: 0.15);
    
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: fallbackBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: fallbackColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor: isDark ? Colors.white24 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor ?? fallbackColor),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (badgeText != null)
            Row(
              children: [
                if (badgeColor != null)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  badgeText!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

