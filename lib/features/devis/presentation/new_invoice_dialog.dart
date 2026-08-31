import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';


import '../../../core/format/formatters.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/services/pdf_receipt_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../stock/application/stock_providers.dart';
import '../../stock/domain/entities/product.dart';

import 'package:nmashop/core/theme/app_theme.dart';

// ─── Ligne de facture (draft) ─────────────────────────────────────────────────
class _InvoiceLine {
  _InvoiceLine({required this.product});
  final Product product;
  int quantity = 1;
  int get total => product.salePrice * quantity;
}

// ─── Dialog principal ─────────────────────────────────────────────────────────
class NewInvoiceDialog extends ConsumerStatefulWidget {
  const NewInvoiceDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NewInvoiceDialog(),
    );
  }

  @override
  ConsumerState<NewInvoiceDialog> createState() => _NewInvoiceDialogState();
}

class _NewInvoiceDialogState extends ConsumerState<NewInvoiceDialog> {
  final _customerController = TextEditingController();
  final _searchController = TextEditingController();
  final _lines = <_InvoiceLine>[];
  String _query = '';

  @override
  void dispose() {
    _customerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _total => _lines.fold(0, (s, l) => s + l.total);

  void _addProduct(Product p) {
    setState(() {
      final idx = _lines.indexWhere((l) => l.product.id == p.id);
      if (idx >= 0) {
        _lines[idx].quantity++;
      } else {
        _lines.add(_InvoiceLine(product: p));
      }
    });
  }

  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  void _changeQty(int i, int delta) {
    setState(() {
      _lines[i].quantity = (_lines[i].quantity + delta).clamp(1, 9999);
    });
  }

  Future<void> _generatePdf() async {
    final settings = ref.read(appSettingsProvider);
    final customerName = _customerController.text.trim();
    final now = DateTime.now();
    final ref_ = 'FAC-${now.millisecondsSinceEpoch.toString().substring(6)}';

    final receiptData = ReceiptData(
      reference: ref_,
      date: now,
      businessName: settings.businessName,
      businessPhone: settings.businessPhone,
      businessAddress: settings.businessAddress,
      businessNif: settings.businessNif,
      lines: _lines.map((l) => ReceiptLineItem(
        name: l.product.name,
        unit: l.product.unit,
        quantity: l.quantity,
        unitPrice: l.product.salePrice,
        lineTotal: l.total,
      )).toList(),
      total: _total,
      amountPaid: 0,
      creditAmount: _total,
      paymentMethodLabel: 'Proforma',
      customerName: customerName.isNotEmpty ? customerName : null,
    );

    await Printing.layoutPdf(
      name: 'Facture_$ref_',
      onLayout: (_) => PdfReceiptService.generateReceiptPdf(receiptData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 860,
        height: 620,
        child: Column(
          children: [
            // ── En-tête ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('Nouvelle Facture / Devis',
                      style: AppTypography.labelMd.copyWith(color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Corps ────────────────────────────────────────────────
            Expanded(
              child: Row(
                children: [
                  // ── Sélecteur de produits (gauche) ──
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Rechercher un produit…',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
                          ),
                        ),
                        Expanded(
                          child: productsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Erreur: $e')),
                            data: (products) {
                              final visible = products.where((p) =>
                                  p.isActive &&
                                  (_query.isEmpty || p.name.toLowerCase().contains(_query))).toList();
                              if (visible.isEmpty) {
                                return Center(
                                  child: Text('Aucun produit', style: TextStyle(color: context.colors.onSurfaceVariant)),
                                );
                              }
                              return ListView.builder(
                                itemCount: visible.length,
                                itemBuilder: (_, i) {
                                  final p = visible[i];
                                  return ListTile(
                                    dense: true,
                                    leading: ProductThumbnail(
                                      imageUrl: p.imageUrl,
                                      size: 36,
                                      borderRadius: 8,
                                      fallbackColor: context.colors.primary,
                                    ),
                                    title: Text(p.name, style: AppTypography.labelSm),
                                    subtitle: Text(formatGnf(p.salePrice),
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
                                    trailing: IconButton(
                                      icon: Icon(Icons.add_circle_outline,
                                          color: context.colors.primary, size: 20),
                                      onPressed: () => _addProduct(p),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const VerticalDivider(width: 1),

                  // ── Facture (droite) ──────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        // Champ client
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: TextField(
                            controller: _customerController,
                            decoration: const InputDecoration(
                              labelText: 'Nom du client *',
                              prefixIcon: Icon(Icons.person_outline, size: 18),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        // En-tête du tableau
                        Container(
                          color: context.colors.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 4, child: Text('Article', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                              Expanded(flex: 2, child: Text('P.U.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                              Expanded(flex: 2, child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                              Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant))),
                              SizedBox(width: 32),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Lignes
                        Expanded(
                          child: _lines.isEmpty
                              ? Center(
                                  child: Text('Ajoutez des produits depuis la liste',
                                      style: TextStyle(color: context.colors.onSurfaceVariant)),
                                )
                              : ListView.separated(
                                  itemCount: _lines.length,
                                  separatorBuilder: (_, i) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final l = _lines[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(l.product.name,
                                                style: AppTypography.labelSm,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(formatGnf(l.product.salePrice),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 12)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                InkWell(
                                                  onTap: () => _changeQty(i, -1),
                                                  child: Icon(Icons.remove_circle_outline, size: 18, color: context.colors.onSurfaceVariant),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  child: Text('${l.quantity}', style: AppTypography.labelSm),
                                                ),
                                                InkWell(
                                                  onTap: () => _changeQty(i, 1),
                                                  child: Icon(Icons.add_circle_outline, size: 18, color: context.colors.primary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(formatGnf(l.total),
                                                textAlign: TextAlign.right,
                                                style: AppTypography.labelSm.copyWith(
                                                    color: theme.colorScheme.primary,
                                                    fontWeight: FontWeight.w700)),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 18, color: context.colors.error),
                                            onPressed: () => _removeLine(i),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // ── Pied : Total + Actions ──
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TOTAL', style: TextStyle(fontSize: 11, color: context.colors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                                  Text(formatGnf(_total),
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: theme.colorScheme.primary)),
                                ],
                              ),
                              const Spacer(),
                              AppButton.secondary(
                                label: 'Annuler',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 10),
                              AppButton(
                                icon: Icons.print_outlined,
                                label: 'Générer PDF',
                                onPressed: _lines.isEmpty ? null : _generatePdf,
                              ),
                            ],
                          ),
                        ),
                      ],
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
