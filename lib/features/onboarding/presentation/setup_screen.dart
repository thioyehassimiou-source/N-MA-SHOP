import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_image_picker.dart';
import '../../../core/widgets/animated_backdrop.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_image.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../auth/presentation/widgets/auth_layout.dart' show kMinPasswordLength;

const kDomaines = [
  'Alimentation Générale',
  'Quincaillerie & Matériaux',
  'Mode & Prêt-à-porter',
  'Électronique & Informatique',
  'Cosmétique & Beauté',
  'Pharmacie & Santé',
  'Téléphonie & Accessoires',
  'Boulangerie & Pâtisserie',
  'Restaurant & Alimentation',
  'Matériel & Équipements',
  'Autre',
];

const kDeviseCode = 'GNF';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _currentStep = 0; // 0 = Boutique, 1 = Compte Admin

  final _shopFormKey = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _nifController = TextEditingController();

  bool _obscure = true;
  String? _selectedDomain;
  String? _logoPath;

  bool _saving = false;
  bool _acceptedTerms = true;

  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = () => _showTermsDialog(context);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _nameController.dispose();
    _ownerNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nifController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final savedPath = await AppImagePicker.pickLogoImage();
      if (savedPath != null && mounted) {
        setState(() => _logoPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sélection logo: $e')),
        );
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_shopFormKey.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_accountFormKey.currentState!.validate()) {
        if (!_acceptedTerms) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: context.colors.error,
              content: const Text('Vous devez accepter les conditions d\'utilisation.'),
            ),
          );
          return;
        }
        _submit();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0 && !_saving) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = ref.read(databaseProvider);
      await db.purgeAllData();

      await ref.read(authProvider.notifier).defineAccount(
        fullName: _ownerNameController.text.trim(),
        password: _passwordController.text,
      );

      await ref.read(appSettingsProvider.notifier).completeSetup(
        businessName: _nameController.text.trim(),
        currency: kDeviseCode,
        logoPath: _logoPath,
        businessDomain: _selectedDomain,
        businessPhone: _phoneController.text.trim(),
        paletteId: AppPalette.fallback.id,
      );

      if (mounted) {
        context.go('/');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: context.colors.error, content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: context.colors.error, content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AppFormDialog(
        title: 'Conditions d\'utilisation',
        subtitle: 'Contrat de licence et politique de confidentialité N\'MaShop.',
        icon: Icons.shield_rounded,
        gradientColors: const [AppColors.brandNavy, AppColors.brandNavyLight],
        width: 600,
        body: const SizedBox(
          height: 350,
          child: SingleChildScrollView(
            child: Text(
              "CONTRAT DE LICENCE UTILISATEUR FINAL ET POLITIQUE DE CONFIDENTIALITÉ\nLOGICIEL N'MASHOP\n\n"
              "1. ACCEPTATION DES CONDITIONS\n"
              "En installant et en utilisant l'application N'MaShop, vous acceptez d'être lié par les termes de ce contrat.\n\n"
              "2. LICENCE D'UTILISATION\n"
              "L'équipe N'MaShop vous accorde une licence non exclusive et non transférable pour utiliser ce Logiciel dans le cadre de la gestion de votre point de vente.\n\n"
              "3. CONFIDENTIALITÉ ET SÉCURITÉ DES DONNÉES\n"
              "Le Logiciel fonctionne hors-ligne. Toutes vos données sont stockées localement sur votre ordinateur.\n",
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ),
        primaryLabel: 'Fermer',
        primaryIcon: Icons.close_rounded,
        onPrimary: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 850;

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildBrandPanel()),
        Expanded(flex: 5, child: _buildFormPanel()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 240, child: _buildBrandPanel(compact: true)),
          _buildFormPanel(),
        ],
      ),
    );
  }

  Widget _buildBrandPanel({bool compact = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AnimatedBackdrop(scrimOpacity: 0.82),
        Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrandLogo(height: compact ? 32 : 44),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'ASSISTANT DE CONFIGURATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
              Text(
                _getStepHeadingTitle(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 22 : 28,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _getStepHeadingSubtitle(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (!compact) const SizedBox(height: AppSpacing.xl),
              if (!compact) ...[
                _featureLine(Icons.verified_user_rounded, 'Architecture Desktop Hors-ligne'),
                _featureLine(Icons.point_of_sale_rounded, 'Caisse & Ventes ultra-rapides'),
                _featureLine(Icons.inventory_2_rounded, 'Gestion de Stock en temps réel'),
                _featureLine(Icons.security_rounded, 'Protection Administrateur Sécurisée'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _getStepHeadingTitle() {
    switch (_currentStep) {
      case 0:
        return 'Fiche de votre\nBoutique';
      case 1:
        return 'Compte Administrateur\nMaître';
      default:
        return 'Configuration N\'MaShop';
    }
  }

  String _getStepHeadingSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Renseignez l\'identité commerciale qui figurera sur vos reçus.';
      case 1:
        return 'Définissez le mot de passe maître protégeant l\'accès administrateur.';
      default:
        return '';
    }
  }

  Widget _featureLine(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppPalette.fallback.seed.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppPalette.fallback.seed),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return Theme(
      data: AppTheme.light(AppPalette.fallback),
      child: Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // ── Header d'étapes (Stepper Header) ──
            _buildStepperHeader(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCurrentStepContent(),
                    ),
                  ),
                ),
              ),
            ),
            // ── Footer de navigation ──
            _buildNavigationFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    final steps = ['Boutique', 'Administrateur'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isDone = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppPalette.fallback.seed
                        : (isCurrent ? AppPalette.fallback.seed : Colors.grey[200]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : Colors.grey[600],
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    steps[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? AppColors.brandNavy : Colors.grey[500],
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isDone ? AppPalette.fallback.seed : Colors.grey[200],
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
        return _buildStep3Account();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── ÉTAPE 1 : Fiche Boutique ──────────────────────────────────────────────
  Widget _buildStep1Shop() {
    return Form(
      key: _shopFormKey,
      child: Column(
        key: const ValueKey('step_shop'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Information de la Boutique',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.brandNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ces coordonnées figureront sur les reçus de vente.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Stack(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                    ),
                    child: ClipOval(
                      child: AppImage(
                        imagePath: _logoPath,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.storefront_rounded,
                        fallbackColor: AppPalette.fallback.seed,
                        enableZoomOnTap: false,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppPalette.fallback.seed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildLabel('Nom de la boutique *'),
          TextFormField(
            controller: _nameController,
            decoration: _inputDeco('Ex: Boutique Hassan & Frères', Icons.storefront_rounded),
            validator: (v) => v == null || v.trim().isEmpty ? 'Le nom est obligatoire' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildLabel('Domaine d\'activité *'),
          _buildDropdown(
            value: _selectedDomain,
            hint: 'Sélectionnez un domaine',
            items: kDomaines,
            icon: Icons.category_rounded,
            onChanged: (val) => setState(() => _selectedDomain = val),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Téléphone'),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDeco('Ex: +224 620 00 00 00', Icons.phone_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('NIF / Numéro Fiscal (Optionnel)'),
                    TextFormField(
                      controller: _nifController,
                      decoration: _inputDeco('NIF ou RCCM', Icons.receipt_long_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildLabel('Adresse / Ville'),
          TextFormField(
            controller: _addressController,
            decoration: _inputDeco('Ex: Madina, Conakry', Icons.location_on_rounded),
          ),
        ],
      ),
    );
  }

  // ── ÉTAPE 2 : Compte Administrateur ───────────────────────────────────────
  Widget _buildStep3Account() {
    return Form(
      key: _accountFormKey,
      child: Column(
        key: const ValueKey('step_account'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Compte Administrateur Sécurisé',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.brandNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Créez l\'accès maître pour protéger les paramètres de votre boutique.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildLabel('Nom complet du propriétaire *'),
          TextFormField(
            controller: _ownerNameController,
            decoration: _inputDeco('Ex: Hassimiou Thioye', Icons.person_rounded),
            validator: (v) => v == null || v.trim().isEmpty ? 'Le nom est obligatoire' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildLabel('Mot de passe administrateur *'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            decoration: _inputDeco(
              'Mot de passe maître',
              Icons.lock_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Le mot de passe est obligatoire';
              if (v.length < kMinPasswordLength) {
                return 'Au moins $kMinPasswordLength caractères requis';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildLabel('Confirmer le mot de passe *'),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscure,
            decoration: _inputDeco('Confirmation du mot de passe', Icons.lock_outline_rounded),
            validator: (v) {
              if (v != _passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          CheckboxListTile(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppPalette.fallback.seed,
            title: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                children: [
                  const TextSpan(text: 'J\'accepte les '),
                  TextSpan(
                    text: 'Conditions Générales & Licence Utilisateur',
                    style: TextStyle(
                      color: AppPalette.fallback.seed,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: _termsRecognizer,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationFooter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _prevStep,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Précédent'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => context.go('/onboarding'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Retour Onboarding'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => context.go('/connexion'),
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Déjà un compte ? Se connecter'),
              ),
            ],
          ),
          SizedBox(
            height: 46,
            child: AppButton(
              label: _saving
                  ? 'Création...'
                  : (_currentStep == 1 ? 'Finaliser & Démarrer' : 'Continuer'),
              icon: _currentStep == 1
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _saving ? null : _nextStep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
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

  InputDecoration _inputDeco(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: BorderSide(color: AppPalette.fallback.seed, width: 2),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _inputDeco(hint, icon),
      hint: Text(hint, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
