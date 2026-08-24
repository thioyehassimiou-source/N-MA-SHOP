import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/product_thumbnail.dart';

import '../../../../features/stock/application/stock_providers.dart';
import '../../../../features/stock/domain/entities/product.dart';
import '../data/repositories/drift_order_repository.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class _OrderLine {
  _OrderLine({required this.product});
  final Product product;
  int quantity = 1;
  int get total => product.salePrice * quantity;
}

class NewOrderDialog extends ConsumerStatefulWidget {
  const NewOrderDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NewOrderDialog(),
    );
  }

  @override
  ConsumerState<NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends ConsumerState<NewOrderDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  DeliveryType _deliveryType = DeliveryType.pickup;
  final List<_OrderLine> _lines = [];
  bool _isSaving = false;
  String _productSearch = '';

  int get _total => _lines.fold(0, (s, l) => s + l.total);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addProduct(Product p) {
    setState(() {
      final idx = _lines.indexWhere((l) => l.product.id == p.id);
      if (idx >= 0) {
        _lines[idx].quantity++;
      } else {
        _lines.add(_OrderLine(product: p));
      }
    });
  }

  void _removeLine(int idx) => setState(() => _lines.removeAt(idx));

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du client est obligatoire')),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un produit')),
      );
      return;
    }
    if (_deliveryType == DeliveryType.delivery && _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'adresse de livraison est obligatoire')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(orderRepositoryProvider).insertOrder(
            customerName: name,
            customerPhone: phone.isEmpty ? null : phone,
            deliveryType: _deliveryType,
            deliveryAddress: _deliveryType == DeliveryType.delivery
                ? _addressCtrl.text.trim()
                : null,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            lines: _lines.map((l) => OrderLine(
                  productId: l.product.id,
                  label: l.product.name,
                  unitPrice: l.product.salePrice,
                  quantity: l.quantity,
                )).toList(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande enregistrée ✓'),
            backgroundColor: AppColors.brandEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    final productsAsync = ref.watch(productsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      child: SizedBox(
        width: 900,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // ── Header Gradient ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nouvelle Commande',
                          style: AppTypography.headlineMd.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Créer une commande client',
                          style: AppTypography.bodySm.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── Corps (2 colonnes) ───────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Colonne gauche : Infos client + catalogue ──
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: context.colors.surface,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Section Client ───
                            _OrderSectionCard(
                              title: 'Informations Client',
                              icon: Icons.person_outline,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppFormField(
                                    label: 'Nom du client',
                                    hint: 'Ex: Mamadou Diallo',
                                    controller: _nameCtrl,
                                    icon: Icons.person_outline,
                                    isRequired: true,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppFormField(
                                    label: 'Téléphone',
                                    hint: 'Ex: 621 00 00 00',
                                    controller: _phoneCtrl,
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    'Mode de livraison *',
                                    style: AppTypography.labelMd.copyWith(
                                      color: context.colors.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: SegmentedButton<DeliveryType>(
                                      style: SegmentedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                        ),
                                      ),
                                      segments: const [
                                        ButtonSegment(
                                          value: DeliveryType.pickup,
                                          label: Text('Retrait boutique'),
                                          icon: Icon(Icons.storefront_outlined, size: 16),
                                        ),
                                        ButtonSegment(
                                          value: DeliveryType.delivery,
                                          label: Text('Livraison à domicile'),
                                          icon: Icon(Icons.local_shipping_outlined, size: 16),
                                        ),
                                      ],
                                      selected: {_deliveryType},
                                      onSelectionChanged: (s) => setState(() => _deliveryType = s.first),
                                    ),
                                  ),
                                  if (_deliveryType == DeliveryType.delivery) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    AppFormField(
                                      label: 'Adresse de livraison',
                                      hint: 'Ex: Kaloum, près du marché',
                                      controller: _addressCtrl,
                                      icon: Icons.location_on_outlined,
                                      isRequired: true,
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.md),
                                  AppFormField(
                                    label: 'Note / Instructions',
                                    hint: 'Instructions spéciales...',
                                    controller: _noteCtrl,
                                    icon: Icons.note_outlined,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ─── Section Catalogue ───
                            _OrderSectionCard(
                              title: 'Ajouter des produits',
                              icon: Icons.inventory_2_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _searchCtrl,
                                    onChanged: (v) => setState(() => _productSearch = v.trim().toLowerCase()),
                                    decoration: InputDecoration(
                                      hintText: 'Rechercher un produit…',
                                      prefixIcon: Icon(Icons.search, size: 20, color: context.colors.primary),
                                      filled: true,
                                      fillColor: context.colors.surface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  productsAsync.when(
                                    loading: () => const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    error: (e, _) => Text('Erreur: $e'),
                                    data: (products) {
                                      final visible = products.where((p) =>
                                          p.isActive &&
                                          (_productSearch.isEmpty ||
                                              p.name.toLowerCase().contains(_productSearch))).toList();

                                      if (visible.isEmpty) {
                                        return Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Center(
                                            child: Text(
                                              _productSearch.isEmpty
                                                  ? 'Aucun produit disponible'
                                                  : 'Aucun résultat pour "$_productSearch"',
                                              style: TextStyle(
                                                color: context.colors.onSurfaceVariant,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: visible.take(8).map((p) {
                                          final inCart = _lines.any((l) => l.product.id == p.id);
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            decoration: BoxDecoration(
                                              color: inCart
                                                  ? indigo.withValues(alpha: 0.06)
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                              leading: ProductThumbnail(
                                                imageUrl: p.imageUrl,
                                                size: 36,
                                                borderRadius: 8,
                                                fallbackColor: indigo,
                                              ),
                                              title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                              subtitle: Text(formatGnf(p.salePrice), style: TextStyle(fontSize: 12, color: context.colors.onSurfaceVariant)),
                                              trailing: IconButton(
                                                icon: Icon(
                                                  inCart ? Icons.check_circle : Icons.add_circle_outline,
                                                  color: inCart ? AppColors.brandEmerald : indigo,
                                                ),
                                                onPressed: () => _addProduct(p),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Séparateur vertical
                  Container(
                    width: 1,
                    color: context.colors.outlineVariant,
                  ),

                  // ── Colonne droite : Récapitulatif ─────────────
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: context.colors.surfaceContainerLowest,
                      child: Column(
                        children: [
                          // En-tête récap
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceContainerLowest,
                              border: Border(
                                bottom: BorderSide(color: context.colors.outlineVariant),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shopping_cart_checkout, size: 20, color: indigo),
                                const SizedBox(width: 8),
                                Text('Récapitulatif', style: AppTypography.labelMd),
                                const Spacer(),
                                if (_lines.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: indigo.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_lines.length} article${_lines.length > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        color: indigo,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Liste des produits ajoutés
                          Expanded(
                            child: _lines.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shopping_cart_outlined,
                                          size: 48,
                                          color: context.colors.outlineVariant,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Aucun produit ajouté',
                                          style: TextStyle(
                                            color: context.colors.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Sélectionnez des produits à gauche',
                                          style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _lines.length,
                                    separatorBuilder: (ctx, idx) => Divider(
                                      height: 1,
                                      color: context.colors.outlineVariant,
                                    ),
                                    itemBuilder: (ctx, i) {
                                      final line = _lines[i];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        child: Row(
                                          children: [
                                            ProductThumbnail(
                                              imageUrl: line.product.imageUrl,
                                              size: 40,
                                              borderRadius: 8,
                                              fallbackColor: indigo,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(line.product.name,
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                  Text(formatGnf(line.product.salePrice),
                                                      style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant)),
                                                ],
                                              ),
                                            ),
                                            // Qty controls
                                            Container(
                                              decoration: BoxDecoration(
                                                color: context.colors.surface,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        if (line.quantity > 1) {
                                                          line.quantity--;
                                                        } else {
                                                          _lines.removeAt(i);
                                                        }
                                                      });
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(6),
                                                      child: Icon(Icons.remove, size: 16, color: context.colors.onSurfaceVariant),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                                    child: Text('${line.quantity}',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  ),
                                                  InkWell(
                                                    onTap: () => setState(() => line.quantity++),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(6),
                                                      child: Icon(Icons.add, size: 16, color: indigo),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                formatGnf(line.total),
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, size: 16, color: context.colors.error),
                                              onPressed: () => _removeLine(i),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          // ── Footer Total + bouton ──────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceContainerLowest,
                              border: Border(
                                top: BorderSide(color: context.colors.outlineVariant),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    Text(
                                      formatGnf(_total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        color: indigo,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    // Annuler
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          side: BorderSide(color: context.colors.outline),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: Text(
                                          'Annuler',
                                          style: TextStyle(
                                            color: context.colors.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Enregistrer gradient
                                    Expanded(
                                      flex: 2,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _isSaving ? null : _save,
                                          borderRadius: BorderRadius.circular(14),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: _isSaving
                                                    ? [Colors.grey.shade400, Colors.grey.shade500]
                                                    : const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                              ),
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: _isSaving
                                                  ? null
                                                  : [
                                                      BoxShadow(
                                                        color: indigo.withValues(alpha: 0.35),
                                                        blurRadius: 12,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Center(
                                              child: _isSaving
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Enregistrer la commande',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section de formulaire avec bordure pour le dialog commande.
class _OrderSectionCard extends StatelessWidget {
  const _OrderSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: indigo),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: indigo,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
