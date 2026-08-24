import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/payment_method.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../application/expense_providers.dart';
import '../data/repositories/drift_expense_repository.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class NewExpenseDialog extends ConsumerStatefulWidget {
  const NewExpenseDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NewExpenseDialog(),
    );
  }

  @override
  ConsumerState<NewExpenseDialog> createState() => _NewExpenseDialogState();
}

class _NewExpenseDialogState extends ConsumerState<NewExpenseDialog> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.rent;
  PaymentMethod _selectedPayment = PaymentMethod.cash;

  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountStr = _amountController.text.trim();
    final desc = _descController.text.trim();

    if (amountStr.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le montant et la description')),
      );
      return;
    }

    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(expenseRepositoryProvider).insertExpense(
            category: _selectedCategory,
            amount: amount,
            description: desc,
            date: DateTime.now(),
            paymentMethod: _selectedPayment,
          );

      ref.invalidate(expensesDataProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dépense enregistrée avec succès'),
            backgroundColor: AppColors.brandEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Nouvelle Dépense',
      subtitle: 'Enregistrer une sortie de fonds',
      icon: Icons.money_off_csred_outlined,
      gradientColors: const [Color(0xFFEF4444), Color(0xFFDC2626)],
      primaryLabel: 'Enregistrer',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: _isSaving ? null : _save,
      isPrimaryLoading: _isSaving,
      sections: [
        FormSection(
          title: 'Détails de la Dépense',
          icon: Icons.receipt_long_outlined,
          child: Column(
            children: [
              FormFieldRow(
                left: AppFormDropdown<ExpenseCategory>(
                  label: 'Catégorie',
                  value: _selectedCategory,
                  icon: Icons.category_outlined,
                  isRequired: true,
                  iconColor: const Color(0xFFEF4444),
                  items: ExpenseCategory.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                right: AppFormField(
                  label: 'Montant (GNF)',
                  hint: 'Ex: 150 000',
                  controller: _amountController,
                  icon: Icons.payments_outlined,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  iconColor: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppFormField(
                label: 'Description',
                hint: 'Motif de la dépense',
                controller: _descController,
                icon: Icons.description_outlined,
                isRequired: true,
                iconColor: const Color(0xFFEF4444),
              ),
              const SizedBox(height: AppSpacing.md),
              AppFormDropdown<PaymentMethod>(
                label: 'Mode de paiement',
                value: _selectedPayment,
                icon: Icons.account_balance_wallet_outlined,
                isRequired: true,
                iconColor: const Color(0xFFEF4444),
                items: PaymentMethod.values
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPayment = val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
