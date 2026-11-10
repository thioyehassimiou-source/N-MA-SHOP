import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/payment_method.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/url_launcher_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../application/receivables_providers.dart';
import '../../domain/credit_summary.dart';
import '../../domain/repositories/receivables_repository.dart';
import '../../domain/repayment_draft.dart';
import '../../domain/usecases/record_repayment.dart';

String _methodLabel(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return 'Espèces';
    case PaymentMethod.mobileMoney:
      return 'Orange / Wave';
    case PaymentMethod.bank:
      return 'Virement / Chèque';
    case PaymentMethod.credit:
      return 'Crédit';
  }
}

IconData _methodIcon(PaymentMethod method) {
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

/// Dialogue de saisie de versement partiel ou total avec traçabilité complète :
/// - Date et heure exactes sélectionnables (par défaut : maintenant)
/// - Mode de règlement (Espèces, Orange Money/Wave, Virement)
/// - Historique chronologique complet des versements passés
/// - Envoi instantané du reçu par WhatsApp pour éliminer les contestations
class RepaymentDialog extends ConsumerStatefulWidget {
  const RepaymentDialog({super.key, required this.summary});

  final CreditSummary summary;

  static Future<void> show(BuildContext context, CreditSummary summary) {
    return showDialog(
      context: context,
      builder: (context) => RepaymentDialog(summary: summary),
    );
  }

  @override
  ConsumerState<RepaymentDialog> createState() => _RepaymentDialogState();
}

class _RepaymentDialogState extends ConsumerState<RepaymentDialog> {
  late final TextEditingController _amountController;
  int? _amount;
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  List<PaymentHistoryItem>? _history;
  bool _isLoadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.summary.balance.toString(),
    );
    _amount = widget.summary.balance;
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final repository = ref.read(receivablesRepositoryProvider);
      final history = await repository.getPaymentHistory(
        widget.summary.customerId,
      );
      if (mounted) {
        setState(() {
          _history = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = e.toString();
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    setState(() {
      _amount = int.tryParse(value.replaceAll(RegExp(r'\D'), ''));
    });
  }

  void _setAmount(int val) {
    final capped = val.clamp(0, widget.summary.balance);
    _amountController.text = capped.toString();
    setState(() {
      _amount = capped;
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFFF59E0B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else if (mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _selectedDate.hour,
            _selectedDate.minute,
          );
        });
      }
    }
  }

  bool get _isValid =>
      _amount != null && _amount! > 0 && _amount! <= widget.summary.balance;

  Future<void> _submit() async {
    if (!_isValid) return;

    setState(() => _isSubmitting = true);

    try {
      final useCase = ref.read(recordRepaymentUseCaseProvider);
      final draft = RepaymentDraft(
        customerId: widget.summary.customerId,
        amount: _amount!,
        method: _selectedMethod,
        date: _selectedDate,
      );

      final result = await useCase(draft);

      if (mounted) {
        if (result is RecordRepaymentSuccess) {
          Navigator.of(context).pop();
          _showSuccessReceiptDialog(
            context: context,
            summary: widget.summary,
            amount: _amount!,
            method: _selectedMethod,
            date: _selectedDate,
            remainingBalance: result.repayment.remainingBalance,
          );
        } else if (result is RecordRepaymentFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : ${result.error.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du règlement : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessReceiptDialog({
    required BuildContext context,
    required CreditSummary summary,
    required int amount,
    required PaymentMethod method,
    required DateTime date,
    required int remainingBalance,
  }) {
    final settings = ref.read(appSettingsProvider);
    final businessName = settings.businessName.isNotEmpty
        ? settings.businessName
        : "N'MaShop";

    showDialog(
      context: context,
      builder: (ctx) {
        final hasPhone = summary.customerPhone != null &&
            summary.customerPhone!.trim().isNotEmpty;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Versement enregistré !',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ctx.colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ctx.colors.outlineVariant),
                ),
                child: Column(
                  children: [
                    _ReceiptRow(label: 'Client', value: summary.customerName),
                    const Divider(height: 16),
                    _ReceiptRow(label: 'Date & heure', value: formatDateTime(date)),
                    const Divider(height: 16),
                    _ReceiptRow(
                      label: 'Montant versé',
                      value: '+ ${formatGnf(amount)}',
                      valueColor: const Color(0xFF10B981),
                      isBold: true,
                    ),
                    const Divider(height: 16),
                    _ReceiptRow(label: 'Mode de règlement', value: _methodLabel(method)),
                    const Divider(height: 16),
                    _ReceiptRow(
                      label: 'Reste dû actualisé',
                      value: remainingBalance <= 0
                          ? '0 GNF (Entièrement soldé 🎉)'
                          : formatGnf(remainingBalance),
                      valueColor: remainingBalance <= 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFDC2626),
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (hasPhone)
                ElevatedButton.icon(
                  onPressed: () {
                    _shareSingleReceiptWhatsApp(
                      context: ctx,
                      customerName: summary.customerName,
                      phone: summary.customerPhone,
                      amount: amount,
                      method: method,
                      date: date,
                      remainingBalance: remainingBalance,
                      businessName: businessName,
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: const Text('Envoyer le reçu par WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareSingleReceiptWhatsApp({
    required BuildContext context,
    required String customerName,
    required String? phone,
    required int amount,
    required PaymentMethod method,
    required DateTime date,
    required int remainingBalance,
    required String businessName,
  }) async {
    if (phone == null || phone.trim().isEmpty) return;

    var cleanPhone = phone.trim().replaceAll(RegExp(r'[\s\-().]+'), '');
    if (cleanPhone.startsWith('+')) cleanPhone = cleanPhone.substring(1);
    if (cleanPhone.startsWith('00')) cleanPhone = cleanPhone.substring(2);
    if (!cleanPhone.startsWith('224') && cleanPhone.length == 9) {
      cleanPhone = '224$cleanPhone';
    }

    final message = Uri.encodeComponent(
      "🧾 *REÇU DE VERSEMENT — $businessName*\n"
      "----------------------------------------\n"
      "👤 *Client :* $customerName\n"
      "📅 *Date :* ${formatDateTime(date)}\n"
      "💰 *Montant versé :* ${formatGnf(amount)}\n"
      "💳 *Mode :* ${_methodLabel(method)}\n"
      "----------------------------------------\n"
      "📌 *Reste total dû :* ${formatGnf(remainingBalance)}\n"
      "----------------------------------------\n"
      "Merci de votre confiance !",
    );

    final urlStr = 'https://wa.me/$cleanPhone?text=$message';
    final success = await UrlLauncherHelper.openUrl(urlStr);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return AppFormDialog(
      title: 'Régler : ${widget.summary.customerName}',
      subtitle: 'Reste dû total : ${formatGnf(widget.summary.balance)}',
      icon: Icons.payments_outlined,
      gradientColors: const [Color(0xFFEAB308), Color(0xFFF59E0B)],
      width: 520,
      primaryLabel: 'Confirmer le versement',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: _isValid && !_isSubmitting ? _submit : null,
      isPrimaryLoading: _isSubmitting,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Champ Montant + Raccourcis ──
          AppFormField(
            label: 'Montant réglé (GNF)',
            controller: _amountController,
            icon: Icons.payments_outlined,
            isRequired: true,
            keyboardType: TextInputType.number,
            onChanged: _onAmountChanged,
          ),
          if (_amount != null && _amount! > widget.summary.balance)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'Montant supérieur au reste dû (${formatGnf(widget.summary.balance)})',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),

          // Boutons rapides pour solder
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                label: Text(
                  'Tout solder (${formatGnf(widget.summary.balance)})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                backgroundColor: const Color(0xFFFEF3C7),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                onPressed: () => _setAmount(widget.summary.balance),
              ),
              if (widget.summary.balance > 100000)
                ActionChip(
                  label: const Text('50 000 GNF', style: TextStyle(fontSize: 12)),
                  onPressed: () => _setAmount(50000),
                ),
              if (widget.summary.balance > 200000)
                ActionChip(
                  label: const Text('100 000 GNF', style: TextStyle(fontSize: 12)),
                  onPressed: () => _setAmount(100000),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Mode de règlement ──
          Text(
            'Mode de règlement',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _MethodChip(
                label: 'Espèces',
                icon: Icons.payments_outlined,
                isSelected: _selectedMethod == PaymentMethod.cash,
                onSelected: () => setState(() => _selectedMethod = PaymentMethod.cash),
              ),
              const SizedBox(width: 8),
              _MethodChip(
                label: 'Orange / Wave',
                icon: Icons.phone_android_rounded,
                isSelected: _selectedMethod == PaymentMethod.mobileMoney,
                onSelected: () =>
                    setState(() => _selectedMethod = PaymentMethod.mobileMoney),
              ),
              const SizedBox(width: 8),
              _MethodChip(
                label: 'Virement',
                icon: Icons.account_balance_outlined,
                isSelected: _selectedMethod == PaymentMethod.bank,
                onSelected: () => setState(() => _selectedMethod = PaymentMethod.bank),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Date et heure du versement (Traçabilité) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date & heure du paiement',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${formatDateTime(_selectedDate)} ${isToday ? "(Aujourd'hui)" : ""}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Changer', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Historique chronologique des versements ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historique des versements (${_history?.length ?? 0})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_history != null && _history!.isNotEmpty)
                Text(
                  '${_history!.length} tranche${_history!.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 8),

          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_historyError != null)
            Text(
              'Erreur: $_historyError',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            )
          else if (_history == null || _history!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  'Aucun versement précédent enregistré.\nLe client règle sa première tranche.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _history!.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final item = _history![index];
                  final settings = ref.read(appSettingsProvider);
                  final bName = settings.businessName.isNotEmpty
                      ? settings.businessName
                      : "N'MaShop";

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _methodIcon(item.paymentMethod),
                          size: 16,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+ ${formatGnf(item.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${formatDateTime(item.date)} • ${_methodLabel(item.paymentMethod)}'
                              '${item.saleReference != null ? ' (${item.saleReference})' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.summary.customerPhone != null &&
                          widget.summary.customerPhone!.trim().isNotEmpty)
                        IconButton(
                          tooltip: 'Partager le reçu WhatsApp de ce versement',
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: Color(0xFF25D366),
                          ),
                          onPressed: () {
                            _shareSingleReceiptWhatsApp(
                              context: context,
                              customerName: widget.summary.customerName,
                              phone: widget.summary.customerPhone,
                              amount: item.amount,
                              method: item.paymentMethod,
                              date: item.date,
                              remainingBalance: widget.summary.balance,
                              businessName: bName,
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                : context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF59E0B)
                  : context.colors.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFFB45309) : context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFFB45309)
                        : context.colors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.colors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? context.colors.onSurface,
          ),
        ),
      ],
    );
  }
}
