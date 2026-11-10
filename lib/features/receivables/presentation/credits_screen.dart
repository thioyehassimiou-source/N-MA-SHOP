import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/payment_method.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../application/receivables_providers.dart';
import '../domain/credit_summary.dart';
import '../domain/repositories/receivables_repository.dart';
import 'widgets/repayment_dialog.dart';

import 'package:nmashop/core/theme/app_theme.dart';

// ─────────────────────────────── Écran principal ────────────────────────────

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(creditSummariesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (summaries) {
        if (summaries.isEmpty) return const _EmptyState();

        final totalOwed = summaries.fold<int>(0, (s, c) => s + c.balance);
        final clientCount = summaries.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête premium ──
            _Header(totalOwed: totalOwed, clientCount: clientCount),

            // ── Liste des clients ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                itemCount: summaries.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _CreditTile(summary: summaries[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────── En-tête premium ────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.totalOwed, required this.clientCount});

  final int totalOwed;
  final int clientCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre + sous-titre
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clients & Crédits',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Cahier numérique — qui vous doit combien',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Cartes de résumé
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total dû',
                  value: formatGnf(totalOwed),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SummaryCard(
                  label: 'Clients débiteurs',
                  value: '$clientCount',
                  icon: Icons.person_outline_rounded,
                  color: const Color(0xFFF97316),
                  bgColor: const Color(0xFFFFF7ED),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Carte résumé KPI ────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.8),
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Tuile client premium ────────────────────────

String _paymentMethodLabel(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return 'Espèces';
    case PaymentMethod.mobileMoney:
      return 'Orange / Wave';
    case PaymentMethod.bank:
      return 'Virement';
    case PaymentMethod.credit:
      return 'Crédit';
  }
}

IconData _paymentMethodIcon(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return Icons.payments_outlined;
    case PaymentMethod.mobileMoney:
      return Icons.phone_android_rounded;
    case PaymentMethod.bank:
      return Icons.account_balance_outlined;
    case PaymentMethod.credit:
      return Icons.receipt_long_outlined;
  }
}

class _CreditTile extends ConsumerStatefulWidget {
  const _CreditTile({required this.summary});

  final CreditSummary summary;

  @override
  ConsumerState<_CreditTile> createState() => _CreditTileState();
}

class _CreditTileState extends ConsumerState<_CreditTile> {
  bool _isExpanded = false;
  List<PaymentHistoryItem>? _history;
  bool _isLoadingHistory = false;

  bool get _hasPhone =>
      widget.summary.customerPhone != null &&
      widget.summary.customerPhone!.trim().isNotEmpty;

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final repo = ref.read(receivablesRepositoryProvider);
      final items = await repo.getPaymentHistory(widget.summary.customerId);
      if (mounted) {
        setState(() {
          _history = items;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded && _history == null) {
      _loadHistory();
    }
  }

  /// Normalise le numéro et ouvre WhatsApp (avec fallback xdg-open sur Linux).
  Future<void> _launchWhatsApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var phone = widget.summary.customerPhone!.trim();
    phone = phone.replaceAll(RegExp(r'[\s\-().]+'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('00')) phone = phone.substring(2);
    if (!phone.startsWith('224') && phone.length == 9) phone = '224$phone';

    final settings = ref.read(appSettingsProvider);
    final businessName = settings.businessName.isNotEmpty
        ? settings.businessName
        : "N'MaShop";

    final message = Uri.encodeComponent(
      "Bonjour ${widget.summary.customerName},\n\n"
      "Petit rappel amical de $businessName : il vous reste un solde dû de "
      "${formatGnf(widget.summary.balance)} à régler pour vos achats.\n"
      "Merci de votre confiance et à bientôt !",
    );

    final urlStr = 'https://wa.me/$phone?text=$message';
    final success = await UrlLauncherHelper.openUrl(urlStr);
    if (!success) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
      );
    }
  }

  /// Envoie le relevé complet de tous les versements successifs avec dates
  Future<void> _shareAccountStatementWhatsApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var phone = widget.summary.customerPhone!.trim();
    phone = phone.replaceAll(RegExp(r'[\s\-().]+'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('00')) phone = phone.substring(2);
    if (!phone.startsWith('224') && phone.length == 9) phone = '224$phone';

    final settings = ref.read(appSettingsProvider);
    final businessName = settings.businessName.isNotEmpty
        ? settings.businessName
        : "N'MaShop";

    final buffer = StringBuffer();
    buffer.writeln("📑 *RELEVÉ DE COMPTE CLIENT — $businessName*");
    buffer.writeln("----------------------------------------");
    buffer.writeln("👤 *Client :* ${widget.summary.customerName}");
    buffer.writeln("📅 *Date du relevé :* ${formatDateTime(DateTime.now())}");
    buffer.writeln("----------------------------------------");

    if (_history == null || _history!.isEmpty) {
      buffer.writeln("ℹ️ *Aucun versement partiel enregistré.*");
      buffer.writeln("Le crédit initial reste en cours.");
    } else {
      buffer.writeln("💵 *HISTORIQUE DES VERSEMENTS REÇUS :*");
      for (final item in _history!) {
        final mStr = _paymentMethodLabel(item.paymentMethod);
        final refStr = item.saleReference != null ? ' (${item.saleReference})' : '';
        buffer.writeln("• ${formatDateTime(item.date)} : +${formatGnf(item.amount)} via $mStr$refStr");
      }
    }

    buffer.writeln("----------------------------------------");
    buffer.writeln("📌 *RESTE TOTAL DÛ À CE JOUR : ${formatGnf(widget.summary.balance)}*");
    buffer.writeln("----------------------------------------");
    buffer.writeln("Merci pour votre confiance !");

    final message = Uri.encodeComponent(buffer.toString());
    final urlStr = 'https://wa.me/$phone?text=$message';
    final success = await UrlLauncherHelper.openUrl(urlStr);
    if (!success) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
      );
    }
  }

  /// Envoie un reçu spécifique pour une tranche
  Future<void> _shareSinglePaymentReceipt(
    BuildContext context,
    PaymentHistoryItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    var phone = widget.summary.customerPhone!.trim();
    phone = phone.replaceAll(RegExp(r'[\s\-().]+'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('00')) phone = phone.substring(2);
    if (!phone.startsWith('224') && phone.length == 9) phone = '224$phone';

    final settings = ref.read(appSettingsProvider);
    final businessName = settings.businessName.isNotEmpty
        ? settings.businessName
        : "N'MaShop";

    final message = Uri.encodeComponent(
      "🧾 *REÇU DE VERSEMENT — $businessName*\n"
      "----------------------------------------\n"
      "👤 *Client :* ${widget.summary.customerName}\n"
      "📅 *Date :* ${formatDateTime(item.date)}\n"
      "💰 *Montant versé :* ${formatGnf(item.amount)}\n"
      "💳 *Mode :* ${_paymentMethodLabel(item.paymentMethod)}\n"
      "${item.saleReference != null ? "🏷️ *Affecté à :* ${item.saleReference}\n" : ""}"
      "----------------------------------------\n"
      "📌 *Reste total dû :* ${formatGnf(widget.summary.balance)}\n"
      "----------------------------------------\n"
      "Merci de votre confiance !",
    );

    final urlStr = 'https://wa.me/$phone?text=$message';
    final success = await UrlLauncherHelper.openUrl(urlStr);
    if (!success) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Couleur de l'avatar basée sur la première lettre (déterministe)
    final avatarColors = [
      [const Color(0xFF6366F1), const Color(0xFF4F46E5)], // indigo
      [const Color(0xFF10B981), const Color(0xFF059669)], // emerald
      [const Color(0xFFF59E0B), const Color(0xFFD97706)], // amber
      [const Color(0xFFEF4444), const Color(0xFFDC2626)], // red
      [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)], // violet
      [const Color(0xFF06B6D4), const Color(0xFF0891B2)], // cyan
    ];
    final colorPair = avatarColors[
        widget.summary.customerName.codeUnitAt(0) % avatarColors.length];
    final initials = widget.summary.customerName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    final totalRepaid = _history?.fold<int>(0, (sum, i) => sum + i.amount) ?? 0;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Bande colorée gauche ──
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colorPair,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(_isExpanded ? 0 : AppRadius.lg),
                    ),
                  ),
                ),

                // ── Contenu principal ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar avec initiales
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colorPair,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: colorPair[0].withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Infos client
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.summary.customerName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (_hasPhone) ...[
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 12,
                                      color: context.colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.summary.customerPhone!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: context.colors.outlineVariant,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
                                  Icon(
                                    Icons.access_time_outlined,
                                    size: 12,
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    formatRelativeDay(widget.summary.lastSaleDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  AppChip(
                                    label:
                                        '${widget.summary.salesCount} vente${widget.summary.salesCount > 1 ? 's' : ''} impayée${widget.summary.salesCount > 1 ? 's' : ''}',
                                    status: AppChipStatus.warning,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Solde + actions
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Badge montant dû
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Reste dû',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    formatGnf(widget.summary.balance),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Boutons d'action
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_hasPhone) ...[
                                  // Bouton WhatsApp vert
                                  _WhatsAppButton(
                                    onPressed: () => _launchWhatsApp(context),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                ],
                                // Bouton Historique des versements
                                OutlinedButton.icon(
                                  onPressed: _toggleExpand,
                                  icon: Icon(
                                    _isExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.history_rounded,
                                    size: 15,
                                  ),
                                  label: Text(
                                    _isExpanded ? 'Masquer' : 'Historique',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.lg),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppButton.secondary(
                                  label: 'Régler',
                                  icon: Icons.payments_outlined,
                                  onPressed: () async {
                                    await RepaymentDialog.show(
                                        context, widget.summary);
                                    if (_isExpanded) {
                                      _loadHistory();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Section Déroulante : Historique & Dates de versements ──
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En-tête historique
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Traçabilité chronologique des versements',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_history != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_history!.length} versement${_history!.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_hasPhone)
                        TextButton.icon(
                          onPressed: () => _shareAccountStatementWhatsApp(context),
                          icon: const Icon(
                            Icons.chat_bubble_rounded,
                            size: 14,
                            color: Color(0xFF25D366),
                          ),
                          label: const Text(
                            'Envoyer relevé complet WhatsApp',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF128C7E),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_isLoadingHistory)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_history == null || _history!.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: context.colors.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Aucun versement partiel enregistré à ce jour. '
                              'La totalité du crédit (${formatGnf(widget.summary.balance)}) reste due.',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: context.colors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.colors.outlineVariant),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _history!.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final item = _history![idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    // Puce date
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _paymentMethodIcon(item.paymentMethod),
                                        size: 15,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Date et heure
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            formatDateTime(item.date),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Mode : ${_paymentMethodLabel(item.paymentMethod)}'
                                            '${item.saleReference != null ? ' • Facture ${item.saleReference}' : ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context
                                                  .colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Montant réglé
                                    Text(
                                      '+ ${formatGnf(item.amount)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                    if (_hasPhone) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Partager le reçu de ce versement',
                                        icon: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 15,
                                          color: Color(0xFF25D366),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _shareSinglePaymentReceipt(
                                          context,
                                          item,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Récapitulatif
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Total remboursé : ${formatGnf(totalRepaid)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '•   Reste dû : ${formatGnf(widget.summary.balance)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Bouton WhatsApp ─────────────────────────────

class _WhatsAppButton extends StatefulWidget {
  const _WhatsAppButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_WhatsAppButton> createState() => _WhatsAppButtonState();
}

class _WhatsAppButtonState extends State<_WhatsAppButton> {
  bool _hovered = false;

  static const _green = Color(0xFF25D366);
  static const _greenDark = Color(0xFF128C7E);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: 'Envoyer un rappel WhatsApp',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? _green : Colors.transparent,
            border: Border.all(color: _green),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_rounded,
                    size: 14,
                    color: _hovered ? Colors.white : _greenDark,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Relancer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _hovered ? Colors.white : _greenDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── État vide ────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Aucun impayé en cours !',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Toutes vos ventes sont réglées.\nContinuez comme ça !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
