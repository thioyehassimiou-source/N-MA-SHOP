import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../application/receivables_providers.dart';
import '../domain/credit_summary.dart';
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

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.summary});

  final CreditSummary summary;

  bool get _hasPhone =>
      summary.customerPhone != null && summary.customerPhone!.trim().isNotEmpty;

  /// Normalise le numéro et ouvre WhatsApp (avec fallback xdg-open sur Linux).
  Future<void> _launchWhatsApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var phone = summary.customerPhone!.trim();
    phone = phone.replaceAll(RegExp(r'[\s\-().]+'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('00')) phone = phone.substring(2);
    if (!phone.startsWith('224') && phone.length == 9) phone = '224$phone';

    final message = Uri.encodeComponent(
      "Bonjour ${summary.customerName} 👋,\n\n"
      "Petit rappel amical de N'MaShop : il vous reste un solde dû de "
      "${formatGnf(summary.balance)} à régler pour vos achats.\n"
      "Merci de votre confiance et à bientôt !",
    );

    final urlStr = 'https://wa.me/$phone?text=$message';

    try {
      // Appel direct OS — contourne le canal Pigeon de url_launcher sur Desktop
      if (Platform.isLinux) {
        await Process.run('xdg-open', [urlStr]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', urlStr], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [urlStr]);
      } else {
        // Android / iOS : url_launcher standard
        await launchUrl(Uri.parse(urlStr), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Impossible d'ouvrir WhatsApp : $e")),
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
    final colorPair =
        avatarColors[summary.customerName.codeUnitAt(0) % avatarColors.length];
    final initials = summary.customerName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
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
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
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
                            summary.customerName,
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
                                  summary.customerPhone!,
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
                                formatRelativeDay(summary.lastSaleDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AppChip(
                            label:
                                '${summary.salesCount} vente${summary.salesCount > 1 ? 's' : ''} impayée${summary.salesCount > 1 ? 's' : ''}',
                            status: AppChipStatus.warning,
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
                                formatGnf(summary.balance),
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
                            AppButton.secondary(
                              label: 'Régler',
                              icon: Icons.payments_outlined,
                              onPressed: () =>
                                  RepaymentDialog.show(context, summary),
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
            'Aucun impayé en cours ! 🎉',
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
