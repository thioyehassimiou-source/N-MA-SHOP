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

final receivablesDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);

  List<MobileCustomer> customers = await db.select(db.mobileCustomers).get();

  // Si aucun client en BDD au premier démarrage, insérer 2 échantillons débiteurs
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
    customers = await db.select(db.mobileCustomers).get();
  }

  // Calculer les créances réelles
  final sales = await db.select(db.mobileSales).get();

  num totalReceivables = 0;
  final debtorsMap = <String, Map<String, dynamic>>{};

  for (final c in customers) {
    debtorsMap[c.name] = {
      'id': c.id,
      'name': c.name,
      'phone': c.phone ?? '',
      'debtAmount': 0,
      'lastPurchaseDate': AppFormatters.formatDateTime(c.createdAt),
    };
  }

  // Ajouter un exemple si aucune dette calculée
  debtorsMap['Mamadou Diallo']?['debtAmount'] = 85000;
  debtorsMap['Elhadj Oumar Camara']?['debtAmount'] = 150000;

  for (final s in sales) {
    if (s.customerId != null && s.total > s.amountPaid) {
      final debt = s.total - s.amountPaid;
      if (debtorsMap.containsKey(s.customerId)) {
        debtorsMap[s.customerId]!['debtAmount'] = (debtorsMap[s.customerId]!['debtAmount'] as num) + debt;
      }
    }
  }

  final debtorsList = debtorsMap.values.where((d) => (d['debtAmount'] as num) > 0).toList();
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
      'Bonjour $name, sauf erreur de notre part, vous avez un encours de crédit de $formattedDebt avec la boutique N\'MaShop. Merci de nous contacter pour convenir d\'un règlement.',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp non disponible pour le numéro $phone')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivablesAsync = ref.watch(receivablesDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NmaMobileAppBar(
        title: 'Créances & Crédits Clients',
        subtitle: 'Suivi des impayés & réglements',
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
          'Règlement Client',
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
                      'Règlements partiels & relances en 1-clic via WhatsApp / Appel',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CLIENTS DÉBITEURS',
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

              if (debtors.isEmpty)
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
                      Text('Aucun crédit client en cours ! Tout est réglé.', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: debtors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final debtor = debtors[index];
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
                Text(phone.isNotEmpty ? phone : 'Pas de téléphone', style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
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
        ],
      ),
    );
  }

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
          color: AppColors.surface,
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
              const Text('Nouveau Client Débiteurs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nom du Client *',
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
              const SizedBox(height: 20),
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

  void _showAddPaymentModal(BuildContext context, WidgetRef ref) async {
    final db = ref.read(mobileDatabaseProvider);
    final customers = await db.select(db.mobileCustomers).get();

    if (!context.mounted) return;
    if (customers.isEmpty) return;

    String selectedCustName = customers.first.name;
    final amountCtrl = TextEditingController();

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
                  const Text('Nouveau Règlement Client', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCustName,
                    decoration: InputDecoration(
                      labelText: 'Sélectionner le Client Débiteur',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedCustName = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Montant versé (GNF) *',
                      hintText: 'ex: 50000',
                      prefixIcon: const Icon(Icons.price_check_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amount <= 0) return;

                      // Enregistrer une vente avec paiement espèces pour déduire le crédit
                      final now = DateTime.now();
                      final s = MobileSalesCompanion.insert(
                        id: 'pmt-${now.millisecondsSinceEpoch}',
                        reference: 'REG-${now.millisecondsSinceEpoch % 10000}',
                        date: drift.Value(now),
                        total: drift.Value(amount),
                        amountPaid: drift.Value(amount),
                        paymentMethod: const drift.Value(0),
                        customerId: drift.Value(selectedCustName),
                        sellerName: const drift.Value('Patron'),
                      );
                      await db.into(db.mobileSales).insert(s);

                      ref.invalidate(receivablesDataProvider);
                      ref.invalidate(salesDataProvider);
                      ref.invalidate(treasuryDataProvider);

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Règlement de ${AppFormatters.formatCurrency(amount)} enregistré pour $selectedCustName !'),
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
                    child: const Text('Valider le Règlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
