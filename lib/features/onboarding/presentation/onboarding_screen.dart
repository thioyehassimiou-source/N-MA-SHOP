import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/startup_flags.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'package:nmashop/core/theme/app_theme.dart';

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.image,
    required this.category,
    required this.title,
    required this.description,
    required this.accent,
    required this.features,
  });

  final String image;
  final String category;
  final String title;
  final String description;
  final Color accent;
  final List<_FeatureItem> features;
}

const _pages = [
  _OnboardingPage(
    image: 'assets/images/onboarding_sales.png',
    category: 'VENTES & CAISSE',
    title: 'Encaissez chaque vente en quelques secondes',
    description:
        'Une expérience de caisse fluide et intuitive conçue pour votre quotidien. '
        'Éditez des reçus professionnels et sécurisez vos recettes sans effort.',
    accent: AppColors.brandOrange,
    features: [
      _FeatureItem(
        icon: Icons.receipt_long_rounded,
        title: 'Reçus thermiques & Factures',
        description: 'Impression instantanée sur imprimante 58/80mm ou partage PDF.',
      ),
      _FeatureItem(
        icon: Icons.payments_rounded,
        title: 'Multiples modes de paiement',
        description: 'Encaissement par Espèces, Orange Money, Wave, Moov et virements.',
      ),
      _FeatureItem(
        icon: Icons.wifi_off_rounded,
        title: '100% Autonome Hors-ligne',
        description: 'Continuez d\'enregistrer vos ventes même sans connexion internet.',
      ),
    ],
  ),
  _OnboardingPage(
    image: 'assets/images/onboarding_stock.png',
    category: 'STOCKS & INVENTAIRE',
    title: 'Gardez un contrôle total sur vos marchandises',
    description:
        'Suivez vos entrées, vos sorties et vos quantités disponibles en temps réel. '
        'Évitez les ruptures imprévues et réduisez les pertes.',
    accent: AppColors.brandEmerald,
    features: [
      _FeatureItem(
        icon: Icons.notification_important_rounded,
        title: 'Alertes automatiques de rupture',
        description: 'Soyez prévenu avant l\'épuisement de vos articles les plus demandés.',
      ),
      _FeatureItem(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Scan rapide par code-barres',
        description: 'Bippez vos produits directement à l\'aide d\'une douchette USB.',
      ),
      _FeatureItem(
        icon: Icons.local_shipping_rounded,
        title: 'Suivi des approvisionnements',
        description: 'Historique clair des livraisons fournisseurs et des réassorts.',
      ),
    ],
  ),
  _OnboardingPage(
    image: 'assets/images/onboarding_bilan.png',
    category: 'FINANCES & BÉNÉFICES',
    title: 'Visualisez vos bénéfices réels avec précision',
    description:
        'Accédez à une vue claire de votre activité commerciale en un coup d\'œil : '
        'recettes du jour, marge nette dégagée et suivi des crédits clients.',
    accent: Color(0xFF2563EB),
    features: [
      _FeatureItem(
        icon: Icons.trending_up_rounded,
        title: 'Calcul automatique des marges nettes',
        description: 'Connaissez votre rentabilité exacte sans calcul sur cahier.',
      ),
      _FeatureItem(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Gestion des crédits clients',
        description: 'Suivi rigoureux des dettes et historique des règlements partiels.',
      ),
      _FeatureItem(
        icon: Icons.shield_rounded,
        title: 'Protection Administrateur',
        description: 'Confidentialité totale de vos bénéfices grâce à un code secret.',
      ),
    ],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350),
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
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go('/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 880;

    return Scaffold(
      backgroundColor: context.colors.surface,
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

          // Bandeau d'accès direct si une boutique existe déjà sur l'appareil
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
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
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
                      fontSize: 13,
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
        Expanded(flex: 6, child: _buildInfoPanel(page)),
      ],
    );
  }

  Widget _buildNarrowPage(_OnboardingPage page) {
    return Column(
      children: [
        SizedBox(height: 250, child: _buildImagePanel(page)),
        Expanded(child: _buildInfoPanel(page)),
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
          errorBuilder: (context, error, stack) => ColoredBox(
            color: AppColors.brandNavy,
            child: Center(
              child: Icon(Icons.storefront_rounded, size: 80, color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
        ),
        // Voile dégradé sobre et élégant
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel(_OnboardingPage page) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 48,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contenu centré avec espacements généreux (style SaaS épuré)
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag catégorie minimaliste
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: page.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            page.category,
                            style: TextStyle(
                              color: page.accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Titre principal percutant
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: context.colors.onSurface,
                            height: 1.2,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Description simple et aérée
                        Text(
                          page.description,
                          style: TextStyle(
                            fontSize: 15,
                            color: context.colors.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 3 points clés simples et attrayants
                        ...page.features.map((feat) => _buildFeatureItem(feat, page.accent)),
                      ],
                    ),
                  ),
                ),
              ),

              // Pied de page : pagination propre et boutons de navigation
              _buildFooterNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(_FeatureItem item, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNavigation() {
    final isLast = _currentPage == _pages.length - 1;

    return Row(
      children: [
        // Numérotation explicite (Étape X sur 3) et indicateurs fins
        Row(
          children: [
            Text(
              'Étape ${_currentPage + 1} sur ${_pages.length}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 6),
                  width: i == _currentPage ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? AppColors.brandOrange
                        : context.colors.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),

        // Boutons de navigation
        if (_currentPage > 0) ...[
          TextButton.icon(
            onPressed: _previous,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
        if (!isLast) ...[
          TextButton(
            onPressed: () => context.go('/setup'),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Passer', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton.icon(
          onPressed: _next,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          icon: Icon(
            isLast ? Icons.storefront_rounded : Icons.arrow_forward_rounded,
            size: 17,
          ),
          label: Text(
            isLast ? 'Configurer ma boutique' : 'Suivant',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}
