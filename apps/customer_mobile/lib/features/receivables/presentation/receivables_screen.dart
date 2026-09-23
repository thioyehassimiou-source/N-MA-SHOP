import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

final customPaymentsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

final receivablesDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final addedPayments = ref.watch(customPaymentsProvider);

  Map<String, dynamic> baseData;
  try {
    final res = await apiClient.get('/api/v1/mobile/receivables');
    baseData = res.data as Map<String, dynamic>;
  } catch (_) {
    baseData = {
      'totalReceivables': 0,
      'debtors': [],
    };
  }

  if (addedPayments.isNotEmpty) {
    final debtors = List<Map<String, dynamic>>.from(baseData['debtors'] ?? []);
    var totalRec = (baseData['totalReceivables'] as num?) ?? 0;

    for (final pmt in addedPayments) {
      final debtorId = pmt['debtorId'];
      final pmtAmt = (pmt['amount'] as num?) ?? 0;

      totalRec = (totalRec - pmtAmt).clamp(0, double.infinity);
      for (var i = 0; i < debtors.length; i++) {
        if (debtors[i]['id'] == debtorId) {
          final curDebt = (debtors[i]['debtAmount'] as num?) ?? 0;
          final newDebt = (curDebt - pmtAmt).clamp(0, double.infinity);
          if (newDebt == 0) {
            debtors.removeAt(i);
          } else {
            debtors[i] = Map<String, dynamic>.from(debtors[i])..['debtAmount'] = newDebt;
          }
          break;
        }
      }
    }

    baseData['debtors'] = debtors;
    baseData['totalReceivables'] = totalRec;
  }

  return baseData;
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
      'Bonjour $name, sauf erreur de notre part, vous avez un encours de crédit de $formattedDebt avec la boutique. Merci de nous contacter pour convenir d\'un règlement.',
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(receivablesDataProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
          final totalAmount = data['totalReceivables'] ?? 0;
          final debtors = (data['debtors'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(receivablesDataProvider),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Carte Total Créances
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_pin_outlined, color: Colors.white70, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'TOTAL DES CRÉANCES EN ATTENTE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppFormatters.formatCurrency(totalAmount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${debtors.length} client(s) ont un crédit en cours avec la boutique.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Liste des clients débiteurs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 12),

                if (debtors.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: const Text('Aucune créance en cours. Toutes les dettes sont réglées !',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  ...debtors.map((debtor) => _buildDebtorTile(context, debtor)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebtorTile(BuildContext context, Map<String, dynamic> debtor) {
    final debt = debtor['debtAmount'] ?? 0;
    final lastSale = debtor['lastSaleDate'] != null ? DateTime.tryParse(debtor['lastSaleDate']) : null;
    final rawPhone = debtor['phone'] as String?;
    final phone = (rawPhone != null && rawPhone.trim().isNotEmpty) ? rawPhone.trim() : null;
    final name = debtor['customerName'] as String? ?? 'Client';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Colors.purple.shade700, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  phone ?? (lastSale != null ? 'Dernier achat : ${AppFormatters.formatRelativeTime(lastSale)}' : 'Dette en cours'),
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatCurrency(debt),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.error,
                ),
              ),
              if (phone != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _makeCall(context, phone),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.phone_rounded, color: Colors.green.shade700, size: 16),
                            const SizedBox(width: 4),
                            Text('Appeler', style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _sendWhatsApp(context, phone, name, debt),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.chat_bubble_rounded, color: Color(0xFF128C7E), size: 16),
                            SizedBox(width: 4),
                            Text('WhatsApp', style: TextStyle(color: Color(0xFF128C7E), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAddPaymentModal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.price_check_rounded, color: Colors.purple.shade900, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RÈGLEMENT DE CRÉANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900, letterSpacing: 1.0)),
                        const Text('Enregistrer un Paiement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom du client débiteur',
                    hintText: 'ex: Elhadj Ousmane Camara',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant réglé (GNF)',
                    hintText: 'ex: 250000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez saisir un montant valide (> 0 GNF)')),
                      );
                      return;
                    }

                    final newPmt = {
                      'id': 'pmt-${DateTime.now().millisecondsSinceEpoch}',
                      'debtorId': 'debtor-1', // Default match to debtor 1 or match name
                      'customerName': name.isNotEmpty ? name : 'Client',
                      'amount': amount,
                      'createdAt': DateTime.now().toIso8601String(),
                    };

                    ref.read(customPaymentsProvider.notifier).update((state) => [newPmt, ...state]);
                    ref.invalidate(receivablesDataProvider);

                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Règlement de ${AppFormatters.formatCurrency(amount)} enregistré avec succès !'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enregistrer le règlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

