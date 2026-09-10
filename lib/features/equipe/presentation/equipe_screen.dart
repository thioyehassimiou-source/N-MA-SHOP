import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/users.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../reports/application/reports_providers.dart';
import '../application/equipe_providers.dart';
import '../application/sellers_providers.dart';
import 'widgets/seller_report_dialog.dart';

class EquipeScreen extends ConsumerStatefulWidget {
  const EquipeScreen({super.key});

  @override
  ConsumerState<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends ConsumerState<EquipeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(sellerRangeProvider);
    final isPerformanceTab = _tabController.index == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: 'Équipe & Vendeurs',
          subtitle: 'Suivi des performances commerciales et gestion des accès',
          icon: Icons.people_outline_rounded,
          gradientColors: const [Colors.indigo, Colors.blue],
          actions: [
            if (!isPerformanceTab)
              AppButton(
                label: 'Ajouter un utilisateur',
                icon: Icons.person_add_outlined,
                onPressed: () => _showAddUserDialog(context, ref),
              ),
          ],
        ),

        // ── Onglets de Navigation ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: context.colors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Row(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: context.colors.primary,
                unselectedLabelColor: context.colors.onSurfaceVariant,
                indicatorColor: context.colors.primary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.trending_up_rounded, size: 18),
                    text: 'Performances Commerciales',
                  ),
                  Tab(
                    icon: Icon(Icons.manage_accounts_outlined, size: 18),
                    text: 'Comptes & Accès',
                  ),
                ],
              ),
              const Spacer(),
              if (isPerformanceTab) _buildPeriodFilter(context, ref, range),
            ],
          ),
        ),

        // ── Vue des Onglets ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPerformancesTab(context, ref),
              _buildAccountsTab(context, ref),
            ],
          ),
        ),
      ],
    );
  }

  // ─── FILTRE PÉRIODE (CHOICE CHIPS) ─────────────────────────────────────────

  Widget _buildPeriodFilter(
    BuildContext context,
    WidgetRef ref,
    ReportRange currentRange,
  ) {
    Widget chip(ReportPeriod p, String label) {
      final active = currentRange.period == p;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Colors.white : context.colors.onSurfaceVariant,
            ),
          ),
          selected: active,
          selectedColor: const Color(0xFF6366F1),
          backgroundColor: context.colors.surfaceContainerHighest,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          onSelected: (_) {
            ref
                .read(sellerRangeProvider.notifier)
                .updateRange(ReportRange.forPeriod(p));
          },
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(ReportPeriod.today, "Aujourd'hui"),
        chip(ReportPeriod.week, 'Semaine'),
        chip(ReportPeriod.month, 'Mois'),
        ActionChip(
          label: const Text('Personnalisé', style: TextStyle(fontSize: 12)),
          backgroundColor: context.colors.surfaceContainerHighest,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
              initialDateRange: DateTimeRange(
                start: currentRange.start,
                end: currentRange.end.subtract(const Duration(days: 1)),
              ),
            );
            if (picked != null) {
              ref.read(sellerRangeProvider.notifier).updateRange(
                    ReportRange.forPeriod(
                      ReportPeriod.custom,
                      customStart: picked.start,
                      customEnd: picked.end,
                    ),
                  );
            }
          },
        ),
      ],
    );
  }

  // ─── TAB 1 : PERFORMANCES COMMERCIALES ─────────────────────────────────────

  Widget _buildPerformancesTab(BuildContext context, WidgetRef ref) {
    final performancesAsync = ref.watch(sellerPerformancesProvider);

    return performancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur: $err')),
      data: (performances) {
        if (performances.isEmpty) {
          return Center(
            child: Text(
              'Aucun utilisateur ou donnée de vente disponible.',
              style: AppTypography.bodyMd.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          );
        }

        // Calculs consolidés de l'équipe
        final teamRevenue = performances.fold<int>(
            0, (sum, p) => sum + p.totalRevenue);
        final teamCollected = performances.fold<int>(
            0, (sum, p) => sum + p.totalCollected);
        final teamRemaining = performances.fold<int>(
            0, (sum, p) => sum + p.totalRemaining);
        final teamCommissions = performances.fold<int>(
            0, (sum, p) => sum + p.commissionAmount);
        final teamSalesCount = performances.fold<int>(
            0, (sum, p) => sum + p.salesCount);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // ── Cartes KPIs de l'équipe ──
            Row(
              children: [
                _buildTeamKpiCard(
                  context,
                  title: 'Chiffre d\'Affaires Équipe',
                  value: formatGnf(teamRevenue),
                  subtitle: '$teamSalesCount vente${teamSalesCount > 1 ? 's' : ''}',
                  icon: Icons.trending_up_rounded,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: AppSpacing.md),
                _buildTeamKpiCard(
                  context,
                  title: 'Total Encaissé',
                  value: formatGnf(teamCollected),
                  subtitle: teamRevenue > 0
                      ? '${((teamCollected / teamRevenue) * 100).toStringAsFixed(1)}% du CA'
                      : '100%',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.brandEmerald,
                ),
                const SizedBox(width: AppSpacing.md),
                _buildTeamKpiCard(
                  context,
                  title: 'Crédits / Reste à recouvrer',
                  value: formatGnf(teamRemaining),
                  subtitle: 'Impayés clients',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: AppSpacing.md),
                _buildTeamKpiCard(
                  context,
                  title: 'Total Commissions',
                  value: formatGnf(teamCommissions),
                  subtitle: 'Rémunération variable',
                  icon: Icons.savings_outlined,
                  color: Colors.orange.shade800,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Titre du Tableau ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Classement & Performances par Vendeur',
                  style: AppTypography.headlineMd,
                ),
                Text(
                  '${performances.length} collaborateur${performances.length > 1 ? 's' : ''}',
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Tableau des Vendeurs ──
            AppCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  columnSpacing: 20,
                  horizontalMargin: 20,
                  columns: const [
                    DataColumn(label: Text('Vendeur')),
                    DataColumn(label: Text('Rôle')),
                    DataColumn(label: Text('Commission')),
                    DataColumn(label: Text('Ventes'), numeric: true),
                    DataColumn(label: Text('Clients'), numeric: true),
                    DataColumn(label: Text('Encaissé'), numeric: true),
                    DataColumn(label: Text('Reste Dû'), numeric: true),
                    DataColumn(label: Text('Chiffre d\'Affaires'), numeric: true),
                    DataColumn(label: Text('Commission Due'), numeric: true),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: performances.asMap().entries.map((entry) {
                    final index = entry.key;
                    final p = entry.value;
                    final isTop = index == 0 && p.totalRevenue > 0;

                    return DataRow(
                      cells: [
                        // Vendeur
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTop) ...[
                                const Icon(Icons.workspace_premium,
                                    color: Colors.amber, size: 20),
                                const SizedBox(width: 6),
                              ],
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: p.isActive
                                    ? context.colors.primaryContainer
                                    : context.colors.surfaceContainerHighest,
                                child: Text(
                                  p.sellerName.isNotEmpty
                                      ? p.sellerName.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: p.isActive
                                        ? context.colors.primary
                                        : context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                p.sellerName,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Rôle
                        DataCell(
                          p.role != null
                              ? AppChip(
                                  label: p.role == UserRole.admin
                                      ? 'Admin'
                                      : 'Vendeur',
                                  status: p.role == UserRole.admin
                                      ? AppChipStatus.warning
                                      : AppChipStatus.success,
                                )
                              : const Text('-'),
                        ),
                        // Commission %
                        DataCell(
                          Text('${p.commissionRate.toStringAsFixed(1)} %'),
                        ),
                        // Ventes
                        DataCell(Text('${p.salesCount}')),
                        // Clients servis
                        DataCell(Text('${p.customersServedCount}')),
                        // Encaissé
                        DataCell(
                          Text(
                            formatGnf(p.totalCollected),
                            style: const TextStyle(color: AppColors.brandEmerald),
                          ),
                        ),
                        // Reste dû
                        DataCell(
                          Text(
                            formatGnf(p.totalRemaining),
                            style: TextStyle(
                              color: p.totalRemaining > 0
                                  ? Colors.red.shade700
                                  : null,
                            ),
                          ),
                        ),
                        // CA
                        DataCell(
                          Text(
                            formatGnf(p.totalRevenue),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Commission Due
                        DataCell(
                          Text(
                            formatGnf(p.commissionAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                        // Action
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.analytics_outlined, size: 20),
                            tooltip: 'Voir détails & exporter rapport',
                            color: context.colors.primary,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => SellerReportDialog(seller: p),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeamKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.labelSm.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.headlineMd.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySm.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2 : COMPTES & ACCÈS ───────────────────────────────────────────────

  Widget _buildAccountsTab(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersListProvider);
    final currentUser = ref.watch(authProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur: $err')),
      data: (users) {
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isMe = user.id == currentUser?.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: user.isActive
                          ? context.colors.primaryContainer
                          : context.colors.surfaceContainerHighest,
                      child: Text(
                        user.initials,
                        style: TextStyle(
                          color: user.isActive
                              ? context.colors.primary
                              : context.colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user.fullName,
                                style: AppTypography.labelMd.copyWith(
                                  color: user.isActive
                                      ? null
                                      : context.colors.onSurfaceVariant,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: AppSpacing.sm),
                                const AppChip(
                                  label: 'Moi',
                                  status: AppChipStatus.neutral,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              AppChip(
                                label: user.role == UserRole.admin
                                    ? 'Administrateur'
                                    : 'Vendeur',
                                status: user.role == UserRole.admin
                                    ? AppChipStatus.warning
                                    : AppChipStatus.success,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                'Commission: ${user.commissionRate.toStringAsFixed(1)} %',
                                style: AppTypography.bodySm.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                tooltip: 'Modifier la commission',
                                onPressed: () =>
                                    _showEditCommissionRateDialog(user),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                'Créé le ${formatDate(user.createdAt)}',
                                style: AppTypography.bodySm.copyWith(
                                  color: context.colors.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Switch(
                          value: user.isActive,
                          onChanged: isMe
                              ? null
                              : (val) {
                                  ref
                                      .read(equipeControllerProvider.notifier)
                                      .toggleStatus(user.id, val);
                                },
                        ),
                        if (user.lastLoginAt != null)
                          Text(
                            'Dernière connexion: ${formatDateTime(user.lastLoginAt!)}',
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 10,
                              color: context.colors.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditCommissionRateDialog(AppUser user) async {
    final controller = TextEditingController(
      text: user.commissionRate.toStringAsFixed(1),
    );

    final updated = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Taux de commission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collaborateur : ${user.fullName}'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Commission (%)',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val >= 0) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (updated != null) {
      await ref
          .read(equipeControllerProvider.notifier)
          .updateCommissionRate(user.id, updated);
      ref.invalidate(sellerPerformancesProvider);
    }
  }

  Future<void> _showAddUserDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final commissionCtrl = TextEditingController(text: '0.0');
    UserRole selectedRole = UserRole.cashier;
    bool isLoading = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppFormDialog(
              title: 'Ajouter un collaborateur',
              subtitle: 'Créer un nouvel accès pour l\'équipe de vente',
              icon: Icons.person_add_outlined,
              gradientColors: const [Color(0xFF0F1B3D), Color(0xFF1A2B52)],
              width: 480,
              primaryLabel: 'Créer',
              primaryIcon: Icons.check_circle_outline,
              isPrimaryLoading: isLoading,
              onCancel: isLoading ? null : () => Navigator.pop(ctx),
              onPrimary: isLoading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty || pwdCtrl.text.isEmpty) {
                        setState(
                            () => error = 'Veuillez remplir tous les champs');
                        return;
                      }
                      final commission = double.tryParse(
                              commissionCtrl.text.replaceAll(',', '.')) ??
                          0.0;
                      setState(() {
                        isLoading = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(equipeControllerProvider.notifier)
                            .createUser(
                              fullName: nameCtrl.text,
                              password: pwdCtrl.text,
                              role: selectedRole,
                              commissionRate: commission,
                            );
                        ref.invalidate(sellerPerformancesProvider);
                        if (context.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() {
                          error = e.toString();
                          isLoading = false;
                        });
                      }
                    },
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      color: context.colors.errorContainer,
                      child: Text(
                        error!,
                        style: TextStyle(color: context.colors.error),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppFormField(
                    label: 'Nom complet',
                    controller: nameCtrl,
                    icon: Icons.person_outline,
                    isRequired: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppFormField(
                    label: 'Mot de passe',
                    controller: pwdCtrl,
                    icon: Icons.lock_outline,
                    isRequired: true,
                    obscureText: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppFormField(
                    label: 'Taux de commission (%)',
                    controller: commissionCtrl,
                    icon: Icons.percent_outlined,
                    hint: 'Ex: 5.0 pour 5%',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Rôle', style: AppTypography.labelMd),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(
                          value: UserRole.cashier, label: Text('Vendeur')),
                      ButtonSegment(
                          value: UserRole.admin, label: Text('Admin')),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (set) {
                      setState(() => selectedRole = set.first);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
