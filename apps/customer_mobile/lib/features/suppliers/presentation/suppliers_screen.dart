import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';
import '../../stock/presentation/stock_screen.dart';
import '../../treasury/presentation/treasury_screen.dart';

final suppliersTabProvider = StateProvider<int>((ref) => 0);
final suppliersSearchQueryProvider = StateProvider<String>((ref) => '');

final suppliersDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);

  List<MobileSupplier> suppliers = await db.select(db.mobileSuppliers).get();
  List<MobilePurchase> purchases = await db.select(db.mobilePurchases).get();
  List<MobilePurchaseItem> purchaseItems = await db.select(db.mobilePurchaseItems).get();
  List<MobileProduct> products = await db.select(db.mobileProducts).get();

  // Initialisation échantillons si vide
  if (suppliers.isEmpty) {
    final now = DateTime.now();
    final s1 = MobileSuppliersCompanion.insert(
      id: 'supp-${now.millisecondsSinceEpoch}-1',
      name: 'Grossiste Sobragui & Cie',
      phone: const drift.Value('624556677'),
      company: const drift.Value('Sobragui Guinée S.A.'),
    );
    final s2 = MobileSuppliersCompanion.insert(
      id: 'supp-${now.millisecondsSinceEpoch}-2',
      name: 'Importateur Riz & Huile Diallo',
      phone: const drift.Value('621889900'),
      company: const drift.Value('Diallo & Frères Import-Export'),
    );
    await db.into(db.mobileSuppliers).insert(s1);
    await db.into(db.mobileSuppliers).insert(s2);
    suppliers = await db.select(db.mobileSuppliers).get();
  }

  // Échantillons d'achats si vide et des produits existent
  if (purchases.isEmpty && products.isNotEmpty) {
    final now = DateTime.now();
    final p1 = MobilePurchasesCompanion.insert(
      id: 'BL-${now.year}09-01',
      supplierId: suppliers.first.id,
      totalAmount: const drift.Value(450000),
      amountPaid: const drift.Value(450000),
      date: drift.Value(now.subtract(const Duration(days: 2))),
    );
    await db.into(db.mobilePurchases).insert(p1);

    final item1 = MobilePurchaseItemsCompanion.insert(
      id: 'item-purch-1',
      purchaseId: 'BL-${now.year}09-01',
      productId: products.first.id,
      quantity: const drift.Value(20),
      unitPrice: drift.Value(products.first.purchasePrice),
    );
    await db.into(db.mobilePurchaseItems).insert(item1);

    purchases = await db.select(db.mobilePurchases).get();
    purchaseItems = await db.select(db.mobilePurchaseItems).get();
  }

  // Map des achats par fournisseur
  final Map<String, List<MobilePurchase>> purchasesBySupplier = {};
  for (final p in purchases) {
    purchasesBySupplier.putIfAbsent(p.supplierId, () => []).add(p);
  }

  // Map des items par achat
  final Map<String, List<MobilePurchaseItem>> itemsByPurchase = {};
  for (final item in purchaseItems) {
    itemsByPurchase.putIfAbsent(item.purchaseId, () => []).add(item);
  }

  purchases.sort((a, b) => b.date.compareTo(a.date));

  return {
    'suppliers': suppliers,
    'purchases': purchases,
    'purchasesBySupplier': purchasesBySupplier,
    'itemsByPurchase': itemsByPurchase,
    'products': products,
  };
});

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(suppliersDataProvider);
    final activeTab = ref.watch(suppliersTabProvider);
    final searchQuery = ref.watch(suppliersSearchQueryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: NmaMobileAppBar(
        title: 'Fournisseurs & Approvisionnements',
        subtitle: 'Gestion des réceptions & réassorts',
        onLeadingPressed: () => Navigator.of(context).maybePop(),
        leadingIcon: Icons.arrow_back_rounded,
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(suppliersDataProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_suppliers_action',
        onPressed: () {
          if (activeTab == 0) {
            _showAddSupplierModal(context, ref);
          } else {
            _showAddPurchaseModal(context, ref);
          }
        },
        backgroundColor: activeTab == 0 ? AppColors.brandOrange : AppColors.brandNavy,
        icon: Icon(activeTab == 0 ? Icons.person_add_alt_1_rounded : Icons.add_shopping_cart_rounded, color: Colors.white),
        label: Text(
          activeTab == 0 ? 'Nouveau Fournisseur' : 'Nouveau Réassort (BL)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Erreur de chargement ($err)', style: const TextStyle(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
        data: (data) {
          final suppliers = (data['suppliers'] as List<MobileSupplier>?) ?? [];
          final purchases = (data['purchases'] as List<MobilePurchase>?) ?? [];
          final purchasesBySupplier = (data['purchasesBySupplier'] as Map<String, List<MobilePurchase>>?) ?? {};
          final itemsByPurchase = (data['itemsByPurchase'] as Map<String, List<MobilePurchaseItem>>?) ?? {};
          final products = (data['products'] as List<MobileProduct>?) ?? [];

          // Calcul KPIs globaux
          int totalPurchasesAmount = 0;
          int totalDebtsToSuppliers = 0;
          for (final p in purchases) {
            if (!p.isCancelled) {
              totalPurchasesAmount += p.totalAmount;
              final remaining = p.totalAmount - p.amountPaid;
              if (remaining > 0) totalDebtsToSuppliers += remaining;
            }
          }

          // Filtres de recherche
          final filteredSuppliers = suppliers.where((s) {
            if (searchQuery.isEmpty) return true;
            final q = searchQuery.toLowerCase();
            return s.name.toLowerCase().contains(q) ||
                (s.company ?? '').toLowerCase().contains(q) ||
                (s.phone ?? '').contains(q);
          }).toList();

          final filteredPurchases = purchases.where((p) {
            if (searchQuery.isEmpty) return true;
            final q = searchQuery.toLowerCase();
            final supp = suppliers.cast<MobileSupplier?>().firstWhere((s) => s?.id == p.supplierId, orElse: () => null);
            final suppName = supp?.name.toLowerCase() ?? '';
            return p.id.toLowerCase().contains(q) || suppName.contains(q);
          }).toList();

          return Column(
            children: [
              // ── KPIs BANNER ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppColors.heroNavyGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandNavy.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('RÉASSORTS CUMULÉS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.formatCurrency(totalPurchasesAmount),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text('${purchases.length} bon(s) de réception', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: Colors.white24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DETTES FOURNISSEURS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.formatCurrency(totalDebtsToSuppliers),
                            style: TextStyle(
                              color: totalDebtsToSuppliers > 0 ? const Color(0xFFF87171) : AppColors.brandEmerald,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalDebtsToSuppliers > 0 ? 'Factures en attente' : 'Toutes factures soldées',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── TAB SELECTOR ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => ref.read(suppliersTabProvider.notifier).state = 0,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: activeTab == 0 ? AppColors.brandNavy : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_alt_rounded, size: 16, color: activeTab == 0 ? Colors.white : AppColors.brandNavy),
                                const SizedBox(width: 6),
                                Text(
                                  'Fournisseurs (${suppliers.length})',
                                  style: TextStyle(
                                    fontWeight: activeTab == 0 ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 12.5,
                                    color: activeTab == 0 ? Colors.white : AppColors.brandNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => ref.read(suppliersTabProvider.notifier).state = 1,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: activeTab == 1 ? AppColors.brandNavy : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 16, color: activeTab == 1 ? Colors.white : AppColors.brandNavy),
                                const SizedBox(width: 6),
                                Text(
                                  'Bons Réassort (${purchases.length})',
                                  style: TextStyle(
                                    fontWeight: activeTab == 1 ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 12.5,
                                    color: activeTab == 1 ? Colors.white : AppColors.brandNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── BARRE DE RECHERCHE ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: activeTab == 0 ? 'Rechercher un fournisseur, marque, tél...' : 'Rechercher par N° BL ou fournisseur...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.brandNavy),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => ref.read(suppliersSearchQueryProvider.notifier).state = '',
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceBright,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                  onChanged: (val) => ref.read(suppliersSearchQueryProvider.notifier).state = val,
                ),
              ),
              const SizedBox(height: 6),

              // ── CONTENU DE L'ONGLET SÉLECTIONNÉ ──
              Expanded(
                child: activeTab == 0
                    ? _buildSuppliersList(context, ref, filteredSuppliers, purchasesBySupplier, products)
                    : _buildPurchasesList(context, ref, filteredPurchases, suppliers, itemsByPurchase, products),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── ONGLET 1 : LISTE DES FOURNISSEURS ──
  Widget _buildSuppliersList(
    BuildContext context,
    WidgetRef ref,
    List<MobileSupplier> suppliers,
    Map<String, List<MobilePurchase>> purchasesBySupplier,
    List<MobileProduct> products,
  ) {
    if (suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_search_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text('Aucun fournisseur trouvé', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = suppliers[index];
        final suppPurchases = purchasesBySupplier[s.id] ?? [];
        int totalBought = 0;
        int remainingDue = 0;
        for (final p in suppPurchases) {
          if (!p.isCancelled) {
            totalBought += p.totalAmount;
            final diff = p.totalAmount - p.amountPaid;
            if (diff > 0) remainingDue += diff;
          }
        }

        return InkWell(
          onTap: () => _showSupplierDetailModal(context, ref, s, suppPurchases, products),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceBright,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF6366F1), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      const SizedBox(height: 2),
                      Text(s.company != null && s.company!.isNotEmpty ? s.company! : 'Société non renseignée', style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                      if (s.phone != null && s.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 12, color: AppColors.brandOrange),
                            const SizedBox(width: 4),
                            Text(s.phone!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatters.formatCurrency(totalBought),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${suppPurchases.length} achat(s)',
                      style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                    if (remainingDue > 0) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'Dû: ${AppFormatters.formatCurrency(remainingDue)}',
                          style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── ONGLET 2 : LISTE DES BONS DE RÉASSORT (PURCHASES) ──
  Widget _buildPurchasesList(
    BuildContext context,
    WidgetRef ref,
    List<MobilePurchase> purchases,
    List<MobileSupplier> suppliers,
    Map<String, List<MobilePurchaseItem>> itemsByPurchase,
    List<MobileProduct> products,
  ) {
    if (purchases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text('Aucun bon de réassort trouvé', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      itemCount: purchases.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = purchases[index];
        final supp = suppliers.cast<MobileSupplier?>().firstWhere((s) => s?.id == p.supplierId, orElse: () => null);
        final suppName = supp != null ? supp.name : 'Fournisseur inconnu';
        final items = itemsByPurchase[p.id] ?? [];
        final isFullyPaid = p.amountPaid >= p.totalAmount;
        final remaining = p.totalAmount - p.amountPaid;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceBright,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isFullyPaid ? AppColors.outline.withValues(alpha: 0.5) : AppColors.warning.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brandNavy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.brandNavy)),
                      ),
                      const SizedBox(width: 8),
                      Text(AppFormatters.formatDateTime(p.date), style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isFullyPaid ? AppColors.brandEmerald : AppColors.warning).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFullyPaid ? 'Payé comptant' : 'Reste dû : ${AppFormatters.formatCurrency(remaining)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isFullyPaid ? AppColors.brandEmerald : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(suppName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
              const SizedBox(height: 4),

              if (items.isNotEmpty)
                Text(
                  '${items.length} article(s) réceptionné(s)',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant),
                ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Réception :', style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                  Text(
                    AppFormatters.formatCurrency(p.totalAmount),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.brandNavy),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── FICHE FOURNISSEUR DÉTAILLÉE ──
  void _showSupplierDetailModal(
    BuildContext context,
    WidgetRef ref,
    MobileSupplier s,
    List<MobilePurchase> purchases,
    List<MobileProduct> products,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceBright,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF6366F1), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      Text(s.company != null && s.company!.isNotEmpty ? s.company! : 'Fournisseur partenaire', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Boutons d'actions contact
            Row(
              children: [
                if (s.phone != null && s.phone!.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:${s.phone}')),
                      icon: const Icon(Icons.phone_rounded, size: 16, color: AppColors.brandNavy),
                      label: Text('Appeler (${s.phone})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('whatsapp://send?phone=${s.phone}')),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Historique des bons de livraison avec ce fournisseur
            const Text('HISTORIQUE DES RÉASSORTS FOURNISSEUR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8)),
            const SizedBox(height: 8),

            Expanded(
              child: purchases.isEmpty
                  ? const Center(child: Text('Aucun réassort enregistré pour ce fournisseur', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                  : ListView.separated(
                      itemCount: purchases.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final p = purchases[idx];
                        return Container(
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
                                  Text(p.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy)),
                                  Text(AppFormatters.formatDateTime(p.date), style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                ],
                              ),
                              Text(AppFormatters.formatCurrency(p.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showAddPurchaseModal(context, ref, defaultSupplierId: s.id);
                    },
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Nouveau Réassort', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _confirmDeleteSupplier(context, ref, s, purchases.isNotEmpty),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── MODALE CRÉATION FOURNISSEUR ──
  void _showAddSupplierModal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceBright,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: AppColors.brandOrange, size: 22),
                  SizedBox(width: 8),
                  Text('Nouveau Fournisseur', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nom du Fournisseur / Contact *',
                  hintText: 'ex: Mamadou Diallo',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyCtrl,
                decoration: InputDecoration(
                  labelText: 'Entreprise / Marque',
                  hintText: 'ex: Sobragui Guinée S.A.',
                  prefixIcon: const Icon(Icons.business_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de Téléphone',
                  hintText: 'ex: 624 55 66 77',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final db = ref.read(mobileDatabaseProvider);
                  final newSupp = MobileSuppliersCompanion.insert(
                    id: 'supp-${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    company: drift.Value(companyCtrl.text.trim().isNotEmpty ? companyCtrl.text.trim() : null),
                    phone: drift.Value(phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null),
                  );
                  await db.into(db.mobileSuppliers).insert(newSupp);
                  ref.invalidate(suppliersDataProvider);

                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fournisseur "$name" enregistré !'), backgroundColor: AppColors.brandEmerald),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enregistrer le Fournisseur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MODALE NOUVEAU RÉASSORT / BON DE RÉCEPTION MULTI-PRODUITS ──
  void _showAddPurchaseModal(BuildContext context, WidgetRef ref, {String? defaultSupplierId}) async {
    final db = ref.read(mobileDatabaseProvider);
    final products = await db.select(db.mobileProducts).get();
    final suppliers = await db.select(db.mobileSuppliers).get();

    if (!context.mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter des produits en stock d\'abord !')),
      );
      return;
    }
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez enregistrer au moins un fournisseur d\'abord !')),
      );
      return;
    }

    String selectedSuppId = defaultSupplierId ?? suppliers.first.id;
    String selectedProdId = products.first.id;
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(text: '${products.first.purchasePrice}');
    final refCtrl = TextEditingController(text: 'BL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    int paymentMethod = 0; // 0: Espèces (déduit de caisse), 1: Mobile Money, 2: À Crédit

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          final targetProd = products.firstWhere((p) => p.id == selectedProdId, orElse: () => products.first);
          final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
          final unitCost = int.tryParse(costCtrl.text.trim()) ?? targetProd.purchasePrice;
          final totalCost = qty * unitCost;

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceBright,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, color: AppColors.brandNavy, size: 22),
                      SizedBox(width: 8),
                      Text('Réassort / Bon de Réception', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Référence BL
                  TextField(
                    controller: refCtrl,
                    decoration: InputDecoration(
                      labelText: 'N° Bon de Livraison / Facture *',
                      hintText: 'ex: BL-4029',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sélection Fournisseur
                  DropdownButtonFormField<String>(
                    initialValue: suppliers.any((s) => s.id == selectedSuppId) ? selectedSuppId : suppliers.first.id,
                    decoration: InputDecoration(
                      labelText: 'Fournisseur *',
                      prefixIcon: const Icon(Icons.local_shipping_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedSuppId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Produit réapprovisionné
                  DropdownButtonFormField<String>(
                    initialValue: selectedProdId,
                    decoration: InputDecoration(
                      labelText: 'Produit à réceptionner *',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (Stock actuel: ${p.stockQuantity})'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateModal(() {
                          selectedProdId = val;
                          final prod = products.firstWhere((p) => p.id == val);
                          costCtrl.text = '${prod.purchasePrice}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantité Reçue *',
                            hintText: 'ex: 20',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => setStateModal(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'P.A. Unitaire (GNF) *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => setStateModal(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Mode de paiement de la facture fournisseur
                  const Text('Règlement de la facture fournisseur :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildPaymentChip('Espèces (Caisse)', 0, paymentMethod, () => setStateModal(() => paymentMethod = 0)),
                      const SizedBox(width: 6),
                      _buildPaymentChip('Mobile Money', 1, paymentMethod, () => setStateModal(() => paymentMethod = 1)),
                      const SizedBox(width: 6),
                      _buildPaymentChip('À Crédit (Dette)', 2, paymentMethod, () => setStateModal(() => paymentMethod = 2)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Récapitulatif total
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant Total Facturé :', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                        Text(AppFormatters.formatCurrency(totalCost), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.brandOrange)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: () async {
                      final blRef = refCtrl.text.trim();
                      if (blRef.isEmpty || qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner une référence et une quantité valide')),
                        );
                        return;
                      }

                      final now = DateTime.now();
                      final purchaseId = blRef;
                      final isPaidCash = paymentMethod == 0;
                      final isPaidMomo = paymentMethod == 1;
                      final amountPaid = (isPaidCash || isPaidMomo) ? totalCost : 0;

                      // 1. Enregistrement Bon de Réassort
                      await db.into(db.mobilePurchases).insert(
                        MobilePurchasesCompanion.insert(
                          id: purchaseId,
                          supplierId: selectedSuppId,
                          totalAmount: drift.Value(totalCost),
                          amountPaid: drift.Value(amountPaid),
                          date: drift.Value(now),
                        ),
                      );

                      // 2. Enregistrement Article Réceptionné
                      await db.into(db.mobilePurchaseItems).insert(
                        MobilePurchaseItemsCompanion.insert(
                          id: 'pitem-${now.millisecondsSinceEpoch}',
                          purchaseId: purchaseId,
                          productId: selectedProdId,
                          quantity: drift.Value(qty),
                          unitPrice: drift.Value(unitCost),
                        ),
                      );

                      // 3. Mouvement de stock d'entrée (Audit trail)
                      await db.into(db.mobileStockMovements).insert(
                        MobileStockMovementsCompanion.insert(
                          id: 'smov-purch-${now.millisecondsSinceEpoch}',
                          productId: selectedProdId,
                          type: 0, // Purchase
                          quantity: qty,
                          unitCost: drift.Value(unitCost),
                          sourceReference: drift.Value(purchaseId),
                          reason: const drift.Value('Réassort Fournisseur'),
                          date: drift.Value(now),
                        ),
                      );

                      // 4. Mise à jour de la quantité en stock du produit
                      final newStockQty = targetProd.stockQuantity + qty;
                      await (db.update(db.mobileProducts)..where((tbl) => tbl.id.equals(selectedProdId))).write(
                        MobileProductsCompanion(
                          stockQuantity: drift.Value(newStockQty),
                          purchasePrice: drift.Value(unitCost > 0 ? unitCost : targetProd.purchasePrice),
                        ),
                      );

                      // 5. Si payé en espèces depuis la caisse -> enregistrer la dépense de caisse
                      if (isPaidCash) {
                        await db.into(db.mobileExpenses).insert(
                          MobileExpensesCompanion.insert(
                            id: 'exp-purch-${now.millisecondsSinceEpoch}',
                            title: 'Réassort: ${targetProd.name} (x$qty) - $purchaseId',
                            amount: drift.Value(totalCost),
                            category: const drift.Value('Approvisionnement'),
                            note: drift.Value('Payé au fournisseur'),
                          ),
                        );
                      }

                      ref.invalidate(suppliersDataProvider);
                      ref.invalidate(stockDataProvider);
                      ref.invalidate(treasuryDataProvider);

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Réassort $purchaseId validé ! Stock +$qty ${targetProd.unit}'),
                          backgroundColor: AppColors.brandEmerald,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Valider la Réception & Incrémenter Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentChip(String label, int value, int selectedVal, VoidCallback onTap) {
    final isSelected = value == selectedVal;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandNavy : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.brandNavy : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.brandNavy,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSupplier(BuildContext context, WidgetRef ref, MobileSupplier s, bool hasPurchases) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce fournisseur ?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          hasPurchases
              ? 'Ce fournisseur possède des réassorts enregistrés. Êtes-vous sûr de vouloir supprimer la fiche de "${s.name}" ?'
              : 'Voulez-vous supprimer le fournisseur "${s.name}" ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(mobileDatabaseProvider);
              await (db.delete(db.mobileSuppliers)..where((tbl) => tbl.id.equals(s.id))).go();
              ref.invalidate(suppliersDataProvider);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(); // Ferme dialog
              Navigator.of(context).pop(); // Ferme fiche
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fournisseur supprimé')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
