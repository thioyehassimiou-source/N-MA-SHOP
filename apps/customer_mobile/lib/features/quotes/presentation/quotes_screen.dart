import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/mobile_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/mobile_barcode_scanner_modal.dart';
import '../../../../core/widgets/nma_mobile_header.dart';
import '../data/quotes_repository.dart';

final quotesListProvider = FutureProvider.autoDispose<List<MobileQuote>>((ref) async {
  final repo = ref.watch(quotesRepositoryProvider);
  return repo.getQuotes();
});

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'converted', 'cancelled'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NmaMobileAppBar(
        title: 'Devis & Proformas',
        subtitle: 'Propositions & conversion immédiate en vente',
        leadingIcon: Icons.arrow_back_rounded,
        onLeadingPressed: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.brandOrange),
            tooltip: 'Nouveau Devis',
            onPressed: () => _openNewQuoteModal(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewQuoteModal(context),
        backgroundColor: AppColors.brandOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau Devis', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: quotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (allQuotes) {
          final filtered = allQuotes.where((q) {
            final matchesFilter = switch (_selectedFilter) {
              'pending' => q.isPending,
              'converted' => q.isConverted,
              'cancelled' => q.isCancelled,
              _ => true,
            };

            final qText = '${q.reference} ${q.customerName} ${q.customerPhone}'.toLowerCase();
            final matchesSearch = _searchQuery.isEmpty || qText.contains(_searchQuery.toLowerCase());

            return matchesFilter && matchesSearch;
          }).toList();

          final pendingCount = allQuotes.where((q) => q.isPending).length;
          final convertedCount = allQuotes.where((q) => q.isConverted).length;
          final pendingTotal = allQuotes.where((q) => q.isPending).fold<int>(0, (sum, q) => sum + q.total);

          return Column(
            children: [
              // Bandeau de statistiques Devis
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.heroNavyGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandNavy.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('En attente de validation', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.formatCurrency(pendingTotal),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 36, width: 1, color: Colors.white24),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$pendingCount en cours ⏳', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('$convertedCount convertis ✅', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // Barre de Recherche & Filtres
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par référence, client...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.brandNavy),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filtres horizontaux
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'Tous (${allQuotes.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('pending', 'En attente ($pendingCount) ⏳'),
                          const SizedBox(width: 8),
                          _buildFilterChip('converted', 'Convertis ($convertedCount) ✅'),
                          const SizedBox(width: 8),
                          _buildFilterChip('cancelled', 'Annulés ❌'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Liste des Devis
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.request_quote_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucun devis trouvé',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Créez une proposition pour vos clients en un clic.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final quote = filtered[index];
                          return _buildQuoteCard(quote);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.brandNavy,
      ),
      selected: isSelected,
      selectedColor: AppColors.brandNavy,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }

  Widget _buildQuoteCard(MobileQuote quote) {
    final statusColor = switch (quote.status) {
      'converted' => AppColors.brandEmerald,
      'cancelled' => AppColors.error,
      _ => AppColors.brandOrange,
    };

    final statusText = switch (quote.status) {
      'converted' => 'Converti en Vente',
      'cancelled' => 'Annulé',
      _ => 'En attente',
    };

    final isValid = quote.validUntil.isAfter(DateTime.now());

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la carte : Réf & Statut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  quote.reference,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.brandNavy),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Client & Date
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  quote.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.brandNavy),
                ),
              ),
              if (quote.customerPhone.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  quote.customerPhone,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Date & Validité
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Émis le ${quote.date.day.toString().padLeft(2, '0')}/${quote.date.month.toString().padLeft(2, '0')}/${quote.date.year}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Icon(Icons.schedule_rounded, size: 14, color: isValid ? AppColors.textMuted : AppColors.error),
              const SizedBox(width: 4),
              Text(
                'Valable jusqu\'au ${quote.validUntil.day.toString().padLeft(2, '0')}/${quote.validUntil.month.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 11.5, color: isValid ? AppColors.textMuted : AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Liste condensée des articles
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${quote.items.length} article(s) :',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                ...quote.items.take(3).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${item.quantity}x ${item.label}',
                            style: const TextStyle(fontSize: 12, color: AppColors.brandNavy),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          AppFormatters.formatCurrency(item.lineTotal),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                if (quote.items.length > 3)
                  Text(
                    '+ ${quote.items.length - 3} autre(s) article(s)...',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Total & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Proforma', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  Text(
                    AppFormatters.formatCurrency(quote.total),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.brandNavy),
                  ),
                ],
              ),
              Row(
                children: [
                  // Bouton WhatsApp
                  IconButton(
                    icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
                    tooltip: 'Partager sur WhatsApp',
                    onPressed: () => _shareQuoteWhatsApp(quote),
                  ),

                  // Si en attente : Bouton Convertir en Vente
                  if (quote.isPending)
                    ElevatedButton.icon(
                      onPressed: () => _showConvertDialog(quote),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                      label: const Text('Convertir Vente', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                  // Menu d'options
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                    onSelected: (action) async {
                      if (action == 'cancel') {
                        await ref.read(quotesRepositoryProvider).updateStatus(quote.id, 'cancelled');
                        ref.invalidate(quotesListProvider);
                      } else if (action == 'delete') {
                        await ref.read(quotesRepositoryProvider).deleteQuote(quote.id);
                        ref.invalidate(quotesListProvider);
                      }
                    },
                    itemBuilder: (_) => [
                      if (quote.isPending)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Marquer Annulé', style: TextStyle(fontSize: 13, color: AppColors.error)),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('Supprimer', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareQuoteWhatsApp(MobileQuote quote) async {
    final itemsList = quote.items
        .map((i) => '• ${i.quantity}x ${i.label} à ${AppFormatters.formatCurrency(i.unitPrice)} = ${AppFormatters.formatCurrency(i.lineTotal)}')
        .join('\n');

    final msg = '''
📄 *DEVIS / FACTURE PROFORMA* : ${quote.reference}
Client : *${quote.customerName}*
Date : ${quote.date.day.toString().padLeft(2, '0')}/${quote.date.month.toString().padLeft(2, '0')}/${quote.date.year}
Valable jusqu'au : ${quote.validUntil.day.toString().padLeft(2, '0')}/${quote.validUntil.month.toString().padLeft(2, '0')}/${quote.validUntil.year}

📋 *Détail des articles* :
$itemsList

💰 *MONTANT TOTAL* : *${AppFormatters.formatCurrency(quote.total)}*

${quote.note != null && quote.note!.isNotEmpty ? "📝 Note : ${quote.note}\n" : ""}Merci pour votre confiance !
— N'MaShop
''';

    final cleanPhone = quote.customerPhone.replaceAll(RegExp(r'\D'), '');
    String targetPhone = cleanPhone;
    if (cleanPhone.length == 9 && cleanPhone.startsWith('6')) {
      targetPhone = '224$cleanPhone';
    }

    final uri = targetPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$targetPhone?text=${Uri.encodeComponent(msg)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Texte du devis copié dans le presse-papier !')),
        );
      }
    }
  }

  void _showConvertDialog(MobileQuote quote) {
    int paymentMethod = 0; // 0: Espèces, 1: Orange Money, 2: Wave, 5: Crédit

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.brandOrange),
                  const SizedBox(width: 8),
                  const Text('Convertir en Vente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'La conversion du devis ${quote.reference} va enregistrer la vente, déduire les stocks et alimenter la caisse.',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant à encaisser :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        Text(
                          AppFormatters.formatCurrency(quote.total),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.brandNavy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Mode de règlement :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: paymentMethod,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('💵 Espèces')),
                      DropdownMenuItem(value: 1, child: Text('🟠 Orange Money')),
                      DropdownMenuItem(value: 2, child: Text('🌊 Wave')),
                      DropdownMenuItem(value: 5, child: Text('⏳ Vente à Crédit')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => paymentMethod = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final amountPaid = paymentMethod == 5 ? 0 : quote.total;
                      await ref.read(quotesRepositoryProvider).convertQuoteToSale(
                            quote: quote,
                            paymentMethod: paymentMethod,
                            amountPaid: amountPaid,
                          );
                      ref.invalidate(quotesListProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Devis ${quote.reference} converti en vente avec succès !'),
                            backgroundColor: AppColors.brandEmerald,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Confirmer la Vente', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openNewQuoteModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewQuoteModal(),
    ).then((_) => ref.invalidate(quotesListProvider));
  }
}

class _NewQuoteModal extends ConsumerStatefulWidget {
  const _NewQuoteModal();

  @override
  ConsumerState<_NewQuoteModal> createState() => _NewQuoteModalState();
}

class _NewQuoteModalState extends ConsumerState<_NewQuoteModal> {
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int _validityDays = 15;
  final List<MobileQuoteItem> _items = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _total => _items.fold<int>(0, (sum, i) => sum + i.lineTotal);

  void _addItem(MobileProduct product, int quantity, int unitPrice) {
    final existingIndex = _items.indexWhere((i) => i.productId == product.id);
    setState(() {
      if (existingIndex >= 0) {
        final current = _items[existingIndex];
        final newQty = current.quantity + quantity;
        _items[existingIndex] = MobileQuoteItem(
          productId: product.id,
          label: product.name,
          quantity: newQty,
          unitPrice: unitPrice,
          lineTotal: newQty * unitPrice,
        );
      } else {
        _items.add(MobileQuoteItem(
          productId: product.id,
          label: product.name,
          quantity: quantity,
          unitPrice: unitPrice,
          lineTotal: quantity * unitPrice,
        ));
      }
    });
  }

  void _scanBarcodeToAdd() async {
    final code = await MobileBarcodeScannerModal.show(context);
    if (code == null || code.trim().isEmpty) return;

    final db = ref.read(mobileDatabaseProvider);
    final products = await db.select(db.mobileProducts).get();
    final product = products.where((p) => p.barcode == code || p.reference == code).firstOrNull;

    if (product != null) {
      _addItem(product, 1, product.salePrice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Ajouté : ${product.name}'),
            backgroundColor: AppColors.brandEmerald,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code-barres inconnu : $code'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  void _showAddProductPicker() async {
    final db = ref.read(mobileDatabaseProvider);
    final products = await db.select(db.mobileProducts).get();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (pickerCtx) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = products.where((p) {
              final term = '${p.name} ${p.barcode ?? ""} ${p.reference ?? ""}'.toLowerCase();
              return search.isEmpty || term.contains(search.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Choisir un Article', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.brandOrange),
                        onPressed: () {
                          Navigator.of(pickerCtx).pop();
                          _scanBarcodeToAdd();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (val) => setPickerState(() => search = val),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Aucun article correspondant'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = filtered[i];
                              return ListTile(
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('Stock : ${p.stockQuantity} ${p.unit} • Prix : ${AppFormatters.formatCurrency(p.salePrice)}', style: const TextStyle(fontSize: 11)),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    _addItem(p, 1, p.salePrice);
                                    Navigator.of(pickerCtx).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Ajouter', style: TextStyle(fontSize: 12)),
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
      },
    );
  }

  Future<void> _saveQuote() async {
    final customer = _customerNameCtrl.text.trim();
    if (customer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner le nom du client.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un article au devis.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final quote = MobileQuote(
      id: 'quote-${now.millisecondsSinceEpoch}',
      reference: 'DEV-${now.millisecondsSinceEpoch % 10000}',
      customerName: customer,
      customerPhone: _customerPhoneCtrl.text.trim(),
      date: now,
      validUntil: now.add(Duration(days: _validityDays)),
      total: _total,
      status: 'pending',
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      items: _items,
    );

    await ref.read(quotesRepositoryProvider).saveQuote(quote);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Devis ${quote.reference} créé avec succès !'),
          backgroundColor: AppColors.brandEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.request_quote_rounded, color: AppColors.brandOrange),
                    SizedBox(width: 8),
                    Text('Nouveau Devis Proforma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Client & Téléphone
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customerNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nom du client *',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Téléphone (WhatsApp)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Durée de validité
            Row(
              children: [
                const Text('Validité :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('7 jours'),
                  selected: _validityDays == 7,
                  onSelected: (_) => setState(() => _validityDays = 7),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('15 jours'),
                  selected: _validityDays == 15,
                  onSelected: (_) => setState(() => _validityDays = 15),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('30 jours'),
                  selected: _validityDays == 30,
                  onSelected: (_) => setState(() => _validityDays = 30),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Boutons d'ajout d'articles
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddProductPicker,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('Choisir un Produit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandNavy,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _scanBarcodeToAdd,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  tooltip: 'Scanner code-barres',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Liste des articles ajoutés au devis
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Aucun article dans ce devis.\nAjoutez des articles via le catalogue ou la caméra.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    return ListTile(
                      dense: true,
                      title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        '${item.quantity} x ${AppFormatters.formatCurrency(item.unitPrice)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppFormatters.formatCurrency(item.lineTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.error),
                            onPressed: () {
                              setState(() {
                                if (item.quantity > 1) {
                                  final newQty = item.quantity - 1;
                                  _items[i] = MobileQuoteItem(
                                    productId: item.productId,
                                    label: item.label,
                                    quantity: newQty,
                                    unitPrice: item.unitPrice,
                                    lineTotal: newQty * item.unitPrice,
                                  );
                                } else {
                                  _items.removeAt(i);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            // Note facultative
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note / Conditions spécifiques (facultatif)',
                prefixIcon: const Icon(Icons.note_alt_outlined),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Total et Enregistrement
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Devis :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    AppFormatters.formatCurrency(_total),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.brandOrange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveQuote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer le Devis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

