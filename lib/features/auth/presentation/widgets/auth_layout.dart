import 'package:flutter/material.dart';

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
  });

  /// Titre du formulaire (« Content de vous revoir »).
  final String title;

  /// Ligne d'explication sous le titre.
  final String subtitle;

  /// Accroche affichée sur le panneau de marque.
  final String pitch;

  final Widget child;

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
        // Fond animé avec photos de boutiques
        const AnimatedBackdrop(scrimOpacity: 0.45),

        // Gradient de bas vers le haut pour améliorer la lisibilité du texte
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0F1B3D).withValues(alpha: 0.6),
                ],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
        ),

        // Contenu du panneau
        Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo textuel intégré — aucun fond, rendu direct sur la photo
              _buildInlineLogo(compact: compact),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
              // Pitch
              if (!compact) ...[
                Text(
                  pitch,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    shadows: [
                      Shadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '— GÉRER  •  VENDRE  •  GRANDIR —',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 6),
                    ],
                  ),
                ),
              ] else
                Text(
                  pitch,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    shadows: [
                      Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Logo premium — intégré directement sur le fond sombre, style glassmorphism.
  Widget _buildInlineLogo({bool compact = false}) {
    final bagSize = compact ? 36.0 : 60.0;
    final nameFontSize = compact ? 22.0 : 42.0;
    final tagSize = compact ? 9.0 : 11.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icône sac stylisée
            Container(
              width: bagSize,
              height: bagSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(bagSize * 0.25),
                border: Border.all(
                  color: const Color(0xFFE85D04).withValues(alpha: 0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE85D04).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.shopping_bag_rounded,
                color: const Color(0xFFE85D04),
                size: bagSize * 0.55,
              ),
            ),
            SizedBox(width: compact ? 12 : 16),
            // Texte N'MA Shop
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "N'MA",
                        style: TextStyle(
                          color: const Color(0xFFE85D04),
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -1.0,
                          shadows: const [
                            Shadow(color: Color(0xBB000000), blurRadius: 16, offset: Offset(0, 3)),
                          ],
                        ),
                      ),
                      TextSpan(
                        text: 'Shop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -1.0,
                          shadows: const [
                            Shadow(color: Color(0xBB000000), blurRadius: 16, offset: Offset(0, 3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Swoosh orange sous le texte
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    height: 2.5,
                    width: nameFontSize * 4.2,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE85D04), Color(0xFFFF9A3D), Colors.transparent],
                        stops: [0.0, 0.6, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          // Tagline sous le logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: ['GÉRER', 'VENDRE', 'GRANDIR'].expand((tag) {
              final isLast = tag == 'GRANDIR';
              return [
                Text(
                  tag,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: tagSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE85D04),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ];
            }).toList(),
          ),
        ],
      ],
    );
  }


  Widget _buildFormPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        // En mode sombre, ajouter un léger dégradé pour donner plus de profondeur
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.surface,
                  const Color(0xFF0A1229), // Très foncé
                ],
              )
            : null,
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(-10, 0),
            ),
        ],
        // Bordure subtile orange pour séparer du fond
        border: isDark
            ? Border(
                left: BorderSide(
                  color: const Color(0xFFE85D04).withValues(alpha: 0.2),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - val)),
                  child: Opacity(
                    opacity: val,
                    child: child,
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
    prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
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
