import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_providers.dart';
import '../domain/repositories/auth_repository.dart';
import 'widgets/auth_layout.dart';
import '../../../core/widgets/app_form_dialog.dart';

import 'package:nmashop/core/theme/app_theme.dart';

/// Écran de déverrouillage : l'application demande le nom complet du boutiquier
/// ainsi que son mot de passe.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).unlock(
            fullName: _nameController.text,
            password: _passwordController.text,
          );
      // Le routeur bascule seul sur le tableau de bord en observant la session.
    } on AuthException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Ouverture impossible : $e';
      });
    }
  }

  /// Réinitialise complètement la boutique après confirmation de l'utilisateur.
  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppFormDialog(
        title: 'Réinitialiser la boutique ?',
        subtitle: 'Cette action supprime toutes les données (ventes, stock, compte administrateur).\n\nCette opération est irréversible.',
        icon: Icons.warning_amber_rounded,
        gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
        width: 450,
        primaryLabel: 'Réinitialiser',
        primaryIcon: Icons.delete_forever,
        onCancel: () => Navigator.of(ctx).pop(false),
        onPrimary: () => Navigator.of(ctx).pop(true),
        body: const SizedBox.shrink(),
      ),
    );

    if (confirm != true || !mounted) return;

    // 1. Déconnexion et suppression du compte dans la session Riverpod
    await ref.read(authProvider.notifier).deleteAccount();

    // 2. Vider les préférences (isSetupCompleted, businessName, licence...)
    await ref.read(appSettingsProvider.notifier).resetSetup();

    // 3. Purger l'intégralité de la base de données SQLite
    final db = ref.read(databaseProvider);
    await db.purgeAllData();

    if (!mounted) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final businessName = ref.watch(appSettingsProvider).businessName;

    return AuthLayout(
      title: 'Content de vous revoir',
      subtitle: 'Saisissez vos identifiants pour ouvrir $businessName.',
      pitch: 'Gérez votre boutique\ncomme un pro.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthFieldLabel('Nom complet'),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: authInputDecoration(
                context,
                'Ex: Mamadou Diallo',
                Icons.person_outline_rounded,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Saisissez votre nom complet'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),

            const AuthFieldLabel('Mot de passe'),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submitting ? null : _submit(),
              decoration: authInputDecoration(
                context,
                '••••••••',
                Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Saisissez votre mot de passe'
                  : null,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (_error != null) AuthErrorBanner(_error!),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_open_rounded, size: 18),
                label: Text(
                  _submitting ? 'Ouverture...' : 'Ouvrir ma boutique',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/onboarding'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text("Revoir la présentation"),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.primary,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: _confirmReset,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reconfigurer'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.onSurfaceVariant,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
