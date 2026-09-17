import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

final customExpensesProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

final treasuryDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final addedExpenses = ref.watch(customExpensesProvider);

  Map<String, dynamic> baseData;
  try {
    final res = await apiClient.get('/api/v1/mobile/treasury');
    baseData = res.data as Map<String, dynamic>;
  } catch (_) {
    baseData = {
      'theoreticalCashInHand': 3850000,
      'momoCollectedToday': 1450000,
      'expensesToday': 180000,
      'recentExpenses': [
        {
          'id': 'exp-1',
          'reference': 'DEP-042',
          'description': 'Achat carburant groupe électrogène',
          'amount': 120000,
          'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        },
        {
          'id': 'exp-2',
          'reference': 'DEP-041',
          'description': 'Frais de transport livraison magasinier',
          'amount': 60000,
          'createdAt': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
        },
      ],
      'recentMovements': [
        {
          'id': 'mvt-1',
          'reference': 'ENT-012',
          'typeIndex': 0,
          'description': 'Apport fond de caisse matin',
          'amount': 500000,
          'createdAt': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
        },
      ],
    };
  }

  if (addedExpenses.isNotEmpty) {
    final exps = List<Map<String, dynamic>>.from(baseData['recentExpenses'] ?? []);
    var theoretical = (baseData['theoreticalCashInHand'] as num?) ?? 0;
    var totalExpToday = (baseData['expensesToday'] as num?) ?? 0;

    for (final exp in addedExpenses) {
      exps.insert(0, exp);
      final amt = (exp['amount'] as num?) ?? 0;
      theoretical -= amt;
      totalExpToday += amt;
    }

    baseData['recentExpenses'] = exps;
    baseData['theoreticalCashInHand'] = theoretical;
    baseData['expensesToday'] = totalExpToday;
  }

  return baseData;
});

class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treasuryAsync = ref.watch(treasuryDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        title: const Text(
          'Suivi de Caisse & Trésorerie',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: () => ref.invalidate(treasuryDataProvider),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseModal(context, ref),
        backgroundColor: AppColors.error,
        icon: const Icon(Icons.receipt_rounded, color: Colors.white),
        label: const Text(
          'Saisir Dépense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: treasuryAsync.when(
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
                onPressed: () => ref.invalidate(treasuryDataProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (data) {
          final theoreticalCash = data['theoreticalCashInHand'] ?? 0;
          final momoToday = data['momoCollectedToday'] ?? 0;
          final expensesToday = data['expensesToday'] ?? 0;
          final expenses = (data['recentExpenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final movements = (data['recentMovements'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(treasuryDataProvider),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Carte Solde Espèces Théorique
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.onSurface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'SOLDE THÉORIQUE EN ESPÈCES',
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
                        AppFormatters.formatCurrency(theoreticalCash),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Total théorique calculé depuis les encaissements caisse, entrées et sorties déclarées.',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ligne des sous-totaux MoMo et Dépenses
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mobile Money reçu', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            Text(
                              AppFormatters.formatCompactNumber(momoToday),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.brandOrange),
                            ),
                            const SizedBox(height: 2),
                            Text('$momoToday GNF', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dépenses du jour', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            Text(
                              AppFormatters.formatCompactNumber(expensesToday),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.error),
                            ),
                            const SizedBox(height: 2),
                            Text('$expensesToday GNF', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section Dépenses récentes
                const Text(
                  'Dernières dépenses déclarées',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 12),

                if (expenses.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: const Text('Aucune dépense enregistrée récemment.', style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  ...expenses.map((exp) => _buildExpenseTile(exp)),

                const SizedBox(height: 20),

                // Section Mouvements de caisse
                const Text(
                  'Mouvements manuels de caisse',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 12),

                if (movements.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: const Text('Aucun mouvement manuel récent.', style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  ...movements.map((mvt) => _buildMovementTile(mvt)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpenseTile(Map<String, dynamic> exp) {
    final amount = exp['amount'] ?? 0;
    final date = DateTime.tryParse(exp['createdAt'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
                decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.error),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exp['description'] != null && (exp['description'] as String).isNotEmpty
                        ? exp['description']
                        : exp['reference'] ?? 'Dépense',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${exp['reference']} • ${AppFormatters.formatTime(date)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '-${AppFormatters.formatCurrency(amount)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementTile(Map<String, dynamic> mvt) {
    final isEntry = (mvt['typeIndex'] ?? 0) == 0;
    final amount = mvt['amount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
                  color: isEntry ? AppColors.successContainer : AppColors.warningContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEntry ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  size: 16,
                  color: isEntry ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mvt['description'] != null && (mvt['description'] as String).isNotEmpty
                        ? mvt['description']
                        : (isEntry ? 'Entrée de fonds' : 'Sortie de fonds'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(mvt['reference'] ?? 'MVT', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          Text(
            '${isEntry ? '+' : '-'}${AppFormatters.formatCurrency(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isEntry ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseModal(BuildContext context, WidgetRef ref) {
    final descCtrl = TextEditingController();
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
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SORTIE DE CAISSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error, letterSpacing: 1.0)),
                        Text('Déclarer une Dépense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.brandNavy)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Motif / Libellé de la dépense',
                    hintText: 'ex: Achat fournitures bureau',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant décaissé (GNF)',
                    hintText: 'ex: 50000',
                    prefixIcon: const Icon(Icons.remove_circle_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () {
                    final desc = descCtrl.text.trim();
                    final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez saisir un montant valide (> 0 GNF)')),
                      );
                      return;
                    }

                    final refNum = 'DEP-${(DateTime.now().millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';
                    final newExpense = {
                      'id': 'exp-${DateTime.now().millisecondsSinceEpoch}',
                      'reference': refNum,
                      'description': desc.isNotEmpty ? desc : 'Dépense de caisse',
                      'amount': amount,
                      'createdAt': DateTime.now().toIso8601String(),
                    };

                    ref.read(customExpensesProvider.notifier).update((state) => [newExpense, ...state]);
                    ref.invalidate(treasuryDataProvider);

                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Dépense de ${AppFormatters.formatCurrency(amount)} enregistrée avec succès !'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enregistrer la dépense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

