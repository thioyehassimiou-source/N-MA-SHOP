import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/database/database.dart';
import '../../../../core/license/license_core.dart';
import '../../../../core/license/license_model.dart';
import '../../../../core/license/license_provider.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/admin_providers.dart';

class AdminLicensesScreen extends ConsumerWidget {
  const AdminLicensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licensesAsync = ref.watch(adminLicensesStreamProvider);
    final clientsAsync = ref.watch(adminClientsStreamProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF34D399), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gestion des Licences', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                        const Text('Créez et gérez les clés d\'activation', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateDialog(context, ref, clientsAsync.value ?? []),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nouvelle Licence'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Table ─────────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: licensesAsync.when(
                data: (licenses) {
                  if (licenses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'Aucune licence créée. Cliquez sur "Nouvelle Licence" pour commencer.',
                          style: TextStyle(color: textSecondary),
                        ),
                      ),
                    );
                  }

                  final clients = clientsAsync.value ?? [];
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dataTableTheme: DataTableThemeData(
                          headingTextStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                          dataTextStyle: TextStyle(color: textPrimary, fontSize: 13),
                          dividerThickness: 1,
                          headingRowColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                      ),
                      child: DataTable(
                        columnSpacing: AppSpacing.lg,
                        columns: const [
                          DataColumn(label: Text('Client')),
                          DataColumn(label: Text('Clé de Licence')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Début')),
                          DataColumn(label: Text('Expiration')),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: licenses.map((lic) {
                          final client = clients.where((c) => c.id == lic.adminClientId).firstOrNull;
                          return DataRow(
                            cells: [
                              DataCell(Text(client?.name ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      lic.licenseKey,
                                      style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                                      tooltip: 'Copier la clé',
                                      splashRadius: 20,
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: lic.licenseKey));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Clé copiée dans le presse-papier !')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(_TypeBadge(type: lic.licenseType)),
                              DataCell(Text(lic.validFrom.toLocal().toString().split(' ')[0])),
                              DataCell(Text(
                                lic.expiresAt == null
                                    ? '∞ Illimitée'
                                    : lic.expiresAt!.year >= 9999
                                        ? '∞ Illimitée'
                                        : lic.expiresAt!.toLocal().toString().split(' ')[0],
                              )),
                              DataCell(_StatusBadge(status: lic.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (lic.status == 'active')
                                      IconButton(
                                        icon: const Icon(Icons.computer_rounded, size: 18, color: Color(0xFF10B981)),
                                        tooltip: 'Activer sur cette instance',
                                        splashRadius: 20,
                                        onPressed: () {
                                          final res = ref.read(licenseProvider.notifier).activate(lic.licenseKey);
                                          if (res.result == LicenseActivationResult.success) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('🎉 Boutique locale activée avec succès !')),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('❌ Impossible d\'activer cette clé localement (expirée ou invalide).')),
                                            );
                                          }
                                        },
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF3B82F6)),
                                      tooltip: 'Renouveler',
                                      splashRadius: 20,
                                      onPressed: lic.licenseType == 'lifetime'
                                          ? null
                                          : () => _showRenewDialog(context, ref, lic),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF94A3B8)),
                                      tooltip: 'Modifier',
                                      splashRadius: 20,
                                      onPressed: () => _showEditDialog(context, ref, lic, clientsAsync.value ?? []),
                                    ),
                                    if (lic.status == 'active')
                                      IconButton(
                                        icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFFF59E0B)),
                                        tooltip: 'Annuler la licence',
                                        splashRadius: 20,
                                        onPressed: () => _confirmCancel(context, ref, lic),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, s) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.red))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, List<AdminClient> clients) {
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord créer un client avant de générer une licence.')),
      );
      return;
    }

    AdminClient? selectedClient = clients.first;
    String selectedType = 'annual';
    DateTime validFrom = DateTime.now();
    DateTime expiresAt = DateTime.now().add(const Duration(days: 365));
    String? generatedKey;
    final notesCtrl = TextEditingController();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (selectedType == 'lifetime') {
            generatedKey = LicenseCore.generateLifetimeKey();
          } else if (selectedType == 'monthly') {
            generatedKey = LicenseCore.generateMonthlyKey(validFrom);
          } else {
            generatedKey = LicenseCore.generateAnnualKey(expiresAt);
          }

          return AlertDialog(
            backgroundColor: surfaceColor,
            title: Text('Nouvelle Licence', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Client
                    Text('Client *', style: TextStyle(color: textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AdminClient>(
                      initialValue: selectedClient,
                      dropdownColor: surfaceColor,
                      style: TextStyle(color: textPrimary),
                      items: clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                      onChanged: (v) => setDialogState(() => selectedClient = v),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Type de licence
                    Text('Type de licence', style: TextStyle(color: textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Mensuelle'),
                          avatar: const Icon(Icons.calendar_view_month, size: 14),
                          selected: selectedType == 'monthly',
                          selectedColor: isDark
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                              : const Color(0xFFDBEAFE),
                          onSelected: (_) => setDialogState(() {
                            selectedType = 'monthly';
                            expiresAt = DateTime.now().add(const Duration(days: 30));
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Annuelle'),
                          avatar: const Icon(Icons.calendar_today, size: 14),
                          selected: selectedType == 'annual',
                          selectedColor: isDark
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFD1FAE5),
                          onSelected: (_) => setDialogState(() {
                            selectedType = 'annual';
                            expiresAt = DateTime.now().add(const Duration(days: 365));
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('À vie'),
                          avatar: const Icon(Icons.all_inclusive, size: 14),
                          selected: selectedType == 'lifetime',
                          selectedColor: isDark
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                              : const Color(0xFFEDE9FE),
                          onSelected: (_) => setDialogState(() => selectedType = 'lifetime'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Date de début
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Date de début', style: TextStyle(color: textSecondary, fontSize: 13)),
                      subtitle: Text(validFrom.toLocal().toString().split(' ')[0], style: TextStyle(color: textPrimary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_calendar, color: Color(0xFF94A3B8)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: validFrom,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2099),
                          );
                          if (picked != null) setDialogState(() => validFrom = picked);
                        },
                      ),
                    ),

                    // Date d'expiration (seulement pour annuelle, mensuelle auto-calculée)
                    if (selectedType == 'annual')
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Date d\'expiration', style: TextStyle(color: textSecondary, fontSize: 13)),
                        subtitle: Text(expiresAt.toLocal().toString().split(' ')[0], style: TextStyle(color: textPrimary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_calendar, color: Color(0xFF94A3B8)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: expiresAt,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2099),
                            );
                            if (picked != null) setDialogState(() => expiresAt = picked);
                          },
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),

                    // Prévisualisation de la clé
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: fieldBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clé générée :', style: TextStyle(color: textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          SelectableText(
                            generatedKey ?? '',
                            style: TextStyle(color: textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Notes (optionnel)',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Créer & Copier la clé'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (selectedClient == null || generatedKey == null) return;

                  final db = ref.read(databaseProvider);
                  final DateTime effectiveExpiry;
                  if (selectedType == 'lifetime') {
                    effectiveExpiry = DateTime(9999, 12, 31);
                  } else if (selectedType == 'monthly') {
                    effectiveExpiry = validFrom.add(const Duration(days: 30));
                  } else {
                    effectiveExpiry = expiresAt;
                  }

                  await db.into(db.adminLicenses).insert(AdminLicensesCompanion.insert(
                    adminClientId: selectedClient!.id,
                    licenseKey: generatedKey!,
                    licenseType: selectedType,
                    validFrom: validFrom,
                    expiresAt: drift.Value(effectiveExpiry),
                    notes: drift.Value(notesCtrl.text.trim()),
                  ));

                  await Clipboard.setData(ClipboardData(text: generatedKey!));

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('✅ Licence créée et clé copiée dans le presse-papier !')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRenewDialog(BuildContext context, WidgetRef ref, AdminLicense lic) {
    final oldExpiry = lic.expiresAt;
    DateTime newExpiry = (oldExpiry ?? DateTime.now()).add(const Duration(days: 365));
    String? newKey;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          newKey = LicenseCore.generateAnnualKey(newExpiry);

          return AlertDialog(
            backgroundColor: surfaceColor,
            title: Text('Renouveler la Licence', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (oldExpiry != null)
                    _InfoRow(label: 'Ancienne expiration', value: oldExpiry.toLocal().toString().split(' ')[0]),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Nouvelle expiration', style: TextStyle(color: textSecondary, fontSize: 13)),
                    subtitle: Text(
                      newExpiry.toLocal().toString().split(' ')[0],
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar, color: Color(0xFF94A3B8)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: newExpiry,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2099),
                        );
                        if (picked != null) setDialogState(() => newExpiry = picked);
                      },
                    ),
                  ),
                  Divider(color: fieldBorder),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: fieldBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nouvelle clé :', style: TextStyle(color: textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        SelectableText(
                          newKey ?? '',
                          style: TextStyle(color: textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Renouveler & Copier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (newKey == null) return;
                  final db = ref.read(databaseProvider);
                  await (db.update(db.adminLicenses)..where((t) => t.id.equals(lic.id))).write(
                    AdminLicensesCompanion(
                      licenseKey: drift.Value(newKey!),
                      expiresAt: drift.Value(newExpiry),
                      status: const drift.Value('active'),
                    ),
                  );
                  await Clipboard.setData(ClipboardData(text: newKey!));
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('✅ Licence renouvelée et nouvelle clé copiée !')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, AdminLicense lic, List<AdminClient> clients) {
    final notesCtrl = TextEditingController(text: lic.notes);
    String selectedStatus = lic.status;
    String selectedType = lic.licenseType;
    DateTime expiresAt = lic.expiresAt ?? DateTime.now().add(const Duration(days: 365));
    // Si la date stockée est "lifetime" (9999), on initialise à +1 an pour le picker
    if (expiresAt.year >= 9999) expiresAt = DateTime.now().add(const Duration(days: 365));
    bool typeChanged = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Génère la nouvelle clé si le type a changé
          final String? previewKey = typeChanged
              ? (selectedType == 'lifetime'
                  ? LicenseCore.generateLifetimeKey()
                  : LicenseCore.generateAnnualKey(expiresAt))
              : null;

          return AlertDialog(
            backgroundColor: surfaceColor,
            title: Text('Modifier la licence', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Clé actuelle
                    _InfoRow(label: 'Clé actuelle', value: lic.licenseKey),
                    const SizedBox(height: AppSpacing.md),

                    // ── Type de licence ──────────────────────────────────
                    Text('Type de licence', style: TextStyle(color: textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Mensuelle'),
                          avatar: const Icon(Icons.calendar_view_month, size: 14),
                          selected: selectedType == 'monthly',
                          selectedColor: isDark
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                              : const Color(0xFFDBEAFE),
                          onSelected: (_) => setDialogState(() {
                            selectedType = 'monthly';
                            typeChanged = selectedType != lic.licenseType;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Annuelle'),
                          avatar: const Icon(Icons.calendar_today, size: 14),
                          selected: selectedType == 'annual',
                          selectedColor: isDark
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFD1FAE5),
                          onSelected: (_) => setDialogState(() {
                            selectedType = 'annual';
                            typeChanged = selectedType != lic.licenseType;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('À vie'),
                          avatar: const Icon(Icons.all_inclusive, size: 14),
                          selected: selectedType == 'lifetime',
                          selectedColor: isDark
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                              : const Color(0xFFEDE9FE),
                          onSelected: (_) => setDialogState(() {
                            selectedType = 'lifetime';
                            typeChanged = selectedType != lic.licenseType;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Date d'expiration (visible seulement si annuelle) ─
                    if (selectedType == 'annual')
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Date d\'expiration', style: TextStyle(color: textSecondary, fontSize: 13)),
                        subtitle: Text(
                          expiresAt.toLocal().toString().split(' ')[0],
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_calendar, color: Color(0xFF94A3B8)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: expiresAt,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2099),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                expiresAt = picked;
                                typeChanged = selectedType != lic.licenseType || picked != lic.expiresAt;
                              });
                            }
                          },
                        ),
                      ),

                    // ── Aperçu nouvelle clé (si type a changé) ───────────
                    if (typeChanged && previewKey != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF10B981).withValues(alpha: 0.08)
                              : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Text(
                                  'Nouvelle clé générée :',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              previewKey,
                              style: TextStyle(
                                color: textPrimary,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '⚠️ La clé sera régénérée et l\'ancienne ne fonctionnera plus.',
                        style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 11),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.md),

                    // ── Statut ───────────────────────────────────────────
                    Text('Statut', style: TextStyle(color: textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      dropdownColor: surfaceColor,
                      style: TextStyle(color: textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'expired', child: Text('Expirée')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedStatus = v!),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Notes ────────────────────────────────────────────
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 3,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final db = ref.read(databaseProvider);

                  // Si le type a changé → on régénère la clé
                  final String finalKey = typeChanged
                      ? (previewKey ?? lic.licenseKey)
                      : lic.licenseKey;
                  final DateTime finalExpiry;
                  if (selectedType == 'lifetime') {
                    finalExpiry = DateTime(9999, 12, 31);
                  } else if (selectedType == 'monthly') {
                    finalExpiry = DateTime.now().add(const Duration(days: 30));
                  } else {
                    finalExpiry = expiresAt;
                  }

                  await (db.update(db.adminLicenses)..where((t) => t.id.equals(lic.id))).write(
                    AdminLicensesCompanion(
                      licenseKey: drift.Value(finalKey),
                      licenseType: drift.Value(selectedType),
                      expiresAt: drift.Value(finalExpiry),
                      status: drift.Value(selectedStatus),
                      notes: drift.Value(notesCtrl.text.trim()),
                    ),
                  );

                  if (typeChanged) {
                    await Clipboard.setData(ClipboardData(text: finalKey));
                  }

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          typeChanged
                              ? '✅ Licence mise à jour et nouvelle clé copiée !'
                              : '✅ Licence mise à jour.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, AdminLicense lic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 40),
        title: Text('Annuler la licence ?', style: TextStyle(color: textPrimary)),
        content: Text(
          'Êtes-vous sûr de vouloir annuler cette licence ?\nL\'utilisateur ne pourra plus l\'utiliser pour s\'activer.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Non, conserver', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await (db.update(db.adminLicenses)..where((t) => t.id.equals(lic.id))).write(
                const AdminLicensesCompanion(status: drift.Value('cancelled')),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Licence annulée.')),
                );
              }
            },
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('Active', const Color(0xFF10B981)),
      'expired' => ('Expirée', const Color(0xFFF59E0B)),
      'cancelled' => ('Annulée', const Color(0xFFEF4444)),
      _ => (status, const Color(0xFF64748B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'lifetime' => ('À vie', const Color(0xFF8B5CF6)),
      'monthly'  => ('Mensuelle', const Color(0xFF3B82F6)),
      _          => ('Annuelle', const Color(0xFF10B981)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    
    return Row(
      children: [
        Text('$label : ', style: TextStyle(fontWeight: FontWeight.w600, color: textSecondary)),
        Expanded(child: Text(value, style: TextStyle(fontFamily: 'monospace', color: textPrimary))),
      ],
    );
  }
}
