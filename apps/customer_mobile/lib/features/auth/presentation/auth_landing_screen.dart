import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import 'login_shop_screen.dart';
import 'register_shop_screen.dart';

class AuthLandingScreen extends ConsumerWidget {
  const AuthLandingScreen({super.key});

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginShopScreen()),
    );
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterShopScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Halo ambiant de fond
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandOrange.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandOrange.withValues(alpha: 0.12),
                    blurRadius: 140,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),

                  // Header Badge Officiel avec Logo Desktop
                  const BrandLogo(height: 44, showCard: false),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.brandNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brandNavy.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.phone_android_rounded, color: AppColors.brandNavy, size: 13),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'N\'MASHOP MOBILE • GESTION COMMERCIALE & CAISSE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.brandNavy,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Card d'illustration utilisant l'image officielle Desktop (onboarding_sales.png)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroNavyGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandNavy.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  'assets/images/onboarding_sales.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppColors.brandNavyLight,
                                      child: const Center(
                                        child: Icon(Icons.storefront_rounded, size: 64, color: Colors.white70),
                                      ),
                                    );
                                  },
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          AppColors.brandNavy.withValues(alpha: 0.85),
                                        ],
                                        stops: const [0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: const [
                              Text(
                                'Votre Boutique dans la Poche',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pilotez vos ventes, votre caisse, vos stocks et vos créances directement depuis votre smartphone Android.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. BOUTON PRINCIPAL : ACCÉDER À MA BOUTIQUE (LOGIN)
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandOrange.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToLogin(context),
                      icon: const Icon(Icons.storefront_rounded, size: 22),
                      label: const Text(
                        'Ouvrir ma boutique',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. BOUTON SECONDAIRE : CRÉER UNE NOUVELLE BOUTIQUE (REGISTER)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToRegister(context),
                      icon: const Icon(Icons.add_business_rounded, size: 20, color: AppColors.brandNavy),
                      label: const Text(
                        'Créer une nouvelle boutique',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.brandNavy),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Pied de page : Note de sécurité
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shield_rounded, size: 14, color: AppColors.onSurfaceVariant),
                      SizedBox(width: 6),
                      Text(
                        'N\'MaShop Mobile • Données 100% Sécurisées',
                        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
