import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../auth/presentation/auth_landing_screen.dart';

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
        title: '100% Fonctionnel Hors-ligne',
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
        description: 'Bippez vos produits directement à l\'aide de la caméra de votre téléphone.',
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
        title: 'Protection Patron Sécurisée',
        description: 'Confidentialité totale de vos bénéfices grâce à votre code PIN secret.',
      ),
    ],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String prefKeyHasSeenOnboarding = 'nmashop_has_seen_onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.prefKeyHasSeenOnboarding, true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, anim, secAnim) => const AuthLandingScreen(),
        transitionsBuilder: (context, animation, secAnim, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // En-tête : Logo N'MaShop & Bouton Passer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BrandLogo(height: 36),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Passer',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Carrousel de slides (adapté exact du Desktop)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPageContent(page);
                },
              ),
            ),

            // Pied de page : Dots & Bouton d'action principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isSelected ? 32 : 8,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.brandOrange : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.brandOrange.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppColors.brandOrange.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'Démarrer l\'expérience patron'
                                : 'Suivant',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(_OnboardingPage page) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panneau Image (exact Desktop onboarding_sales / stock / bilan)
          Container(
            height: 220,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    page.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.brandNavy,
                      child: const Center(
                        child: Icon(Icons.storefront_rounded, size: 64, color: Colors.white24),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tag Catégorie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: page.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              page.category,
              style: TextStyle(
                color: page.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Titre principal percutant
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.brandNavy,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // 3 points clés avec icônes
          ...page.features.map((feat) => _buildFeatureItem(feat, page.accent)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(_FeatureItem item, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
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
