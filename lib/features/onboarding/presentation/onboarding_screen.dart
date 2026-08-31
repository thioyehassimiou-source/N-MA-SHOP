import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/startup_flags.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_backdrop.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class _OnboardingPage {
  const _OnboardingPage({
    required this.image,
    required this.tag,
    required this.title,
    required this.description,
    required this.accent,
    required this.features,
  });

  final String image;
  final String tag;
  final String title;
  final String description;
  final Color accent;
  final List<String> features;
}

const _pages = [
  _OnboardingPage(
    image: 'assets/images/onboarding_sales.png',
    tag: 'VENTES',
    title: 'Encaissez en toute confiance',
    description:
        'Enregistrez chaque vente en quelques secondes, générez des reçus et '
        'suivez vos recettes journalières sans effort.',
    accent: AppColors.brandEmerald,
    features: ['Reçus automatiques', 'Ventes rapides', 'Historique complet'],
  ),
  _OnboardingPage(
    image: 'assets/images/onboarding_stock.png',
    tag: 'STOCKS',
    title: 'Gardez toujours le contrôle',
    description:
        "Soyez alerté avant d'être en rupture. Gérez vos entrées, suivez vos "
        'produits et évitez les mauvaises surprises.',
    accent: AppColors.brandEmerald,
    features: [
      'Alertes de rupture',
      'Suivi en temps réel',
      'Gestion fournisseurs',
    ],
  ),
  _OnboardingPage(
    image: 'assets/images/onboarding_bilan.png',
    tag: 'BILAN',
    title: 'Voyez vos profits clairement',
    description:
        "Accédez à votre bilan en un clin d'œil : ventes du jour, gains nets, "
        'dettes clients. Vos finances à portée de main.',
    accent: AppColors.brandEmerald,
    features: ['Bilan mensuel', 'Gains nets', 'Crédits clients'],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _fadeController.reset();
    _fadeController.forward();
  }

  void _previous() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 800;

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return isWide ? _buildWidePage(page) : _buildNarrowPage(page);
            },
          ),

          // Bandeau « Se connecter / Accéder à la boutique existante » :
          // n'apparaît que si une boutique est déjà configurée sur cet appareil.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Consumer(
                builder: (context, ref, _) {
                  final hasData = ref.watch(businessDataExistsProvider);
                  if (!hasData) return const SizedBox.shrink();
                  return _buildResumeRibbon(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeRibbon(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/setup'),
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.brandNavy,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppColors.brandOrange.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 18, color: AppColors.brandOrange),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Accéder à ma boutique existante',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.brandOrange),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWidePage(_OnboardingPage page) {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildImagePanel(page)),
        Expanded(flex: 5, child: _buildInfoPanel(page)),
      ],
    );
  }

  Widget _buildNarrowPage(_OnboardingPage page) {
    return Column(
      children: [
        Expanded(flex: 5, child: _buildImagePanel(page)),
        Expanded(flex: 5, child: _buildInfoPanel(page)),
      ],
    );
  }

  Widget _buildImagePanel(_OnboardingPage page) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          page.image,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const ColoredBox(
            color: AppColors.brandNavyLight,
            child: Center(
              child: Icon(Icons.storefront, size: 80, color: Colors.white24),
            ),
          ),
        ),
        // Voile haut discret
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Logo N'MaShop avec conteneur stylisé sur la photo
        Positioned(
          top: AppSpacing.lg,
          left: AppSpacing.lg,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandNavy.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const BrandLogo(height: 32, onDark: true),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel(_OnboardingPage page) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: context.colors.surface,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: page.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: page.accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      page.tag,
                      style: TextStyle(
                        color: page.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    page.title,
                    style: AppTypography.headlineLg.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    page.description,
                    style: AppTypography.bodyLg.copyWith(
                      color: context.colors.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: page.features.asMap().entries.map((e) {
                      final label = e.value;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, child) {
                          return Transform.translate(
                            offset: Offset(20 * (1 - val), 0),
                            child: Opacity(
                              opacity: val,
                              child: child,
                            ),
                          );
                        },
                        child: _chip(label, context),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Navigation intégrée proprement dans le panneau blanc de droite
            _buildInfoPanelNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: context.colors.onSurface.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoPanelNavigation() {
    final isLast = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          // Points de progression
          Row(
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: i == _currentPage ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _currentPage
                      ? AppColors.brandOrange
                      : context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentPage > 0) ...[
                  TextButton.icon(
                    onPressed: _previous,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Précédent'),
                  ),
                  const SizedBox(width: 4),
                ],
                if (!isLast) ...[
                  TextButton(
                    onPressed: () => context.go('/setup'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text('Passer'),
                  ),
                  const SizedBox(width: 6),
                ],
                FilledButton.icon(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  icon: Icon(
                    isLast
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isLast ? 'Configurer ma boutique' : 'Suivant',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
