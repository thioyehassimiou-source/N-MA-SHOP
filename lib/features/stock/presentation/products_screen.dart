import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format/formatters.dart';
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
import 'package:path_provider/path_provider.dart';
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

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  StockStatus? _statusFilter;
  int _page = 0;
  final _selected = <String>{};

  List<Product> _applyFilter(List<Product> all) {
    if (_statusFilter == null) return all;
    if (_statusFilter == StockStatus.reorder) {
      return all
          .where(
            (p) =>
                _statusOf(p) == StockStatus.reorder ||
                _statusOf(p) == StockStatus.critical,
          )
          .toList();
    }
    return all.where((p) => _statusOf(p) == _statusFilter).toList();
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
                      const SizedBox(height: AppSpacing.lg),
                      _buildFilterBar(filtered.length, start, pageItems.length),
                      const SizedBox(height: AppSpacing.lg),
                      _buildTableCard(pageItems, pageCount, isAdmin),
                      const SizedBox(height: AppSpacing.xl),
                      _buildInsights(all),
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
      gradientColors: const [Color(0xFF0F7B6C), Color(0xFF10B981)],
      actions: [
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
        if (isAdmin) ...[
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            icon: Icons.add,
            label: 'Nouveau Produit',
            onPressed: () => _openDialog(null),
          ),
        ]
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

    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Checkbox(value: false, onChanged: (_) {})),
                const DataColumn(label: Text('NOM')),
                const DataColumn(label: Text('CATÉGORIE')),
                const DataColumn(label: Text('NIVEAU DE STOCK'), numeric: true),
                const DataColumn(label: Text('PRIX (GNF)'), numeric: true),
                const DataColumn(label: Text('STATUT')),
                if (isAdmin) const DataColumn(label: Text('ACTIONS')),
              ],
              rows: items.map((p) {
                final status = _statusOf(p);
                final out = status == StockStatus.out;

                return DataRow(
                  cells: [
                    DataCell(
                      Checkbox(
                        value: _selected.contains(p.id),
                        onChanged: (_) {},
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Opacity(
                            opacity: out ? 0.5 : 1.0,
                            child: ProductThumbnail(
                              imageUrl: p.imageUrl,
                              size: 40,
                              borderRadius: 8,
                              fallbackColor: Colors.indigo,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(p.name, style: AppTypography.labelMd),
                              Text(
                                'Réf: ${p.reference ?? p.id.substring(0, 6)}',
                                style: AppTypography.labelSm.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const DataCell(
                      Text('Générale', style: AppTypography.bodySm),
                    ),
                    DataCell(
                      AppBadge(
                        text: '${formatQuantity(p.stockQuantity)} unités',
                        status: _chipStatusOf(status),
                      ),
                    ),
                    DataCell(
                      Text(
                        formatAmount(p.salePrice),
                        style: AppTypography.labelMd,
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
                              tooltip: 'Imprimer code-barres',
                              onPressed: () => BarcodePrinterService.printProductLabel(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
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

  Widget _buildInsights(List<Product> products) {
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
        final cardWidth = isMobile ? double.infinity : (constraints.maxWidth - AppSpacing.lg) / 2;

        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            SizedBox(
              width: cardWidth,
              child: AppMetricCard(
                title: 'Valeur du Stock (GNF)',
                value: formatAmount(inventoryValue),
                icon: Icons.inventory_2,
                iconColor: context.colors.primary,
                iconBackgroundColor: context.colors.primaryContainer,
                badgeText: '+4.2%',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AppMetricCard(
                title: 'Alertes de Réappro.',
                value: '$restock',
                icon: Icons.notification_important,
                iconColor: context.colors.error,
                iconBackgroundColor: context.colors.errorContainer,
                badgeText: 'À traiter',
              ),
            ),
          ],
        );
      }
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
  String? _imageUrl;
  String? _barcode;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _imageUrl = p?.imageUrl;
    _barcode = p?.barcode;
    _name = TextEditingController(text: p?.name ?? '');
    _reference = TextEditingController(text: p?.reference ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'pièce');
    _purchase = TextEditingController(text: '${p?.purchasePrice ?? 0}');
    _sale = TextEditingController(text: '${p?.salePrice ?? 0}');
    _stock = TextEditingController(text: formatQuantity(p?.stockQuantity ?? 0));
    _threshold = TextEditingController(
      text: formatQuantity(p?.lowStockThreshold ?? 0),
    );
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        // Copier dans le répertoire permanent de l'app
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/product_images');
        if (!imagesDir.existsSync()) {
          imagesDir.createSync(recursive: true);
        }
        final ext = picked.path.split('.').last;
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final permanentFile = await File(picked.path).copy('${imagesDir.path}/$fileName');
        setState(() => _imageUrl = permanentFile.path);
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
      barcode: _barcode?.trim().isEmpty == true ? null : _barcode?.trim(),
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
    final hasImage = _imageUrl != null && File(_imageUrl!).existsSync();

    return AppFormDialog(
      title: _isEdit ? 'Modifier Produit' : 'Ajouter Produit',
      subtitle: _isEdit
          ? 'Mise à jour des informations du produit'
          : 'Nouveau produit dans votre catalogue',
      icon: Icons.inventory_2_outlined,
      gradientColors: const [Color(0xFF0F7B6C), Color(0xFF10B981)],
      width: 520,
      primaryLabel: 'Enregistrer',
      primaryIcon: Icons.check_circle_outline,
      onPrimary: _saving ? null : _save,
      isPrimaryLoading: _saving,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Section Photo ─────────────────────────────────
            _FormSectionContainer(
              title: 'Photo du Produit',
              icon: Icons.camera_alt_outlined,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.outline,
                            width: 2,
                          ),
                        ),
                        child: hasImage
                            ? ClipOval(
                                child: Image.file(
                                  File(_imageUrl!),
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 28,
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Photo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    // Camera overlay badge
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.surfaceContainerLowest,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                    // Remove button
                    if (hasImage)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: InkWell(
                          onTap: () => setState(() => _imageUrl = null),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: context.colors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section Informations ──────────────────────────
            _FormSectionContainer(
              title: 'Informations Produit',
              icon: Icons.info_outline,
              child: Column(
                children: [
                  AppFormField(
                    label: 'Nom du produit',
                    hint: 'Ex: Riz Uncle Ben\'s 5kg',
                    controller: _name,
                    icon: Icons.label_outline,
                    isRequired: true,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormFieldRow(
                    left: AppFormField(
                      label: 'Référence',
                      hint: 'Auto-généré si vide',
                      controller: _reference,
                      icon: Icons.qr_code_outlined,
                    ),
                    right: AppFormField(
                      label: 'Unité',
                      hint: 'Ex: pièce, kg, litre',
                      controller: _unit,
                      icon: Icons.straighten_outlined,
                      isRequired: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section Prix ──────────────────────────────────
            _FormSectionContainer(
              title: 'Prix & Tarification',
              icon: Icons.payments_outlined,
              child: FormFieldRow(
                left: AppFormField(
                  label: 'Prix d\'achat (GNF)',
                  hint: 'Ex: 50 000',
                  controller: _purchase,
                  icon: Icons.shopping_cart_outlined,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  iconColor: const Color(0xFFF59E0B),
                ),
                right: AppFormField(
                  label: 'Prix de vente (GNF)',
                  hint: 'Ex: 75 000',
                  controller: _sale,
                  icon: Icons.sell_outlined,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  iconColor: const Color(0xFF10B981),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section Stock ─────────────────────────────────
            _FormSectionContainer(
              title: 'Niveaux de Stock',
              icon: Icons.inventory_outlined,
              child: FormFieldRow(
                left: AppFormField(
                  label: 'Stock initial',
                  hint: 'Ex: 100',
                  controller: _stock,
                  icon: Icons.archive_outlined,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                ),
                right: AppFormField(
                  label: 'Seuil d\'alerte',
                  hint: 'Ex: 10',
                  controller: _threshold,
                  icon: Icons.warning_amber_outlined,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  iconColor: const Color(0xFFEF4444),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section Code-barres ────────────────────────────
            _FormSectionContainer(
              title: 'Code-barres (Scan POS)',
              icon: Icons.qr_code_2_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _barcode,
                      decoration: InputDecoration(
                        hintText: 'Ex: 6141234567890',
                        prefixIcon: Icon(Icons.barcode_reader, size: 20, color: context.colors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onChanged: (v) => _barcode = v.isEmpty ? null : v,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Tooltip(
                    message: 'Scanner via caméra',
                    child: FilledButton.icon(
                      onPressed: () async {
                        final code = await BarcodeScannerDialog.show(context);
                        if (code != null && mounted) setState(() => _barcode = code);
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Scanner'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              Icon(icon, size: 20, color: context.colors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: context.colors.onSurface,
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
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
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
                    color: Color(0xFFB91C1C),
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
                        color: isOut ? const Color(0xFFEF4444) : const Color(0xFFF97316),
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
            icon: const Icon(Icons.close, size: 18, color: Color(0xFFEF4444)),
            onPressed: () => setState(() => _dismissed = true),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

