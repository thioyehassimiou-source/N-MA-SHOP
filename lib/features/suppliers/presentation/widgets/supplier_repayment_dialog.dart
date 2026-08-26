import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/domain/payment_method.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../application/suppliers_providers.dart';
import '../../domain/supplier_summary.dart';

class SupplierRepaymentDialog extends ConsumerStatefulWidget {
  const SupplierRepaymentDialog({super.key, required this.summary});

  final SupplierSummary summary;

  static Future<void> show(BuildContext context, SupplierSummary summary) {
    return showDialog(
      context: context,
      builder: (context) => SupplierRepaymentDialog(summary: summary),
    );
  }

  @override
  ConsumerState<SupplierRepaymentDialog> createState() =>
      _SupplierRepaymentDialogState();
}

class _SupplierRepaymentDialogState
    extends ConsumerState<SupplierRepaymentDialog> {
  late final TextEditingController _amountController;
  int? _amount;
  PaymentMethod _method = PaymentMethod.cash;
  bool _isSubmitting = false;

  List<SupplierPayment>? _history;
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
      final service = ref.read(purchaseServiceProvider);
      final history = await service.getSupplierPaymentHistory(
        widget.summary.supplierId,
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

  void _setPercentage(double percent) {
    final newAmount = (widget.summary.balance * percent).round();
    setState(() {
      _amount = newAmount;
      _amountController.text = newAmount.toString();
    });
  }

  bool get _isValid =>
      _amount != null && _amount! > 0 && _amount! <= widget.summary.balance;

  Future<void> _submit() async {
    if (!_isValid) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(purchaseServiceProvider);
      await service.recordSupplierPayment(
        widget.summary.supplierId,
        _amount!,
        _method,
      );

      // Invalider les fournisseurs pour forcer le recalcul des dettes
      ref.invalidate(supplierSummariesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Règlement enregistré avec succès.')),
        );
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
      title: 'Régler : ${widget.summary.supplierName}',
      subtitle: 'Dette restante : ${formatGnf(widget.summary.balance)}',
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
                'Montant supérieur à la dette',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('25%'),
                onPressed: () => _setPercentage(0.25),
              ),
              ActionChip(
                label: const Text('50%'),
                onPressed: () => _setPercentage(0.5),
              ),
              ActionChip(
                label: const Text('100%'),
                onPressed: () => _setPercentage(1.0),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppFormDropdown<PaymentMethod>(
            label: 'Moyen de paiement',
            value: _method,
            icon: Icons.account_balance_wallet_outlined,
            isRequired: true,
            items: PaymentMethod.values
                .where((m) => m != PaymentMethod.credit)
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.name.toUpperCase()),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _method = val);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (_amount != null && _amount! > 0 && _amount! <= widget.summary.balance)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Nouveau solde :', style: theme.textTheme.bodyMedium),
                  Text(
                    formatGnf(widget.summary.balance - _amount!),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
