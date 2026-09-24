import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../data/auth_service.dart';
import '../../shell/main_navigation_shell.dart';
import 'register_shop_screen.dart';

/// Écran de Connexion Patron Mobile — Design Tactile Premium avec Clavier PIN.
class LoginShopScreen extends ConsumerStatefulWidget {
  const LoginShopScreen({super.key});

  @override
  ConsumerState<LoginShopScreen> createState() => _LoginShopScreenState();
}

class _LoginShopScreenState extends ConsumerState<LoginShopScreen> {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  String _shopName = 'Ma Boutique';

  @override
  void initState() {
    super.initState();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final storage = ref.read(storageServiceProvider);
    final name = await storage.getShopName();
    if (mounted && name.isNotEmpty) {
      setState(() => _shopName = name);
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      (route) => false,
    );
  }

  void _onKeypadTap(String digit) {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      if (_pin.length < 4) {
        _pin += digit;
        if (_pin.length == 4) {
          _submit();
        }
      }
    });
  }

  void _onKeypadBackspace() {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _submit() async {
    if (_pin.length < 4) {
      setState(() => _errorMessage = 'Code PIN à 4 chiffres requis');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(authServiceProvider).loginWithPin(_pin);

    if (!mounted) return;

    if (result.isSuccess) {
      _navigateToMain();
    } else {
      setState(() {
        _isLoading = false;
        _pin = '';
        _errorMessage = result.errorMessage ?? 'Code PIN incorrect.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.brandNavy,
        child: SafeArea(
          bottom: false,
          child: Container(
            color: AppColors.background,
            child: Column(
              children: [
                // Top Header unifié avec la barre de statut
                _buildTopHeader(),

                // Contenu principal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card d'affichage du PIN et statut
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.brandOrange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.storefront_rounded, color: AppColors.brandOrange, size: 28),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _shopName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tapez votre code PIN Patron à 4 chiffres',
                                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 16),

                              // Indicateurs de points PIN animés
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (index) {
                                  final isFilled = index < _pin.length;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    width: isFilled ? 18 : 14,
                                    height: isFilled ? 18 : 14,
                                    decoration: BoxDecoration(
                                      color: isFilled ? AppColors.brandOrange : AppColors.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isFilled ? AppColors.brandOrange : AppColors.border,
                                        width: 2,
                                      ),
                                      boxShadow: isFilled
                                          ? [
                                              BoxShadow(
                                                color: AppColors.brandOrange.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_isLoading) ...[
                          const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
                          const SizedBox(height: 16),
                        ],

                        // Clavier Tactile Numérique
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: ['1', '2', '3'].map((d) => _buildKeypadButton(d)).toList(),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: ['4', '5', '6'].map((d) => _buildKeypadButton(d)).toList(),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: ['7', '8', '9'].map((d) => _buildKeypadButton(d)).toList(),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  const SizedBox(width: 64, height: 64),
                                  _buildKeypadButton('0'),
                                  InkWell(
                                    onTap: _onKeypadBackspace,
                                    borderRadius: BorderRadius.circular(32),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.backspace_outlined, color: AppColors.brandNavy, size: 24),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const RegisterShopScreen()),
                              );
                            },
                            icon: const Icon(Icons.add_business_rounded, size: 16, color: AppColors.brandOrange),
                            label: RichText(
                              text: const TextSpan(
                                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                                children: [
                                  TextSpan(text: 'Nouvelle boutique ? '),
                                  TextSpan(
                                    text: 'Créer ma boutique',
                                    style: TextStyle(color: AppColors.brandOrange, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.brandNavy,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Center(
                  child: BrandLogo(height: 30, onDark: true),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandOrange.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ESPACE SÉCURISÉ PATRON',
              style: TextStyle(
                color: AppColors.brandOrangeLight,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Content de vous revoir',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saisissez votre code PIN secret à 4 chiffres pour ouvrir votre boutique.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeypadTap(digit),
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.brandNavy,
            ),
          ),
        ),
      ),
    );
  }
}
