import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/payment_method.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/services/app_print_service.dart';
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
import '../../../core/widgets/product_thumbnail.dart';
import '../../../core/widgets/app_image.dart';
import '../../stock/application/stock_providers.dart';
import '../../stock/domain/entities/product.dart';
import '../../clients/application/clients_providers.dart';
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
          // ── Mode large : sélection produits + panier côte à côte (espace égal 50% / 50%) ──
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: _ProductPicker()),
                const SizedBox(width: AppSpacing.lg),
                const Expanded(child: _CartPanel()),
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _barcodeBuffer = '';
  DateTime? _lastKeystrokeTime;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Écoute globale des frappes de douchettes code-barres (USB / Bluetooth)
  /// Même si le caissier a cliqué ailleurs, le scan est capturé et injecté directement au panier !
  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Si le focus est déjà dans le champ de recherche, le TextField gère naturellement via onSubmitted
    if (_searchFocusNode.hasFocus) {
      if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _submitBarcode(_searchController.text.trim());
        return true;
      }
      return false;
    }

    final now = DateTime.now();
    // Les douchettes envoient les caractères avec un intervalle < 60ms
    if (_lastKeystrokeTime != null && now.difference(_lastKeystrokeTime!).inMilliseconds > 150) {
      _barcodeBuffer = '';
    }
    _lastKeystrokeTime = now;

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_barcodeBuffer.isNotEmpty) {
        _submitBarcode(_barcodeBuffer.trim());
        _barcodeBuffer = '';
        return true;
      }
      return false;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty) {
      _barcodeBuffer += char;
    }
    return false;
  }

  /// Recherche immédiate et ajout direct au panier dès qu'un code-barres est scanné
  void _submitBarcode(String rawCode) {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    final products = ref.read(productsStreamProvider).value ?? [];
    // Correspondance exacte sur le code-barres ou la référence article
    final match = products.where((p) =>
      p.isActive &&
      ((p.barcode != null && p.barcode!.trim().toLowerCase() == code.toLowerCase()) ||
       (p.reference != null && p.reference!.trim().toLowerCase() == code.toLowerCase()))
    ).firstOrNull;

    if (match != null) {
      ref.read(saleCartControllerProvider.notifier).addProduct(match);
      SystemSound.play(SystemSoundType.click);

      _searchController.clear();
      setState(() => _query = '');
      _searchFocusNode.requestFocus();

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${match.name} scanné et ajouté au panier (${formatGnf(match.salePrice)})')),
            ],
          ),
          backgroundColor: AppColors.brandEmerald,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      // Si c'est un format de code-barres (au moins 3 caractères alphanumériques sans espace)
      final isLikelyBarcode = RegExp(r'^[0-9A-Za-z\-_]{3,}$').hasMatch(code);
      if (isLikelyBarcode) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Code-barres inconnu : $code'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

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
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    hintText: 'Scanner ou rechercher un produit…',
                    hintStyle: AppTypography.bodySm.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.base,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                              _searchFocusNode.requestFocus();
                            },
                          )
                        : null,
                  ),
                  style: AppTypography.bodySm,
                  onChanged: (v) {
                    setState(() => _query = v.trim().toLowerCase());
                    // Si la douchette injecte directement un code-barres complet :
                    if (v.trim().length >= 6) {
                      final products = ref.read(productsStreamProvider).value ?? [];
                      final exactMatch = products.where((p) => p.isActive && p.barcode != null && p.barcode!.trim().toLowerCase() == v.trim().toLowerCase()).firstOrNull;
                      if (exactMatch != null) {
                        _submitBarcode(v);
                      }
                    }
                  },
                  onSubmitted: (v) => _submitBarcode(v),
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
                            backgroundColor: AppColors.brandEmerald,
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
                  maxCrossAxisExtent: 220,
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
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ProductThumbnail(
                  imageUrl: product.imageUrl,
                  size: 44,
                  borderRadius: AppRadius.md,
                  enableZoomOnTap: false,
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

                // Total et Remise négociée
                if (state.hasAnyDiscount) ...[
                  Row(
                    children: [
                      Text(
                        'Total normal',
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatGnf(state.catalogTotal),
                        style: AppTypography.bodySm.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: context.colors.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Remise accordée',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.brandEmerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '-${formatGnf(state.totalDiscount)}',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.brandEmerald,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Total final
                Row(
                  children: [
                    Text(
                      'Total',
                      style: AppTypography.labelMd.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!state.isEmpty)
                      InkWell(
                        onTap: () => _showGlobalDiscountDialog(context, ref, state),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sell_outlined, size: 12, color: AppColors.brandOrange),
                              SizedBox(width: 4),
                              Text(
                                'Remise',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandOrange,
                                ),
                              ),
                            ],
                          ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 38,
              color: context.colors.outlineVariant,
            ),
            const SizedBox(height: 6),
            Text(
              'Panier vide',
              style: AppTypography.labelMd.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Cliquez sur un produit à gauche pour l\'ajouter.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                fontSize: 12,
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
          subtitle: 'Imprimez le reçu ou enregistrez-le directement en PDF.',
          icon: Icons.check_circle_outline,
          gradientColors: const [AppColors.brandEmerald, Color(0xFF059669)],
          width: 540,
          primaryLabel: 'Imprimer Ticket',
          primaryIcon: Icons.print_outlined,
          onPrimary: () async {
            Navigator.of(dialogContext).pop();
            await AppPrintService.printDocument(
              context: context,
              documentName: 'Recu_${receiptData.reference}',
              onLayout: (_) => PdfReceiptService.generateReceiptPdf(receiptData),
            );
          },
          secondaryLabel: 'Enregistrer PDF',
          secondaryIcon: Icons.save_alt_rounded,
          onSecondary: () async {
            Navigator.of(dialogContext).pop();
            final bytes =
                await PdfReceiptService.generateReceiptPdf(receiptData);
            if (context.mounted) {
              await AppPrintService.savePdfWithDialog(
                context: context,
                bytes: bytes,
                defaultFileName: 'Recu_${receiptData.reference}.pdf',
              );
            }
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
          // Icône / Photo produit
          AppImage(
            imagePath: line.imageUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            fallbackIcon: Icons.inventory_2_outlined,
            fallbackColor: hasIssue ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.base),

          // Nom + prix unitaire négociable
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd,
                ),
                InkWell(
                  onTap: () => _showDiscountDialog(context, ref, index, line),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (line.hasDiscount) ...[
                          Flexible(
                            child: Text(
                              formatAmount(line.basePrice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: context.colors.outlineVariant,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${formatGnf(line.unitPrice)}/${line.unit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandEmerald,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.brandEmerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${formatAmount(line.discountAmount)}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandEmerald,
                              ),
                            ),
                          ),
                        ] else ...[
                          Flexible(
                            child: Text(
                              '${formatGnf(line.unitPrice)}/${line.unit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                color: hasIssue
                                    ? theme.colorScheme.error
                                    : context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.edit_outlined,
                            size: 11,
                            color: context.colors.primary.withValues(alpha: 0.6),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contrôles quantité (incrémentation, décrémentation et saisie directe)
          _QuantityControl(
            quantity: line.quantity,
            available: line.availableStock,
            onDecrement: () => controller.setQuantity(index, line.quantity - 1),
            onIncrement: () => controller.setQuantity(index, line.quantity + 1),
            onQuantityChanged: (newQty) => controller.setQuantity(index, newQty),
          ),

          // Sous-total
          SizedBox(
            width: 65,
            child: Text(
              formatAmount(line.lineTotal),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.bold,
                color: hasIssue ? context.colors.error : context.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends StatefulWidget {
  const _QuantityControl({
    required this.quantity,
    required this.available,
    required this.onDecrement,
    required this.onIncrement,
    required this.onQuantityChanged,
  });

  final int quantity;
  final int available;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<int> onQuantityChanged;

  @override
  State<_QuantityControl> createState() => _QuantityControlState();
}

class _QuantityControlState extends State<_QuantityControl> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.quantity}');
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _applyText();
      } else {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant _QuantityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity && !_focusNode.hasFocus) {
      _controller.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applyText() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed != null && parsed > 0) {
      widget.onQuantityChanged(parsed);
    } else {
      _controller.text = '${widget.quantity}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atMax = widget.quantity >= widget.available;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _focusNode.hasFocus
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(icon: Icons.remove, onTap: widget.onDecrement),
          SizedBox(
            width: 36,
            height: 26,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 3),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _applyText(),
            ),
          ),
          _QtyBtn(
            icon: Icons.add,
            onTap: atMax ? null : widget.onIncrement,
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
        padding: const EdgeInsets.all(5),
        child: Icon(
          icon,
          size: 15,
          color: disabled ? context.colors.outlineVariant : context.colors.onSurface,
        ),
      ),
    );
  }
}

/// Boîte de dialogue pour négocier / réduire le prix unitaire d'un produit.
Future<void> _showDiscountDialog(
  BuildContext context,
  WidgetRef ref,
  int index,
  CartLine line,
) async {
  final controller = ref.read(saleCartControllerProvider.notifier);
  final textController = TextEditingController(text: '${line.unitPrice}');
  int currentPrice = line.unitPrice;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final diff = line.basePrice - currentPrice;
        final isDiscounted = diff > 0;
        final isIncreased = diff < 0;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sell_outlined, color: AppColors.brandOrange, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Prix négocié / Réduction',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prix normal en boutique : ${formatGnf(line.basePrice)} / ${line.unit}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Prix convenu pour la vente (GNF) :',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: textController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    suffixText: 'GNF',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (val) {
                    final p = int.tryParse(val.trim());
                    if (p != null) {
                      setDialogState(() => currentPrice = p);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (isDiscounted) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brandEmerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.brandEmerald.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppColors.brandEmerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Remise : -${formatAmount(diff)} GNF / unité (-${((diff / line.basePrice) * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandEmerald),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isIncreased) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Majoration : +${formatAmount(-diff)} GNF / unité',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    if (line.unitPrice != line.basePrice)
                      ActionChip(
                        label: const Text('Prix normal'),
                        avatar: const Icon(Icons.refresh, size: 14),
                        onPressed: () {
                          textController.text = '${line.basePrice}';
                          setDialogState(() => currentPrice = line.basePrice);
                        },
                      ),
                    ActionChip(
                      label: const Text('-500 GNF'),
                      onPressed: () {
                        final np = (line.basePrice - 500).clamp(0, 999999999);
                        textController.text = '$np';
                        setDialogState(() => currentPrice = np);
                      },
                    ),
                    ActionChip(
                      label: const Text('-1 000 GNF'),
                      onPressed: () {
                        final np = (line.basePrice - 1000).clamp(0, 999999999);
                        textController.text = '$np';
                        setDialogState(() => currentPrice = np);
                      },
                    ),
                    ActionChip(
                      label: const Text('-2 000 GNF'),
                      onPressed: () {
                        final np = (line.basePrice - 2000).clamp(0, 999999999);
                        textController.text = '$np';
                        setDialogState(() => currentPrice = np);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final np = int.tryParse(textController.text.trim()) ?? currentPrice;
                controller.setUnitPrice(index, np);
                Navigator.of(ctx).pop();
              },
              child: const Text('Appliquer le prix'),
            ),
          ],
        );
      },
    ),
  );
}

/// Boîte de dialogue pour accorder une remise globale sur le total du panier.
Future<void> _showGlobalDiscountDialog(
  BuildContext context,
  WidgetRef ref,
  SaleCartState state,
) async {
  final controller = ref.read(saleCartControllerProvider.notifier);
  final textController = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.brandOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.discount_outlined, color: AppColors.brandOrange, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Remise globale sur la vente',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total actuel du panier : ${formatGnf(state.total)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Montant de la remise à déduire (GNF) :',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: textController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Ex: 2 000 ou 5 000',
                prefixIcon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.brandEmerald),
                suffixText: 'GNF',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              children: [
                if (state.hasAnyDiscount)
                  ActionChip(
                    label: const Text('Rétablir prix normaux'),
                    avatar: const Icon(Icons.refresh, size: 14),
                    onPressed: () {
                      controller.resetPrices();
                      Navigator.of(ctx).pop();
                    },
                  ),
                ActionChip(
                  label: const Text('-1 000 GNF'),
                  onPressed: () => textController.text = '1000',
                ),
                ActionChip(
                  label: const Text('-2 000 GNF'),
                  onPressed: () => textController.text = '2000',
                ),
                ActionChip(
                  label: const Text('-5 000 GNF'),
                  onPressed: () => textController.text = '5000',
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fermer'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandOrange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final discount = int.tryParse(textController.text.trim()) ?? 0;
            if (discount > 0) {
              controller.applyGlobalDiscount(discount);
            }
            Navigator.of(ctx).pop();
          },
          child: const Text('Appliquer la remise'),
        ),
      ],
    ),
  );
}

// ─────────────────────────── Sélecteur de paiement ───────────────────────────

// ─────────────────────────── Sélecteur de paiement ───────────────────────────

class _PaymentSelector extends ConsumerStatefulWidget {
  const _PaymentSelector({required this.state, required this.controller});

  final SaleCartState state;
  final SaleCartController controller;

  @override
  ConsumerState<_PaymentSelector> createState() => _PaymentSelectorState();
}

class _PaymentSelectorState extends ConsumerState<_PaymentSelector> {
  // Contrôleurs persistants : les champs ne se vident pas lors du changement
  // de méthode de paiement.
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  String? _selectedCustomerId;

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
  void didUpdateWidget(_PaymentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.customerName != widget.state.customerName &&
        widget.state.customerName.isEmpty) {
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _selectedCustomerId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    final clientsAsync = ref.watch(clientsStreamProvider);
    final clients = clientsAsync.asData?.value ?? [];

    // Auto-lier si un nom est déjà saisi
    if (_selectedCustomerId == null && state.customerName.isNotEmpty && clients.isNotEmpty) {
      final match = clients.where(
        (c) => c.name.trim().toLowerCase() == state.customerName.trim().toLowerCase(),
      );
      if (match.isNotEmpty) {
        _selectedCustomerId = match.first.id;
      }
    }

    final isExistingClientSelected = _selectedCustomerId != null &&
        _selectedCustomerId != '__new__' &&
        clients.any((c) => c.id == _selectedCustomerId);

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
                onTap: () {
                  controller.setMethod(entry.key);
                  if (entry.key == PaymentMethod.credit && !isExistingClientSelected && (_selectedCustomerId == null || _selectedCustomerId == '__none__')) {
                    setState(() => _selectedCustomerId = '__new__');
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Sélection du Client (disponible pour TOUS les modes de paiement) ──
        Row(
          children: [
            Icon(
              state.isCredit ? Icons.person_pin : Icons.person_outline,
              size: 18,
              color: state.isCredit ? context.colors.primary : context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              state.isCredit
                  ? 'Client (Vente à crédit) *'
                  : 'Client (Optionnel) :',
              style: AppTypography.labelSm.copyWith(
                color: state.isCredit ? context.colors.primary : context.colors.onSurface,
                fontWeight: state.isCredit ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (state.isCredit) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Requis',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: context.colors.error,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (!state.isCredit && (isExistingClientSelected || _selectedCustomerId == '__new__' || state.customerName.isNotEmpty))
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedCustomerId = '__none__';
                    _nameCtrl.clear();
                    _phoneCtrl.clear();
                    controller.setCustomerName('');
                    controller.setCustomerPhone('');
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 13, color: context.colors.error),
                      const SizedBox(width: 2),
                      Text(
                        'Retirer',
                        style: TextStyle(fontSize: 11, color: context.colors.error),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Liste déroulante directe des clients
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isExistingClientSelected
                  ? context.colors.primary
                  : context.colors.outlineVariant,
              width: isExistingClientSelected ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: isExistingClientSelected
                  ? _selectedCustomerId
                  : (_selectedCustomerId == '__new__'
                      ? '__new__'
                      : (state.isCredit ? '__new__' : '__none__')),
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.isCredit
                          ? 'Sélectionner le client à créditer *'
                          : 'Client comptoir / anonyme…',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              items: [
                if (!state.isCredit)
                  const DropdownMenuItem<String?>(
                    value: '__none__',
                    child: Row(
                      children: [
                        Icon(Icons.person_off_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '👤 Client anonyme / Comptant (aucun)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                DropdownMenuItem<String?>(
                  value: '__new__',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1, size: 18, color: context.colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '➕ Nouveau client (saisie manuelle)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (clients.isNotEmpty)
                  ...clients.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${c.name}${c.phone != null && c.phone!.isNotEmpty ? ' (${c.phone})' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              onChanged: (selectedId) {
                setState(() {
                  _selectedCustomerId = selectedId;
                  if (selectedId != null && selectedId != '__new__' && selectedId != '__none__') {
                    final selectedClient = clients.firstWhere(
                      (c) => c.id == selectedId,
                    );
                    _nameCtrl.text = selectedClient.name;
                    _phoneCtrl.text = selectedClient.phone ?? '';
                    controller.setCustomerName(selectedClient.name);
                    controller.setCustomerPhone(selectedClient.phone ?? '');
                  } else {
                    _nameCtrl.clear();
                    _phoneCtrl.clear();
                    controller.setCustomerName('');
                    controller.setCustomerPhone('');
                  }
                });
              },
            ),
          ),
        ),

        // Si un client existant est sélectionné : afficher sa fiche validée
        if (isExistingClientSelected) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 17, color: context.colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _nameCtrl.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (_phoneCtrl.text.isNotEmpty)
                        Text(
                          'Tél : ${_phoneCtrl.text}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCustomerId = '__new__';
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Modifier', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ] else if (_selectedCustomerId == '__new__' || (state.isCredit && !isExistingClientSelected)) ...[
          // Si nouveau client ou crédit requis : afficher les champs texte compacts sur une même ligne
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppFormField(
                  label: state.isCredit ? 'Nom du client *' : 'Nom du client',
                  controller: _nameCtrl,
                  icon: Icons.person_outline,
                  hint: 'Ex : Mamadou Diallo',
                  isRequired: state.isCredit,
                  onChanged: (val) {
                    controller.setCustomerName(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppFormField(
                  label: 'Tél. (WhatsApp)',
                  controller: _phoneCtrl,
                  icon: Icons.phone_outlined,
                  hint: 'Ex : 622 12 34 56',
                  keyboardType: TextInputType.phone,
                  onChanged: controller.setCustomerPhone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 13,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Le client sera automatiquement enregistré pour vos prochaines ventes.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
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
