import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

final salesPeriodProvider = StateProvider<String>((ref) => 'today');
final salesSearchProvider = StateProvider<String>((ref) => '');

final customSalesProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

final salesDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final period = ref.watch(salesPeriodProvider);
  final addedSales = ref.watch(customSalesProvider);
  
  Map<String, dynamic> baseData;
  try {
    final res = await apiClient.get('/api/v1/mobile/sales', queryParameters: {'period': period});
    baseData = res.data as Map<String, dynamic>;
  } catch (_) {
    baseData = {
      'summary': {
        'totalSales': 0,
        'totalProfit': 0,
        'salesCount': 0,
        'averageTicket': 0,
        'cashCollected': 0,
        'momoCollected': 0,
        'creditIssued': 0,
      },
      'recentSales': [],
    };
  }

  if (addedSales.isNotEmpty) {
    final summary = {
      'totalSales': 0,
      'totalProfit': 0,
      'salesCount': 0,
      'averageTicket': 0,
      'cashCollected': 0,
      'momoCollected': 0,
      'creditIssued': 0,
    };
    final recent = List<Map<String, dynamic>>.from(addedSales);
    
    int totalAmt = 0;
    int cash = 0;
    int momo = 0;
    int credit = 0;

    for (final newSale in addedSales) {
      final amt = ((newSale['totalAmount'] as num?) ?? 0).toInt();
      final paid = ((newSale['amountPaid'] as num?) ?? amt).toInt();
      final pIndex = newSale['paymentMethodIndex'] ?? 0;
      
      totalAmt += amt;
      
      if (pIndex == 0) {
        cash += paid;
      } else if (pIndex == 1) {
        momo += paid;
      } else if (pIndex == 2) {
        credit += (amt - paid);
      }
    }
    
    summary['totalSales'] = totalAmt;
    summary['salesCount'] = addedSales.length;
    summary['averageTicket'] = addedSales.isNotEmpty ? (totalAmt / addedSales.length).round() : 0;
    summary['cashCollected'] = cash;
    summary['momoCollected'] = momo;
    summary['creditIssued'] = credit;
    
    baseData['summary'] = summary;
    baseData['recentSales'] = recent;
  }
  
  return baseData;
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.invalidate(salesDataProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
          // Sélecteur de période et barre de recherche
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
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text('Données indisponibles ($err)', style: const TextStyle(color: AppColors.onSurfaceVariant)),
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
                final recentSales = (data['recentSales'] as List?)?.cast<Map<String, dynamic>>() ?? [];

                final query = search.trim().toLowerCase();
                final filteredSales = recentSales.where((s) {
                  if (query.isEmpty) return true;
                  final refStr = (s['reference'] as String? ?? '').toLowerCase();
                  final custStr = (s['customerName'] as String? ?? '').toLowerCase();
                  return refStr.contains(query) || custStr.contains(query);
                }).toList();

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(salesDataProvider),
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Cartouche Synthèse
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total des ventes', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                                Text(
                                  '${summary['salesCount'] ?? 0} transaction(s)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppFormatters.formatCurrency(summary['totalSales'] ?? 0),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetricColumn('Marge brute', summary['totalProfit'] ?? 0, AppColors.success),
                                _buildMetricColumn('Panier moyen', summary['averageTicket'] ?? 0, AppColors.brandNavy),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 14),

                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'RÉPARTITION DES ENCAISSEMENTS',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.onSurfaceVariant, letterSpacing: 0.8),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildPaymentRow('Espèces en caisse', summary['cashCollected'] ?? 0, Icons.payments_outlined, Colors.blue),
                            const SizedBox(height: 10),
                            _buildPaymentRow('Mobile Money', summary['momoCollected'] ?? 0, Icons.phone_android_rounded, AppColors.brandOrange),
                            const SizedBox(height: 10),
                            _buildPaymentRow('Ventes à crédit', summary['creditIssued'] ?? 0, Icons.assignment_outlined, Colors.purple),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Liste des transactions récentes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dernières ventes enregistrées',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                          Text(
                            '${filteredSales.length} trouvée(s)',
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (filteredSales.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          margin: const EdgeInsets.only(top: 20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                query.isNotEmpty
                                    ? 'Aucune vente ne correspond à "$search".'
                                    : 'Aucune vente enregistrée',
                                style: const TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Les ventes de la boutique apparaîtront ici\ndès la prochaine synchronisation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredSales.map((sale) => _buildSaleTile(context, sale)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(WidgetRef ref, String label, String value, String current) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(salesPeriodProvider.notifier).state = value,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildMetricColumn(String label, num amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
          AppFormatters.formatCurrency(amount),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, num amount, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onSurface))),
        Text(
          AppFormatters.formatCurrency(amount),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
      ],
    );
  }

  Widget _buildSaleTile(BuildContext context, Map<String, dynamic> sale) {
    final methodIndex = sale['paymentMethodIndex'] ?? 0;
    final methodLabel = methodIndex == 0
        ? 'Espèces'
        : methodIndex == 1
            ? 'Mobile Money'
            : methodIndex == 2
                ? 'Crédit'
                : 'Banque';

    final total = sale['totalAmount'] ?? 0;
    final date = DateTime.tryParse(sale['createdAt'] ?? '') ?? DateTime.now();

    return InkWell(
      onTap: () => _showSaleDetailsModal(context, sale),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: methodIndex == 0
                        ? Colors.blue.withValues(alpha: 0.1)
                        : methodIndex == 1
                            ? AppColors.brandOrange.withValues(alpha: 0.1)
                            : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    methodIndex == 0
                        ? Icons.payments_outlined
                        : methodIndex == 1
                            ? Icons.phone_android_rounded
                            : Icons.assignment_outlined,
                    size: 18,
                    color: methodIndex == 0
                        ? Colors.blue
                        : methodIndex == 1
                            ? AppColors.brandOrange
                            : Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale['reference'] ?? 'VENTE',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sale['customerName'] ?? 'Client standard'} • $methodLabel',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.formatCurrency(total),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.formatTime(date),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSaleDetailsModal(BuildContext context, Map<String, dynamic> sale) {
    final methodIndex = sale['paymentMethodIndex'] ?? 0;
    final methodLabel = methodIndex == 0
        ? 'Espèces en tiroir'
        : methodIndex == 1
            ? 'Mobile Money'
            : methodIndex == 2
                ? 'Vente à crédit'
                : 'Virement bancaire';

    final total = sale['totalAmount'] ?? 0;
    final paid = sale['amountPaid'] ?? total;
    final remaining = total > paid ? total - paid : 0;
    final date = DateTime.tryParse(sale['createdAt'] ?? '') ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Entête du ticket
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TICKET DE CAISSE NUMÉRIQUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandOrange,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sale['reference'] ?? 'VENTE',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onSurface),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Encaissé',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),

            // Informations de la transaction
            _buildDetailRow('Date & Heure', '${AppFormatters.formatRelativeTime(date)} (${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')})'),
            _buildDetailRow('Client', sale['customerName'] ?? 'Client standard'),
            _buildDetailRow('Mode de règlement', methodLabel),
            if (sale['mobileMoneyProvider'] != null)
              _buildDetailRow('Opérateur', sale['mobileMoneyProvider']),

            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),

            // Montants
            _buildDetailRow('Montant Total', AppFormatters.formatCurrency(total), isBold: true),
            _buildDetailRow('Montant Versé', AppFormatters.formatCurrency(paid)),
            if (remaining > 0)
              _buildDetailRow('Reste dû (Crédit)', AppFormatters.formatCurrency(remaining), color: AppColors.error),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onSurface,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Fermer le ticket', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSaleModal(BuildContext context, WidgetRef ref) {
    final clientCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    int selectedMethod = 0; // 0: Espèces, 1: Mobile Money, 2: Crédit

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.brandOrange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NOUVELLE VENTE POS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandOrange, letterSpacing: 1.0)),
                          Text('Saisir une transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: clientCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nom du Client / Client Comptoir',
                      hintText: 'ex: Ousmane Sow',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Montant de la vente (GNF)',
                      hintText: 'ex: 150000',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Mode de Règlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Espèces'),
                          selected: selectedMethod == 0,
                          onSelected: (_) => setState(() => selectedMethod = 0),
                          selectedColor: AppColors.brandNavy,
                          labelStyle: TextStyle(color: selectedMethod == 0 ? Colors.white : AppColors.brandNavy, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Mobile Money'),
                          selected: selectedMethod == 1,
                          onSelected: (_) => setState(() => selectedMethod = 1),
                          selectedColor: AppColors.brandOrange,
                          labelStyle: TextStyle(color: selectedMethod == 1 ? Colors.white : AppColors.brandNavy, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Crédit'),
                          selected: selectedMethod == 2,
                          onSelected: (_) => setState(() => selectedMethod = 2),
                          selectedColor: Colors.purple,
                          labelStyle: TextStyle(color: selectedMethod == 2 ? Colors.white : AppColors.brandNavy, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () {
                      final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez saisir un montant valide (> 0 GNF)')),
                        );
                        return;
                      }

                      final clientName = clientCtrl.text.trim().isNotEmpty ? clientCtrl.text.trim() : 'Client Comptoir';
                      final refNum = 'FAC-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';

                      final newSale = {
                        'id': 'sale-${DateTime.now().millisecondsSinceEpoch}',
                        'reference': refNum,
                        'customerName': clientName,
                        'totalAmount': amount,
                        'amountPaid': selectedMethod == 2 ? 0 : amount,
                        'paymentMethodIndex': selectedMethod,
                        'createdAt': DateTime.now().toIso8601String(),
                      };

                      ref.read(customSalesProvider.notifier).update((state) => [newSale, ...state]);
                      ref.invalidate(salesDataProvider);

                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vente $refNum de ${AppFormatters.formatCurrency(amount)} enregistrée avec succès !'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enregistrer la vente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

