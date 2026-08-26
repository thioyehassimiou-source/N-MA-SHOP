import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/license/license_core.dart';
import '../../../../core/theme/app_spacing.dart';

class AdminMaintenanceScreen extends ConsumerStatefulWidget {
  const AdminMaintenanceScreen({super.key});

  @override
  ConsumerState<AdminMaintenanceScreen> createState() => _AdminMaintenanceScreenState();
}

class _AdminMaintenanceScreenState extends ConsumerState<AdminMaintenanceScreen> {
  final _verifyKeyCtrl = TextEditingController();
  final _genExpiryCtrl = TextEditingController();
  String? _verifyResult;
  bool _verifyIsValid = false;
  String? _generatedKey;
  String _generatedType = 'annual';

  @override
  void dispose() {
    _verifyKeyCtrl.dispose();
    _genExpiryCtrl.dispose();
    super.dispose();
  }

  void _verifyKey() {
    final info = LicenseCore.validateKey(_verifyKeyCtrl.text.trim());
    setState(() {
      if (info == null) {
        _verifyResult = '❌ Clé invalide ou format incorrect.';
        _verifyIsValid = false;
      } else {
        _verifyIsValid = true;
        final expiryStr = info.expiryDate == null
            ? 'Illimitée (À vie)'
            : info.expiryDate!.year >= 9999
                ? 'Illimitée (À vie)'
                : info.expiryDate!.toLocal().toString().split(' ')[0];
        _verifyResult = '✅ Clé valide\n'
            '  • Statut : ${info.status.name}\n'
            '  • Type : ${info.type.name}\n'
            '  • Expiration : $expiryStr\n'
            '  • Jours restants : ${info.daysLeft ?? 'N/A'}';
      }
    });
  }

  void _generateKey() {
    if (_generatedType == 'lifetime') {
      setState(() => _generatedKey = LicenseCore.generateLifetimeKey());
    } else {
      final dateStr = _genExpiryCtrl.text.trim();
      DateTime? expiry;
      try {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          expiry = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}

      if (expiry == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format de date invalide. Utilisez JJ/MM/AAAA')),
        );
        return;
      }
      setState(() => _generatedKey = LicenseCore.generateAnnualKey(expiry!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.build_circle_rounded, color: Color(0xFFFBBF24), size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Maintenance & Outils', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                    const Text('Vérification et génération de licences à la volée', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Section 1 : Vérifier une clé ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF3B82F6), size: 20),
                      const SizedBox(width: 10),
                      Text('Vérifier une clé de licence', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _DarkTextField(
                          controller: _verifyKeyCtrl,
                          label: 'Coller la clé ici (ex: NMAS-20251231-XXXXXXXX)',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _verifyKey,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('Vérifier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  if (_verifyResult != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: _verifyIsValid
                            ? const Color(0xFF10B981).withValues(alpha: 0.08)
                            : const Color(0xFFEF4444).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _verifyIsValid
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _verifyResult!, 
                        style: TextStyle(
                          fontFamily: 'monospace', 
                          fontSize: 13,
                          color: _verifyIsValid ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)) : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Section 2 : Générer une clé ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Text('Générer une clé à la volée', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'La clé générée ici n\'est pas enregistrée dans la base de données. Utilisez "Licences" pour la garder en mémoire.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: fieldBg,
                      foregroundColor: textSecondary,
                      selectedForegroundColor: isDark ? Colors.white : const Color(0xFF059669),
                      selectedBackgroundColor: isDark ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFD1FAE5),
                    ),
                    segments: const [
                      ButtonSegment(value: 'annual', label: Text('Annuelle'), icon: Icon(Icons.calendar_today, size: 16)),
                      ButtonSegment(value: 'lifetime', label: Text('À vie'), icon: Icon(Icons.all_inclusive, size: 16)),
                    ],
                    selected: {_generatedType},
                    onSelectionChanged: (v) => setState(() {
                      _generatedType = v.first;
                      _generatedKey = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_generatedType == 'annual')
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _DarkTextField(
                            controller: _genExpiryCtrl,
                            label: 'Date d\'expiration (JJ/MM/AAAA)',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        ElevatedButton.icon(
                          onPressed: _generateKey,
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                          label: const Text('Générer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _generateKey,
                      icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                      label: const Text('Générer clé À vie'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                  if (_generatedKey != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _generatedKey!,
                              style: TextStyle(color: textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                            tooltip: 'Copier',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _generatedKey!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Clé copiée !')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Section 3 : Informations du système ───────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF8B5CF6), size: 20),
                      const SizedBox(width: 10),
                      Text('Informations Système', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _InfoLine(label: 'Format des clés', value: 'NMAS-YYYYMMDD-HMAC8'),
                  _InfoLine(label: 'Algorithme de signature', value: 'HMAC-SHA256 (8 caractères)'),
                  _InfoLine(label: 'Durée d\'essai', value: '${LicenseCore.trialDays} jours'),
                  _InfoLine(label: 'Clé Lifetime', value: 'Expiration = 9999-12-31'),
                  _InfoLine(label: 'Préfixe requis', value: 'NMAS'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget helper pour les champs de texte ─────────────────────────────
class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return TextFormField(
      controller: controller,
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
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text('$label :', style: TextStyle(fontWeight: FontWeight.w600, color: textSecondary)),
          ),
          Expanded(child: Text(value, style: TextStyle(fontFamily: 'monospace', color: textPrimary))),
        ],
      ),
    );
  }
}
