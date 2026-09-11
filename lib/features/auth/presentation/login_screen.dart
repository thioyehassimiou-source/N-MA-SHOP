import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_settings_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_providers.dart';
import '../domain/repositories/auth_repository.dart';
import 'widgets/auth_layout.dart';

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

  final _recoverNameController = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoverFormKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _submitting = false;
  bool _rememberMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _rememberMe = prefs.getBool('auth_remember_me') ?? false;
    final rememberedName = prefs.getString('auth_remembered_name');
    if (rememberedName != null && rememberedName.isNotEmpty) {
      _nameController.text = rememberedName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _recoverNameController.dispose();
    _recoveryCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
            rememberMe: _rememberMe,
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

  void _showRecoverPasswordDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Réinitialiser le mot de passe'),
        content: Form(
          key: _recoverFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _recoverNameController,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Entrez votre nom' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _recoveryCodeController,
                decoration: const InputDecoration(labelText: 'Code secret'),
                validator: (v) => v == null || v.isEmpty ? 'Entrez le code secret' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (v) => v == null || v.isEmpty ? 'Entrez le nouveau mot de passe' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                validator: (v) => v != _newPasswordController.text ? 'Les mots de passe ne correspondent pas' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (_recoverFormKey.currentState?.validate() != true) return;
              try {
                await ref.read(authProvider.notifier).recoverPassword(
                  fullName: _recoverNameController.text,
                  recoveryCode: _recoveryCodeController.text,
                  newPassword: _newPasswordController.text,
                );
                if (!mounted) return;
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mot de passe réinitialisé')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur : $e')),
                );
              }
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
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
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      height: 22,
                      width: 22,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) => setState(() => _rememberMe = val ?? false),
                        activeColor: context.colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se souvenir de moi (Rester connecté)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (_error != null) AuthErrorBanner(_error!),

            const SizedBox(height: AppSpacing.md),

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

            Center(
              child: TextButton(
                onPressed: _showRecoverPasswordDialog,
                child: Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(color: context.colors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
