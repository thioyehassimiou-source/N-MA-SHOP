import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/payment_method.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../stock/application/stock_providers.dart';
import '../../stock/domain/entities/product.dart';
import '../application/purchase_cart_controller.dart';

/// Écran Nouvel Achat — calqué exactement sur SalesScreen (qui fonctionne).
/// Pas de Scaffold : AppShell en fournit un.
class PurchaseScreen extends ConsumerWidget {
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _ProductPicker()),
          SizedBox(width: AppSpacing.lg),
          SizedBox(width: 360, child: _CartPanel()),
        ],
      ),
    );
  }
}

// ─── Volet catalogue produits ────────────────────────────────────────────────

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => context.go('/fournisseurs'),
              tooltip: 'Retour Fournisseurs',
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouvel Achat', style: AppTypography.headlineMd),
                Text(
                  'Cliquez sur un produit pour l\'ajouter.',
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Barre de recherche
        AppCard(
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
        const SizedBox(height: AppSpacing.md),

        // Grille produits
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
                            p.name.toLowerCase().contains(_query)),
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
                            ? 'Aucun produit.\nAjoutez-en dans « Mes produits ».'
                            : 'Aucun produit ne correspond à « $_query ».',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
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
                itemBuilder: (_, i) => _ProductTile(product: visible[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Tuile produit ───────────────────────────────────────────────────────────

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: () =>
          ref.read(purchaseCartControllerProvider.notifier).addProduct(product),
      hoverBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatGnf(product.purchasePrice),
            style: AppTypography.labelMd.copyWith(color: context.colors.primary),
          ),
          Text(
            'Stock: ${formatQuantity(product.stockQuantity)} ${product.unit}',
            style: AppTypography.labelSm.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Volet panier ────────────────────────────────────────────────────────────

class _CartPanel extends ConsumerWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(purchaseCartControllerProvider);
    final ctrl = ref.read(purchaseCartControllerProvider.notifier);

    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Container(
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
                    Icons.shopping_bag_outlined,
                    size: 18,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Text('Achat en cours', style: AppTypography.labelMd),
                ),
                if (!state.isEmpty)
                  AppButton.secondary(
                    label: 'Vider',
                    icon: Icons.delete_outline,
                    onPressed: ctrl.clear,
                  ),
              ],
            ),
          ),

          // Lignes
          Expanded(
            child: state.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
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
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.base,
                    ),
                    itemCount: state.lines.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                    ),
                    itemBuilder: (_, i) => _CartLineTile(index: i),
                  ),
          ),

          // Pied
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _CartFooter(state: state, ctrl: ctrl),
          ),
        ],
      ),
    );
  }
}

// ─── Ligne du panier ─────────────────────────────────────────────────────────

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final line = ref.watch(purchaseCartControllerProvider).lines[index];
    final ctrl = ref.read(purchaseCartControllerProvider.notifier);

    final isCmpUp = line.projectedCmp > line.currentCmp;
    final isCmpDown = line.projectedCmp < line.currentCmp;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.base,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
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
                const SizedBox(height: 2),
                InkWell(
                  onTap: () async {
                    final newPrice = await _showPriceEditDialog(context, line);
                    if (newPrice != null) {
                      ctrl.setUnitPrice(index, newPrice);
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${formatGnf(line.unitPrice)} / ${line.unit}',
                            style: AppTypography.labelSm.copyWith(
                              color: context.colors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          WidgetSpan(
                            child: Padding(
                              padding: EdgeInsets.only(left: 4.0),
                              child: Icon(Icons.edit, size: 12, color: context.colors.primary),
                            ),
                            alignment: PlaceholderAlignment.middle,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CMP: ${formatGnf(line.currentCmp)} ➔ ${formatGnf(line.projectedCmp)}',
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 10,
                          color: context.colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCmpUp) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_upward, size: 12, color: context.colors.error),
                    ] else if (isCmpDown) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_downward, size: 12, color: Colors.green),
                    ]
                  ],
                ),
              ],
            ),
          ),
          // Contrôles quantité
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyBtn(
                  icon: Icons.remove,
                  onTap: () => ctrl.setQuantity(index, line.quantity - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    formatQuantity(line.quantity),
                    style: AppTypography.labelMd,
                  ),
                ),
                _QtyBtn(
                  icon: Icons.add,
                  onTap: () => ctrl.setQuantity(index, line.quantity + 1),
                ),
              ],
            ),
          ),
          // Sous-total
          SizedBox(
            width: 80,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatGnf(line.lineTotal),
                textAlign: TextAlign.right,
                style: AppTypography.labelMd.copyWith(color: context.colors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int?> _showPriceEditDialog(BuildContext context, PurchaseCartLine line) {
    final controller = TextEditingController(text: line.unitPrice.toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AppFormDialog(
        title: 'Modifier le prix d\'achat',
        subtitle: 'Ajuster le prix pour ce produit',
        icon: Icons.edit_outlined,
        gradientColors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
        width: 400,
        primaryLabel: 'Valider',
        primaryIcon: Icons.check_circle_outline,
        onCancel: () => Navigator.pop(ctx),
        onPrimary: () {
          final val = int.tryParse(controller.text);
          Navigator.pop(ctx, val);
        },
        body: AppFormField(
          label: 'Prix Unitaire (GNF)',
          controller: controller,
          icon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
          isRequired: true,
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: context.colors.onSurface),
      ),
    );
  }
}

// ─── Pied du panier (formulaire + total + bouton) ────────────────────────────

class _CartFooter extends StatefulWidget {
  const _CartFooter({required this.state, required this.ctrl});

  final PurchaseCartState state;
  final PurchaseCartController ctrl;

  @override
  State<_CartFooter> createState() => _CartFooterState();
}

class _CartFooterState extends State<_CartFooter> {
  final _supplierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fournisseur
        AppFormField(
          label: 'Nom du fournisseur',
          controller: _supplierCtrl,
          icon: Icons.store_outlined,
          isRequired: true,
          onChanged: widget.ctrl.setSupplierName,
        ),
        const SizedBox(height: AppSpacing.base),

        // Acompte + méthode
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppFormField(
                label: 'Acompte versé (GNF)',
                controller: _amountCtrl,
                icon: Icons.payments_outlined,
                isRequired: true,
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    widget.ctrl.setAmountPaid(int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: AppSpacing.base),
            DropdownButton<PaymentMethod>(
              value: widget.state.method,
              underline: const SizedBox(),
              isDense: true,
              items: PaymentMethod.values
                  .where((m) => m != PaymentMethod.credit)
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        m.name.toUpperCase(),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (m) {
                if (m != null) widget.ctrl.setMethod(m);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),

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
              formatGnf(widget.state.total),
              style: AppTypography.headlineMd.copyWith(
                color: context.colors.primary,
              ),
            ),
          ],
        ),
        if (widget.state.amountPaid > 0 &&
            widget.state.amountPaid < widget.state.total) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'Reste dû',
                style: AppTypography.labelSm.copyWith(color: context.colors.error),
              ),
              const Spacer(),
              Text(
                formatGnf(widget.state.total - widget.state.amountPaid),
                style: AppTypography.labelMd.copyWith(color: context.colors.error),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),

        // Bouton valider
        AppButton(
          icon: widget.state.submitting ? null : Icons.check_circle_outline,
          label: widget.state.submitting
              ? 'Enregistrement…'
              : 'Valider l\'achat',
          onPressed: widget.state.isEmpty || widget.state.submitting
              ? null
              : () async {
                  final err = await widget.ctrl.submit();
                  if (!context.mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        backgroundColor: context.colors.error,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Achat enregistré avec succès !'),
                      ),
                    );
                    _supplierCtrl.clear();
                    _amountCtrl.clear();
                    if (context.mounted) context.go('/fournisseurs');
                  }
                },
        ),
      ],
    );
  }
}
