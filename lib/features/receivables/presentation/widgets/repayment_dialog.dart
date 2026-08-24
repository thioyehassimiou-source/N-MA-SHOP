import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../application/receivables_providers.dart';
import '../../domain/credit_summary.dart';
import '../../domain/repositories/receivables_repository.dart';
import '../../domain/repayment_draft.dart';
import '../../domain/usecases/record_repayment.dart';

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
      _amount = int.tryParse(value);
    });
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
      );

      final result = await useCase(draft);

      if (mounted) {
        if (result is RecordRepaymentSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Règlement enregistré avec succès.')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppFormDialog(
      title: 'Régler : ${widget.summary.customerName}',
      subtitle: 'Reste dû total : ${formatGnf(widget.summary.balance)}',
      icon: Icons.payments_outlined,
      gradientColors: const [Color(0xFFEAB308), Color(0xFFF59E0B)],
      width: 450,
      primaryLabel: 'Confirmer',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: _isValid && !_isSubmitting ? _submit : null,
      isPrimaryLoading: _isSubmitting,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                'Montant supérieur au reste dû',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Le paiement sera déduit des ventes les plus anciennes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Historique des paiements',
            style: theme.textTheme.titleMedium,
          ),
          const Divider(),
          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_historyError != null)
            Text(
              'Erreur: $_historyError',
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (_history == null || _history!.isEmpty)
            Text(
              'Aucun paiement précédent enregistré.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history!.length,
              itemBuilder: (context, index) {
                final item = _history![index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, size: 20),
                  title: Text(
                    formatGnf(item.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(formatDateTime(item.date)),
                );
              },
            ),
        ],
      ),
    );
  }
}
