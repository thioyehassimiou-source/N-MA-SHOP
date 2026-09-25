import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';
import '../../sales/presentation/sales_screen.dart';
import '../../treasury/presentation/treasury_screen.dart';

final receivablesSearchProvider = StateProvider<String>((ref) => '');

final receivablesDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);

  List<MobileCustomer> customers = await db.select(db.mobileCustomers).get();
  List<MobileSale> sales = await db.select(db.mobileSales).get();

  // Si aucun client en BDD au premier démarrage, insérer 2 échantillons avec de réelles ventes à crédit
  if (customers.isEmpty) {
    final now = DateTime.now();
    final c1 = MobileCustomersCompanion.insert(
      id: 'cust-${now.millisecondsSinceEpoch}-1',
      name: 'Mamadou Diallo',
      phone: const drift.Value('622102030'),
      address: const drift.Value('Kaloum, Conakry'),
    );
    final c2 = MobileCustomersCompanion.insert(
      id: 'cust-${now.millisecondsSinceEpoch}-2',
      name: 'Elhadj Oumar Camara',
      phone: const drift.Value('628445566'),
      address: const drift.Value('Dixinn, Conakry'),
    );
    await db.into(db.mobileCustomers).insert(c1);
    await db.into(db.mobileCustomers).insert(c2);

    // Ventes à crédit échantillon en base
    final saleCredit1 = MobileSalesCompanion.insert(
      id: 'sale-init-cred-1',
      reference: 'FAC-CRED-01',
      customerId: const drift.Value('Mamadou Diallo'),
      date: drift.Value(now.subtract(const Duration(days: 2))),
      total: const drift.Value(125000),
      amountPaid: const drift.Value(40000), // Reste 85 000 GNF
      paymentMethod: const drift.Value(5),
      sellerName: const drift.Value('Administrateur'),
    );
    final saleCredit2 = MobileSalesCompanion.insert(
      id: 'sale-init-cred-2',
      reference: 'FAC-CRED-02',
      customerId: const drift.Value('Elhadj Oumar Camara'),
      date: drift.Value(now.subtract(const Duration(days: 4))),
      total: const drift.Value(150000),
      amountPaid: const drift.Value(0), // Reste 150 000 GNF
      paymentMethod: const drift.Value(5),
      sellerName: const drift.Value('Administrateur'),
    );
    await db.into(db.mobileSales).insert(saleCredit1);
    await db.into(db.mobileSales).insert(saleCredit2);

    customers = await db.select(db.mobileCustomers).get();
    sales = await db.select(db.mobileSales).get();
  }

  // Calcul dynamique et rigoureux des créances réelles
  num totalReceivables = 0;
  final debtorsMap = <String, Map<String, dynamic>>{};

  for (final c in customers) {
    debtorsMap[c.name] = {
      'id': c.id,
      'name': c.name,
      'phone': c.phone ?? '',
      'address': c.address ?? '',
      'debtAmount': 0,
      'lastPurchaseDate': AppFormatters.formatDateTime(c.createdAt),
      'unpaidSalesCount': 0,
    };
  }

  // Agréger les dettes réelles des ventes non annulées
  for (final s in sales) {
    if (s.isCancelled) continue;
    if (s.customerId != null && s.total > s.amountPaid) {
      final debt = s.total - s.amountPaid;
      if (!debtorsMap.containsKey(s.customerId)) {
        debtorsMap[s.customerId!] = {
          'id': s.customerId,
          'name': s.customerId,
          'phone': '',
          'address': '',
          'debtAmount': 0,
          'lastPurchaseDate': AppFormatters.formatDateTime(s.date),
          'unpaidSalesCount': 0,
        };
      }
      debtorsMap[s.customerId!]!['debtAmount'] = (debtorsMap[s.customerId!]!['debtAmount'] as num) + debt;
      debtorsMap[s.customerId!]!['unpaidSalesCount'] = (debtorsMap[s.customerId!]!['unpaidSalesCount'] as int) + 1;
      debtorsMap[s.customerId!]!['lastPurchaseDate'] = AppFormatters.formatDateTime(s.date);
    }
  }

  // Ne garder que les clients ayant une dette strictement positive
  final debtorsList = debtorsMap.values.where((d) => (d['debtAmount'] as num) > 0).toList();
  debtorsList.sort((a, b) => (b['debtAmount'] as num).compareTo(a['debtAmount'] as num));

  for (final d in debtorsList) {
    totalReceivables += (d['debtAmount'] as num);
  }

  return {
    'totalReceivables': totalReceivables,
    'debtors': debtorsList,
  };
});

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  Future<void> _makeCall(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de composer le numéro $phone')),
      );
    }
  }

  Future<void> _sendWhatsApp(BuildContext context, String phone, String name, num debt) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 9 && cleanPhone.startsWith('6')) {
      cleanPhone = '224$cleanPhone';
    }
    final formattedDebt = AppFormatters.formatCurrency(debt);
    final text = Uri.encodeComponent(
      'Bonjour $name,\nSauf erreur de notre part, vous avez un encours de crédit de $formattedDebt auprès de notre boutique N\'MaShop.\nMerci de bien vouloir nous contacter pour convenir d\'un règlement.',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp non disponible pour le numéro $phone')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du lancement de WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivablesAsync = ref.watch(receivablesDataProvider);
    final search = ref.watch(receivablesSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NmaMobileAppBar(
        title: 'Créances & Crédits Clients',
        subtitle: 'Suivi des impayés & règlements',
        onLeadingPressed: () => Navigator.of(context).maybePop(),
        leadingIcon: Icons.arrow_back_rounded,
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(receivablesDataProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_receivables',
        onPressed: () => _showAddPaymentModal(context, ref),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.price_check_rounded, color: Colors.white),
        label: const Text(
          'Encaisser Dette',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: receivablesAsync.when(
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
                onPressed: () => ref.invalidate(receivablesDataProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (data) {
          final totalReceivables = data['totalReceivables'] ?? 0;
          final debtors = (data['debtors'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          final query = search.trim().toLowerCase();
          final filteredDebtors = debtors.where((d) {
            if (query.isEmpty) return true;
            final name = (d['name'] as String? ?? '').toLowerCase();
            final phone = (d['phone'] as String? ?? '').toLowerCase();
            return name.contains(query) || phone.contains(query);
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Valorisation des créances dehors
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB45309), AppColors.brandOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandOrange.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL CRÉANCES CLIENTS (ARGENT DEHORS)', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${debtors.length} débiteur(s)', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppFormatters.formatCurrency(totalReceivables),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Règlements décomptés en direct (FIFO) & relances WhatsApp en 1-clic',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Barre de recherche client
              TextField(
                onChanged: (val) => ref.read(receivablesSearchProvider.notifier).state = val,
                decoration: InputDecoration(
                  hintText: 'Rechercher un client débiteur, téléphone...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                          onPressed: () => ref.read(receivablesSearchProvider.notifier).state = '',
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
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CARNET DES CLIENTS DÉBITEURS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddClientModal(context, ref),
                    icon: const Icon(Icons.person_add_rounded, size: 16, color: AppColors.brandOrange),
                    label: const Text('Nouveau Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandOrange)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (filteredDebtors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.check_circle_outline_rounded, size: 40, color: AppColors.brandEmerald),
                      SizedBox(height: 8),
                      Text('Aucune créance en cours ! Tout est réglé.', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDebtors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final debtor = filteredDebtors[index];
                    return _buildDebtorCard(context, ref, debtor);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDebtorCard(BuildContext context, WidgetRef ref, Map<String, dynamic> debtor) {
    final name = debtor['name'] as String? ?? '';
    final phone = debtor['phone'] as String? ?? '';
    final debtAmount = (debtor['debtAmount'] as num?) ?? 0;
    final unpaidCount = (debtor['unpaidSalesCount'] as int?) ?? 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDebtorDetailModal(context, ref, debtor),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.brandNavy),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      phone.isNotEmpty ? '$phone • $unpaidCount impayé(s)' : '$unpaidCount facture(s) impayée(s)',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatCurrency(debtAmount),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.warning),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (phone.isNotEmpty) ...[
                        InkWell(
                          onTap: () => _makeCall(context, phone),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.brandNavy.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone, size: 14, color: AppColors.brandNavy),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _sendWhatsApp(context, phone, name, debtAmount),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.brandEmerald.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.brandEmerald),
                          ),
                        ),
                      ],
                    ],
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

  // ── Fiche Détaillée & Historique Créances du Client ──
  void _showDebtorDetailModal(BuildContext context, WidgetRef ref, Map<String, dynamic> debtor) async {
    final db = ref.read(mobileDatabaseProvider);
    final customerName = debtor['name'] as String;
    final phone = debtor['phone'] as String? ?? '';
    final address = debtor['address'] as String? ?? '';
    final totalDebt = (debtor['debtAmount'] as num?)?.toInt() ?? 0;

    // Charger toutes les ventes de ce client
    final clientSales = await (db.select(db.mobileSales)
          ..where((tbl) => tbl.customerId.equals(customerName) & tbl.isCancelled.equals(false))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.date)]))
        .get();

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

              // En-tête Client
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.brandNavy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                          Text(phone.isNotEmpty ? phone : (address.isNotEmpty ? address : 'Client sans contact'), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('DÉBITEUR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.warning)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Synthèse de dette
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB45309), AppColors.brandOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ENCOURS ACTUEL DÛ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(AppFormatters.formatCurrency(totalDebt), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showAddPaymentModal(context, ref, initialCustomerName: customerName, maxDebt: totalDebt);
                      },
                      icon: const Icon(Icons.payments_rounded, size: 16),
                      label: const Text('Encaisser', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.brandOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Raccourcis Relance
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: phone.isNotEmpty ? () => _makeCall(context, phone) : null,
                      icon: const Icon(Icons.phone, size: 16, color: AppColors.brandNavy),
                      label: const Text('Appeler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: phone.isNotEmpty ? () => _sendWhatsApp(context, phone, customerName, totalDebt) : null,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                      label: const Text('Rappel WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text('HISTORIQUE DES FACTURES DU CLIENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandNavy, letterSpacing: 0.8)),
              const SizedBox(height: 8),

              Expanded(
                child: clientSales.isEmpty
                    ? const Center(child: Text('Aucune facture enregistrée', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                    : ListView.separated(
                        itemCount: clientSales.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final s = clientSales[idx];
                          final isFullyPaid = s.amountPaid >= s.total;
                          final dueOnSale = s.total - s.amountPaid;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isFullyPaid ? AppColors.border : AppColors.warning.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isFullyPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                  color: isFullyPaid ? AppColors.brandEmerald : AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy)),
                                      Text(AppFormatters.formatDateTime(s.date), style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(AppFormatters.formatCurrency(s.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(
                                      isFullyPaid ? 'Soldé intégralement' : 'Reste : ${AppFormatters.formatCurrency(dueOnSale)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isFullyPaid ? FontWeight.normal : FontWeight.bold,
                                        color: isFullyPaid ? AppColors.brandEmerald : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Modal de Création Client ──
  void _showAddClientModal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              const Text('Nouveau Client', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nom Complet du Client *',
                  hintText: 'ex: Mamadou Diallo',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de Téléphone',
                  hintText: 'ex: 622 10 20 30',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Adresse / Quartier',
                  hintText: 'ex: Kaloum, Conakry',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final db = ref.read(mobileDatabaseProvider);
                  final newCust = MobileCustomersCompanion.insert(
                    id: 'cust-${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    phone: drift.Value(phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null),
                    address: drift.Value(addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null),
                  );
                  await db.into(db.mobileCustomers).insert(newCust);
                  ref.invalidate(receivablesDataProvider);

                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enregistrer le client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modal de Règlement de Crédit (Algorithme FIFO rigoureux) ──
  void _showAddPaymentModal(
    BuildContext context,
    WidgetRef ref, {
    String? initialCustomerName,
    int? maxDebt,
  }) async {
    final db = ref.read(mobileDatabaseProvider);
    final customers = await db.select(db.mobileCustomers).get();

    if (!context.mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord enregistrer des clients.')),
      );
      return;
    }

    String selectedCustName = initialCustomerName ?? customers.first.name;
    final amountCtrl = TextEditingController(text: maxDebt != null && maxDebt > 0 ? maxDebt.toString() : '');
    int paymentMethod = 0; // 0: Espèces, 1: Orange Money, 2: Wave

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
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
                  const Row(
                    children: [
                      Icon(Icons.price_check_rounded, color: AppColors.brandOrange, size: 22),
                      SizedBox(width: 8),
                      Text('Règlement de Créance (FIFO)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: customers.any((c) => c.name == selectedCustName) ? selectedCustName : customers.first.name,
                    decoration: InputDecoration(
                      labelText: 'Client Débiteur',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedCustName = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Mode de paiement
                  const Text('Mode d\'encaissement :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildPaymentChip('Espèces', 0, paymentMethod, () => setStateModal(() => paymentMethod = 0)),
                      const SizedBox(width: 6),
                      _buildPaymentChip('Orange Money', 1, paymentMethod, () => setStateModal(() => paymentMethod = 1)),
                      const SizedBox(width: 6),
                      _buildPaymentChip('Wave', 2, paymentMethod, () => setStateModal(() => paymentMethod = 2)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Montant versé par le client (GNF) *',
                      hintText: 'ex: 50000',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (maxDebt != null && maxDebt > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setStateModal(() => amountCtrl.text = maxDebt.toString()),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: Text('Régler la totalité (${AppFormatters.formatCurrency(maxDebt)})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 14),

                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountCtrl.text.replaceAll(' ', '').trim()) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez saisir un montant valide.')),
                        );
                        return;
                      }

                      final now = DateTime.now();

                      // 1. Récupérer les ventes dues de ce client des plus anciennes aux plus récentes (FIFO)
                      final openSales = await (db.select(db.mobileSales)
                            ..where((tbl) => tbl.customerId.equals(selectedCustName) & tbl.isCancelled.equals(false) & tbl.total.isBiggerThan(tbl.amountPaid))
                            ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.date)]))
                          .get();

                      if (openSales.isEmpty) {
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Le client $selectedCustName n\'a aucune facture impayée.')),
                        );
                        return;
                      }

                      // 2. Déduire le montant de remboursement sur les ventes (FIFO)
                      int remainingPayment = amount;
                      for (final sale in openSales) {
                        if (remainingPayment <= 0) break;
                        final dueOnSale = sale.total - sale.amountPaid;

                        if (remainingPayment >= dueOnSale) {
                          // Facture soldée intégralement
                          await (db.update(db.mobileSales)..where((tbl) => tbl.id.equals(sale.id))).write(
                            MobileSalesCompanion(amountPaid: drift.Value(sale.total)),
                          );
                          remainingPayment -= dueOnSale;
                        } else {
                          // Règlement partiel sur cette facture
                          await (db.update(db.mobileSales)..where((tbl) => tbl.id.equals(sale.id))).write(
                            MobileSalesCompanion(amountPaid: drift.Value(sale.amountPaid + remainingPayment)),
                          );
                          remainingPayment = 0;
                        }
                      }

                      // 3. Enregistrer la trace de versement dans la caisse sans gonfler le CA (total = 0, amountPaid = amount)
                      final receiptRef = 'REG-${now.millisecondsSinceEpoch % 10000}';
                      await db.into(db.mobileSales).insert(
                        MobileSalesCompanion.insert(
                          id: 'pmt-${now.millisecondsSinceEpoch}',
                          reference: receiptRef,
                          date: drift.Value(now),
                          total: const drift.Value(0), // CA déjà compté lors de la vente initiale
                          amountPaid: drift.Value(amount), // Encaissé aujourd'hui dans la caisse
                          paymentMethod: drift.Value(paymentMethod),
                          customerId: drift.Value(selectedCustName),
                          sellerName: const drift.Value('Administrateur'),
                          note: drift.Value('Règlement de dette client ($selectedCustName)'),
                        ),
                      );

                      // Invalidation des providers
                      ref.invalidate(receivablesDataProvider);
                      ref.invalidate(salesDataProvider);
                      ref.invalidate(treasuryDataProvider);

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Règlement de ${AppFormatters.formatCurrency(amount)} déduit avec succès pour $selectedCustName !'),
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
                    child: const Text('Confirmer le Règlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentChip(String label, int index, int selectedIndex, VoidCallback onSelect) {
    final isSelected = index == selectedIndex;
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
}
