import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../data/auth_service.dart';
import '../../shell/main_navigation_shell.dart';
import 'login_shop_screen.dart';

/// Assistant de Configuration Mobile — Reprend le workflow exact Desktop (Stepper 3 étapes).
class RegisterShopScreen extends ConsumerStatefulWidget {
  const RegisterShopScreen({super.key});

  @override
  ConsumerState<RegisterShopScreen> createState() => _RegisterShopScreenState();
}

class _RegisterShopScreenState extends ConsumerState<RegisterShopScreen> {
  int _currentStep = 0; // 0 = Boutique, 1 = Licence, 2 = Patron (PIN)

  final _shopFormKey = GlobalKey<FormState>();
  final _pinFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _currencyController = TextEditingController(text: 'GNF');
  final _deviceNameController = TextEditingController(text: 'Smartphone Patron');
  final _licenseKeyController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _useTrialMode = true;
  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _deviceNameController.dispose();
    _licenseKeyController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _navigateToMain() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      (route) => false,
    );
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_shopFormKey.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_pinFormKey.currentState!.validate()) {
        if (_pinController.text.trim() != _confirmPinController.text.trim()) {
          setState(() => _errorMessage = 'Les deux codes PIN ne sont pas identiques.');
          return;
        }
        _submit();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0 && !_isLoading) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(authServiceProvider).registerShop(
          shopName: _nameController.text.trim(),
          currency: _currencyController.text.trim().isEmpty ? 'GNF' : _currencyController.text.trim(),
          pin: _pinController.text.trim(),
          deviceName: _deviceNameController.text.trim().isEmpty ? 'Smartphone Patron' : _deviceNameController.text.trim(),
        );

    if (!mounted) return;

    if (result.isSuccess) {
      _navigateToMain();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage ?? 'Échec de la création de la boutique.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0) {
              _prevStep();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const BrandLogo(height: 32, onDark: true),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Banner de présentation Desktop Style
          _buildTopBrandBanner(),

          // En-tête Stepper d'étapes (1. Boutique -> 2. Licence -> 3. Patron)
          _buildStepperHeader(),

          // Contenu principal dynamique par étape
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStepContent(),
              ),
            ),
          ),

          // Navigation Footer (Précédent / Suivant / Créer)
          _buildNavigationFooter(),
        ],
      ),
    );
  }

  Widget _buildTopBrandBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: AppColors.heroNavyGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'ASSISTANT DE CONFIGURATION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStepHeadingTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getStepHeadingSubtitle(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  String _getStepHeadingTitle() {
    switch (_currentStep) {
      case 0:
        return 'Fiche de votre Boutique';
      case 1:
        return 'Licence & Activation';
      case 2:
        return 'Compte Patron Sécurisé';
      default:
        return 'Configuration N\'MaShop';
    }
  }

  String _getStepHeadingSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Renseignez l\'identité commerciale qui figurera sur vos reçus.';
      case 1:
        return 'Choisissez d\'activer une licence ou de démarrer votre essai gratuit.';
      case 2:
        return 'Définissez le code PIN secret protégeant l\'accès patron.';
      default:
        return '';
    }
  }

  Widget _buildStepperHeader() {
    final steps = ['Boutique', 'Licence', 'Patron'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isDone = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDone || isCurrent ? AppColors.brandOrange : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : Colors.grey[700],
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    steps[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: isCurrent ? AppColors.brandNavy : Colors.grey[600],
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: isDone ? AppColors.brandOrange : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Shop();
      case 1:
        return _buildStep2License();
      case 2:
        return _buildStep3Account();
      default:
        return const SizedBox.shrink();
    }
  }

  // ÉTAPE 1 : Fiche Boutique (Nom, Devise, Appareil)
  Widget _buildStep1Shop() {
    return Form(
      key: _shopFormKey,
      child: Column(
        key: const ValueKey('step_shop'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Nom de votre boutique *'),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco('Ex: Boutique Diallo & Frères', Icons.storefront_rounded),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Le nom de la boutique est obligatoire' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Devise principale'),
                          TextFormField(
                            controller: _currencyController,
                            decoration: _inputDeco('GNF', Icons.payments_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Nom de l\'appareil'),
                          TextFormField(
                            controller: _deviceNameController,
                            decoration: _inputDeco('Smartphone Patron', Icons.phone_android_rounded),
                          ),
                        ],
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
                  MaterialPageRoute(builder: (_) => const LoginShopScreen()),
                );
              },
              icon: const Icon(Icons.login_rounded, size: 16, color: AppColors.brandOrange),
              label: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  children: [
                    TextSpan(text: 'Déjà un compte ? '),
                    TextSpan(
                      text: 'Se connecter',
                      style: TextStyle(color: AppColors.brandOrange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ÉTAPE 2 : Licence & Activation
  Widget _buildStep2License() {
    return Column(
      key: const ValueKey('step_license'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOptionCard(
          selected: _useTrialMode,
          icon: Icons.card_giftcard_rounded,
          title: 'Période d\'essai gratuite (30 jours)',
          subtitle: 'Découvrez toutes les fonctionnalités de N\'MaShop Mobile sans engagement.',
          onTap: () => setState(() => _useTrialMode = true),
        ),
        const SizedBox(height: 14),

        _buildOptionCard(
          selected: !_useTrialMode,
          icon: Icons.verified_user_rounded,
          title: 'J\'ai une clé de licence',
          subtitle: 'Activez votre clé officielle fournie par l\'équipe N\'MaShop.',
          onTap: () => setState(() => _useTrialMode = false),
        ),

        if (!_useTrialMode) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Clé de licence (NMA-MOB-...)'),
                TextFormField(
                  controller: _licenseKeyController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDeco('NMA-MOB-XXXX-XXXX', Icons.vpn_key_rounded),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ÉTAPE 3 : Compte Patron (Code PIN Secret)
  Widget _buildStep3Account() {
    return Form(
      key: _pinFormKey,
      child: Column(
        key: const ValueKey('step_account'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Code PIN secret Patron (4 à 8 chiffres) *'),
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePin,
                  maxLength: 8,
                  decoration: _inputDeco(
                    '••••',
                    Icons.pin_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().length < 4) ? 'Code PIN de 4 à 8 chiffres requis' : null,
                ),
                const SizedBox(height: 12),

                _buildLabel('Confirmer le code PIN *'),
                TextFormField(
                  controller: _confirmPinController,
                  keyboardType: TextInputType.number,
                  obscureText: _obscureConfirm,
                  maxLength: 8,
                  decoration: _inputDeco(
                    '••••',
                    Icons.lock_clock_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().length < 4) ? 'Confirmation requise' : null,
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
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandOrange.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.brandOrange : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandOrange : AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: selected ? Colors.white : AppColors.brandNavy, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: selected ? AppColors.brandNavy : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.brandOrange : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationFooter() {
    final isLast = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _prevStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandNavy,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _nextStep,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(isLast ? Icons.storefront_rounded : Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  isLast ? 'Créer ma boutique' : 'Continuer',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.brandNavy,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.brandNavy, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandOrange, width: 2),
      ),
    );
  }
}
