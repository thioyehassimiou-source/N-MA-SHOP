import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/business_domain_config.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../../core/widgets/app_metric_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/utils/app_image_picker.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/barcode_scanner_dialog.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../auth/application/auth_providers.dart';
import '../application/stock_providers.dart';
import '../domain/entities/product.dart';
import '../domain/entities/product_draft.dart';
import '../domain/usecases/save_product_result.dart';
import '../../../core/database/tables/users.dart';
import '../../../core/services/barcode_printer_service.dart';

enum StockStatus { inStock, reorder, critical, out }

StockStatus _statusOf(Product p) {
  if (p.stockQuantity <= 0) return StockStatus.out;
  final t = p.lowStockThreshold;
  if (t > 0 && p.stockQuantity <= t * 0.5) return StockStatus.critical;
  if (t > 0 && p.stockQuantity <= t) return StockStatus.reorder;
  return StockStatus.inStock;
}

AppChipStatus _chipStatusOf(StockStatus status) {
  switch (status) {
    case StockStatus.critical:
      return AppChipStatus.error;
    case StockStatus.reorder:
      return AppChipStatus.warning;
    case StockStatus.inStock:
      return AppChipStatus.success;
    case StockStatus.out:
      return AppChipStatus.neutral;
  }
}

String _statusLabelOf(StockStatus status) {
  switch (status) {
    case StockStatus.critical:
      return 'Stock Critique';
    case StockStatus.reorder:
      return 'À Recommander';
    case StockStatus.inStock:
      return 'En Stock';
    case StockStatus.out:
      return 'Rupture';
  }
}

Future<void> _showPrintLabelsDialog(BuildContext context, Product product) async {
  int copies = 1;
  final code = (product.barcode?.trim().isNotEmpty == true)
      ? product.barcode!.trim()
      : (product.reference?.trim().isNotEmpty == true
          ? product.reference!.trim()
          : product.id.substring(0, 8).toUpperCase());

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.print_outlined, color: AppColors.brandOrange),
            const SizedBox(width: 10),
            const Text('Imprimer étiquettes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Code: $code  •  Prix: ${formatAmount(product.salePrice)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              const Text('Nombre d\'exemplaires :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.remove),
                    onPressed: copies > 1 ? () => setDialogState(() => copies--) : null,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: TextFormField(
                      key: ValueKey(copies),
                      initialValue: '$copies',
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val.trim());
                        if (parsed != null && parsed > 0) {
                          copies = parsed;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    icon: const Icon(Icons.add),
                    onPressed: () => setDialogState(() => copies++),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Aligner tous les chiffres sur une seule et même ligne
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [1, 5, 10, 20, 50].map((preset) {
                  final isSelected = copies == preset;
                  return InkWell(
                    onTap: () => setDialogState(() => copies = preset),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandOrange
                            : Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.brandOrange
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        '$preset',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
            icon: const Icon(Icons.print, size: 18),
            label: Text('Imprimer ($copies)'),
            onPressed: () {
              Navigator.of(ctx).pop();
              BarcodePrinterService.printProductLabel(product, copies: copies);
            },
          ),
        ],
      ),
    ),
  );
}

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  StockStatus? _statusFilter;
  int _page = 0;
  final _selected = <String>{};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applyFilter(List<Product> all) {
    var filtered = all;

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((p) {
        final matchName = p.name.toLowerCase().contains(q);
        final matchRef = p.reference != null && p.reference!.toLowerCase().contains(q);
        final matchBarcode = p.barcode != null && p.barcode!.toLowerCase().contains(q);
        return matchName || matchRef || matchBarcode;
      }).toList();
    }

    if (_statusFilter == null) return filtered;
    if (_statusFilter == StockStatus.reorder) {
      return filtered
          .where(
            (p) =>
                _statusOf(p) == StockStatus.reorder ||
                _statusOf(p) == StockStatus.critical,
          )
          .toList();
    }
    return filtered.where((p) => _statusOf(p) == _statusFilter).toList();
  }

  void _openDialog(Product? product) {
    showDialog<void>(
      context: context,
      builder: (_) => _ProductDialog(product: product),
    );
  }

  Future<void> _exportCsv(List<Product> products) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Nom;Référence;Unité;Prix Achat (GNF);Prix Vente (GNF);Stock;Seuil Alerte');
      for (final p in products) {
        buffer.writeln(
          '"${p.name.replaceAll('"', '""')}";'
          '"${(p.reference ?? '').replaceAll('"', '""')}";'
          '"${p.unit.replaceAll('"', '""')}";'
          '${p.purchasePrice};'
          '${p.salePrice};'
          '${p.stockQuantity};'
          '${p.lowStockThreshold}'
        );
      }

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer le catalogue produits (CSV)',
        fileName: 'catalogue_produits_${DateTime.now().millisecondsSinceEpoch}.csv',
        bytes: bytes,
        mimeType: 'text/csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (savedUri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catalogue exporté avec succès !'),
            backgroundColor: AppColors.brandEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'exportation : $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  Future<void> _importCsv() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final content = await file.readAsString(encoding: utf8);
        final lines = LineSplitter.split(content).toList();

        if (lines.isEmpty) return;

        int importedCount = 0;
        final startIdx = lines.first.toLowerCase().contains('nom') ? 1 : 0;

        for (int i = startIdx; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          final parts = line.split(RegExp(r'[;,]')).map((s) => s.trim().replaceAll('"', '')).toList();
          if (parts.isEmpty || parts[0].isEmpty) continue;

          final name = parts[0];
          final reference = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
          final unit = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : 'pièce';
          final purchasePrice = parts.length > 3 ? (int.tryParse(parts[3]) ?? 0) : 0;
          final salePrice = parts.length > 4 ? (int.tryParse(parts[4]) ?? 0) : 0;
          final stockQuantity = parts.length > 5 ? (int.tryParse(parts[5]) ?? 0) : 0;
          final lowStockThreshold = parts.length > 6 ? (int.tryParse(parts[6]) ?? 0) : 0;

          final draft = ProductDraft(
            name: name,
            reference: reference,
            unit: unit,
            purchasePrice: purchasePrice,
            salePrice: salePrice,
            stockQuantity: stockQuantity,
            lowStockThreshold: lowStockThreshold,
          );

          await ref.read(addProductUseCaseProvider).call(draft);
          importedCount++;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$importedCount produits importés avec succès !'),
              backgroundColor: AppColors.brandEmerald,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'importation : $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == UserRole.admin;

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (all) {
        final filtered = _applyFilter(all);
        final pageCount = (filtered.length / 10).ceil().clamp(1, 9999);
        if (_page >= pageCount) _page = pageCount - 1;
        final start = _page * 10;
        final pageItems = filtered
            .skip(start)
            .take(10)
            .toList(growable: false);

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.containerMax,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(all, isAdmin),
                      // ── Bandeau Alerte Stock Bas ─────────────
                      _LowStockAlertBanner(products: all),
                      const SizedBox(height: AppSpacing.md),
                      // ── Statistiques du Stock (En haut du tableau) ───
                      _buildInsights(all, isAdmin),
                      const SizedBox(height: AppSpacing.lg),
                      _buildFilterBar(filtered.length, start, pageItems.length),
                      const SizedBox(height: AppSpacing.lg),
                      _buildTableCard(pageItems, pageCount, isAdmin),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(List<Product> allProducts, bool isAdmin) {
    return AppPageHeader(
      title: 'Inventaire Produits',
      subtitle: 'Catalogue & niveaux de stock — ${allProducts.length} articles actifs',
      icon: Icons.inventory_2_outlined,
      gradientColors: const [AppColors.brandNavy, AppColors.brandNavyLight],
      actions: [
        if (isAdmin) ...[
          AppButton.secondary(
            icon: Icons.file_upload_outlined,
            label: 'Importer',
            onPressed: _importCsv,
          ),
          const SizedBox(width: AppSpacing.xs),
          AppButton.secondary(
            icon: Icons.file_download_outlined,
            label: 'Exporter',
            onPressed: () => _exportCsv(allProducts),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            icon: Icons.add,
            label: 'Nouveau Produit',
            onPressed: () => _openDialog(null),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterBar(int total, int start, int length) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 270,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher nom, réf, code-barres...',
                hintStyle: AppTypography.bodySm.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _page = 0;
                          });
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        tooltip: 'Scanner un code-barres',
                        onPressed: () async {
                          final code = await BarcodeScannerDialog.show(context);
                          if (code != null && mounted) {
                            _searchController.text = code;
                            setState(() {
                              _searchQuery = code;
                              _page = 0;
                            });
                          }
                        },
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: context.colors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: context.colors.outlineVariant),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _page = 0;
                });
              },
            ),
          ),
          Text(
            'FILTRES :',
            style: AppTypography.labelSm.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          _buildDropdown<String>('Toutes Catégories', ['Toutes Catégories']),
          _buildDropdown<StockStatus?>(_statusFilter, [
            null,
            StockStatus.inStock,
            StockStatus.reorder,
            StockStatus.out,
          ], (s) => s == null ? 'Tous les Statuts' : _statusLabelOf(s)),
          Container(
            width: 1,
            height: 32,
            color: context.colors.outlineVariant,
          ),
          Text(
            'Affichage de ${length == 0 ? 0 : start + 1}-${start + length} sur $total',
            style: AppTypography.labelSm.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    T value,
    List<T> items, [
    String Function(T)? labelOf,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: context.colors.onSurface,
          ),
          style: AppTypography.bodySm.copyWith(color: context.colors.onSurface),
          items: items
              .map(
                (it) => DropdownMenuItem(
                  value: it,
                  child: Text(labelOf != null ? labelOf(it) : '$it'),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v is StockStatus? && labelOf != null) {
              setState(() {
                _statusFilter = v;
                _page = 0;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildTableCard(List<Product> items, int pageCount, bool isAdmin) {
    if (items.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(64),
        child: const Center(child: Text('Aucun produit trouvé.')),
      );
    }

    final allSelected = items.isNotEmpty && items.every((p) => _selected.contains(p.id));
    final someSelected = items.any((p) => _selected.contains(p.id)) && !allSelected;

    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Barre de sélection groupée ────────────────────────
          if (_selected.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.25),
                border: Border(
                  bottom: BorderSide(color: context.colors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${_selected.length} produit(s) sélectionné(s)',
                    style: AppTypography.labelMd.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _selected.clear()),
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Tout désélectionner'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          // ── Tableau des produits plein écran & centré équilibré ──
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    columnSpacing: 28,
                    horizontalMargin: 20,
                    headingRowHeight: 46,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 56,
                    headingRowColor: WidgetStateProperty.all(
                      context.colors.surfaceContainerHighest.withValues(alpha: 0.35),
                    ),
                    headingTextStyle: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                    columns: [
                      DataColumn(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: allSelected ? true : (someSelected ? null : false),
                              tristate: true,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selected.addAll(items.map((p) => p.id));
                                  } else {
                                    for (final p in items) {
                                      _selected.remove(p.id);
                                    }
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('SÉLECTION'),
                          ],
                        ),
                      ),
                      const DataColumn(label: Text('PHOTO')),
                      const DataColumn(label: Text("NOM DE L'ARTICLE")),
                      const DataColumn(label: Text('UNITÉ')),
                      const DataColumn(label: Text("PRIX D'ACHAT")),
                      const DataColumn(label: Text('PRIX DE VENTE')),
                      const DataColumn(label: Text('STOCK EN BOUTIQUE')),
                      const DataColumn(label: Text('STATUT')),
                      if (isAdmin) const DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: items.map((p) {
                      final status = _statusOf(p);
                      final out = status == StockStatus.out;
                      final isChecked = _selected.contains(p.id);

                      return DataRow(
                        selected: isChecked,
                        onSelectChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selected.add(p.id);
                            } else {
                              _selected.remove(p.id);
                            }
                          });
                        },
                        cells: [
                          DataCell(
                            Checkbox(
                              value: isChecked,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selected.add(p.id);
                                  } else {
                                    _selected.remove(p.id);
                                  }
                                });
                              },
                            ),
                          ),
                          DataCell(
                            Opacity(
                              opacity: out ? 0.5 : 1.0,
                              child: ProductThumbnail(
                                imageUrl: p.imageUrl,
                                size: 36,
                                borderRadius: 8,
                                fallbackColor: AppColors.brandNavy,
                                enableZoomOnTap: true,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              p.name,
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.brandOrange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.brandOrange.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                p.unit.isNotEmpty ? p.unit : 'pièce',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.brandOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${formatAmount(p.purchasePrice)} GNF',
                              style: AppTypography.bodySm.copyWith(
                                color: context.colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${formatAmount(p.salePrice)} GNF',
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DataCell(
                            AppBadge(
                              text: '${formatQuantity(p.stockQuantity)} ${p.unit.isNotEmpty ? p.unit : 'unités'}',
                              status: _chipStatusOf(status),
                            ),
                          ),
                          DataCell(
                            AppChip(
                              label: _statusLabelOf(status),
                              status: _chipStatusOf(status),
                            ),
                          ),
                          if (isAdmin)
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.print_outlined, size: 20),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    tooltip: 'Imprimer étiquettes code-barres',
                                    onPressed: () => _showPrintLabelsDialog(context, p),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    tooltip: 'Modifier',
                                    onPressed: () => _openDialog(p),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: context.colors.outlineVariant),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppButton.secondary(
                  icon: Icons.chevron_left,
                  label: 'Précédent',
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                ),
                Text(
                  'Page ${_page + 1} sur $pageCount',
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                AppButton.secondary(
                  icon: Icons.chevron_right,
                  label: 'Suivant',
                  onPressed: _page < pageCount - 1
                      ? () => setState(() => _page++)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights(List<Product> products, bool isAdmin) {
    final inventoryValue = products.fold<int>(0, (sum, p) {
      final cost = p.weightedAverageCost > 0
          ? p.weightedAverageCost
          : p.purchasePrice.toDouble();
      return sum + (cost * p.stockQuantity).round();
    });
    final restock = products
        .where((p) => p.isActive && _statusOf(p) != StockStatus.inStock)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardWidth = isMobile || !isAdmin
            ? double.infinity
            : (constraints.maxWidth - AppSpacing.lg) / 2;

        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            if (isAdmin)
              SizedBox(
                width: cardWidth,
                child: AppMetricCard(
                  title: 'Valeur marchande du stock',
                  value: '${formatAmount(inventoryValue)} GNF',
                  icon: Icons.inventory_2,
                  iconColor: context.colors.primary,
                  iconBackgroundColor: context.colors.primaryContainer,
                  badgeText: '${products.length} référence(s)',
                ),
              ),
            SizedBox(
              width: cardWidth,
              child: AppMetricCard(
                title: 'Stock faible (À commander)',
                value: '$restock',
                icon: Icons.notification_important,
                iconColor: context.colors.error,
                iconBackgroundColor: context.colors.errorContainer,
                badgeText: restock == 0 ? 'Stock optimal' : '$restock produit(s)',
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────── Dialogue ajout / édition ───────────────────────────
class _ProductDialog extends ConsumerStatefulWidget {
  const _ProductDialog({this.product});
  final Product? product;

  @override
  ConsumerState<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _reference;
  late final TextEditingController _unit;
  late final TextEditingController _purchase;
  late final TextEditingController _sale;
  late final TextEditingController _stock;
  late final TextEditingController _threshold;
  late final TextEditingController _barcode;
  String? _imageUrl;
  bool _saving = false;

  bool get _isEdit => widget.product != null;
  bool _customUnitMode = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final domain = ref.read(appSettingsProvider).businessDomain;
    final domainConfig = BusinessDomainConfig.forDomain(domain);
    _imageUrl = p?.imageUrl;
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _reference = TextEditingController(text: p?.reference ?? '');
    _unit = TextEditingController(text: p?.unit ?? domainConfig.defaultUnit);
    _purchase = TextEditingController(text: '${p?.purchasePrice ?? 0}');
    _sale = TextEditingController(text: '${p?.salePrice ?? 0}');
    _stock = TextEditingController(text: formatQuantity(p?.stockQuantity ?? 0));
    _threshold = TextEditingController(
      text: formatQuantity(p?.lowStockThreshold ?? 0),
    );
    final standardUnits = domainConfig.allOrderedUnits;
    if (p != null && !standardUnits.contains(p.unit) && p.unit.isNotEmpty) {
      _customUnitMode = true;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _reference,
      _unit,
      _purchase,
      _sale,
      _stock,
      _threshold,
      _barcode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _generateEan13() {
    final random = Random();
    // Préfixe standard interne 200 + 9 chiffres aléatoires = 12 chiffres
    final base12 = '200${List.generate(9, (_) => random.nextInt(10)).join()}';
    // Calcul de la clé de contrôle EAN-13 (modulo 10)
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(base12[i]);
      sum += (i % 2 == 0) ? digit : (digit * 3);
    }
    final checksum = (10 - (sum % 10)) % 10;
    final ean13 = '$base12$checksum';
    setState(() {
      _barcode.text = ean13;
    });
  }

  Future<void> _pickImage() async {
    try {
      final savedPath = await AppImagePicker.pickProductImage();
      if (savedPath != null && mounted) {
        setState(() => _imageUrl = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sélection image: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final draft = ProductDraft(
      name: _name.text.trim(),
      reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      unit: _unit.text.trim().isEmpty ? 'pièce' : _unit.text.trim(),
      purchasePrice: int.tryParse(_purchase.text.trim()) ?? 0,
      salePrice: int.tryParse(_sale.text.trim()) ?? 0,
      stockQuantity: int.tryParse(_stock.text.trim()) ?? 0,
      lowStockThreshold: int.tryParse(_threshold.text.trim()) ?? 0,
      imageUrl: _imageUrl,
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
    );

    final result = _isEdit
        ? await ref
              .read(updateProductUseCaseProvider)
              .call(widget.product!.id, draft)
        : await ref.read(addProductUseCaseProvider).call(draft);

    if (!mounted) return;
    switch (result) {
      case SaveProductSuccess():
        Navigator.of(context).pop();
      case SaveProductFailure(:final error):
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text(error.message),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    final businessDomain = ref.watch(appSettingsProvider.select((s) => s.businessDomain));
    final domainConfig = BusinessDomainConfig.forDomain(businessDomain);
    final orderedUnits = domainConfig.allOrderedUnits;

    return AppFormDialog(
      title: _isEdit ? 'Modifier Produit' : 'Ajouter Produit',
      subtitle: _isEdit
          ? 'Mise à jour des informations de l\'article'
          : 'Enregistrement direct d\'un produit dans votre stock',
      icon: Icons.inventory_2_outlined,
      gradientColors: const [AppColors.brandNavy, AppColors.brandNavyLight],
      width: 860,
      primaryLabel: 'Enregistrer',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: _saving ? null : _save,
      isPrimaryLoading: _saving,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Rangée 1 : Identité & Prix (même hauteur & largeur) ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Carte 1 : Identité du Produit
                  Expanded(
                    child: _FormSectionContainer(
                      title: 'Identité du Produit',
                      icon: Icons.inventory_2_outlined,
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sélecteur Photo compact
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Photo',
                                    style: AppTypography.labelSm.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: _pickImage,
                                    borderRadius: BorderRadius.circular(40),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: context.colors.surfaceContainer,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: context.colors.outline,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: hasImage
                                              ? ClipOval(
                                                  child: AppImage(
                                                    imagePath: _imageUrl,
                                                    fit: BoxFit.cover,
                                                    width: 60,
                                                    height: 60,
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.add_a_photo_outlined,
                                                  size: 22,
                                                  color: context.colors.primary,
                                                ),
                                        ),
                                        Positioned(
                                          bottom: -2,
                                          right: -2,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: context.colors.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: context.colors.surfaceContainerLowest,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 11,
                                            ),
                                          ),
                                        ),
                                        if (hasImage)
                                          Positioned(
                                            top: -4,
                                            right: -4,
                                            child: InkWell(
                                              onTap: () => setState(() => _imageUrl = null),
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: context.colors.error,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Nom de l'article
                              Expanded(
                                child: AppFormField(
                                  label: 'Nom de l\'article',
                                  hint: domainConfig.productNameHint,
                                  controller: _name,
                                  icon: Icons.label_outline,
                                  isRequired: true,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FormFieldRow(
                            left: AppFormField(
                              label: 'Référence',
                              hint: domainConfig.referenceHint,
                              controller: _reference,
                              icon: Icons.qr_code_outlined,
                            ),
                            right: _customUnitMode
                                ? AppFormField(
                                    label: 'Unité personnalisée',
                                    hint: 'Ex: carton 12x1L',
                                    controller: _unit,
                                    icon: Icons.edit_outlined,
                                    isRequired: true,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.list, size: 18),
                                      tooltip: 'Choisir parmi la liste',
                                      onPressed: () => setState(() {
                                        _customUnitMode = false;
                                        _unit.text = domainConfig.defaultUnit;
                                      }),
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Unité *',
                                            style: AppTypography.labelSm.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: context.colors.onSurface,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => setState(
                                              () => _customUnitMode = true,
                                            ),
                                            child: Text(
                                              '+ Autre unité',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: context.colors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        initialValue: orderedUnits.contains(_unit.text)
                                            ? _unit.text
                                            : orderedUnits.first,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          prefixIcon: const Icon(
                                            Icons.straighten_outlined,
                                            size: 18,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 11,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.lg,
                                            ),
                                            borderSide: BorderSide(
                                              color: context.colors.outlineVariant,
                                            ),
                                          ),
                                        ),
                                        items: orderedUnits
                                            .map(
                                              (u) => DropdownMenuItem(
                                                value: u,
                                                child: Text(
                                                  u,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _unit.text = val);
                                          }
                                        },
                                      ),
                                      if (domainConfig.primaryUnits.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: domainConfig.primaryUnits.take(4).map((u) {
                                            final isSelected = _unit.text.trim().toLowerCase() == u.toLowerCase();
                                            return InkWell(
                                              onTap: () => setState(() {
                                                _customUnitMode = false;
                                                _unit.text = u;
                                              }),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? context.colors.primary.withValues(alpha: 0.15)
                                                      : context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: isSelected ? context.colors.primary : Colors.transparent,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  u,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                    color: isSelected ? context.colors.primary : context.colors.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Carte 2 : Prix & Bénéfice
                  Expanded(
                    child: _FormSectionContainer(
                      title: 'Prix & Rentabilité (Gain)',
                      icon: Icons.payments_outlined,
                      child: Column(
                        children: [
                          FormFieldRow(
                            left: AppFormField(
                              label: 'Prix d\'achat (GNF)',
                              hint: 'Ex: 50 000',
                              controller: _purchase,
                              icon: Icons.shopping_cart_outlined,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                              iconColor: AppColors.warning,
                              onChanged: (_) => setState(() {}),
                            ),
                            right: AppFormField(
                              label: 'Prix de vente (GNF)',
                              hint: 'Ex: 75 000',
                              controller: _sale,
                              icon: Icons.sell_outlined,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                              iconColor: AppColors.brandEmerald,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final buy =
                                  int.tryParse(_purchase.text.trim()) ?? 0;
                              final sell =
                                  int.tryParse(_sale.text.trim()) ?? 0;
                              final margin = sell - buy;
                              final isPositive = margin >= 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: (isPositive
                                          ? AppColors.brandEmerald
                                          : context.colors.error)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (isPositive
                                            ? AppColors.brandEmerald
                                            : context.colors.error)
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isPositive
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 16,
                                      color: isPositive
                                          ? AppColors.brandEmerald
                                          : context.colors.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Bénéfice estimé / unité : ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${isPositive ? '+' : ''}${formatAmount(margin)} GNF',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isPositive
                                            ? AppColors.brandEmerald
                                            : context.colors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Rangée 2 : Code-barres & Stock (même hauteur & largeur) ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Carte 3 : Code-barres & Scan
                  Expanded(
                    child: _FormSectionContainer(
                      title: 'Code-barres (Scan & Caisse)',
                      icon: Icons.qr_code_2_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppFormField(
                            label: 'Code-barres',
                            hint: 'Ex: 6141234567890 (ou générer)',
                            controller: _barcode,
                            icon: Icons.barcode_reader,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _generateEan13,
                                  icon: const Icon(Icons.auto_awesome, size: 15),
                                  label: const Text('Générer'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    final code = await BarcodeScannerDialog.show(context);
                                    if (code != null && mounted) {
                                      setState(() => _barcode.text = code);
                                    }
                                  },
                                  icon: const Icon(Icons.qr_code_scanner, size: 15),
                                  label: const Text('Scanner'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brandOrange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isEdit && widget.product != null) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _showPrintLabelsDialog(context, widget.product!),
                                icon: const Icon(Icons.print_outlined, size: 15),
                                label: const Text('Imprimer étiquettes'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Carte 4 : Gestion du Stock & Alertes
                  Expanded(
                    child: _FormSectionContainer(
                      title: 'Gestion du Stock & Alertes',
                      icon: Icons.inventory_outlined,
                      child: Column(
                        children: [
                          FormFieldRow(
                            left: AppFormField(
                              label: 'Stock en boutique',
                              hint: 'Ex: 100',
                              controller: _stock,
                              icon: Icons.archive_outlined,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                            ),
                            right: AppFormField(
                              label: 'Alerte stock faible',
                              hint: 'Ex: 10',
                              controller: _threshold,
                              icon: Icons.warning_amber_outlined,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                              iconColor: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.colors.primary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.notifications_active_outlined,
                                  size: 15,
                                  color: context.colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Alerte automatique dès que le stock passe sous ce seuil.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.onSurfaceVariant,
                                    ),
                                  ),
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

/// Section de formulaire avec bordure et titre icône (utilisé localement).
class _FormSectionContainer extends StatelessWidget {
  const _FormSectionContainer({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        border: Border.all(color: context.colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 16, color: context.colors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: context.colors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Bandeau Alerte Stock Bas ───────────────────────────────────────────────
class _LowStockAlertBanner extends StatefulWidget {
  const _LowStockAlertBanner({required this.products});
  final List<Product> products;

  @override
  State<_LowStockAlertBanner> createState() => _LowStockAlertBannerState();
}

class _LowStockAlertBannerState extends State<_LowStockAlertBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final alerts = widget.products
        .where(
          (p) => p.isActive && p.lowStockThreshold > 0 && p.stockQuantity <= p.lowStockThreshold,
        )
        .toList();

    if (alerts.isEmpty || _dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alerts.length} produit(s) en alerte de stock bas',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: alerts.map((p) {
                    final isOut = p.stockQuantity <= 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOut ? AppColors.error : AppColors.warning,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${p.name} (${formatQuantity(p.stockQuantity)} restant)',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.error),
            onPressed: () => setState(() => _dismissed = true),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

