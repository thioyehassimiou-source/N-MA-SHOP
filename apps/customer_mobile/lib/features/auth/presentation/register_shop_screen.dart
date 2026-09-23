import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../data/auth_service.dart';
import '../../shell/main_navigation_shell.dart';
import 'login_shop_screen.dart';

/// Assistant de Configuration Mobile — Workflow Stepper 3 étapes.
class RegisterShopScreen extends ConsumerStatefulWidget {
  const RegisterShopScreen({super.key});

  @override
  ConsumerState<RegisterShopScreen> createState() => _RegisterShopScreenState();
}

class _RegisterShopScreenState extends ConsumerState<RegisterShopScreen> {
  int _currentStep = 0; // 0 = Boutique, 1 = Licence, 2 = Patron (PIN)

  final _shopFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _currencyController = TextEditingController(text: 'GNF');
  final _deviceNameController = TextEditingController(text: 'Smartphone Patron');
  final _licenseKeyController = TextEditingController();
  String _pin = '';

  bool _useTrialMode = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _deviceNameController.dispose();
    _licenseKeyController.dispose();
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
      if (_pin.length < 4) {
        setState(() => _errorMessage = 'Veuillez saisir un code PIN à 4 chiffres.');
        return;
      }
      _submit();
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
          pin: _pin.trim(),
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

  void _onKeypadTap(String digit) {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      if (_pin.length < 4) {
        _pin += digit;
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
                // Top Navy Header unifié avec la barre de statut
                _buildTopBrandHeader(),

                // Header d'étapes (Stepper 1. Boutique -> 2. Licence -> 3. PIN)
                _buildStepperHeader(),

                // Contenu scrollable principal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentStepContent(),
                    ),
                  ),
                ),

                // Pied de page d'action (Précédent / Continuer)
                _buildNavigationFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBrandHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.brandNavy,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  if (_currentStep > 0) {
                    _prevStep();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              const Expanded(
                child: Center(
                  child: BrandLogo(height: 30, onDark: true),
                ),
              ),
              const SizedBox(width: 48), // Pour centrer le logo
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'ASSISTANT DE CONFIGURATION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
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
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getStepHeadingSubtitle(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
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
        return 'Définissez le code PIN secret à 4 chiffres pour ouvrir votre boutique.';
      default:
        return '';
    }
  }

  Widget _buildStepperHeader() {
    final steps = ['Boutique', 'Licence', 'Code PIN'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(steps.length, (index) {
          final isDone = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDone || isCurrent ? AppColors.brandOrange : Colors.grey[200],
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
              Text(
                steps[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  color: isCurrent ? AppColors.brandNavy : Colors.grey[600],
                ),
              ),
              if (index < steps.length - 1) ...[
                const SizedBox(width: 8),
                Container(
                  width: 16,
                  height: 2,
                  color: isDone ? AppColors.brandOrange : Colors.grey[300],
                ),
                const SizedBox(width: 8),
              ],
            ],
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

  // ÉTAPE 1 : Fiche Boutique
  Widget _buildStep1Shop() {
    return Form(
      key: _shopFormKey,
      child: Column(
        key: const ValueKey('step_shop'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                const SizedBox(height: 14),

                _buildLabel('Devise principale'),
                TextFormField(
                  controller: _currencyController,
                  decoration: _inputDeco('GNF', Icons.payments_rounded),
                ),
                const SizedBox(height: 14),

                _buildLabel('Nom de cet appareil'),
                TextFormField(
                  controller: _deviceNameController,
                  decoration: _inputDeco('Smartphone Patron', Icons.phone_android_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
        const SizedBox(height: 12),

        _buildOptionCard(
          selected: !_useTrialMode,
          icon: Icons.verified_user_rounded,
          title: 'J\'ai une clé de licence',
          subtitle: 'Activez votre clé officielle fournie par l\'équipe N\'MaShop.',
          onTap: () => setState(() => _useTrialMode = false),
        ),

        if (!_useTrialMode) ...[
          const SizedBox(height: 14),
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

  // ÉTAPE 3 : Compte Patron (Code PIN Tactile 4 chiffres)
  Widget _buildStep3Account() {
    return Column(
      key: const ValueKey('step_account'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
              const Text(
                'Créez votre code PIN secret à 4 chiffres',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ce code sécurise l\'accès à votre boutique sur ce téléphone',
                style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Indicateurs PIN Tactiles animés
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
        const SizedBox(height: 14),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Clavier Numérique Tactile
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['1', '2', '3'].map((d) => _buildKeypadButton(d)).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['4', '5', '6'].map((d) => _buildKeypadButton(d)).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['7', '8', '9'].map((d) => _buildKeypadButton(d)).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 60, height: 60),
                  _buildKeypadButton('0'),
                  InkWell(
                    onTap: _onKeypadBackspace,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: const Icon(Icons.backspace_outlined, color: AppColors.brandNavy, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeypadTap(digit),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 60,
          height: 60,
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.brandNavy,
            ),
          ),
        ),
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
          padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandOrange : AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: selected ? Colors.white : AppColors.brandNavy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: selected ? AppColors.brandNavy : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.brandOrange : Colors.grey[400],
                size: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                label: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandNavy,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 10),
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
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
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
