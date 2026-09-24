import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';
import '../../receivables/presentation/receivables_screen.dart';
import '../../stock/presentation/stock_screen.dart';
import '../../treasury/presentation/treasury_screen.dart';

final salesPeriodProvider = StateProvider<String>((ref) => 'today');
final salesSearchProvider = StateProvider<String>((ref) => '');

final salesDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);
  final period = ref.watch(salesPeriodProvider);

  List<MobileSale> sales = await db.select(db.mobileSales).get();

  // Si aucune vente en BDD locale au premier démarrage, insérer 2 échantillons par défaut
  if (sales.isEmpty) {
    final now = DateTime.now();
    final s1 = MobileSalesCompanion.insert(
      id: 'sale-${now.millisecondsSinceEpoch}-1',
      reference: 'FAC-${now.millisecondsSinceEpoch % 10000}',
      date: drift.Value(now),
      total: const drift.Value(40000),
      amountPaid: const drift.Value(40000),
      paymentMethod: const drift.Value(0), // Espèces
      sellerName: const drift.Value('Patron'),
    );
    final s2 = MobileSalesCompanion.insert(
      id: 'sale-${now.millisecondsSinceEpoch}-2',
      reference: 'FAC-${(now.millisecondsSinceEpoch + 1) % 10000}',
      date: drift.Value(now.subtract(const Duration(hours: 3))),
      total: const drift.Value(210000),
      amountPaid: const drift.Value(210000),
      paymentMethod: const drift.Value(1), // Orange Money / Wave
      sellerName: const drift.Value('Patron'),
    );
    await db.into(db.mobileSales).insert(s1);
    await db.into(db.mobileSales).insert(s2);
    sales = await db.select(db.mobileSales).get();
  }

  final now = DateTime.now();
  DateTime cutoff = DateTime(now.year, now.month, now.day);
  if (period == '7d') {
    cutoff = now.subtract(const Duration(days: 7));
  } else if (period == '30d') {
    cutoff = now.subtract(const Duration(days: 30));
  }

  final filteredSales = sales.where((s) => s.date.isAfter(cutoff) || s.date.isAtSameMomentAs(cutoff)).toList();

  int totalAmt = 0;
  int cash = 0;
  int momo = 0;
  int credit = 0;

  for (final s in filteredSales) {
    final amt = s.total;
    final paid = s.amountPaid;
    final method = s.paymentMethod;

    totalAmt += amt;
    if (method == 0) {
      cash += paid;
    } else if (method == 1 || method == 2 || method == 3) {
      momo += paid;
    }
    if (amt > paid) {
      credit += (amt - paid);
    }
  }

  final recentList = filteredSales.reversed.map((s) {
    String methodLabel = 'Espèces';
    if (s.paymentMethod == 1) methodLabel = 'Orange Money';
    if (s.paymentMethod == 2) methodLabel = 'Wave';
    if (s.paymentMethod == 3) methodLabel = 'Moov Money';
    if (s.paymentMethod == 4) methodLabel = 'Virement';
    if (s.paymentMethod == 5) methodLabel = 'Crédit Client';

    return {
      'id': s.id,
      'reference': s.reference,
      'date': AppFormatters.formatDateTime(s.date),
      'customerName': s.customerId ?? 'Client Comptoir',
      'totalAmount': s.total,
      'amountPaid': s.amountPaid,
      'paymentMethod': methodLabel,
      'paymentMethodIndex': s.paymentMethod,
      'sellerName': s.sellerName ?? 'Patron',
    };
  }).toList();

  return {
    'summary': {
      'totalSales': totalAmt,
      'salesCount': filteredSales.length,
      'averageTicket': filteredSales.isNotEmpty ? (totalAmt / filteredSales.length).round() : 0,
      'cashCollected': cash,
      'momoCollected': momo,
      'creditIssued': credit,
    },
    'recentSales': recentList,
  };
});

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(salesPeriodProvider);
    final search = ref.watch(salesSearchProvider);
    final salesAsync = ref.watch(salesDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: NmaMobileAppBar(
        title: 'Activité Commerciale',
        subtitle: 'Suivi des ventes & factures',
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(salesDataProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_sales',
        onPressed: () => _showAddSaleModal(context, ref),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text(
          'Nouvelle Vente',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildPeriodChip(ref, 'Aujourd\'hui', 'today', period),
                    const SizedBox(width: 8),
                    _buildPeriodChip(ref, '7 derniers jours', '7d', period),
                    const SizedBox(width: 8),
                    _buildPeriodChip(ref, '30 jours', '30d', period),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (val) => ref.read(salesSearchProvider.notifier).state = val,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par référence, client...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                            onPressed: () => ref.read(salesSearchProvider.notifier).state = '',
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
              ],
            ),
          ),

          Expanded(
            child: salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Erreur de chargement ($err)', style: const TextStyle(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(salesDataProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                final summary = data['summary'] as Map<String, dynamic>? ?? {};
                final totalSales = summary['totalSales'] ?? 0;
                final salesCount = summary['salesCount'] ?? 0;
                final avgTicket = summary['averageTicket'] ?? 0;
                final cashCollected = summary['cashCollected'] ?? 0;
                final momoCollected = summary['momoCollected'] ?? 0;
                final creditIssued = summary['creditIssued'] ?? 0;

                final recentSales = (data['recentSales'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                final query = search.trim().toLowerCase();
                final filteredSales = recentSales.where((s) {
                  if (query.isEmpty) return true;
                  final refCode = (s['reference'] as String? ?? '').toLowerCase();
                  final cust = (s['customerName'] as String? ?? '').toLowerCase();
                  return refCode.contains(query) || cust.contains(query);
                }).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  children: [
                    // Cartes de métriques
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Chiffre d\'Affaires',
                            AppFormatters.formatCurrency(totalSales),
                            '$salesCount vente(s)',
                            Icons.monetization_on_rounded,
                            AppColors.brandNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            'Panier Moyen',
                            AppFormatters.formatCurrency(avgTicket),
                            'Par reçu',
                            Icons.shopping_bag_rounded,
                            AppColors.brandOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallMetric(
                            'Caisse Espèces',
                            AppFormatters.formatCurrency(cashCollected),
                            Icons.payments_rounded,
                            AppColors.brandEmerald,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSmallMetric(
                            'Mobile Money',
                            AppFormatters.formatCurrency(momoCollected),
                            Icons.phone_android_rounded,
                            const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSmallMetric(
                            'Crédit accordé',
                            AppFormatters.formatCurrency(creditIssued),
                            Icons.account_balance_wallet_rounded,
                            AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'RÉCENTES TRANSACTIONS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),

                    if (filteredSales.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                            SizedBox(height: 8),
                            Text('Aucune vente enregistrée pour cette période', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredSales.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sale = filteredSales[index];
                          return _buildSaleCard(sale);
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(WidgetRef ref, String label, String value, String currentPeriod) {
    final isSelected = currentPeriod == value;
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
      onSelected: (_) => ref.read(salesPeriodProvider.notifier).state = value,
      selectedColor: AppColors.brandNavy,
      backgroundColor: AppColors.surfaceVariant,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildMetricCard(String title, String mainValue, String subValue, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(mainValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subValue, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final refCode = sale['reference'] as String? ?? '';
    final custName = sale['customerName'] as String? ?? 'Client Comptoir';
    final date = sale['date'] as String? ?? '';
    final total = (sale['totalAmount'] as num?) ?? 0;
    final paid = (sale['amountPaid'] as num?) ?? total;
    final methodLabel = sale['paymentMethod'] as String? ?? 'Espèces';

    final isCredit = total > paid;

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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit ? AppColors.warning.withValues(alpha: 0.12) : AppColors.brandEmerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.receipt_long_rounded : Icons.check_circle_rounded,
              color: isCredit ? AppColors.warning : AppColors.brandEmerald,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(refCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(methodLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandNavy)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text('$custName • $date', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatCurrency(total),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              if (isCredit)
                Text(
                  'Reste: ${AppFormatters.formatCurrency(total - paid)}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddSaleModal(BuildContext context, WidgetRef ref) async {
    final db = ref.read(mobileDatabaseProvider);
    final products = await db.select(db.mobileProducts).get();

    if (!context.mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord ajouter des produits dans l\'onglet Stocks !')),
      );
      return;
    }

    final Map<String, int> cart = {};
    String selectedCustomerName = 'Client Comptoir';
    int selectedPaymentMethod = 0; // 0: Espèces, 1: Orange Money, 2: Wave, 3: Moov, 4: Virement, 5: Crédit
    final amountPaidCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          int subtotal = 0;
          cart.forEach((prodId, qty) {
            final p = products.firstWhere((element) => element.id == prodId);
            subtotal += p.salePrice * qty;
          });

          final total = subtotal;
          final amountPaid = int.tryParse(amountPaidCtrl.text.trim()) ?? total;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: AppColors.brandOrange, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CAISSE POS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.brandOrange, letterSpacing: 0.8)),
                        Text('Nouvelle Vente & Encaissement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Sélection des articles dans le panier
                const Text('Sélectionner les articles :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final prod = products[index];
                      final currentQtyInCart = cart[prod.id] ?? 0;
                      final availableStock = prod.stockQuantity;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: currentQtyInCart > 0 ? AppColors.brandOrange : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy)),
                                  Text('${AppFormatters.formatCurrency(prod.salePrice)} • En stock : $availableStock ${prod.unit}', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                if (currentQtyInCart > 0) ...[
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 22),
                                    onPressed: () {
                                      setStateModal(() {
                                        if (currentQtyInCart > 1) {
                                          cart[prod.id] = currentQtyInCart - 1;
                                        } else {
                                          cart.remove(prod.id);
                                        }
                                      });
                                    },
                                  ),
                                  Text('$currentQtyInCart', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.add_circle_rounded, color: AppColors.brandEmerald, size: 24),
                                  onPressed: () {
                                    if (currentQtyInCart >= availableStock) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Stock insuffisant pour ${prod.name}')),
                                      );
                                      return;
                                    }
                                    setStateModal(() {
                                      cart[prod.id] = currentQtyInCart + 1;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Sélection du mode de paiement
                const Text('Mode de paiement :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPaymentOption(setStateModal, 'Espèces', 0, selectedPaymentMethod),
                      const SizedBox(width: 6),
                      _buildPaymentOption(setStateModal, 'Orange Money', 1, selectedPaymentMethod),
                      const SizedBox(width: 6),
                      _buildPaymentOption(setStateModal, 'Wave', 2, selectedPaymentMethod),
                      const SizedBox(width: 6),
                      _buildPaymentOption(setStateModal, 'Moov Money', 3, selectedPaymentMethod),
                      const SizedBox(width: 6),
                      _buildPaymentOption(setStateModal, 'Crédit Client', 5, selectedPaymentMethod),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Synthèse du montant et Bouton d'encaissement
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandNavy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.brandNavy.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total à encaisser :', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                          Text(AppFormatters.formatCurrency(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.brandNavy)),
                        ],
                      ),
                      Text('${cart.values.fold(0, (a, b) => a + b)} article(s)', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandOrange)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: cart.isEmpty
                      ? null
                      : () async {
                          final now = DateTime.now();
                          final saleId = 'sale-${now.millisecondsSinceEpoch}';
                          final refCode = 'FAC-${now.millisecondsSinceEpoch % 10000}';

                          final newSale = MobileSalesCompanion.insert(
                            id: saleId,
                            reference: refCode,
                            date: drift.Value(now),
                            total: drift.Value(total),
                            amountPaid: drift.Value(amountPaid),
                            paymentMethod: drift.Value(selectedPaymentMethod),
                            customerId: drift.Value(selectedCustomerName),
                            sellerName: const drift.Value('Patron'),
                          );

                          await db.into(db.mobileSales).insert(newSale);

                          // Déduire le stock des produits vendus dans SQLite
                          for (final entry in cart.entries) {
                            final p = products.firstWhere((prod) => prod.id == entry.key);
                            final newQty = (p.stockQuantity - entry.value).clamp(0, 999999);

                            await (db.update(db.mobileProducts)..where((tbl) => tbl.id.equals(p.id))).write(
                              MobileProductsCompanion(stockQuantity: drift.Value(newQty)),
                            );
                          }

                          ref.invalidate(salesDataProvider);
                          ref.invalidate(stockDataProvider);
                          ref.invalidate(treasuryDataProvider);
                          ref.invalidate(receivablesDataProvider);

                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Vente $refCode de ${AppFormatters.formatCurrency(total)} enregistrée avec succès !'),
                              backgroundColor: AppColors.brandEmerald,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Valider & Encaisser', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentOption(StateSetter setStateModal, String label, int index, int selectedIndex) {
    final isSelected = selectedIndex == index;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppColors.brandNavy)),
      selected: isSelected,
      onSelected: (_) => setStateModal(() {}),
      selectedColor: AppColors.brandNavy,
      backgroundColor: AppColors.surfaceVariant,
      showCheckmark: false,
    );
  }
}
