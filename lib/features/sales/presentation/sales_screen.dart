import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:printing/printing.dart';

import '../../../core/domain/payment_method.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/services/pdf_receipt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/barcode_scanner_dialog.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../stock/application/stock_providers.dart';
import '../../stock/domain/entities/product.dart';
import '../application/sale_cart_controller.dart';
import '../domain/usecases/record_sale.dart';

/// Écran « Vendre » — le workflow central. Toute la logique vit dans le
/// [SaleCartController] ; ce widget se contente d'afficher et de dispatcher.
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          // ── Mode large : sélection produits + panier côte à côte ──
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(flex: 3, child: _ProductPicker()),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: (constraints.maxWidth * 0.32).clamp(300.0, 400.0),
                  child: const _CartPanel(),
                ),
              ],
            ),
          );
        }

        // ── Mode compact : produits en plein écran + bouton panier flottant ──
        return const _CompactSalesLayout();
      },
    );
  }
}

/// Layout compact (mobile / fenêtre étroite) : produits en plein écran avec
/// un bouton fixe en bas pour ouvrir le panneau panier en bottom sheet.
class _CompactSalesLayout extends ConsumerWidget {
  const _CompactSalesLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(saleCartControllerProvider);
    final itemCount = cartState.lines.fold(0, (sum, l) => sum + l.quantity);

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: itemCount > 0 ? 80 : AppSpacing.md,
          ),
          child: const _ProductPicker(),
        ),

        // Bouton panier flottant en bas
        Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            offset: itemCount > 0 ? Offset.zero : const Offset(0, 2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: itemCount > 0 ? 1 : 0,
              child: FilledButton.icon(
                onPressed: itemCount > 0
                    ? () => _openCartSheet(context)
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                ),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(
                  itemCount > 0
                      ? 'Voir le panier ($itemCount article${itemCount > 1 ? "s" : ""})'
                      : 'Panier vide',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openCartSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          child: const _CartPanel(),
        ),
      ),
    );
  }
}


// ─────────────────────────── Volet produits ───────────────────────────

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker();

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsStreamProvider);
    final cartLines = ref.watch(saleCartControllerProvider).lines;

    // Map productId → quantité dans le panier pour les badges
    final cartQty = {for (final l in cartLines) l.productId: l.quantity};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ──
        AppPageHeader(
          title: 'Caisse POS',
          subtitle: 'Sélectionnez ou scannez un produit pour l\'ajouter au panier',
          icon: Icons.point_of_sale_rounded,
          gradientColors: [AppColors.brandNavy, context.colors.primary],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Barre de recherche + Bouton scan ──
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    hintText: 'Rechercher un produit…',
                    hintStyle: AppTypography.bodySm.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.base,
                    ),
                  ),
                  style: AppTypography.bodySm,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Bouton scan code-barres
            Tooltip(
              message: 'Scanner un code-barres',
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: InkWell(
                  onTap: () async {
                    final code = await BarcodeScannerDialog.show(context);
                    if (code != null && code.isNotEmpty && context.mounted) {
                      final products = ref.read(productsStreamProvider).value ?? [];
                      final match = products.where((p) => p.isActive && p.barcode == code).firstOrNull;
                      if (match != null) {
                        ref.read(saleCartControllerProvider.notifier).addProduct(match);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [const Icon(Icons.check_circle_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Text('${match.name} ajouté au panier')]),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Text('Code inconnu : $code')]),
                            backgroundColor: theme.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Grille produits ──
        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Erreur : $e',
                style: AppTypography.bodySm.copyWith(color: context.colors.error),
              ),
            ),
            data: (products) {
              final visible = products
                  .where(
                    (p) =>
                        p.isActive &&
                        (_query.isEmpty ||
                            p.name.toLowerCase().contains(_query) ||
                            (p.reference != null && p.reference!.toLowerCase().contains(_query)) ||
                            (p.barcode != null && p.barcode!.toLowerCase() == _query)),
                  )
                  .toList();
              if (visible.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        products.isEmpty
                            ? 'Votre stock est vide.\nAjoutez vos premiers produits pour commencer à vendre.'
                            : 'Aucun produit ne correspond à « $_query ».',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      if (products.isEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppButton.secondary(
                          label: 'Gérer le stock (Stock)',
                          icon: Icons.inventory_2_outlined,
                          onPressed: () => context.go('/produits'),
                        ),
                      ],
                    ],
                  ),
                );

              }
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisExtent: 110,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemCount: visible.length,
                itemBuilder: (_, i) => _ProductTile(
                  product: visible[i],
                  cartQuantity: cartQty[visible[i].id] ?? 0,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Tuile produit ───────────────────────────

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product, required this.cartQuantity});

  final Product product;
  final int cartQuantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outOfStock = product.stockQuantity <= 0;
    final inCart = cartQuantity > 0;

    AppChipStatus chipStatus;
    String chipLabel;
    if (outOfStock) {
      chipStatus = AppChipStatus.neutral;
      chipLabel = 'Rupture';
    } else if (product.stockQuantity <=
        (product.lowStockThreshold > 0 ? product.lowStockThreshold : 3)) {
      chipStatus = AppChipStatus.warning;
      chipLabel = 'Stock bas';
    } else {
      chipStatus = AppChipStatus.success;
      chipLabel = 'En stock';
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: outOfStock
          ? null
          : () => ref
                .read(saleCartControllerProvider.notifier)
                .addProduct(product),
      hoverBorder: !outOfStock,
      child: Stack(
        children: [
          Row(
            children: [
              if (product.imageUrl != null && File(product.imageUrl!).existsSync())
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.file(
                      File(product.imageUrl!),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd.copyWith(
                        color: outOfStock
                            ? context.colors.onSurfaceVariant
                            : context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatGnf(product.salePrice),
                          style: AppTypography.labelMd.copyWith(
                            color: outOfStock
                                ? context.colors.onSurfaceVariant
                                : context.colors.primary,
                          ),
                        ),
                        AppChip(label: chipLabel, status: chipStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Badge panier (quantité en cours)
          if (inCart)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  formatQuantity(cartQuantity),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Volet panier ───────────────────────────

class _CartPanel extends ConsumerWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(saleCartControllerProvider);
    final controller = ref.read(saleCartControllerProvider.notifier);

    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── En-tête panier ──
          _CartHeader(isEmpty: state.isEmpty, onClear: controller.clear),

          // ── Lignes ──
          Expanded(
            child: state.isEmpty
                ? _EmptyCartPlaceholder()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.base,
                    ),
                    itemCount: state.lines.length,
                    separatorBuilder: (_, i) => Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                    ),
                    itemBuilder: (_, i) => _CartLineTile(index: i),
                  ),
          ),

          // ── Pied : paiement + total + bouton ──
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PaymentSelector(state: state, controller: controller),
                const SizedBox(height: AppSpacing.md),

                // Total
                Row(
                  children: [
                    Text(
                      'Total',
                      style: AppTypography.labelMd.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatGnf(state.total),
                      style: AppTypography.headlineMd.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Avertissement stock
                if (state.hasStockIssue) ...[
                  const AppChip(
                    label: 'Quantité insuffisante en stock',
                    status: AppChipStatus.error,
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],

                // Bouton enregistrer
                _SubmitButton(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── En-tête du panneau panier ──
class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.isEmpty, required this.onClear});

  final bool isEmpty;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 18,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(child: Text('Vente en cours', style: AppTypography.labelMd)),
          if (!isEmpty)
            AppButton.secondary(
              label: 'Vider',
              icon: Icons.delete_outline,
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ── État vide ──
class _EmptyCartPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: context.colors.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Panier vide',
              style: AppTypography.labelMd.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cliquez sur un produit à gauche\npour l\'ajouter.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: context.colors.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton enregistrer ──
class _SubmitButton extends ConsumerWidget {
  const _SubmitButton({required this.state});
  final SaleCartState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabled = state.isEmpty || state.submitting || state.hasStockIssue;

    return SizedBox(
      width: double.infinity,
      child: AppButton(
        icon: state.submitting ? null : Icons.check_circle_outline,
        label: state.submitting ? 'Enregistrement…' : 'Enregistrer la vente',
        onPressed: disabled ? null : () => _submit(context, ref),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final appSettings = ref.read(appSettingsProvider);
    final cartState = ref.read(saleCartControllerProvider);

    // Préparer les lignes pour le reçu PDF avant la remise à zéro du panier
    final receiptLines = [
      for (final l in cartState.lines)
        ReceiptLineItem(
          name: l.name,
          unit: l.unit,
          quantity: l.quantity,
          unitPrice: l.unitPrice,
          lineTotal: l.lineTotal,
        ),
    ];
    final customerName = cartState.customerName.trim();
    final paymentLabel = switch (cartState.method) {
      PaymentMethod.cash => 'Espèces',
      PaymentMethod.mobileMoney => 'Mobile Money',
      PaymentMethod.bank => 'Banque',
      PaymentMethod.credit => 'Crédit',
    };

    final result = await ref.read(saleCartControllerProvider.notifier).submit();
    if (!context.mounted) return;

    switch (result) {
      case RecordSaleSuccess(:final sale):
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: context.colors.primaryContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            content: Text(
              sale.isCredit
                  ? 'Vente (${sale.reference}) — crédit de ${formatGnf(sale.creditAmount)} noté.'
                  : 'Vente enregistrée (${sale.reference}).',
              style: AppTypography.bodySm.copyWith(
                color: context.colors.onPrimaryContainer,
              ),
            ),
          ),
        );

        final receiptData = ReceiptData(
          reference: sale.reference,
          date: sale.date,
          businessName: appSettings.businessName,
          businessPhone: appSettings.businessPhone,
          businessAddress: appSettings.businessAddress,
          businessNif: appSettings.businessNif,
          lines: receiptLines,
          total: sale.total,
          amountPaid: sale.amountPaid,
          creditAmount: sale.creditAmount,
          paymentMethodLabel: paymentLabel,
          customerName: customerName.isNotEmpty ? customerName : null,
        );

        _showReceiptDialog(context, receiptData);

      case RecordSaleFailure(:final error):
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: context.colors.errorContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            content: Text(
              error.message,
              style: AppTypography.bodySm.copyWith(
                color: context.colors.onErrorContainer,
              ),
            ),
          ),
        );
    }
  }

  void _showReceiptDialog(BuildContext context, ReceiptData receiptData) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppFormDialog(
          title: 'Vente enregistrée !',
          subtitle: 'Souhaitez-vous imprimer ou exporter le reçu PDF ?',
          icon: Icons.check_circle_outline,
          gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
          width: 400,
          primaryLabel: 'Imprimer / PDF',
          primaryIcon: Icons.print_outlined,
          onPrimary: () {
            Navigator.of(dialogContext).pop();
            Printing.layoutPdf(
              name: 'Recu_${receiptData.reference}',
              onLayout: (_) => PdfReceiptService.generateReceiptPdf(receiptData),
            );
          },
          onCancel: () => Navigator.of(dialogContext).pop(),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Référence : ${receiptData.reference}',
                style: AppTypography.labelMd,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Montant Total : ${formatGnf(receiptData.total)}',
                style: AppTypography.bodySm,
              ),
              if (receiptData.isCredit) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Reste à payer (Crédit) : ${formatGnf(receiptData.creditAmount)}',
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Ligne de panier ───────────────────────────

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final line = ref.watch(saleCartControllerProvider).lines[index];
    final controller = ref.read(saleCartControllerProvider.notifier);
    final hasIssue = line.exceedsStock;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.base,
      ),
      child: Row(
        children: [
          // Icône produit
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: line.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Image.file(
                      File(line.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: hasIssue ? theme.colorScheme.error : theme.colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: hasIssue ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
          ),
          const SizedBox(width: AppSpacing.base),

          // Nom + prix unitaire
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd,
                ),
                Text(
                  '${formatGnf(line.unitPrice)} / ${line.unit}',
                  style: AppTypography.labelSm.copyWith(
                    color: hasIssue
                        ? theme.colorScheme.error
                        : context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Contrôles quantité
          _QuantityControl(
            quantity: line.quantity,
            available: line.availableStock,
            onDecrement: () => controller.setQuantity(index, line.quantity - 1),
            onIncrement: () => controller.setQuantity(index, line.quantity + 1),
          ),

          // Sous-total
          SizedBox(
            width: 90,
            child: Text(
              formatAmount(line.lineTotal),
              textAlign: TextAlign.right,
              style: AppTypography.labelMd.copyWith(
                color: hasIssue ? context.colors.error : context.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.available,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final int available;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atMax = quantity >= available;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(icon: Icons.remove, onTap: onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(formatQuantity(quantity), style: AppTypography.labelMd),
          ),
          _QtyBtn(
            icon: Icons.add,
            onTap: atMax ? null : onIncrement,
            disabled: atMax,
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, this.onTap, this.disabled = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: disabled ? context.colors.outlineVariant : context.colors.onSurface,
        ),
      ),
    );
  }
}

// ─────────────────────────── Sélecteur de paiement ───────────────────────────

class _PaymentSelector extends StatefulWidget {
  const _PaymentSelector({required this.state, required this.controller});

  final SaleCartState state;
  final SaleCartController controller;

  @override
  State<_PaymentSelector> createState() => _PaymentSelectorState();
}

class _PaymentSelectorState extends State<_PaymentSelector> {
  // Contrôleurs persistants : les champs ne se vident pas lors du changement
  // de méthode de paiement.
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.state.customerName);
    _phoneCtrl = TextEditingController(text: widget.state.customerPhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  static const _methods = {
    PaymentMethod.cash: (Icons.payments_outlined, 'Espèces'),
    PaymentMethod.mobileMoney: (Icons.phone_android_outlined, 'Mobile Money (OM/MTN)'),
    PaymentMethod.bank: (Icons.account_balance_outlined, 'Banque'),
    PaymentMethod.credit: (Icons.schedule_outlined, 'Crédit'),
  };

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mode de paiement',
          style: AppTypography.labelSm.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: [
            for (final entry in _methods.entries)
              _PaymentChip(
                icon: entry.value.$1,
                label: entry.value.$2,
                selected: state.method == entry.key,
                onTap: () => controller.setMethod(entry.key),
              ),
          ],
        ),
        if (state.isCredit) ...[
          const SizedBox(height: AppSpacing.md),
          AppFormField(
            label: 'Nom du client',
            controller: _nameCtrl,
            icon: Icons.person_outline,
            hint: 'Ex : Mamadou Diallo',
            isRequired: true,
            onChanged: controller.setCustomerName,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppFormField(
            label: 'Numéro de téléphone (WhatsApp)',
            controller: _phoneCtrl,
            icon: Icons.phone_outlined,
            hint: 'Ex : 622 12 34 56',
            keyboardType: TextInputType.phone,
            onChanged: controller.setCustomerPhone,
          ),
        ],
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? context.colors.primary : context.colors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? context.colors.primary : context.colors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? context.colors.onPrimary
                  : context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: selected
                    ? context.colors.onPrimary
                    : context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
