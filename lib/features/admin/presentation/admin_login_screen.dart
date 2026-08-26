import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_form_field.dart';
import '../application/admin_auth_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _passwordController = TextEditingController();
  bool _isFirstTime = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final hasPassword = await ref.read(adminAuthProvider.notifier).hasPasswordSet();
    if (mounted) {
      setState(() {
        _isFirstTime = !hasPassword;
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty) {
      setState(() => _error = 'Veuillez saisir un mot de passe.');
      return;
    }

    setState(() => _error = null);

    final notifier = ref.read(adminAuthProvider.notifier);
    if (_isFirstTime) {
      await notifier.setPassword(pwd);
      if (mounted) context.go('/admin/dashboard');
    } else {
      final success = await notifier.login(pwd);
      if (success) {
        if (mounted) context.go('/admin/dashboard');
      } else {
        setState(() => _error = 'Mot de passe incorrect.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.admin_panel_settings_rounded, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'N\'MaShop Admin',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isFirstTime
                    ? 'Définissez un mot de passe maître pour sécuriser cet accès.'
                    : 'Veuillez saisir le mot de passe maître.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppFormField(
                controller: _passwordController,
                label: 'Mot de passe',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isFirstTime ? 'Définir et Continuer' : 'Accéder',
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Retour à la boutique'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
