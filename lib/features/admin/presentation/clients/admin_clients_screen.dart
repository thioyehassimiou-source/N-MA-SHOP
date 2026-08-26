import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/database/database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/admin_providers.dart';

class AdminClientsScreen extends ConsumerWidget {
  const AdminClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people_rounded, color: Color(0xFFA78BFA), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gestion des Clients', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                        const Text('Liste de vos clients N\'MaShop', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showClientDialog(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nouveau Client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
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
              child: clientsAsync.when(
                data: (clients) {
                  if (clients.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'Aucun client enregistré.',
                          style: TextStyle(color: textSecondary),
                        ),
                      ),
                    );
                  }
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
                        columnSpacing: AppSpacing.xl,
                        columns: const [
                          DataColumn(label: Text('Nom')),
                          DataColumn(label: Text('Téléphone')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Date Install')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: clients.map((client) {
                          return DataRow(
                            cells: [
                              DataCell(Text(client.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(client.phone?.isNotEmpty == true ? client.phone! : '-')),
                              DataCell(Text(client.email?.isNotEmpty == true ? client.email! : '-')),
                              DataCell(Text(client.installDate?.toLocal().toString().split(' ')[0] ?? '-')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF94A3B8)),
                                      onPressed: () => _showClientDialog(context, ref, client: client),
                                      tooltip: 'Modifier',
                                      splashRadius: 20,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)),
                                      onPressed: () => _confirmDelete(context, ref, client),
                                      tooltip: 'Supprimer',
                                      splashRadius: 20,
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

  void _showClientDialog(BuildContext context, WidgetRef ref, {AdminClient? client}) {
    final nameCtrl = TextEditingController(text: client?.name);
    final phoneCtrl = TextEditingController(text: client?.phone);
    final emailCtrl = TextEditingController(text: client?.email);
    final notesCtrl = TextEditingController(text: client?.notes);
    final formKey = GlobalKey<FormState>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          client == null ? 'Nouveau Client' : 'Modifier Client',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DarkTextField(controller: nameCtrl, label: 'Nom du client *', validator: (v) => v!.isEmpty ? 'Requis' : null),
                const SizedBox(height: AppSpacing.md),
                _DarkTextField(controller: phoneCtrl, label: 'Téléphone'),
                const SizedBox(height: AppSpacing.md),
                _DarkTextField(controller: emailCtrl, label: 'Email'),
                const SizedBox(height: AppSpacing.md),
                _DarkTextField(controller: notesCtrl, label: 'Notes', maxLines: 3),
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
              if (!formKey.currentState!.validate()) return;
              
              final db = ref.read(databaseProvider);
              if (client == null) {
                await db.into(db.adminClients).insert(AdminClientsCompanion.insert(
                  name: nameCtrl.text.trim(),
                  phone: drift.Value(phoneCtrl.text.trim()),
                  email: drift.Value(emailCtrl.text.trim()),
                  notes: drift.Value(notesCtrl.text.trim()),
                  installDate: drift.Value(DateTime.now()),
                ));
              } else {
                await (db.update(db.adminClients)..where((t) => t.id.equals(client.id))).write(
                  AdminClientsCompanion(
                    name: drift.Value(nameCtrl.text.trim()),
                    phone: drift.Value(phoneCtrl.text.trim()),
                    email: drift.Value(emailCtrl.text.trim()),
                    notes: drift.Value(notesCtrl.text.trim()),
                  ),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AdminClient client) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('Supprimer ce client ?', style: TextStyle(color: textPrimary)),
        content: Text(
          'Voulez-vous vraiment supprimer ${client.name} ?\nAttention : Toutes les licences associées à ce client seront également supprimées de l\'historique.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.transaction(() async {
                await (db.delete(db.adminLicenses)..where((t) => t.adminClientId.equals(client.id))).go();
                await (db.delete(db.adminClients)..where((t) => t.id.equals(client.id))).go();
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ── Widget helper pour les champs de texte ─────────────────────────────
class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
        ),
      ),
    );
  }
}
