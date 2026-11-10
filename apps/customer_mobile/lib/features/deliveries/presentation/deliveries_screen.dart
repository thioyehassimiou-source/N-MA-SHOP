import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nma_mobile_header.dart';
import '../data/deliveries_repository.dart';

final deliveriesTabProvider = StateProvider<int>((ref) => 0); // 0: Livraisons, 1: Livreurs
final deliveriesFilterProvider = StateProvider<String>((ref) => 'all'); // 'all', 'pending', 'transit', 'delivered'

final deliveriesListProvider = FutureProvider.autoDispose<List<MobileDelivery>>((ref) async {
  final repo = ref.watch(deliveriesRepositoryProvider);
  return repo.getDeliveries();
});

final couriersListProvider = FutureProvider.autoDispose<List<MobileCourier>>((ref) async {
  final repo = ref.watch(deliveriesRepositoryProvider);
  return repo.getCouriers();
});

class DeliveriesScreen extends ConsumerWidget {
  const DeliveriesScreen({super.key});

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String message) async {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9 && clean.startsWith('6')) {
      clean = '224$clean';
    }
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(deliveriesTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: NmaMobileAppBar(
        title: 'Livraisons & Coursiers',
        subtitle: 'Suivi des colis et gestion de la flotte',
        actions: [
          NmaMobileHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(deliveriesListProvider);
              ref.invalidate(couriersListProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_delivery',
        onPressed: () {
          if (currentTab == 0) {
            _showNewDeliveryModal(context, ref);
          } else {
            _showNewCourierModal(context, ref);
          }
        },
        backgroundColor: currentTab == 0 ? AppColors.brandOrange : AppColors.brandNavy,
        icon: Icon(currentTab == 0 ? Icons.add_location_alt_rounded : Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text(
          currentTab == 0 ? 'Nouvelle Livraison' : 'Nouveau Livreur',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Sélecteur d'Onglets
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Colis & Livraisons',
                    icon: Icons.local_shipping_rounded,
                    isSelected: currentTab == 0,
                    onTap: () => ref.read(deliveriesTabProvider.notifier).state = 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTabButton(
                    label: 'Flotte Livreurs',
                    icon: Icons.two_wheeler_rounded,
                    isSelected: currentTab == 1,
                    onTap: () => ref.read(deliveriesTabProvider.notifier).state = 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Contenu selon onglet
          Expanded(
            child: currentTab == 0 ? _buildDeliveriesTab(context, ref) : _buildCouriersTab(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandNavy : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.brandNavy),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.brandNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // ONGLET 1 : SUIVI DES LIVRAISONS
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildDeliveriesTab(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(deliveriesListProvider);
    final filter = ref.watch(deliveriesFilterProvider);

    return deliveriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (allDeliveries) {
        final filtered = allDeliveries.where((d) {
          if (filter == 'all') return true;
          if (filter == 'pending') return d.status == MobileDeliveryStatus.pending;
          if (filter == 'transit') return d.status == MobileDeliveryStatus.transit;
          if (filter == 'delivered') return d.status == MobileDeliveryStatus.delivered;
          return true;
        }).toList();

        final pendingCount = allDeliveries.where((d) => d.status == MobileDeliveryStatus.pending).length;
        final transitCount = allDeliveries.where((d) => d.status == MobileDeliveryStatus.transit).length;
        final deliveredCount = allDeliveries.where((d) => d.status == MobileDeliveryStatus.delivered).length;

        return Column(
          children: [
            // Filtres rapides
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(ref, 'Toutes (${allDeliveries.length})', 'all', filter),
                    const SizedBox(width: 8),
                    _buildFilterChip(ref, 'À expédier ($pendingCount)', 'pending', filter, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    _buildFilterChip(ref, 'En transit ($transitCount)', 'transit', filter, color: const Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    _buildFilterChip(ref, 'Livrées ($deliveredCount)', 'delivered', filter, color: AppColors.brandEmerald),
                  ],
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 54, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'Aucune livraison enregistrée',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brandNavy),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Créez une livraison pour assigner un colis à un coursier.',
                            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final item = filtered[idx];
                        return _buildDeliveryCard(context, ref, item);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String value, String currentFilter, {Color? color}) {
    final isSelected = currentFilter == value;
    final chipColor = color ?? AppColors.brandNavy;

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
      onSelected: (_) => ref.read(deliveriesFilterProvider.notifier).state = value,
      selectedColor: chipColor,
      backgroundColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, WidgetRef ref, MobileDelivery item) {
    Color statusBg;
    Color statusFg;
    IconData statusIcon;

    switch (item.status) {
      case MobileDeliveryStatus.pending:
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFFD97706);
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case MobileDeliveryStatus.transit:
        statusBg = const Color(0xFFEEF2FF);
        statusFg = const Color(0xFF4F46E5);
        statusIcon = Icons.delivery_dining_rounded;
        break;
      case MobileDeliveryStatus.delivered:
        statusBg = const Color(0xFFECFDF5);
        statusFg = const Color(0xFF059669);
        statusIcon = Icons.check_circle_rounded;
        break;
      case MobileDeliveryStatus.failed:
        statusBg = const Color(0xFFFEF2F2);
        statusFg = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Référence & Statut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.brandNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_rounded, size: 14, color: AppColors.brandNavy),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.saleReference,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusFg),
                    const SizedBox(width: 4),
                    Text(
                      item.status.label,
                      style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Client & Destination
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: AppColors.brandOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandNavy),
                    ),
                    Text(
                      item.deliveryAddress,
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (item.customerPhone.isNotEmpty) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.phone_rounded, color: AppColors.brandEmerald, size: 18),
                  tooltip: 'Appeler le client',
                  onPressed: () => _makePhoneCall(item.customerPhone),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                  tooltip: 'WhatsApp client',
                  onPressed: () => _openWhatsApp(
                    item.customerPhone,
                    'Bonjour ${item.customerName}, votre commande ${item.saleReference} est en cours de livraison par ${item.courierName}.',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Livreur rattaché
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports_motorsports_rounded, size: 16, color: AppColors.brandNavy),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Livreur : ${item.courierName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandNavy),
                  ),
                ),
                if (item.courierPhone.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.call_outlined, size: 16, color: AppColors.brandNavy),
                    tooltip: 'Appeler le livreur',
                    onPressed: () => _makePhoneCall(item.courierPhone),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Montants & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('À encaisser au client', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Text(
                    AppFormatters.formatCurrency(item.amountToCollect),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.brandOrange),
                  ),
                ],
              ),
              PopupMenuButton<MobileDeliveryStatus>(
                onSelected: (newStatus) async {
                  final repo = ref.read(deliveriesRepositoryProvider);
                  await repo.updateDeliveryStatus(item.id, newStatus);
                  ref.invalidate(deliveriesListProvider);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: MobileDeliveryStatus.pending,
                    child: Text('Marquer "À expédier"'),
                  ),
                  const PopupMenuItem(
                    value: MobileDeliveryStatus.transit,
                    child: Text('Marquer "En transit" (Parti)'),
                  ),
                  const PopupMenuItem(
                    value: MobileDeliveryStatus.delivered,
                    child: Text('Marquer "Livrée" (Encaissée)'),
                  ),
                  const PopupMenuItem(
                    value: MobileDeliveryStatus.failed,
                    child: Text('Signaler Échec / Retour'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.brandNavy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Text('Changer Statut', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // ONGLET 2 : FLOTTE DES COURSIERS / LIVREURS
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildCouriersTab(BuildContext context, WidgetRef ref) {
    final couriersAsync = ref.watch(couriersListProvider);

    return couriersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (couriers) {
        if (couriers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.two_wheeler_rounded, size: 54, color: AppColors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text(
                  'Aucun coursier enregistré',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brandNavy),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enregistrez vos livreurs avec leur numéro et véhicule.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: couriers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, idx) {
            final courier = couriers[idx];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brandOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(courier.vehicleType.iconName, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courier.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.brandNavy),
                        ),
                        Text(
                          '${courier.vehicleType.label} • ${courier.phone.isNotEmpty ? courier.phone : "Sans numéro"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (courier.phone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.call_rounded, color: AppColors.brandEmerald),
                      tooltip: 'Appeler',
                      onPressed: () => _makePhoneCall(courier.phone),
                    ),
                  Switch(
                    value: courier.isActive,
                    activeColor: AppColors.brandEmerald,
                    onChanged: (val) async {
                      final repo = ref.read(deliveriesRepositoryProvider);
                      await repo.toggleCourierActive(courier.id, val);
                      ref.invalidate(couriersListProvider);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // MODALS DE CRÉATION
  // ═════════════════════════════════════════════════════════════════════════════

  void _showNewDeliveryModal(BuildContext context, WidgetRef ref) async {
    final couriers = await ref.read(deliveriesRepositoryProvider).getCouriers();

    if (!context.mounted) return;
    if (couriers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord enregistrer au moins un livreur dans l\'onglet "Flotte Livreurs".'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final refCtrl = TextEditingController(text: 'CMD-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final customerNameCtrl = TextEditingController();
    final customerPhoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '15000');
    final noteCtrl = TextEditingController();

    MobileCourier selectedCourier = couriers.first;

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
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 12),
                  const Text('Nouvelle Expédition / Livraison', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                  const SizedBox(height: 14),

                  TextField(
                    controller: refCtrl,
                    decoration: InputDecoration(
                      labelText: 'Référence Commande / Ticket *',
                      prefixIcon: const Icon(Icons.receipt_long_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customerNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nom du Client *',
                            prefixIcon: const Icon(Icons.person_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: customerPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Téléphone Client',
                            prefixIcon: const Icon(Icons.phone_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: addressCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Adresse de livraison (Quartier, Repère) *',
                      prefixIcon: const Icon(Icons.location_on_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Choix du livreur
                  DropdownButtonFormField<MobileCourier>(
                    value: selectedCourier,
                    decoration: InputDecoration(
                      labelText: 'Assigner au Livreur *',
                      prefixIcon: const Icon(Icons.sports_motorsports_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: couriers.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text('${c.vehicleType.iconName} ${c.name} (${c.phone})', style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedCourier = val);
                    },
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Montant à Encaisser (GNF)',
                            hintText: 'ex: 150000',
                            prefixIcon: const Icon(Icons.payments_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Frais Livreur (GNF)',
                            hintText: 'ex: 15000',
                            prefixIcon: const Icon(Icons.motorcycle_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      final refText = refCtrl.text.trim();
                      final clientName = customerNameCtrl.text.trim();
                      final address = addressCtrl.text.trim();

                      if (refText.isEmpty || clientName.isEmpty || address.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez remplir la référence, le nom du client et l\'adresse.')),
                        );
                        return;
                      }

                      final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                      final fee = int.tryParse(feeCtrl.text.trim()) ?? 0;

                      final repo = ref.read(deliveriesRepositoryProvider);
                      await repo.createDelivery(
                        saleReference: refText,
                        courierId: selectedCourier.id,
                        courierName: selectedCourier.name,
                        courierPhone: selectedCourier.phone,
                        customerName: clientName,
                        customerPhone: customerPhoneCtrl.text.trim(),
                        deliveryAddress: address,
                        deliveryFee: fee,
                        amountToCollect: amount,
                        note: noteCtrl.text.trim(),
                      );

                      ref.invalidate(deliveriesListProvider);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Livraison pour "$clientName" assignée à ${selectedCourier.name} !'),
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
                    child: const Text('Confirmer & Assigner la Livraison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNewCourierModal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    MobileVehicleType selectedVehicle = MobileVehicleType.moto;

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
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 12),
                  const Text('Nouveau Livreur / Coursier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy)),
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nom complet du livreur *',
                      hintText: 'Ex: Ibrahima Sory',
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Numéro de Téléphone *',
                      hintText: 'Ex: +224 620 00 00 00',
                      prefixIcon: const Icon(Icons.phone_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<MobileVehicleType>(
                    value: selectedVehicle,
                    decoration: InputDecoration(
                      labelText: 'Type de véhicule',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: MobileVehicleType.values.map((v) {
                      return DropdownMenuItem(
                        value: v,
                        child: Text('${v.iconName} ${v.label}', style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedVehicle = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner le nom du livreur.')),
                        );
                        return;
                      }

                      final repo = ref.read(deliveriesRepositoryProvider);
                      await repo.addCourier(name: name, phone: phone, vehicleType: selectedVehicle);

                      ref.invalidate(couriersListProvider);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Livreur "$name" enregistré avec succès !'),
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
                    child: const Text('Enregistrer le Livreur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

