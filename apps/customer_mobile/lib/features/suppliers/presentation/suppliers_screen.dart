import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';

final customSuppliersProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(customSuppliersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NmaMobileAppBar(
        title: 'Fournisseurs & Achats',
        subtitle: 'Contacts & réapprovisionnements',
        onLeadingPressed: () => Navigator.of(context).maybePop(),
        leadingIcon: Icons.arrow_back_rounded,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplierModal(context, ref),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text(
          'Nouveau Fournisseur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: suppliers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_outlined, size: 48, color: AppColors.brandNavy),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun fournisseur enregistré',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ajoutez des partenaires et grossistes pour suivre vos approvisionnements et dettes de commande.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                final debt = (supplier['debt'] as num?) ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        (supplier['name'] as String? ?? 'F')[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.brandNavy, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      supplier['name'] ?? 'Fournisseur',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Tél: ${supplier['phone'] ?? 'N/A'} • ${supplier['city'] ?? 'Conakry'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Dette due', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        Text(
                          AppFormatters.formatCurrency(debt),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: debt > 0 ? AppColors.error : AppColors.brandEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddSupplierModal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController();

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
              const Text('Nouveau Fournisseur / Grossiste', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom du Fournisseur / Entreprise', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(labelText: 'Ville / Marché (ex: Madina)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final newSupplier = {
                    'id': 'sup-${DateTime.now().millisecondsSinceEpoch}',
                    'name': name,
                    'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : 'Non renseigné',
                    'city': cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'Conakry',
                    'debt': 0,
                  };

                  ref.read(customSuppliersProvider.notifier).update((state) => [newSupplier, ...state]);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fournisseur "$name" ajouté avec succès !'), backgroundColor: AppColors.success),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Enregistrer le Fournisseur', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
