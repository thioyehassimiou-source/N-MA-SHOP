import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/admin_providers.dart';
import '../../core/theme/app_theme.dart';

class PinAuthScreen extends ConsumerStatefulWidget {
  const PinAuthScreen({super.key});

  @override
  ConsumerState<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends ConsumerState<PinAuthScreen> {
  final _usernameCtrl = TextEditingController(text: 'admin');
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMsg;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final repo = ref.read(adminRepositoryProvider);
    final correctPin = repo.getPin();

    if (_usernameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Veuillez saisir votre identifiant');
      return;
    }

    final inputPin = _passwordCtrl.text.trim();
    if (inputPin == correctPin) {
      ref.read(isAuthenticatedProvider.notifier).authenticate();
    } else {
      setState(() => _errorMsg = 'Mot de passe ou code PIN incorrect');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bgSlate,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Hero Gradient Header with Curved Arc
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, mediaQuery.padding.top + 32, 24, 40),
              decoration: const BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3D4F46E5),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Logo Box with Glowing Monogram
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/admin_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // N'MaShop KeyManager Pro Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'N\'MASHOP KEYMANAGER PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Portail d\'Administration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Form Content Container
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Card(
                elevation: 4,
                shadowColor: AppTheme.primaryIndigo.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: AppTheme.borderSlate),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Connexion Securisée',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Accédez au contrôle des licences PC',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.roseBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.roseAlert.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.roseAlert, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: const TextStyle(color: AppTheme.roseAlert, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Username Input
                      TextField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Identifiant Administrateur',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primaryIndigo),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password / PIN Input
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        keyboardType: TextInputType.visiblePassword,
                        onSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe ou Code PIN',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryIndigo),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Button with Brand Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.brandGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryIndigo.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Accéder au Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'N\'MaShop Business Solutions © 2026',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
