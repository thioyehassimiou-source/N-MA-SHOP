import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

final stockFilterProvider = StateProvider<String>((ref) => 'all'); // 'all', 'low', 'out'
final stockSearchProvider = StateProvider<String>((ref) => '');

final stockDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);

  // Charger les produits depuis la base SQLite locale (MobileDatabase)
  List<MobileProduct> products = await db.select(db.mobileProducts).get();

  // Si la base est totalement vide au premier démarrage, insérer 2 échantillons par défaut
  if (products.isEmpty) {
    final sample1 = MobileProductsCompanion.insert(
      id: 'prod-${DateTime.now().millisecondsSinceEpoch}-1',
      name: 'Jus de Mangue 1L',
      barcode: const drift.Value('61510001002'),
      unit: const drift.Value('pièce'),
      purchasePrice: const drift.Value(15000),
      salePrice: const drift.Value(20000),
      stockQuantity: const drift.Value(20),
      lowStockThreshold: const drift.Value(5),
    );
    final sample2 = MobileProductsCompanion.insert(
      id: 'prod-${DateTime.now().millisecondsSinceEpoch}-2',
      name: 'Sac de Riz Parfumé 25kg',
      barcode: const drift.Value('61510001003'),
      unit: const drift.Value('Sac'),
      purchasePrice: const drift.Value(180000),
      salePrice: const drift.Value(210000),
      stockQuantity: const drift.Value(3),
      lowStockThreshold: const drift.Value(5),
    );
    await db.into(db.mobileProducts).insert(sample1);
    await db.into(db.mobileProducts).insert(sample2);
    products = await db.select(db.mobileProducts).get();
  }

  num totalValue = 0;
  int lowCount = 0;
  int outCount = 0;

  final itemsList = products.map((p) {
    final qty = p.stockQuantity;
    final price = p.salePrice;
    final threshold = p.lowStockThreshold;

    final status = qty <= 0 ? 'out' : (threshold > 0 && qty <= threshold ? 'low' : 'ok');

    totalValue += (qty * price);
    if (status == 'low') lowCount++;
    if (status == 'out') outCount++;

    return {
      'id': p.id,
      'name': p.name,
      'barcode': p.barcode ?? p.reference ?? '',
      'unit': p.unit,
      'purchasePrice': p.purchasePrice,
      'unitPrice': p.salePrice,
      'quantity': qty,
      'lowStockThreshold': threshold,
      'imageUrl': p.imageUrl,
      'status': status,
    };
  }).toList();

  return {
    'totalProducts': itemsList.length,
    'totalInventoryValue': totalValue,
    'lowStockCount': lowCount,
    'outOfStockCount': outCount,
    'items': itemsList,
  };
});

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(stockFilterProvider);
    final search = ref.watch(stockSearchProvider);
    final stockAsync = ref.watch(stockDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: NmaMobileAppBar(
        title: 'Inventaire & Stock',
        subtitle: 'Gestion des articles & ruptures',
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(stockDataProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_stock',
        onPressed: () => _showAddProductModal(context, ref),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.add_box_rounded, color: Colors.white),
        label: const Text(
          'Nouveau Produit',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('Erreur de chargement ($err)', style: const TextStyle(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(stockDataProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (data) {
          final totalProducts = data['totalProducts'] ?? 0;
          final totalValue = data['totalInventoryValue'] ?? 0;
          final lowStockCount = data['lowStockCount'] ?? 0;
          final outOfStockCount = data['outOfStockCount'] ?? 0;
          final allItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          final query = search.trim().toLowerCase();
          final filteredItems = allItems.where((item) {
            if (filter == 'low' && item['status'] != 'low') return false;
            if (filter == 'out' && item['status'] != 'out') return false;
            if (query.isNotEmpty) {
              final name = (item['name'] as String? ?? '').toLowerCase();
              final barcode = (item['barcode'] as String? ?? '').toLowerCase();
              if (!name.contains(query) && !barcode.contains(query)) return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Synthèse de la valorisation et recherche
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Valeur marchande totale', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.formatCurrency(totalValue),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalProducts référence(s)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandNavy),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Barre de recherche
                    TextField(
                      onChanged: (val) => ref.read(stockSearchProvider.notifier).state = val,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit, code-barres...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                        suffixIcon: search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                                onPressed: () => ref.read(stockSearchProvider.notifier).state = '',
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filtres rapides
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(ref, 'Tous ($totalProducts)', 'all', filter),
                          const SizedBox(width: 8),
                          _buildFilterChip(ref, 'Stock bas ($lowStockCount)', 'low', filter, color: AppColors.warning),
                          const SizedBox(width: 8),
                          _buildFilterChip(ref, 'Ruptures ($outOfStockCount)', 'out', filter, color: AppColors.error),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Liste des articles
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.inventory_rounded, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text('Aucun produit trouvé', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildProductCard(context, item);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String value, String currentFilter, {Color? color}) {
    final isSelected = currentFilter == value;
    final chipColor = color ?? AppColors.brandNavy;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => ref.read(stockFilterProvider.notifier).state = value,
      selectedColor: chipColor,
      backgroundColor: AppColors.surfaceVariant,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> item) {
    final qty = (item['quantity'] as num?) ?? 0;
    final price = (item['unitPrice'] as num?) ?? 0;
    final unit = item['unit'] as String? ?? 'pièce';
    final status = item['status'] as String? ?? 'ok';
    final imageUrl = item['imageUrl'] as String?;

    Color statusBg;
    Color statusFg;
    String statusText;

    if (status == 'out') {
      statusBg = AppColors.error.withValues(alpha: 0.12);
      statusFg = AppColors.error;
      statusText = '0 $unit';
    } else if (status == 'low') {
      statusBg = AppColors.warning.withValues(alpha: 0.15);
      statusFg = const Color(0xFFD97706);
      statusText = '$qty $unit(s)';
    } else {
      statusBg = AppColors.brandEmerald.withValues(alpha: 0.12);
      statusFg = AppColors.brandEmerald;
      statusText = '$qty $unit(s)';
    }

    Widget leadImage;
    if (imageUrl != null && imageUrl.isNotEmpty && File(imageUrl).existsSync()) {
      leadImage = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(imageUrl),
          width: 46,
          height: 46,
          fit: BoxFit.cover,
        ),
      );
    } else {
      leadImage = Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.brandNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.inventory_2_rounded, color: AppColors.brandNavy, size: 24),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          leadImage,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Prix unitaire : ${AppFormatters.formatCurrency(price)} • Seuil min : ${item['lowStockThreshold']}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant),
                ),
                if ((item['barcode'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Réf : ${item['barcode']}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusFg),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductModal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final purchasePriceCtrl = TextEditingController();
    final salePriceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '10');
    final thresholdCtrl = TextEditingController(text: '5');

    String selectedUnit = 'pièce';
    String? selectedImagePath;

    final unitsList = ['pièce', 'kg', 'g', 'litre', 'mètre', 'sac', 'carton', 'boîte', 'paquet'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          Future<void> pickImage(ImageSource source) async {
            final path = await MobileImagePicker.pickAndSaveImage(
              source: source,
              folderName: 'product_images',
            );
            if (path != null) {
              setStateModal(() {
                selectedImagePath = path;
              });
            }
          }

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandNavy.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_box_rounded, color: AppColors.brandNavy, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GESTION DU STOCK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8)),
                          Text('Nouveau Produit / Article', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 📸 SECTION SÉLECTION IMAGE DU PRODUIT
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: selectedImagePath != null && File(selectedImagePath!).existsSync()
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(selectedImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.add_a_photo_rounded, color: AppColors.brandNavy, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Photo du Produit',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => pickImage(ImageSource.camera),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandNavy,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('Photo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => pickImage(ImageSource.gallery),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: AppColors.border),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.photo_library_rounded, size: 12, color: AppColors.brandNavy),
                                          SizedBox(width: 4),
                                          Text('Galerie', style: TextStyle(color: AppColors.brandNavy, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
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
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nom de l\'article / Produit *',
                      hintText: 'ex: Cartouche Huile 1L',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: barcodeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Code-barres / Référence',
                            hintText: 'ex: 615102930491',
                            prefixIcon: const Icon(Icons.qr_code_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          decoration: InputDecoration(
                            labelText: 'Unité',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          items: unitsList
                              .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setStateModal(() => selectedUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: purchasePriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Prix d\'Achat (GNF)',
                            hintText: 'ex: 15000',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: salePriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Prix de Vente (GNF) *',
                            hintText: 'ex: 20000',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Stock Initial *',
                            hintText: 'ex: 20',
                            prefixIcon: const Icon(Icons.numbers_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: thresholdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Seuil Alerte Stock',
                            hintText: 'ex: 5',
                            prefixIcon: const Icon(Icons.warning_amber_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final purchasePrice = int.tryParse(purchasePriceCtrl.text.trim()) ?? 0;
                      final salePrice = int.tryParse(salePriceCtrl.text.trim()) ?? 0;
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final threshold = int.tryParse(thresholdCtrl.text.trim()) ?? 5;
                      final barcode = barcodeCtrl.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner le nom du produit')),
                        );
                        return;
                      }

                      final db = ref.read(mobileDatabaseProvider);

                      final newProd = MobileProductsCompanion.insert(
                        id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        barcode: drift.Value(barcode.isNotEmpty ? barcode : null),
                        reference: drift.Value(barcode.isNotEmpty ? barcode : 'REF-${DateTime.now().millisecondsSinceEpoch % 10000}'),
                        unit: drift.Value(selectedUnit),
                        purchasePrice: drift.Value(purchasePrice),
                        salePrice: drift.Value(salePrice),
                        stockQuantity: drift.Value(qty),
                        lowStockThreshold: drift.Value(threshold),
                        imageUrl: drift.Value(selectedImagePath),
                      );

                      await db.into(db.mobileProducts).insertOnConflictUpdate(newProd);

                      ref.invalidate(stockDataProvider);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Produit "$name" ($qty $selectedUnit) enregistré avec succès !'),
                          backgroundColor: AppColors.brandEmerald,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enregistrer le produit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
