import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:url_launcher/url_launcher.dart';
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
      sellerName: const drift.Value('Administrateur'),
    );
    final s2 = MobileSalesCompanion.insert(
      id: 'sale-${now.millisecondsSinceEpoch}-2',
      reference: 'FAC-${(now.millisecondsSinceEpoch + 1) % 10000}',
      date: drift.Value(now.subtract(const Duration(hours: 3))),
      total: const drift.Value(210000),
      amountPaid: const drift.Value(210000),
      paymentMethod: const drift.Value(1), // Orange Money / Wave
      sellerName: const drift.Value('Administrateur'),
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
  int validSalesCount = 0;

  for (final s in filteredSales) {
    if (s.isCancelled) continue; // Les ventes annulées sont exclues du CA
    validSalesCount++;
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
      'rawDate': s.date,
      'customerName': s.customerId ?? 'Client Comptoir',
      'totalAmount': s.total,
      'amountPaid': s.amountPaid,
      'paymentMethod': methodLabel,
      'paymentMethodIndex': s.paymentMethod,
      'sellerName': s.sellerName ?? 'Administrateur',
      'isCancelled': s.isCancelled,
      'note': s.note,
    };
  }).toList();

  return {
    'summary': {
      'totalSales': totalAmt,
      'salesCount': validSalesCount,
      'averageTicket': validSalesCount > 0 ? (totalAmt / validSalesCount).round() : 0,
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
        title: 'Caisse & Ventes',
        subtitle: 'Encaissement POS & Factures',
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
                    hintText: 'Rechercher par facture, client...',
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
                            '$salesCount vente(s) validée(s)',
                            Icons.monetization_on_rounded,
                            AppColors.brandNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            'Panier Moyen',
                            AppFormatters.formatCurrency(avgTicket),
                            'Par passage en caisse',
                            Icons.shopping_basket_rounded,
                            AppColors.brandOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ventilation des encaissements
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallMetric(
                            'Espèces reçues',
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
                            const Color(0xFF6366F1),
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TRANSACTIONS DE CAISSE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8),
                        ),
                        Text(
                          '${filteredSales.length} résultat(s)',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
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
                            Text('Aucune vente trouvée', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
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
                          return _buildSaleCard(context, ref, sale);
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
            blurRadius: 8,
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
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(mainValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(subValue, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
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

  Widget _buildSaleCard(BuildContext context, WidgetRef ref, Map<String, dynamic> sale) {
    final refCode = sale['reference'] as String? ?? '';
    final custName = sale['customerName'] as String? ?? 'Client Comptoir';
    final date = sale['date'] as String? ?? '';
    final total = (sale['totalAmount'] as num?) ?? 0;
    final paid = (sale['amountPaid'] as num?) ?? total;
    final methodLabel = sale['paymentMethod'] as String? ?? 'Espèces';
    final isCancelled = sale['isCancelled'] as bool? ?? false;
    final isCredit = total > paid;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSaleReceiptDialog(context, ref, sale),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCancelled ? const Color(0xFFF8FAFC) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCancelled ? AppColors.border : AppColors.outline.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? Colors.grey.withValues(alpha: 0.15)
                      : (isCredit ? AppColors.warning.withValues(alpha: 0.12) : AppColors.brandEmerald.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCancelled
                      ? Icons.cancel_outlined
                      : (isCredit ? Icons.receipt_long_rounded : Icons.check_circle_rounded),
                  color: isCancelled ? Colors.grey : (isCredit ? AppColors.warning : AppColors.brandEmerald),
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
                        Text(
                          refCode,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isCancelled ? Colors.grey : AppColors.brandNavy,
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCancelled ? Colors.grey.shade200 : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCancelled ? 'Annulée' : methodLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isCancelled ? Colors.red.shade700 : AppColors.brandNavy,
                            ),
                          ),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCancelled ? Colors.grey : AppColors.onSurface,
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (isCredit && !isCancelled)
                    Text(
                      'Reste: ${AppFormatters.formatCurrency(total - paid)}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  if (isCancelled)
                    const Text(
                      'Non comptabilisée',
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modale de Ticket de Caisse & Facture Détaillée ──
  void _showSaleReceiptDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> sale) async {
    final db = ref.read(mobileDatabaseProvider);
    final saleId = sale['id'] as String? ?? '';
    final refCode = sale['reference'] as String? ?? 'FAC';
    final isCancelled = sale['isCancelled'] as bool? ?? false;
    final total = (sale['totalAmount'] as num?)?.toInt() ?? 0;
    final amountPaid = (sale['amountPaid'] as num?)?.toInt() ?? total;
    final custName = sale['customerName'] as String? ?? 'Client Comptoir';
    final dateStr = sale['date'] as String? ?? '';
    final paymentMethod = sale['paymentMethod'] as String? ?? 'Espèces';

    // Charger les articles vendus
    final items = await (db.select(db.mobileSaleItems)..where((tbl) => tbl.saleId.equals(saleId))).get();

    // Charger la boutique
    final shops = await db.select(db.mobileShops).get();
    final shopName = shops.isNotEmpty ? shops.first.name : 'N\'MaShop';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.82,
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

              // En-tête du ticket
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shopName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      Text('Facture : $refCode', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.brandOrange)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? Colors.red.shade50
                          : (total > amountPaid ? AppColors.warning.withValues(alpha: 0.15) : AppColors.brandEmerald.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCancelled ? 'VENTE ANNULÉE' : (total > amountPaid ? 'CRÉDIT ENCOURS' : 'PAYÉ INTÉGRAL'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isCancelled ? AppColors.error : (total > amountPaid ? AppColors.warning : AppColors.brandEmerald),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Date & Heure :', style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                        Text(dateStr, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Client :', style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                        Text(custName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Caissier / Vendeur :', style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                        Text(sale['sellerName'] ?? 'Administrateur', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Règlement :', style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                        Text(paymentMethod, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.brandOrange)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text('DÉTAILS DES ARTICLES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8)),
              const SizedBox(height: 6),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Vente comptoir globale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(AppFormatters.formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 12),
                          itemBuilder: (ctx, idx) {
                            final item = items[idx];
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                                      Text('${item.quantity} x ${AppFormatters.formatCurrency(item.unitPrice)}', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Text(
                                  AppFormatters.formatCurrency(item.lineTotal),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // Synthèse Financière du Ticket
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.brandNavy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL FACTURE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(AppFormatters.formatCurrency(total), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant versé :', style: TextStyle(color: Colors.white60, fontSize: 11.5)),
                        Text(AppFormatters.formatCurrency(amountPaid), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (total > amountPaid) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reste à payer (Dette) :', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(AppFormatters.formatCurrency(total - amountPaid), style: const TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ] else if (amountPaid > total) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monnaie rendue :', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(AppFormatters.formatCurrency(amountPaid - total), style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Boutons d'Action (WhatsApp + Annulation)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareTicketWhatsApp(
                        context: context,
                        shopName: shopName,
                        refCode: refCode,
                        date: dateStr,
                        customerName: custName,
                        paymentMethod: paymentMethod,
                        total: total,
                        amountPaid: amountPaid,
                        items: items.map((i) => {'label': i.label, 'quantity': i.quantity, 'unitPrice': i.unitPrice, 'lineTotal': i.lineTotal}).toList(),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Partager WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (!isCancelled) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _confirmCancelSale(context, ref, saleId, refCode, items),
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                      label: const Text('Annuler', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Partage WhatsApp du ticket
  Future<void> _shareTicketWhatsApp({
    required BuildContext context,
    required String shopName,
    required String refCode,
    required String date,
    required String customerName,
    required String paymentMethod,
    required int total,
    required int amountPaid,
    required List<Map<String, dynamic>> items,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🧾 *TICKET DE CAISSE — $shopName*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📄 Facture : *$refCode*');
    buffer.writeln('📅 Date : $date');
    buffer.writeln('👤 Client : $customerName');
    buffer.writeln('💳 Paiement : $paymentMethod');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📦 *Articles :*');
    if (items.isEmpty) {
      buffer.writeln(' • Vente comptoir globale : *${AppFormatters.formatCurrency(total)}*');
    } else {
      for (final item in items) {
        final label = item['label'] ?? 'Article';
        final qty = item['quantity'] ?? 1;
        final price = (item['unitPrice'] as num?)?.toInt() ?? 0;
        final lineTot = (item['lineTotal'] as num?)?.toInt() ?? (price * qty as int);
        buffer.writeln(' • $label');
        buffer.writeln('   $qty x ${AppFormatters.formatCurrency(price)} = *${AppFormatters.formatCurrency(lineTot)}*');
      }
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *TOTAL : ${AppFormatters.formatCurrency(total)}*');
    buffer.writeln('💵 Versé : ${AppFormatters.formatCurrency(amountPaid)}');
    if (total > amountPaid) {
      buffer.writeln('⚠️ *Reste dû : ${AppFormatters.formatCurrency(total - amountPaid)}*');
    } else if (amountPaid > total) {
      buffer.writeln('🔄 Monnaie rendue : ${AppFormatters.formatCurrency(amountPaid - total)}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Merci pour votre fidélité ! À bientôt.');

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir l\'application WhatsApp.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du lancement de WhatsApp.')),
        );
      }
    }
  }

  // Confirmation et annulation d'une vente (remise en stock)
  void _confirmCancelSale(
    BuildContext context,
    WidgetRef ref,
    String saleId,
    String refCode,
    List<MobileSaleItem> items,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Annuler la vente ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment annuler la facture $refCode ?\n\n'
          'Les articles vendus seront réintégrés automatiquement dans votre stock et cette vente sera déduite du chiffre d\'affaires.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Non, fermer'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(mobileDatabaseProvider);

              // 1. Marquer la vente annulée
              await (db.update(db.mobileSales)..where((tbl) => tbl.id.equals(saleId))).write(
                const MobileSalesCompanion(isCancelled: drift.Value(true)),
              );

              // 2. Réintégrer le stock et tracer le mouvement inverse
              final now = DateTime.now();
              for (final item in items) {
                final product = await (db.select(db.mobileProducts)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
                if (product != null) {
                  final restoredQty = product.stockQuantity + item.quantity;
                  await (db.update(db.mobileProducts)..where((tbl) => tbl.id.equals(product.id))).write(
                    MobileProductsCompanion(stockQuantity: drift.Value(restoredQty)),
                  );

                  await db.into(db.mobileStockMovements).insert(
                    MobileStockMovementsCompanion.insert(
                      id: 'mvt-cancel-${now.millisecondsSinceEpoch}-${item.id}',
                      productId: product.id,
                      type: 2, // Réajustement / Restitution
                      quantity: item.quantity,
                      unitCost: drift.Value(item.unitCost),
                      sourceReference: drift.Value(refCode),
                      reason: drift.Value('Annulation vente $refCode'),
                      date: drift.Value(now),
                    ),
                  );
                }
              }

              // Invalider les fournisseurs de données
              ref.invalidate(salesDataProvider);
              ref.invalidate(stockDataProvider);
              ref.invalidate(treasuryDataProvider);
              ref.invalidate(receivablesDataProvider);

              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(); // Ferme dialogue confirmation
              if (context.mounted) {
                Navigator.of(context).pop(); // Ferme ticket
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Vente $refCode annulée et articles réintégrés en stock.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, annuler la vente'),
          ),
        ],
      ),
    );
  }

  // ── Modal de Saisie POS & Encaissement ──
  void _showAddSaleModal(BuildContext context, WidgetRef ref) async {
    final db = ref.read(mobileDatabaseProvider);
    final products = await db.select(db.mobileProducts).get();
    final customers = await db.select(db.mobileCustomers).get();

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
    final customerCtrl = TextEditingController(text: 'Client Comptoir');
    String itemSearchQuery = '';

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

          // Par défaut, si espèces et champ vide, montant payé = total
          int amountPaid = int.tryParse(amountPaidCtrl.text.replaceAll(' ', '').trim()) ?? (selectedPaymentMethod == 5 ? 0 : total);
          int changeToReturn = 0;
          if (selectedPaymentMethod == 0 && amountPaid > total) {
            changeToReturn = amountPaid - total;
          }

          final visibleProducts = products.where((p) {
            if (itemSearchQuery.isEmpty) return true;
            final q = itemSearchQuery.toLowerCase();
            return p.name.toLowerCase().contains(q) || (p.barcode ?? '').contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 16,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.brandOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.point_of_sale_rounded, color: AppColors.brandOrange, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CAISSE POS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.brandOrange, letterSpacing: 0.8)),
                            Text('Nouvelle Vente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                          ],
                        ),
                      ],
                    ),
                    if (cart.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setStateModal(() => cart.clear()),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.error),
                        label: const Text('Vider panier', style: TextStyle(color: AppColors.error, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Filtre de recherche d'articles
                TextField(
                  onChanged: (val) => setStateModal(() => itemSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Filtrer les articles du comptoir...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Sélection des articles
                Expanded(
                  child: visibleProducts.isEmpty
                      ? const Center(
                          child: Text('Aucun article ne correspond à la recherche', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        )
                      : ListView.separated(
                          itemCount: visibleProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final prod = visibleProducts[index];
                            final currentQtyInCart = cart[prod.id] ?? 0;
                            final availableStock = prod.stockQuantity;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: currentQtyInCart > 0 ? AppColors.brandOrange.withValues(alpha: 0.05) : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: currentQtyInCart > 0 ? AppColors.brandOrange : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.brandNavy)),
                                        Text(
                                          '${AppFormatters.formatCurrency(prod.salePrice)} • Dispo: $availableStock ${prod.unit}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: availableStock <= 0 ? AppColors.error : AppColors.onSurfaceVariant,
                                            fontWeight: availableStock <= 0 ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (currentQtyInCart > 0) ...[
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
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
                                        Text('$currentQtyInCart', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.brandEmerald, size: 22),
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

                // Client & Mode de paiement
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Client :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                          const SizedBox(height: 4),
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: customers.any((c) => c.name == selectedCustomerName) ? selectedCustomerName : 'Client Comptoir',
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                items: [
                                  const DropdownMenuItem(value: 'Client Comptoir', child: Text('Client Comptoir', style: TextStyle(fontSize: 12))),
                                  ...customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, style: const TextStyle(fontSize: 12)))),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setStateModal(() {
                                      selectedCustomerName = val;
                                      customerCtrl.text = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Règlement :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                          const SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildPaymentChip('Espèces', 0, selectedPaymentMethod, () => setStateModal(() => selectedPaymentMethod = 0)),
                                const SizedBox(width: 4),
                                _buildPaymentChip('Orange Money', 1, selectedPaymentMethod, () => setStateModal(() => selectedPaymentMethod = 1)),
                                const SizedBox(width: 4),
                                _buildPaymentChip('Wave', 2, selectedPaymentMethod, () => setStateModal(() => selectedPaymentMethod = 2)),
                                const SizedBox(width: 4),
                                _buildPaymentChip('Crédit', 5, selectedPaymentMethod, () => setStateModal(() => selectedPaymentMethod = 5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Calcul monnaie / acompte
                if (selectedPaymentMethod == 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountPaidCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Montant remis par le client (GNF)',
                            labelStyle: const TextStyle(fontSize: 11),
                            hintText: total.toString(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) => setStateModal(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: changeToReturn > 0 ? AppColors.brandEmerald.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Monnaie à rendre', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            Text(
                              AppFormatters.formatCurrency(changeToReturn),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: changeToReturn > 0 ? AppColors.brandEmerald : AppColors.brandNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Raccourcis de billets
                  Row(
                    children: [
                      _buildQuickMoneyChip('Total exact', total, setStateModal, amountPaidCtrl),
                      const SizedBox(width: 6),
                      _buildQuickMoneyChip('50 000', 50000, setStateModal, amountPaidCtrl),
                      const SizedBox(width: 6),
                      _buildQuickMoneyChip('100 000', 100000, setStateModal, amountPaidCtrl),
                      const SizedBox(width: 6),
                      _buildQuickMoneyChip('200 000', 200000, setStateModal, amountPaidCtrl),
                    ],
                  ),
                ] else if (selectedPaymentMethod == 5) ...[
                  TextField(
                    controller: amountPaidCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Acompte versé aujourd\'hui (facultatif)',
                      labelStyle: const TextStyle(fontSize: 11),
                      hintText: '0',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setStateModal(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reste dû par le client : ${AppFormatters.formatCurrency(total - amountPaid)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                  ),
                ],

                const SizedBox(height: 10),

                // Synthèse & Validation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.brandNavy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Net à Encaisser', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
                          Text(AppFormatters.formatCurrency(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                      Text('${cart.values.fold(0, (a, b) => a + b)} article(s)', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandOrangeLight)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: cart.isEmpty
                      ? null
                      : () async {
                          if (selectedPaymentMethod == 5 && selectedCustomerName == 'Client Comptoir') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez renseigner un client débiteur pour une vente à crédit !')),
                            );
                            return;
                          }

                          final now = DateTime.now();
                          final saleId = 'sale-${now.millisecondsSinceEpoch}';
                          final refCode = 'FAC-${now.millisecondsSinceEpoch % 10000}';

                          final actualPaid = selectedPaymentMethod == 0
                              ? (amountPaid >= total ? total : amountPaid)
                              : (selectedPaymentMethod == 5 ? amountPaid : total);

                          // 1. Insertion de la vente
                          final newSale = MobileSalesCompanion.insert(
                            id: saleId,
                            reference: refCode,
                            date: drift.Value(now),
                            total: drift.Value(total),
                            amountPaid: drift.Value(actualPaid),
                            paymentMethod: drift.Value(selectedPaymentMethod),
                            customerId: drift.Value(selectedCustomerName),
                            sellerName: const drift.Value('Administrateur'),
                          );
                          await db.into(db.mobileSales).insert(newSale);

                          // 2. Insertion des lignes de vente (SaleItems) et déduction stock + traçabilité
                          int itemIndex = 1;
                          for (final entry in cart.entries) {
                            final p = products.firstWhere((prod) => prod.id == entry.key);
                            final qty = entry.value;
                            final lineTot = p.salePrice * qty;

                            // Ligne de vente
                            await db.into(db.mobileSaleItems).insert(
                              MobileSaleItemsCompanion.insert(
                                id: 'item-${now.millisecondsSinceEpoch}-$itemIndex',
                                saleId: saleId,
                                productId: p.id,
                                label: p.name,
                                quantity: drift.Value(qty),
                                unitPrice: drift.Value(p.salePrice),
                                unitCost: drift.Value(p.purchasePrice),
                                lineTotal: drift.Value(lineTot),
                              ),
                            );

                            // Mouvement de stock
                            await db.into(db.mobileStockMovements).insert(
                              MobileStockMovementsCompanion.insert(
                                id: 'mvt-${now.millisecondsSinceEpoch}-$itemIndex',
                                productId: p.id,
                                type: 1, // Vente
                                quantity: -qty,
                                unitCost: drift.Value(p.purchasePrice),
                                sourceReference: drift.Value(refCode),
                                reason: drift.Value('Vente $refCode'),
                                date: drift.Value(now),
                              ),
                            );

                            // Déduire stock produit
                            final newQty = (p.stockQuantity - qty).clamp(0, 999999);
                            await (db.update(db.mobileProducts)..where((tbl) => tbl.id.equals(p.id))).write(
                              MobileProductsCompanion(stockQuantity: drift.Value(newQty)),
                            );

                            itemIndex++;
                          }

                          // 3. Si crédit client et client inexistant, création automatique du profil client
                          if (selectedPaymentMethod == 5 && !customers.any((c) => c.name.toLowerCase() == selectedCustomerName.toLowerCase())) {
                            await db.into(db.mobileCustomers).insert(
                              MobileCustomersCompanion.insert(
                                id: 'cust-${now.millisecondsSinceEpoch}',
                                name: selectedCustomerName,
                                phone: const drift.Value(''),
                                address: const drift.Value(''),
                              ),
                            );
                          }

                          // Invalider les fournisseurs pour mise à jour immédiate UI
                          ref.invalidate(salesDataProvider);
                          ref.invalidate(stockDataProvider);
                          ref.invalidate(treasuryDataProvider);
                          ref.invalidate(receivablesDataProvider);

                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();

                          // Ouvrir immédiatement le ticket numérique
                          if (context.mounted) {
                            String methodLabel = 'Espèces';
                            if (selectedPaymentMethod == 1) methodLabel = 'Orange Money';
                            if (selectedPaymentMethod == 2) methodLabel = 'Wave';
                            if (selectedPaymentMethod == 3) methodLabel = 'Moov Money';
                            if (selectedPaymentMethod == 5) methodLabel = 'Crédit Client';

                            _showSaleReceiptDialog(context, ref, {
                              'id': saleId,
                              'reference': refCode,
                              'date': AppFormatters.formatDateTime(now),
                              'customerName': selectedCustomerName,
                              'totalAmount': total,
                              'amountPaid': actualPaid,
                              'paymentMethod': methodLabel,
                              'sellerName': 'Administrateur',
                              'isCancelled': false,
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Valider & Générer le Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentChip(String label, int index, int selectedIndex, VoidCallback onSelect) {
    final isSelected = selectedIndex == index;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.brandNavy,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelect(),
      selectedColor: AppColors.brandNavy,
      backgroundColor: AppColors.surfaceVariant,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildQuickMoneyChip(String label, int amount, StateSetter setStateModal, TextEditingController ctrl) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setStateModal(() {
            ctrl.text = amount.toString();
          });
        },
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandNavy),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
