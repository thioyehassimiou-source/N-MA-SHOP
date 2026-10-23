import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/services/app_print_service.dart';
import '../../../../core/services/pdf_z_report_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/z_report_service.dart';
import '../../domain/z_report_data.dart';

/// Dialogue complet de Clôture Journalière de Caisse (Rapport Z).
/// Permet le comptage physique des espèces, le calcul immédiat de l'écart,
/// la billetterie par coupures, et l'impression en Ticket Thermique 80mm ou Rapport A4.
class ClotureCaisseDialog extends ConsumerStatefulWidget {
  const ClotureCaisseDialog({super.key});

  @override
  ConsumerState<ClotureCaisseDialog> createState() => _ClotureCaisseDialogState();
}

class _ClotureCaisseDialogState extends ConsumerState<ClotureCaisseDialog> {
  DateTime _selectedDate = DateTime.now();
  bool _useBilletterie = false;
  bool _initializedAmount = false;

  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  static const List<int> _denominations = [20000, 10000, 5000, 2000, 1000, 500];
  final Map<int, TextEditingController> _denomControllers = {};

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    for (final d in _denominations) {
      _denomControllers[d] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    for (final c in _denomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _recalculateFromDenominations() {
    int total = 0;
    for (final d in _denominations) {
      final qty = int.tryParse(_denomControllers[d]?.text.trim() ?? '0') ?? 0;
      total += d * qty;
    }
    setState(() {
      _amountController.text = total.toString();
    });
  }

  Map<int, int> _getDenominationsMap() {
    final map = <int, int>{};
    for (final d in _denominations) {
      final qty = int.tryParse(_denomControllers[d]?.text.trim() ?? '0') ?? 0;
      if (qty > 0) {
        map[d] = qty;
      }
    }
    return map;
  }

  ZReportData _buildCurrentReport(ZReportData baseData) {
    final counted = int.tryParse(_amountController.text.trim()) ?? baseData.theoreticalCash;
    return baseData.copyWithCounted(
      countedCash: counted,
      denominations: _getDenominationsMap(),
      notes: _notesController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reportAsync = ref.watch(zReportDataProvider(_selectedDate));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Gradient ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F1B3D), Color(0xFF1A2B52)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Clôture de Caisse Journalière (Rapport Z)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contrôle physique des espèces, arrêté des comptes et certification',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Contenu Scrollable ───────────────────────────────────
            Expanded(
              child: reportAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Erreur lors du calcul du Rapport Z : $err'),
                  ),
                ),
                data: (baseData) {
                  if (!_initializedAmount) {
                    _initializedAmount = true;
                    _amountController.text = baseData.theoreticalCash.toString();
                  }

                  final counted = int.tryParse(_amountController.text.trim()) ?? baseData.theoreticalCash;
                  final discrepancy = counted - baseData.theoreticalCash;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Barre de sélection de la date ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.brandNavy),
                                const SizedBox(width: 8),
                                Text(
                                  'Journée clôturée : ${formatDate(_selectedDate)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                    _initializedAmount = false;
                                  });
                                }
                              },
                              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                              label: const Text('Changer de date'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Métriques Synthétiques de la Journée ──
                        Row(
                          children: [
                            Expanded(
                              child: _metricBox(
                                title: 'Chiffre d\'Affaires Brut',
                                value: formatGnf(baseData.totalRevenue),
                                subtitle: '${baseData.totalSalesCount} ventes réalisées',
                                color: context.colors.primary,
                                bgColor: context.colors.primaryContainer,
                                icon: Icons.shopping_bag_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricBox(
                                title: 'Total Encaissé (Toutes voies)',
                                value: formatGnf(baseData.totalCollectedToday),
                                subtitle: 'Espèces, MoMo, Banque',
                                color: AppColors.brandEmerald,
                                bgColor: context.colors.secondaryContainer,
                                icon: Icons.payments_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricBox(
                                title: 'Décaissements Espèces',
                                value: '-${formatGnf(baseData.totalOutflowCash)}',
                                subtitle: 'Dépenses & Achats',
                                color: context.colors.error,
                                bgColor: context.colors.errorContainer,
                                icon: Icons.arrow_upward_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricBox(
                                title: 'Solde Théorique Tiroir',
                                value: formatGnf(baseData.theoreticalCash),
                                subtitle: 'Fond départ + Flux nets',
                                color: const Color(0xFF0F1B3D),
                                bgColor: const Color(0xFFF1F5F9),
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Détail des encaissements par mode ──
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ventilation du Chiffre d\'Affaires & Règlements',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _breakdownItem('Espèces (Ventes)', formatGnf(baseData.cashSales), Icons.attach_money),
                                  _breakdownItem('Mobile Money (OM/MoMo)', formatGnf(baseData.mobileMoneySales), Icons.phone_android),
                                  _breakdownItem('Virement / Banque', formatGnf(baseData.bankSales), Icons.account_balance),
                                  if (baseData.creditSales > 0)
                                    _breakdownItem('Ventes à Crédit (Restes dûs)', formatGnf(baseData.creditSales), Icons.credit_score, isAlert: true),
                                  if (baseData.totalCreditPayments > 0)
                                    _breakdownItem('Recouvrement Créances (Espèces)', formatGnf(baseData.creditPaymentsCash), Icons.price_check),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Section Contrôle Physique du Tiroir-Caisse ──
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Comptage Physique des Espèces en Caisse',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        'Comptez les billets et pièces dans le tiroir-caisse',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  SegmentedButton<bool>(
                                    segments: const [
                                      ButtonSegment(
                                        value: false,
                                        label: Text('Saisie directe'),
                                        icon: Icon(Icons.edit_outlined, size: 16),
                                      ),
                                      ButtonSegment(
                                        value: true,
                                        label: Text('Billetterie'),
                                        icon: Icon(Icons.calculate_outlined, size: 16),
                                      ),
                                    ],
                                    selected: {_useBilletterie},
                                    onSelectionChanged: (set) {
                                      setState(() => _useBilletterie = set.first);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (!_useBilletterie) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _amountController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        decoration: InputDecoration(
                                          labelText: 'Total Espèces Comptées (GNF)',
                                          prefixIcon: const Icon(Icons.payments_rounded),
                                          suffixText: 'GNF',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onChanged: (val) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        setState(() {
                                          _amountController.text = baseData.theoreticalCash.toString();
                                        });
                                      },
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      child: const Text('Égal au théorique'),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const Text(
                                  'Saisissez le nombre de billets par coupure :',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                const SizedBox(height: 10),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 2.7,
                                  ),
                                  itemCount: _denominations.length,
                                  itemBuilder: (context, index) {
                                    final d = _denominations[index];
                                    final controller = _denomControllers[d]!;
                                    final count = int.tryParse(controller.text.trim()) ?? 0;
                                    final subtotal = d * count;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainer,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: theme.colorScheme.outlineVariant),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${formatAmount(d)} GNF',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                                Text(
                                                  subtotal > 0 ? formatGnf(subtotal) : '0 GNF',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: subtotal > 0 ? AppColors.brandEmerald : Colors.grey,
                                                    fontWeight: subtotal > 0 ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 70,
                                            height: 38,
                                            child: TextField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              onChanged: (_) => _recalculateFromDenominations(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Total Calculé Billetterie : ${formatGnf(counted)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),

                              // ── Indicateur Dynamique d'Écart ──
                              _discrepancyBanner(context, discrepancy),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Notes / Observations ──
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Observations & Remarques du caissier (optionnel)',
                            hintText: 'ex: Billet déchiré refusé, erreur de rendu monnaie vente #12...',
                            prefixIcon: const Icon(Icons.comment_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Footer avec Actions d'Impression & Partage ───────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: reportAsync.maybeWhen(
                data: (baseData) {
                  final reportData = _buildCurrentReport(baseData);

                  return Row(
                    children: [
                      // Partage WhatsApp / Copier
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: reportData.toShareableText()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Synthèse de clôture copiée ! Prête à coller dans WhatsApp.'),
                              backgroundColor: AppColors.brandEmerald,
                            ),
                          );
                        },
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Partager WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Rapport Officiel A4 (PDF)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await AppPrintService.printDocument(
                            context: context,
                            format: PdfPageFormat.a4,
                            documentName: 'Rapport_Z_A4_${formatDate(reportData.date).replaceAll('/', '-')}',
                            onLayout: (fmt) => PdfZReportService.generateA4ZReportPdf(reportData),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('Rapport A4 (PDF)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const Spacer(),

                      // Bouton Principal : Ticket Thermique 80mm
                      FilledButton.icon(
                        onPressed: () async {
                          await AppPrintService.printDocument(
                            context: context,
                            format: PdfPageFormat.roll80,
                            documentName: 'Ticket_Z_80mm_${formatDate(reportData.date).replaceAll('/', '-')}',
                            onLayout: (fmt) => PdfZReportService.generateThermalZReportPdf(reportData),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('Ticket Thermique (80mm)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F1B3D),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _breakdownItem(String label, String value, IconData icon, {bool isAlert = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isAlert ? AppColors.brandOrange : Colors.grey),
        const SizedBox(width: 4),
        Text(
          '$label : ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isAlert ? AppColors.brandOrange : null,
          ),
        ),
      ],
    );
  }

  Widget _discrepancyBanner(BuildContext context, int discrepancy) {
    if (discrepancy == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.brandEmerald),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.brandEmerald, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caisse parfaitement équilibrée (0 GNF)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandEmerald, fontSize: 13),
                  ),
                  Text(
                    'Les espèces comptées correspondent exactement au montant théorique calculé.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (discrepancy > 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Excédent de caisse : +${formatGnf(discrepancy)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309), fontSize: 13),
                  ),
                  const Text(
                    'Il y a plus d\'espèces dans le tiroir que prévu par les ventes enregistrées.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Déficit / Manquant de caisse : ${formatGnf(discrepancy)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C), fontSize: 13),
                  ),
                  const Text(
                    'Attention : Le montant d\'espèces compté est inférieur au solde théorique attendu.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}
