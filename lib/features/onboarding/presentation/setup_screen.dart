import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/startup_flags.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_backdrop.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_form_dialog.dart';
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



/// N'MaShop cible les commerçants guinéens : le franc guinéen est la seule
/// devise gérée. Elle n'est ni affichée ni modifiable à la configuration,
/// simplement appliquée par défaut.
const kDeviseCode = 'GNF';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _currentStep = 0; // 0 = Fiche Boutique, 1 = Compte Administrateur

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
  bool _acceptedTerms = false;
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoPath = picked.path);
  }

  bool get _isResuming => ref.watch(businessDataExistsProvider);

  void _goToAccountStep() {
    if (_shopFormKey.currentState!.validate()) {
      setState(() => _currentStep = 1);
    }
  }

  void _goToShopStep() {
    setState(() => _currentStep = 0);
  }

  Widget _buildResumeBanner() {
    final counts = ref.watch(orphanDataCountsProvider);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.08),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_rounded,
              color: context.colors.primary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              counts.when(
                loading: () => 'Vos données existantes seront conservées.',
                error: (error, stack) =>
                    'Vos données existantes seront conservées.',
                data: (c) =>
                    'Vos données sont là : ${c.products} produit(s) et '
                    '${c.sales} vente(s) seront conservés.',
              ),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF1a2e5a),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_accountFormKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.colors.error,
          content: const Text('Vous devez accepter les conditions d\'utilisation et la politique de confidentialité.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(authProvider.notifier)
          .defineAccount(
            fullName: _ownerNameController.text,
            password: _passwordController.text,
          );

      await ref
          .read(appSettingsProvider.notifier)
          .completeSetup(
            businessName: _nameController.text.trim(),
            currency: kDeviseCode,
            logoPath: _logoPath,
            businessDomain: _selectedDomain,
            businessPhone: _phoneController.text.trim(),
          );
    } on AuthException catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: context.colors.error, content: Text(e.message)),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colors.error,
            content: Text('Erreur: $e'),
          ),
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
        gradientColors: const [Color(0xFF1a2e5a), Color(0xFF2d4a86)],
        width: 600,
        body: const SizedBox(
          height: 350,
          child: SingleChildScrollView(
            child: Text(
              "CONTRAT DE LICENCE UTILISATEUR FINAL ET POLITIQUE DE CONFIDENTIALITÉ\nLOGICIEL N'MASHOP\n\n"
              "1. ACCEPTATION DES CONDITIONS\n"
              "En installant et en utilisant l'application N'MaShop, vous acceptez d'être lié par les termes de ce contrat.\n\n"
              "2. LICENCE D'UTILISATION\n"
              "L'équipe N'MaShop vous accorde une licence non exclusive et non transférable pour utiliser ce Logiciel dans le cadre de la gestion de votre point de vente. Vous ne pouvez pas distribuer, louer, vendre ou sous-licencier ce Logiciel.\n\n"
              "3. CONFIDENTIALITÉ ET SÉCURITÉ DES DONNÉES\n"
              "a. Données Locales : Le Logiciel fonctionne hors-ligne. Toutes vos données sont stockées localement sur votre ordinateur.\n"
              "b. Responsabilité : Vous êtes seul responsable de la sécurité de vos données.\n"
              "c. Traitement des données : N'MaShop n'a pas accès à vos données commerciales, ne les collecte pas et ne les transmet à aucun serveur distant.\n\n"
              "4. LIMITATION DE RESPONSABILITÉ\n"
              "N'MaShop ne saurait être tenu responsable de toute perte de profits, perte de données, ou dommages indirects découlant de l'utilisation du Logiciel.\n",
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
    final isWide = size.width > 800;

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
          SizedBox(height: 260, child: _buildBrandPanel(compact: true)),
          _buildFormPanel(),
        ],
      ),
    );
  }

  Widget _buildBrandPanel({bool compact = false}) {
    final isStep0 = _currentStep == 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        const AnimatedBackdrop(scrimOpacity: 0.78),
        Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrandLogo(height: compact ? 32 : 44),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
              Text(
                isStep0
                    ? 'Bienvenue dans\nvotre espace boutique'
                    : 'Sécurisez votre\naccès administrateur',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 24 : 30,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isStep0
                    ? 'Étape 1 sur 2 : Renseignez les informations de votre commerce.'
                    : 'Étape 2 sur 2 : Créez vos identifiants administrateur confidentiels.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              if (!compact) const SizedBox(height: AppSpacing.xl),
              if (!compact) ...[
                _featureLine(Icons.point_of_sale_rounded, 'Caisse & ventes'),
                _featureLine(Icons.inventory_2_rounded, 'Stocks en temps réel'),
                _featureLine(
                  Icons.analytics_rounded,
                  'Bilan & rapport financier',
                ),
                _featureLine(
                  Icons.groups_rounded,
                  'Gestion des crédits clients',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureLine(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppPalette.fallback.accent.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppPalette.fallback.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStepIndicator(),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentStep == 0
                        ? _buildShopForm()
                        : _buildAccountForm(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/connexion'),
                      child: Text(
                        'Vous avez déjà un compte ? Se connecter',
                        style: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _currentStep == 1
                      ? context.colors.primary
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _currentStep == 0
              ? 'Étape 1 / 2 : Fiche de la boutique'
              : 'Étape 2 / 2 : Compte administrateur',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.colors.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildShopForm() {
    return Form(
      key: _shopFormKey,
      child: Column(
        key: const ValueKey('shop_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isResuming ? 'Reprenez votre boutique' : 'Créer votre boutique',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1a2e5a),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isResuming
                ? 'Vérifiez les informations de votre commerce.'
                : 'Ces informations apparaîtront sur vos reçus et factures.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          if (_isResuming) _buildResumeBanner(),
          const SizedBox(height: AppSpacing.md),

          // ── Logo picker ────────────────────────────────
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: _pickLogo,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(
                      0xFF1a2e5a,
                    ).withValues(alpha: 0.08),
                    backgroundImage: _logoPath != null
                        ? FileImage(File(_logoPath!))
                        : null,
                    child: _logoPath == null
                        ? const Icon(
                            Icons.storefront_rounded,
                            size: 44,
                            color: Color(0xFF1a2e5a),
                          )
                        : null,
                  ),
                ),
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppPalette.fallback.seed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Nom ──────────────────────────────────────
          _buildLabel('Nom de votre commerce *'),
          TextFormField(
            controller: _nameController,
            decoration: _inputDeco(
              'Ex: Boutique Diallo & Fils',
              Icons.store_rounded,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ce champ est obligatoire'
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Domaine ───────────────────────────────────
          _buildLabel("Domaine d'activité"),
          _buildDropdown(
            value: _selectedDomain,
            hint: 'Choisissez un domaine',
            items: kDomaines,
            icon: Icons.category_rounded,
            onChanged: (v) => setState(() {
              _selectedDomain = v;
              // Le choix du thème appartient au propriétaire — aucune suggestion automatique.
            }),
          ),
          const SizedBox(height: AppSpacing.sm),


          // ── Téléphone ─────────────────────────────────
          _buildLabel('Téléphone du commerce *'),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDeco(
              'Ex: 622 00 00 00',
              Icons.phone_outlined,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ce numéro figurera sur vos reçus'
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Adresse ───────────────────────────────────
          _buildLabel('Adresse précise'),
          TextFormField(
            controller: _addressController,
            decoration: _inputDeco(
              'Ex: Marché Madina, allée 3, face pharmacie',
              Icons.place_outlined,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── NIF ───────────────────────────────────────
          _buildLabel('NIF (numéro d\'identification fiscale)'),
          TextFormField(
            controller: _nifController,
            decoration: _inputDeco(
              'Facultatif — pour vos factures officielles',
              Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Bouton Étape Suivante ─────────────────────
          SizedBox(
            height: 52,
            child: AppButton(
              label: 'Continuer — Créer mon compte',
              icon: Icons.arrow_forward_rounded,
              onPressed: _goToAccountStep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountForm() {
    return Form(
      key: _accountFormKey,
      child: Column(
        key: const ValueKey('account_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Créer votre compte',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1a2e5a),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Un seul compte administre la boutique. Ce mot de passe protégera son ouverture.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Carte récapitulatif de la boutique créée à l'étape 1
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded,
                    color: context.colors.primary, size: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Commerce',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _nameController.text.trim().isEmpty
                            ? 'Boutique'
                            : _nameController.text.trim(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1a2e5a),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _goToShopStep,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Nom de l'administrateur ──────────────────
          _buildLabel('Votre nom complet *'),
          TextFormField(
            controller: _ownerNameController,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDeco(
              'Ex: Mamadou Diallo',
              Icons.person_outline_rounded,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Indiquez votre nom'
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Mot de passe ────────────────────────────
          _buildLabel('Mot de passe *'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            decoration: _inputDeco(
              'Au moins $kMinPasswordLength caractères',
              Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: Colors.grey[500],
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.length < kMinPasswordLength)
                ? '$kMinPasswordLength caractères minimum'
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Confirmation mot de passe ───────────────
          _buildLabel('Confirmer le mot de passe *'),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscure,
            decoration: _inputDeco(
              'Ressaisissez le mot de passe',
              Icons.lock_reset_rounded,
            ),
            validator: (v) => v != _passwordController.text
                ? 'Les mots de passe ne correspondent pas'
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Conditions d'utilisation ─────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _acceptedTerms,
                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                  activeColor: context.colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                  child: Text.rich(
                    TextSpan(
                      text: 'En créant ce compte, j\'accepte les ',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: 'Conditions d\'utilisation',
                          style: TextStyle(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _termsRecognizer,
                        ),
                        const TextSpan(text: ' et la '),
                        TextSpan(
                          text: 'Politique de confidentialité',
                          style: TextStyle(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _termsRecognizer,
                        ),
                        const TextSpan(text: ' de N\'MaShop.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Actions finale & Retour ─────────────────
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _goToShopStep,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Retour'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 52,
                  child: AppButton(
                    label: _saving
                        ? (_isResuming ? 'Ouverture...' : 'Création...')
                        : (_isResuming
                              ? 'Reprendre'
                              : 'Finaliser'),
                    icon: _isResuming
                        ? Icons.lock_open_rounded
                        : Icons.rocket_launch_rounded,
                    onPressed: _saving ? null : _submit,
                  ),
                ),
              ),
            ],
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
