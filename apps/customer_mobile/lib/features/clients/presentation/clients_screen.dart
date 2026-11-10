import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';
import '../../receivables/presentation/receivables_screen.dart';

final clientSearchProvider = StateProvider<String>((ref) => '');

final clientsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(mobileDatabaseProvider);

  final customers = await db.select(db.mobileCustomers).get();
  final sales = await db.select(db.mobileSales).get();

  final list = <Map<String, dynamic>>[];

  for (final c in customers) {
    num totalPurchases = 0;
    num totalDebt = 0;
    int salesCount = 0;

    for (final s in sales) {
      if (s.isCancelled) continue;
      if (s.customerId == c.id || s.customerId == c.name) {
        totalPurchases += s.total;
        salesCount++;
        if (s.total > s.amountPaid) {
          totalDebt += (s.total - s.amountPaid);
        }
      }
    }

    list.add({
      'customer': c,
      'totalPurchases': totalPurchases,
      'totalDebt': totalDebt,
      'salesCount': salesCount,
    });
  }

  // Trier par montant d'achat décroissant
  list.sort((a, b) => (b['totalPurchases'] as num).compareTo(a['totalPurchases'] as num));
  return list;
});

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendWhatsApp(String phone, String name) async {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9 && clean.startsWith('6')) clean = '224$clean';
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent("Bonjour $name, merci de votre fidélité à notre boutique N\'MaShop.")}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsListProvider);
    final search = ref.watch(clientSearchProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: NmaMobileAppBar(
        title: 'Répertoire Clients',
        subtitle: 'Annuaire des clients & historique',
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(clientsListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_client',
        onPressed: () => _showAddClientModal(context, ref),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Nouveau Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (clients) {
          final filtered = clients.where((item) {
            final c = item['customer'] as MobileCustomer;
            final query = search.trim().toLowerCase();
            if (query.isEmpty) return true;
            return c.name.toLowerCase().contains(query) || (c.phone ?? '').contains(query);
          }).toList();

          return Column(
            children: [
              // Barre de recherche
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  onChanged: (val) => ref.read(clientSearchProvider.notifier).state = val,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client (nom ou numéro)...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.people_outline_rounded, size: 54, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text('Aucun client trouvé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brandNavy)),
                            SizedBox(height: 4),
                            Text('Appuyez sur "Nouveau Client" pour enrichir votre annuaire.', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final item = filtered[idx];
                          final c = item['customer'] as MobileCustomer;
                          final totalPurchases = item['totalPurchases'] as num;
                          final totalDebt = item['totalDebt'] as num;
                          final salesCount = item['salesCount'] as int;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.brandNavy.withValues(alpha: 0.1),
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.brandNavy),
                                          ),
                                          if (c.phone != null && c.phone!.isNotEmpty)
                                            Text(
                                              c.phone!,
                                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (c.phone != null && c.phone!.isNotEmpty) ...[
                                      IconButton(
                                        icon: const Icon(Icons.call_rounded, color: AppColors.brandEmerald, size: 20),
                                        onPressed: () => _makeCall(c.phone!),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
                                        onPressed: () => _sendWhatsApp(c.phone!, c.name),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: AppColors.border),
                                const SizedBox(height: 10),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Achats', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        Text(
                                          '${AppFormatters.formatCurrency(totalPurchases)} ($salesCount v.)',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Crédit en cours', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        Text(
                                          totalDebt > 0 ? AppFormatters.formatCurrency(totalDebt) : '0 GNF',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: totalDebt > 0 ? AppColors.warning : AppColors.brandEmerald,
                                          ),
                                        ),
                                      ],
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
          );
        },
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
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                labelText: 'Nom & Prénom du Client *',
                hintText: 'Ex: Amadou Bah',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Numéro de Téléphone',
                hintText: 'Ex: +224 620 00 00 00',
                prefixIcon: const Icon(Icons.phone_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: addressCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Adresse / Quartier',
                hintText: 'Ex: Kipé, Conakry',
                prefixIcon: const Icon(Icons.location_on_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez renseigner le nom du client.')));
                  return;
                }

                final db = ref.read(mobileDatabaseProvider);
                final id = 'cust-${DateTime.now().millisecondsSinceEpoch}';

                await db.into(db.mobileCustomers).insert(
                  MobileCustomersCompanion.insert(
                    id: id,
                    name: name,
                    phone: drift.Value(phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null),
                    address: drift.Value(addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null),
                  ),
                );

                ref.invalidate(clientsListProvider);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Client "$name" enregistré avec succès !'), backgroundColor: AppColors.brandEmerald),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Enregistrer le Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

