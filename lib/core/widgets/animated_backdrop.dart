import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Images du carrousel d'accueil, dans l'ordre de défilement.
const kBackdropImages = [
  'assets/images/onboarding_sales.png',
  'assets/images/onboarding_stock.png',
  'assets/images/onboarding_bilan.png',
];

/// Fond animé plein écran : les illustrations défilent lentement
/// (effet Ken Burns : zoom + translation) et se fondent l'une dans l'autre.
///
/// Utilisé en arrière-plan de l'onboarding et de la configuration pour donner
/// une première impression vivante sans nuire à la lisibilité du texte : un
/// voile dégradé marine est appliqué par-dessus.
class AnimatedBackdrop extends StatefulWidget {
  const AnimatedBackdrop({
    super.key,
    this.activeIndex,
    this.autoPlay = true,
    this.interval = const Duration(seconds: 7),
    this.scrimOpacity = 0.72,
  });

  /// Index imposé de l'image affichée. Si `null`, le carrousel avance seul.
  final int? activeIndex;

  /// Fait défiler les images automatiquement (ignoré si [activeIndex] est fourni).
  final bool autoPlay;

  /// Durée d'affichage d'une image avant le fondu vers la suivante.
  final Duration interval;

  /// Opacité maximale du voile marine posé sur les images.
  final double scrimOpacity;

  @override
  State<AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<AnimatedBackdrop> {
  late PageController _pageController;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.activeIndex ?? 0;
    _pageController = PageController(initialPage: _index);
    _restartTimer();
  }

  @override
  void didUpdateWidget(AnimatedBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex != null && widget.activeIndex != _index) {
      _index = widget.activeIndex!;
      _pageController.animateToPage(
        _index,
        duration: const Duration(milliseconds: 800),
        curve: Curves.fastOutSlowIn,
      );
    }
    if (widget.autoPlay != oldWidget.autoPlay ||
        widget.interval != oldWidget.interval ||
        widget.activeIndex != oldWidget.activeIndex) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.activeIndex != null || !widget.autoPlay) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      _index = (_index + 1) % kBackdropImages.length;
      _pageController.animateToPage(
        _index,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.brandNavy),

        // Carrousel coulissant d'images
        PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Désactive le scroll manuel pour garder l'effet
          itemBuilder: (context, index) {
            final imageIndex = index % kBackdropImages.length;
            return Image.asset(
              kBackdropImages[imageIndex],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: AppColors.brandNavy),
            );
          },
        ),

        // Voile marine : garantit le contraste du texte posé par-dessus.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandNavy.withValues(
                  alpha: widget.scrimOpacity + 0.16,
                ),
                AppColors.brandNavy.withValues(alpha: widget.scrimOpacity),
                AppColors.brandEmerald.withValues(alpha: 0.12),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),

        // Renfort en bas pour les commandes (indicateurs, boutons).
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.brandNavy.withValues(alpha: 0.75),
              ],
              stops: const [0.6, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo N'MaShop officiel — utilise les versions PNG transparentes haute résolution.
/// [onDark] sélectionne la version claire adaptée aux arrière-plans sombres.
/// [showCard] encapsule le logo dans un conteneur blanc soigné pour un contraste parfait sur photos complexes.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 42,
    this.onDark = false,
    this.showCard = false,
  });

  final double height;
  final bool onDark;
  final bool showCard;

  @override
  Widget build(BuildContext context) {
    // Si une carte est demandée (pour contraster sur une photo/arrière-plan complexe)
    if (showCard) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: height * 0.45,
          vertical: height * 0.22,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height * 0.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/logo.png',
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _fallbackLogo(darkFallback: false),
        ),
      );
    }

    final assetName = onDark ? 'assets/images/logo_light.png' : 'assets/images/logo.png';

    return Image.asset(
      assetName,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => _fallbackLogo(darkFallback: onDark),
    );
  }

  Widget _fallbackLogo({required bool darkFallback}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(height * 0.18),
          decoration: BoxDecoration(
            color: AppColors.brandOrange,
            borderRadius: BorderRadius.circular(height * 0.25),
          ),
          child: Icon(
            Icons.shopping_bag_rounded,
            color: Colors.white,
            size: height * 0.65,
          ),
        ),
        SizedBox(width: height * 0.25),
        Text(
          'N\'MaShop',
          style: TextStyle(
            color: darkFallback ? Colors.white : AppColors.brandNavy,
            fontSize: height * 0.65,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
