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
    final now = DateTime.now();
    final sample1 = MobileProductsCompanion.insert(
      id: 'prod-${now.millisecondsSinceEpoch}-1',
      name: 'Jus de Mangue 1L',
      barcode: const drift.Value('61510001002'),
      reference: const drift.Value('REF-JUS-01'),
      unit: const drift.Value('pièce'),
      purchasePrice: const drift.Value(15000),
      salePrice: const drift.Value(20000),
      stockQuantity: const drift.Value(20),
      lowStockThreshold: const drift.Value(5),
    );
    final sample2 = MobileProductsCompanion.insert(
      id: 'prod-${now.millisecondsSinceEpoch}-2',
      name: 'Sac de Riz Parfumé 25kg',
      barcode: const drift.Value('61510001003'),
      reference: const drift.Value('REF-RIZ-25'),
      unit: const drift.Value('Sac'),
      purchasePrice: const drift.Value(180000),
      salePrice: const drift.Value(210000),
      stockQuantity: const drift.Value(3),
      lowStockThreshold: const drift.Value(5),
    );
    await db.into(db.mobileProducts).insert(sample1);
    await db.into(db.mobileProducts).insert(sample2);

    // Enregistrer les mouvements initiaux
    await db.into(db.mobileStockMovements).insert(
      MobileStockMovementsCompanion.insert(
        id: 'mvt-init-1',
        productId: 'prod-${now.millisecondsSinceEpoch}-1',
        type: 0,
        quantity: 20,
        unitCost: const drift.Value(15000),
        reason: const drift.Value('Stock initial'),
        date: drift.Value(now),
      ),
    );
    await db.into(db.mobileStockMovements).insert(
      MobileStockMovementsCompanion.insert(
        id: 'mvt-init-2',
        productId: 'prod-${now.millisecondsSinceEpoch}-2',
        type: 0,
        quantity: 3,
        unitCost: const drift.Value(180000),
        reason: const drift.Value('Stock initial'),
        date: drift.Value(now),
      ),
    );

    products = await db.select(db.mobileProducts).get();
  }

  num totalValue = 0;
  int lowCount = 0;
  int outCount = 0;

  final itemsList = products.map((p) {
    final qty = p.stockQuantity;
    final cost = p.purchasePrice;
    final threshold = p.lowStockThreshold;

    final status = qty <= 0 ? 'out' : (threshold > 0 && qty <= threshold ? 'low' : 'ok');

    totalValue += (qty * cost); // Valeur du stock valorisée au coût d'achat
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
        title: 'Inventaire & Stocks',
        subtitle: 'Gestion du catalogue & réassorts',
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
        backgroundColor: AppColors.brandNavy,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Nouvel Article',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Erreur : $err', style: const TextStyle(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(stockDataProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (data) {
          final totalProducts = data['totalProducts'] as int? ?? 0;
          final totalInventoryValue = data['totalInventoryValue'] as num? ?? 0;
          final lowStockCount = data['lowStockCount'] as int? ?? 0;
          final outOfStockCount = data['outOfStockCount'] as int? ?? 0;
          final allItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          // Filtrer par recherche textuelle et par état (tous, stock bas, rupture)
          final filteredItems = allItems.where((item) {
            final name = (item['name'] as String? ?? '').toLowerCase();
            final barcode = (item['barcode'] as String? ?? '').toLowerCase();
            final q = search.trim().toLowerCase();
            final matchesQuery = q.isEmpty || name.contains(q) || barcode.contains(q);

            final status = item['status'] as String? ?? 'ok';
            if (filter == 'low') return matchesQuery && (status == 'low');
            if (filter == 'out') return matchesQuery && (status == 'out');
            return matchesQuery;
          }).toList();

          return Column(
            children: [
              // Bloc valorisation globale & filtres
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // Synthèse valorisation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroNavyGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x330F1B3D),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Valeur Globale du Stock (Achat)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                AppFormatters.formatCurrency(totalInventoryValue),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: AppColors.brandOrange, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$totalProducts article(s)',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Champ de recherche
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
                          return _buildProductCard(context, ref, item);
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

  Widget _buildProductCard(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
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
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    } else {
      leadImage = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.brandNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.inventory_2_rounded, color: AppColors.brandNavy, size: 24),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showProductDetailModal(context, ref, item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
                      'Prix vente : ${AppFormatters.formatCurrency(price)} • Seuil : ${item['lowStockThreshold']}',
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
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fiche Détaillée & Actions Produit ──
  void _showProductDetailModal(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final db = ref.read(mobileDatabaseProvider);
    final productId = item['id'] as String;

    final product = await (db.select(db.mobileProducts)..where((tbl) => tbl.id.equals(productId))).getSingleOrNull();
    if (product == null || !context.mounted) return;

    // Charger les 5 derniers mouvements de stock pour cet article
    final movements = await (db.select(db.mobileStockMovements)
          ..where((tbl) => tbl.productId.equals(productId))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.date)])
          ..limit(5))
        .get();

    final margin = product.salePrice - product.purchasePrice;
    final marginPercent = product.purchasePrice > 0 ? ((margin / product.purchasePrice) * 100).round() : 0;
    final stockValue = product.stockQuantity * product.purchasePrice;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
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
              const SizedBox(height: 14),

              // En-tête produit avec photo et badge de statut
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.imageUrl != null && product.imageUrl!.isNotEmpty && File(product.imageUrl!).existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(product.imageUrl!),
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.brandNavy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: AppColors.brandNavy, size: 28),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Réf : ${product.barcode ?? product.reference ?? "N/A"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.stockQuantity <= 0
                          ? AppColors.error.withValues(alpha: 0.15)
                          : (product.stockQuantity <= product.lowStockThreshold
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : AppColors.brandEmerald.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      product.stockQuantity <= 0 ? 'RUPTURE' : (product.stockQuantity <= product.lowStockThreshold ? 'STOCK BAS' : 'EN STOCK'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: product.stockQuantity <= 0 ? AppColors.error : (product.stockQuantity <= product.lowStockThreshold ? AppColors.warning : AppColors.brandEmerald),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grille des métriques économiques
              Row(
                children: [
                  Expanded(
                    child: _buildDetailCard(
                      'Prix d\'Achat',
                      AppFormatters.formatCurrency(product.purchasePrice),
                      'Coût unitaire',
                      Icons.shopping_bag_outlined,
                      AppColors.brandNavy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDetailCard(
                      'Prix de Vente',
                      AppFormatters.formatCurrency(product.salePrice),
                      'Comptoir TTC',
                      Icons.sell_outlined,
                      AppColors.brandOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildDetailCard(
                      'Marge Unitaire',
                      AppFormatters.formatCurrency(margin),
                      marginPercent >= 0 ? '+$marginPercent% de rentabilité' : '$marginPercent%',
                      Icons.trending_up_rounded,
                      AppColors.brandEmerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDetailCard(
                      'Stock Disponible',
                      '${product.stockQuantity} ${product.unit}(s)',
                      'Valeur : ${AppFormatters.formatCurrency(stockValue)}',
                      Icons.warehouse_rounded,
                      product.stockQuantity <= product.lowStockThreshold ? AppColors.warning : AppColors.brandNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Boutons d'Action Principaux (Ajuster Stock / Modifier / Supprimer)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showStockAdjustmentModal(context, ref, product);
                      },
                      icon: const Icon(Icons.swap_vert_rounded, size: 18),
                      label: const Text('Ajuster le Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showEditProductModal(context, ref, product);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.brandNavy),
                      label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _confirmDeleteProduct(context, ref, product),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    tooltip: 'Supprimer l\'article',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section Mouvements d'inventaire récents
              const Text(
                'DERNIERS MOUVEMENTS D\'INVENTAIRE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: movements.isEmpty
                      ? const Center(
                          child: Text('Aucun mouvement enregistré', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(10),
                          itemCount: movements.length,
                          separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 10),
                          itemBuilder: (context, idx) {
                            final m = movements[idx];
                            final isPositive = m.quantity > 0;
                            String typeLabel = 'Réajustement';
                            IconData typeIcon = Icons.tune_rounded;
                            Color typeColor = AppColors.brandNavy;

                            if (m.type == 0) {
                              typeLabel = 'Entrée / Achat';
                              typeIcon = Icons.add_circle_outline_rounded;
                              typeColor = AppColors.brandEmerald;
                            } else if (m.type == 1) {
                              typeLabel = 'Vente Caisse';
                              typeIcon = Icons.remove_circle_outline_rounded;
                              typeColor = AppColors.brandOrange;
                            } else if (m.type == 2) {
                              typeLabel = isPositive ? 'Restitution / Correction' : 'Sortie / Casse';
                              typeIcon = isPositive ? Icons.undo_rounded : Icons.delete_outline_rounded;
                              typeColor = isPositive ? AppColors.brandEmerald : AppColors.error;
                            }

                            return Row(
                              children: [
                                Icon(typeIcon, size: 18, color: typeColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(typeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                                      Text(
                                        '${m.reason ?? "Mouvement"} • ${AppFormatters.formatDateTime(m.date)}',
                                        style: const TextStyle(fontSize: 10.5, color: AppColors.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isPositive ? "+" : ""}${m.quantity} ${product.unit}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isPositive ? AppColors.brandEmerald : AppColors.error,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ── Modal d'Ajustement de Stock (Entrée / Sortie / Inventaire) ──
  void _showStockAdjustmentModal(BuildContext context, WidgetRef ref, MobileProduct product) {
    int adjustmentType = 0; // 0: Entrée (+), 1: Sortie (-), 2: Inventaire réel (=)
    final qtyCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController(text: 'Réapprovisionnement marchandise');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          final enteredQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
          int resultingStock = product.stockQuantity;
          if (adjustmentType == 0) {
            resultingStock = product.stockQuantity + enteredQty;
          } else if (adjustmentType == 1) {
            resultingStock = (product.stockQuantity - enteredQty).clamp(0, 999999);
          } else if (adjustmentType == 2) {
            resultingStock = enteredQty.clamp(0, 999999);
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
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
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_vert_rounded, color: AppColors.brandOrange, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AJUSTEMENT D\'INVENTAIRE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.brandOrange, letterSpacing: 0.8)),
                            Text(product.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sélecteur Type d'Ajustement
                  Row(
                    children: [
                      Expanded(
                        child: _buildAdjustTypeOption('Entrée (+)', 0, adjustmentType, () {
                          setStateModal(() {
                            adjustmentType = 0;
                            reasonCtrl.text = 'Réapprovisionnement marchandise';
                          });
                        }, AppColors.brandEmerald),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildAdjustTypeOption('Sortie (-)', 1, adjustmentType, () {
                          setStateModal(() {
                            adjustmentType = 1;
                            reasonCtrl.text = 'Casse / Dépréciation';
                          });
                        }, AppColors.error),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildAdjustTypeOption('Inventaire (=)', 2, adjustmentType, () {
                          setStateModal(() {
                            adjustmentType = 2;
                            qtyCtrl.text = product.stockQuantity.toString();
                            reasonCtrl.text = 'Comptage physique magasin';
                          });
                        }, AppColors.brandNavy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Champ Quantité avec boutons rapides
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: adjustmentType == 2 ? 'Quantité réelle constatée' : 'Quantité à ajouter / retirer',
                      suffixText: product.unit,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (_) => setStateModal(() {}),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      _buildQuickAdjustChip('+1', 1, setStateModal, qtyCtrl),
                      const SizedBox(width: 6),
                      _buildQuickAdjustChip('+5', 5, setStateModal, qtyCtrl),
                      const SizedBox(width: 6),
                      _buildQuickAdjustChip('+10', 10, setStateModal, qtyCtrl),
                      const SizedBox(width: 6),
                      _buildQuickAdjustChip('+50', 50, setStateModal, qtyCtrl),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Motif du mouvement
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Motif ou Remarque',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Aperçu du calcul
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stock Actuel', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text('${product.stockQuantity} ${product.unit}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted, size: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Nouveau Stock', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              '$resultingStock ${product.unit}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: resultingStock <= product.lowStockThreshold ? AppColors.warning : AppColors.brandEmerald,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final db = ref.read(mobileDatabaseProvider);

                      int movementQty = enteredQty;
                      int mvtType = 2; // Adjustment
                      if (adjustmentType == 0) {
                        movementQty = enteredQty;
                        mvtType = 0; // Purchase/Entrée
                      } else if (adjustmentType == 1) {
                        movementQty = -enteredQty;
                        mvtType = 2; // Adjustment/Sortie
                      } else if (adjustmentType == 2) {
                        movementQty = resultingStock - product.stockQuantity;
                        mvtType = 2;
                      }

                      // 1. Mettre à jour le stock
                      await (db.update(db.mobileProducts)..where((tbl) => tbl.id.equals(product.id))).write(
                        MobileProductsCompanion(stockQuantity: drift.Value(resultingStock)),
                      );

                      // 2. Tracer dans MobileStockMovements
                      await db.into(db.mobileStockMovements).insert(
                        MobileStockMovementsCompanion.insert(
                          id: 'mvt-manual-${now.millisecondsSinceEpoch}',
                          productId: product.id,
                          type: mvtType,
                          quantity: movementQty,
                          unitCost: drift.Value(product.purchasePrice),
                          reason: drift.Value(reasonCtrl.text.trim().isEmpty ? 'Ajustement manuel' : reasonCtrl.text.trim()),
                          date: drift.Value(now),
                        ),
                      );

                      ref.invalidate(stockDataProvider);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Stock de "${product.name}" mis à jour : $resultingStock ${product.unit}(s) !'),
                            backgroundColor: AppColors.brandEmerald,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmer l\'ajustement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdjustTypeOption(String label, int type, int selectedType, VoidCallback onSelect, Color activeColor) {
    final isSelected = type == selectedType;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.brandNavy,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAdjustChip(String label, int amount, StateSetter setStateModal, TextEditingController ctrl) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setStateModal(() {
            final curr = int.tryParse(ctrl.text.trim()) ?? 0;
            ctrl.text = (curr + amount).toString();
          });
        },
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
      ),
    );
  }

  // ── Modal de Modification de Produit ──
  void _showEditProductModal(BuildContext context, WidgetRef ref, MobileProduct product) {
    final nameCtrl = TextEditingController(text: product.name);
    final barcodeCtrl = TextEditingController(text: product.barcode ?? '');
    final purchasePriceCtrl = TextEditingController(text: product.purchasePrice.toString());
    final salePriceCtrl = TextEditingController(text: product.salePrice.toString());
    final thresholdCtrl = TextEditingController(text: product.lowStockThreshold.toString());

    String selectedUnit = product.unit;
    String? selectedImagePath = product.imageUrl;

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
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: AppColors.brandNavy, size: 22),
                      SizedBox(width: 8),
                      Text('Modifier l\'article', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sélecteur Image
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        if (selectedImagePath != null && File(selectedImagePath!).existsSync())
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(selectedImagePath!),
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.brandNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined, color: AppColors.brandNavy),
                          ),
                        const SizedBox(width: 14),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_rounded, size: 14),
                              label: const Text('Photo', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_rounded, size: 14),
                              label: const Text('Galerie', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nom du Produit *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: barcodeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Code-barres / Réf',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: unitsList.contains(selectedUnit) ? selectedUnit : 'pièce',
                          decoration: InputDecoration(
                            labelText: 'Unité',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          items: unitsList
                              .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setStateModal(() => selectedUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: purchasePriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Prix d\'Achat (GNF)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: salePriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Prix de Vente (GNF) *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: thresholdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Seuil d\'Alerte Stock',
                      prefixIcon: const Icon(Icons.warning_amber_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final purchase = int.tryParse(purchasePriceCtrl.text.trim()) ?? product.purchasePrice;
                      final sale = int.tryParse(salePriceCtrl.text.trim()) ?? product.salePrice;
                      final threshold = int.tryParse(thresholdCtrl.text.trim()) ?? product.lowStockThreshold;

                      if (name.isEmpty) return;

                      final db = ref.read(mobileDatabaseProvider);

                      await (db.update(db.mobileProducts)..where((tbl) => tbl.id.equals(product.id))).write(
                        MobileProductsCompanion(
                          name: drift.Value(name),
                          barcode: drift.Value(barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : product.barcode),
                          unit: drift.Value(selectedUnit),
                          purchasePrice: drift.Value(purchase),
                          salePrice: drift.Value(sale),
                          lowStockThreshold: drift.Value(threshold),
                          imageUrl: drift.Value(selectedImagePath),
                        ),
                      );

                      ref.invalidate(stockDataProvider);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fiche de "$name" modifiée avec succès !'),
                            backgroundColor: AppColors.brandEmerald,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enregistrer les modifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Confirmation de Suppression Produit ──
  void _confirmDeleteProduct(BuildContext context, WidgetRef ref, MobileProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Supprimer cet article ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "${product.name}" de votre catalogue ?\n\n'
          'Cette action est irréversible. L\'historique des ventes antérieures sera conservé.',
          style: const TextStyle(fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(mobileDatabaseProvider);
              await (db.delete(db.mobileProducts)..where((tbl) => tbl.id.equals(product.id))).go();

              ref.invalidate(stockDataProvider);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(); // Ferme confirmation
              if (context.mounted) {
                Navigator.of(context).pop(); // Ferme fiche produit
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Produit "${product.name}" supprimé.'), backgroundColor: AppColors.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ── Modal d'Ajout de Nouveau Produit ──
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
                  const Row(
                    children: [
                      Icon(Icons.add_box_rounded, color: AppColors.brandNavy, size: 22),
                      SizedBox(width: 8),
                      Text('Ajouter un nouvel article', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sélecteur Image
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        if (selectedImagePath != null && File(selectedImagePath!).existsSync())
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(selectedImagePath!),
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.brandNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined, color: AppColors.brandNavy),
                          ),
                        const SizedBox(width: 14),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_rounded, size: 14),
                              label: const Text('Photo', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_rounded, size: 14),
                              label: const Text('Galerie', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                      final now = DateTime.now();
                      final prodId = 'prod-${now.millisecondsSinceEpoch}';
                      final refCode = barcode.isNotEmpty ? barcode : 'REF-${now.millisecondsSinceEpoch % 10000}';

                      final newProd = MobileProductsCompanion.insert(
                        id: prodId,
                        name: name,
                        barcode: drift.Value(barcode.isNotEmpty ? barcode : null),
                        reference: drift.Value(refCode),
                        unit: drift.Value(selectedUnit),
                        purchasePrice: drift.Value(purchasePrice),
                        salePrice: drift.Value(salePrice),
                        stockQuantity: drift.Value(qty),
                        lowStockThreshold: drift.Value(threshold),
                        imageUrl: drift.Value(selectedImagePath),
                      );

                      await db.into(db.mobileProducts).insertOnConflictUpdate(newProd);

                      // Si stock initial > 0, tracer le mouvement initial
                      if (qty > 0) {
                        await db.into(db.mobileStockMovements).insert(
                          MobileStockMovementsCompanion.insert(
                            id: 'mvt-init-${now.millisecondsSinceEpoch}',
                            productId: prodId,
                            type: 0, // Entrée / Stock initial
                            quantity: qty,
                            unitCost: drift.Value(purchasePrice),
                            reason: const drift.Value('Stock initial'),
                            date: drift.Value(now),
                          ),
                        );
                      }

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
