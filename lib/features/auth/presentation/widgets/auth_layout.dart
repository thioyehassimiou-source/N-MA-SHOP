import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/animated_backdrop.dart';

import 'package:nmashop/core/theme/app_theme.dart';

/// Longueur minimale d'un mot de passe accepté.
const kMinPasswordLength = 6;

/// Mise en page commune aux écrans de connexion et d'inscription :
/// panneau de marque animé à gauche, formulaire lisible à droite.
///
/// Sur écran étroit, seul le formulaire reste, surmonté d'une entête réduite.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pitch,
    required this.child,
    this.onBack,
    this.showBackButton = true,
  });

  /// Titre du formulaire (« Content de vous revoir »).
  final String title;

  /// Ligne d'explication sous le titre.
  final String subtitle;

  /// Accroche affichée sur le panneau de marque.
  final String pitch;

  final Widget child;

  /// Action de retour personnalisée
  final VoidCallback? onBack;

  /// Affiche un bouton de retour
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 800;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.brandNavy,
              AppColors.brandNavyLight,
              Color(0xFF1E3A6E),
            ],
          ),
        ),
        child: isWide
            ? Row(
                children: [
                  Expanded(flex: 6, child: _buildBrandPanel()),
                  Expanded(flex: 4, child: _buildFormPanel(context)),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 200, child: _buildBrandPanel(compact: true)),
                    _buildFormPanel(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBrandPanel({bool compact = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond animé avec les nouvelles photos professionnelles
        const AnimatedBackdrop(scrimOpacity: 0.5),

        // Voile dégradé sombre élégant
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  const Color(0xFF0B132B).withValues(alpha: 0.85),
                ],
                stops: const [0.25, 1.0],
              ),
            ),
          ),
        ),

        // Contenu du panneau gauche
        Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.lg : 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Véritable logo officiel N'MaShop avec carte blanche contrastée
              BrandLogo(
                height: compact ? 38 : 50,
                showCard: true,
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),

              // Carte de présentation glassmorphic
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ESPACE SÉCURISÉ',
                        style: TextStyle(
                          color: AppColors.brandOrangeLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pitch,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 18 : 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 16),
                      _buildBulletItem(Icons.point_of_sale_rounded, 'Point de vente & Encaissement ultra-rapide'),
                      const SizedBox(height: 10),
                      _buildBulletItem(Icons.wifi_off_rounded, 'Données sécurisées 100% Hors-ligne'),
                      const SizedBox(height: 10),
                      _buildBulletItem(Icons.security_rounded, 'Protection Administrateur garantie'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brandOrangeLight),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormPanel(BuildContext context) {
    return Container(
      color: context.colors.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - val)),
                  child: Opacity(
                    opacity: val,
                    child: child,
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBackButton) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: OutlinedButton.icon(
                          onPressed: onBack ?? () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.go('/setup');
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.onSurfaceVariant,
                            side: BorderSide(color: context.colors.outlineVariant),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 15),
                          label: const Text(
                            'Retour à la configuration',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.colors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Libellé de champ, aligné sur celui de l'écran de configuration.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Décoration commune des champs de saisie des écrans d'authentification.
InputDecoration authInputDecoration(
  BuildContext context,
  String hint,
  IconData icon, {
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
    prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 19),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: context.colors.primary, width: 2),
    ),
  );
}

/// Bandeau d'erreur affiché au-dessus du bouton de validation.
class AuthErrorBanner extends StatefulWidget {
  const AuthErrorBanner(this.message, {super.key});
  final String message;

  @override
  State<AuthErrorBanner> createState() => _AuthErrorBannerState();
}

class _AuthErrorBannerState extends State<AuthErrorBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    // Animation de secousse (shake)
    _anim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(AuthErrorBanner old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_anim.value, 0),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: context.colors.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicateur de force du mot de passe
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  final String password;

  double get _strength {
    if (password.isEmpty) return 0.0;
    double score = 0.0;
    if (password.length >= 8) score += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) score += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) score += 0.25;
    if (password.contains(RegExp(r'[!@#\$&*~]'))) score += 0.25;
    return score;
  }

  Color _getColor(BuildContext context, double strength) {
    if (strength <= 0.25) return context.colors.error;
    if (strength <= 0.5) return Colors.orange;
    if (strength <= 0.75) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getLabel(double strength) {
    if (strength == 0) return 'Mot de passe';
    if (strength <= 0.25) return 'Faible';
    if (strength <= 0.5) return 'Moyen';
    if (strength <= 0.75) return 'Bon';
    return 'Fort';
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    final color = _getColor(context, strength);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            final isActive = strength >= (index + 1) * 0.25;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: isActive ? color : context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _getLabel(strength),
          style: TextStyle(
            fontSize: 11,
            color: strength == 0 ? context.colors.onSurfaceVariant : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
