import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_model.dart';
import '../../../core/license/license_provider.dart';
import '../../../core/theme/app_spacing.dart';

/// Écran affiché quand la période d'essai ou la licence est expirée.
/// Bloque totalement l'accès à toutes les fonctionnalités.
class LicenseGateScreen extends ConsumerStatefulWidget {
  const LicenseGateScreen({super.key});

  @override
  ConsumerState<LicenseGateScreen> createState() => _LicenseGateScreenState();
}

class _LicenseGateScreenState extends ConsumerState<LicenseGateScreen>
    with SingleTickerProviderStateMixin {
  final _keyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isActivating = false;
  String? _errorMsg;
  bool _obscure = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isActivating = true;
      _errorMsg = null;
    });

    // Légère pause pour feedback visuel
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final res = await ref.read(licenseProvider.notifier).activate(_keyCtrl.text.trim());

    switch (res.result) {
      case LicenseActivationResult.success:
        // Le provider est déjà mis à jour — le router redirige automatiquement.
        if (mounted) context.go('/');
      case LicenseActivationResult.expiredKey:
        setState(() => _errorMsg = 'Cette clé a expiré. Contactez votre revendeur.');
      case LicenseActivationResult.invalidKey:
        setState(() => _errorMsg = 'Clé invalide. Vérifiez la saisie.');
      case LicenseActivationResult.deviceMismatch:
        setState(() => _errorMsg = 'Clé déjà activée sur une autre machine.');
    }

    if (mounted) setState(() => _isActivating = false);
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider);
    final isWide = MediaQuery.sizeOf(context).width > 780;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: isWide ? _buildWide(license) : _buildNarrow(license),
      ),
    );
  }

  Widget _buildWide(LicenseInfo license) {
    return Row(
      children: [
        // Panneau gauche — branding
        Expanded(
          flex: 5,
          child: _BrandPanel(license: license),
        ),
        // Panneau droit — formulaire
        Expanded(
          flex: 5,
          child: _buildForm(),
        ),
      ],
    );
  }

  Widget _buildNarrow(LicenseInfo license) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 220, child: _BrandPanel(license: license)),
          _buildForm(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Titre
                  const Text(
                    'Activer votre licence',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Entrez votre clé pour continuer à utiliser N\'MaShop.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 28),

                  // Champ clé
                  const Text(
                    'CLÉ DE LICENCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _keyCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      letterSpacing: 1.2,
                      color: Color(0xFF0F172A),
                    ),
                    inputFormatters: [
                      // Formater automatiquement en majuscules
                      TextInputFormatter.withFunction((old, newVal) {
                        return newVal.copyWith(text: newVal.text.toUpperCase());
                      }),
                    ],
                    decoration: InputDecoration(
                      hintText: 'NMAS-XXXXXXXX-XXXXXXXX',
                      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), letterSpacing: 0),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Entrez votre clé';
                      final parts = v.trim().split('-');
                      if (parts.length != 3 || parts[0] != 'NMAS') {
                        return 'Format invalide (NMAS-XXXXXXXX-XXXXXXXX)';
                      }
                      return null;
                    },
                  ),

                  // Bandeau d'erreur
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Bouton Activer
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isActivating ? null : _activate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isActivating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Activer la licence',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contact
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Obtenir une licence',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 6),
                        _ContactLine(
                          icon: Icons.phone_rounded,
                          label: '+224 621 XX XX XX',
                        ),
                        SizedBox(height: 4),
                        _ContactLine(
                          icon: Icons.email_rounded,
                          label: 'contact@nmashop.app',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Panneau de branding ───────────────────────────────────────────────────────

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.license});
  final LicenseInfo license;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4C1D95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Cercles décoratifs
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Contenu
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "N'MaShop",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    license.isTrial
                        ? 'Votre période d\'essai\nde 7 jours est terminée.'
                        : 'Votre licence a expiré.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Badge statut
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Accès bloqué',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget contact ───────────────────────────────────────────────────────────

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
      ],
    );
  }
}
