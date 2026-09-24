import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';
import '../../stock/presentation/stock_screen.dart';
import '../../treasury/presentation/treasury_screen.dart';

final suppliersDataProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);

  List<MobileSupplier> suppliers = await db.select(db.mobileSuppliers).get();

  // Si aucun fournisseur en BDD au premier démarrage, insérer 2 échantillons
  if (suppliers.isEmpty) {
    final now = DateTime.now();
    final s1 = MobileSuppliersCompanion.insert(
      id: 'supp-${now.millisecondsSinceEpoch}-1',
      name: 'Grossiste Sobragui & Cie',
      phone: const drift.Value('624556677'),
      company: const drift.Value('Sobragui Guinée'),
    );
    final s2 = MobileSuppliersCompanion.insert(
      id: 'supp-${now.millisecondsSinceEpoch}-2',
      name: 'Importateur Riz & Huile Diallo',
      phone: const drift.Value('621889900'),
      company: const drift.Value('Diallo & Frères S.A.'),
    );
    await db.into(db.mobileSuppliers).insert(s1);
    await db.into(db.mobileSuppliers).insert(s2);
    suppliers = await db.select(db.mobileSuppliers).get();
  }

  return suppliers.map((s) => {
        'id': s.id,
        'name': s.name,
        'phone': s.phone ?? '',
        'company': s.company ?? '',
        'date': AppFormatters.formatDateTime(s.createdAt),
      }).toList();
});

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NmaMobileAppBar(
        title: 'Fournisseurs & Approvisionnements',
        subtitle: 'Contacts & réapprovisionnements',
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
        heroTag: 'fab_suppliers',
        onPressed: () => _showAddSupplierModal(context, ref),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text(
          'Nouveau Fournisseur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: suppliersAsync.when(
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
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.local_shipping_outlined, size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('Aucun fournisseur enregistré', style: TextStyle(color: AppColors.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${suppliers.length} FOURNISSEUR(S) REGISTRÉS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8)),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPurchaseModal(context, ref),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                    label: const Text('Réassort Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suppliers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final s = suppliers[index];
                  return _buildSupplierCard(context, s);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupplierCard(BuildContext context, Map<String, dynamic> s) {
    final name = s['name'] as String? ?? '';
    final company = s['company'] as String? ?? '';
    final phone = s['phone'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF6366F1), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(company.isNotEmpty ? company : 'Société non renseignée', style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Tél : $phone', style: const TextStyle(fontSize: 11, color: AppColors.brandNavy, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

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
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              const Text('Nouveau Fournisseur', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nom du Fournisseur *',
                  hintText: 'ex: Grossiste Sobragui & Cie',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyCtrl,
                decoration: InputDecoration(
                  labelText: 'Société / Marque',
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

  void _showAddPurchaseModal(BuildContext context, WidgetRef ref) async {
    final db = ref.read(mobileDatabaseProvider);
    final products = await db.select(db.mobileProducts).get();

    if (!context.mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter des produits en stock d\'abord !')),
      );
      return;
    }

    String selectedProdId = products.first.id;
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(text: '${products.first.purchasePrice}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),
                  const Text('Réassort / Achat Fournisseur', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedProdId,
                    decoration: InputDecoration(
                      labelText: 'Produit à réapprovisionner',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (Actuel: ${p.stockQuantity} ${p.unit})'))).toList(),
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
                            labelText: 'Quantité Ajoutée *',
                            hintText: 'ex: 10',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Coût Unitaire (GNF)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final qtyToAdd = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final costUnit = int.tryParse(costCtrl.text.trim()) ?? 0;

                      if (qtyToAdd <= 0) return;

                      final targetProd = products.firstWhere((p) => p.id == selectedProdId);
                      final newQty = targetProd.stockQuantity + qtyToAdd;

                      // Mettre à jour la quantité en stock dans SQLite
                      await (db.update(db.mobileProducts)..where((tbl) => tbl.id.equals(selectedProdId))).write(
                        MobileProductsCompanion(
                          stockQuantity: drift.Value(newQty),
                          purchasePrice: drift.Value(costUnit > 0 ? costUnit : targetProd.purchasePrice),
                        ),
                      );

                      // Saisir une dépense automatique de caisse
                      final now = DateTime.now();
                      final exp = MobileExpensesCompanion.insert(
                        id: 'exp-purchase-${now.millisecondsSinceEpoch}',
                        title: 'Achat Réassort: ${targetProd.name} (x$qtyToAdd)',
                        amount: drift.Value(qtyToAdd * costUnit),
                        category: const drift.Value('Approvisionnement'),
                      );
                      await db.into(db.mobileExpenses).insert(exp);

                      ref.invalidate(stockDataProvider);
                      ref.invalidate(treasuryDataProvider);
                      ref.invalidate(suppliersDataProvider);

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Stock de "${targetProd.name}" augmenté de +$qtyToAdd ${targetProd.unit} !'),
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
                    child: const Text('Valider le Réassort', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
