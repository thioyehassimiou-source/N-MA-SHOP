import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/database/mobile_database.dart';
import '../../../core/license/mobile_license_core.dart';
import '../../../core/license/mobile_license_provider.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/brand_logo.dart';
import '../data/auth_service.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../shell/main_navigation_shell.dart';
import 'login_shop_screen.dart';

const kDomainesActivite = [
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

/// Assistant de Configuration Mobile N'MaShop.
///
/// Reproduction exacte et fidèle de l'expérience Desktop adaptée pour smartphone :
/// Étape 1 : Fiche Boutique (Logo, Nom, Domaine, Téléphone, NIF, Adresse)
/// Étape 2 : Licence & Mode d'Utilisation (Essai gratuit 7 jours ou Clé sans Hardware ID)
/// Étape 3 : Compte Administrateur Maître (Nom gérant, Code PIN/MDP, Confirmation, CGU)
class RegisterShopScreen extends ConsumerStatefulWidget {
  const RegisterShopScreen({super.key});

  @override
  ConsumerState<RegisterShopScreen> createState() => _RegisterShopScreenState();
}

class _RegisterShopScreenState extends ConsumerState<RegisterShopScreen> {
  int _currentStep = 0; // 0 = Boutique, 1 = Licence, 2 = Compte Administrateur

  final _shopFormKey = GlobalKey<FormState>();
  final _licenseFormKey = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();

  // Contrôleurs Étape 1 : Boutique
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _nifController = TextEditingController();
  String? _selectedDomain = 'Alimentation Générale';
  String? _logoPath;

  // Contrôleurs Étape 2 : Licence
  final _licenseKeyController = TextEditingController();
  bool _useTrialMode = true;
  bool _isLicenseKeyValid = false;
  String? _licenseKeySuccessMessage;
  String? _licenseKeyErrorMessage;

  // Contrôleurs Étape 3 : Administrateur
  final _ownerNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = true;

  bool _isLoading = false;
  String? _errorMessage;
  String? _hardwareId;

  @override
  void initState() {
    super.initState();
    _loadHardwareId();
  }

  Future<void> _loadHardwareId() async {
    try {
      final hwId = await ref.read(mobileLicenseServiceProvider).getOrCreateHardwareId();
      if (mounted) {
        setState(() => _hardwareId = hwId);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nifController.dispose();
    _licenseKeyController.dispose();
    _ownerNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo(ImageSource source) async {
    final path = await MobileImagePicker.pickAndSaveImage(
      source: source,
      folderName: 'shop_logo',
    );
    if (path != null && mounted) {
      setState(() => _logoPath = path);
    }
  }

  void _showLogoPickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Logo ou Photo de votre Boutique',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.brandOrange),
                ),
                title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Utiliser l\'appareil photo du smartphone', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickLogo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.photo_library_rounded, color: AppColors.brandNavy),
                ),
                title: const Text('Choisir dans la galerie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Sélectionner un logo ou une image existante', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickLogo(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _activateLicenseKey() async {
    final key = _licenseKeyController.text.trim().toUpperCase();
    if (key.isEmpty) {
      setState(() {
        _licenseKeyErrorMessage = 'Veuillez saisir votre clé de licence officielle.';
        _licenseKeySuccessMessage = null;
        _isLicenseKeyValid = false;
      });
      return false;
    }

    final hwId = await ref.read(mobileLicenseServiceProvider).getOrCreateHardwareId();
    final info = MobileLicenseCore.validateKey(key, hardwareId: hwId);

    if (info == null || info.isExpired) {
      setState(() {
        _licenseKeyErrorMessage = 'Clé de licence invalide ou expirée. Vérifiez votre saisie.';
        _licenseKeySuccessMessage = null;
        _isLicenseKeyValid = false;
      });
      return false;
    } else {
      setState(() {
        _isLicenseKeyValid = true;
        _licenseKeySuccessMessage = '✓ Licence activée avec succès (${info.tier.toUpperCase()}) — Valable jusqu\'au ${info.expiryDate.day}/${info.expiryDate.month}/${info.expiryDate.year}';
        _licenseKeyErrorMessage = null;
        _errorMessage = null;
      });
      return true;
    }
  }

  void _nextStep() async {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (_shopFormKey.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (!_useTrialMode) {
        if (!_isLicenseKeyValid) {
          final ok = await _activateLicenseKey();
          if (!ok) return;
        }
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_accountFormKey.currentState!.validate()) {
        if (!_acceptedTerms) {
          setState(() => _errorMessage = 'Vous devez accepter les conditions d\'utilisation pour continuer.');
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

    try {
      final db = ref.read(mobileDatabaseProvider);

      // 1. Purger toutes les données fictives pour un démarrage vierge
      await db.purgeAllData();

      final now = DateTime.now();
      final shopId = 'shop-${now.millisecondsSinceEpoch}';
      final userId = 'user-${now.millisecondsSinceEpoch}';

      // 2. Enregistrer la boutique dans SQLite
      await db.into(db.mobileShops).insert(
        MobileShopsCompanion.insert(
          id: shopId,
          name: _nameController.text.trim(),
          currency: const drift.Value('GNF'),
          phone: drift.Value(_phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null),
          address: drift.Value(_addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null),
          lowStockThreshold: const drift.Value(5),
          createdAt: drift.Value(now),
        ),
      );

      // 3. Enregistrer l'administrateur maître dans SQLite
      await db.into(db.mobileUsers).insert(
        MobileUsersCompanion.insert(
          id: userId,
          fullName: _ownerNameController.text.trim(),
          role: const drift.Value('admin'),
          pinHash: drift.Value(_passwordController.text.trim()),
          createdAt: drift.Value(now),
        ),
      );

      // 4. Enregistrer dans le stockage sécurisé et SharedPreferences
      final storage = ref.read(storageServiceProvider);
      await storage.saveLocalShop(
        shopName: _nameController.text.trim(),
        currency: 'GNF',
        pin: _passwordController.text.trim(),
      );

      // 5. Activation de la licence
      if (!_useTrialMode && _licenseKeyController.text.trim().isNotEmpty) {
        await ref.read(mobileLicenseProvider.notifier).activate(_licenseKeyController.text.trim());
      } else {
        // Mode essai gratuit 7 jours
        await ref.read(mobileLicenseServiceProvider).checkLicense();
        ref.invalidate(mobileLicenseProvider);
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors de la configuration : $e';
        });
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.brandOrange),
            SizedBox(width: 8),
            Text('Conditions N\'MaShop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SizedBox(
          height: 320,
          child: SingleChildScrollView(
            child: Text(
              "CONTRAT D'UTILISATION ET SÉCURITÉ DES DONNÉES N'MASHOP\n\n"
              "1. AUTONOMIE TOTALE ET STOCKAGE LOCAL\n"
              "N'MaShop Mobile est une solution de gestion commerciale 100% hors-ligne. "
              "Toutes vos données (ventes, stocks, dépenses, clients, crédits) sont stockées en local sur votre smartphone dans une base SQLite chiffrée.\n\n"
              "2. AUCUNE DÉPENDANCE INTERNET POUR ENCAISSER\n"
              "Vous pouvez effectuer toutes vos opérations commerciales quotidiennes sans connexion Internet.\n\n"
              "3. LICENCE BOUTIQUE OFFICIELLE\n"
              "L'application fonctionne selon la formule choisie (Essai 7 jours, Abonnement Annuel ou Licence Illimitée) validée par signature cryptographique HMAC.\n\n"
              "4. CONFIDENTIALITÉ STRICTE\n"
              "Aucune information commerciale privée n'est vendue à des tiers.",
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandNavy, foregroundColor: Colors.white),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
                _buildTopBrandHeader(),
                _buildStepperHeader(),
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
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
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
        return 'Compte Administrateur Maître';
      default:
        return 'Configuration N\'MaShop';
    }
  }

  String _getStepHeadingSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Renseignez l\'identité commerciale qui figurera sur vos reçus.';
      case 1:
        return 'Activez votre clé officielle ou démarrez votre essai gratuit de 7 jours.';
      case 2:
        return 'Définissez le mot de passe maître protégeant l\'accès administrateur.';
      default:
        return '';
    }
  }

  Widget _buildStepperHeader() {
    final steps = ['Boutique', 'Licence', 'Administrateur'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              color: isCurrent ? Colors.white : Colors.grey[600],
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
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? AppColors.brandNavy : Colors.grey[500],
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

  // ── ÉTAPE 1 : Fiche Boutique (Exactement comme Desktop) ──────────────────────
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
                // Sélecteur Logo Boutique
                Center(
                  child: GestureDetector(
                    onTap: _showLogoPickerDialog,
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.4), width: 2),
                          ),
                          child: ClipOval(
                            child: AppProductImage(
                              imageSource: _logoPath,
                              width: 80,
                              height: 80,
                              borderRadius: 40,
                              fallbackIcon: Icons.storefront_rounded,
                              fallbackColor: AppColors.brandNavy,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.brandOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Appuyez pour ajouter le logo de votre boutique',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel('Nom de la boutique *'),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco('Ex: Boutique Diallo & Frères', Icons.storefront_rounded),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Le nom de la boutique est obligatoire' : null,
                ),
                const SizedBox(height: 14),

                _buildLabel('Domaine d\'activité *'),
                DropdownButtonFormField<String>(
                  value: _selectedDomain,
                  decoration: _inputDeco('', Icons.category_rounded),
                  items: kDomainesActivite.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _selectedDomain = val),
                ),
                const SizedBox(height: 14),

                _buildLabel('Numéro de Téléphone (Reçus & WhatsApp)'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDeco('Ex: +224 620 00 00 00', Icons.phone_rounded),
                ),
                const SizedBox(height: 14),

                _buildLabel('NIF / Numéro Fiscal (Optionnel)'),
                TextFormField(
                  controller: _nifController,
                  decoration: _inputDeco('NIF ou RCCM de la boutique', Icons.receipt_long_rounded),
                ),
                const SizedBox(height: 14),

                _buildLabel('Adresse / Ville'),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco('Ex: Madina Marché, Conakry', Icons.location_on_rounded),
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

  // ── ÉTAPE 2 : Licence & Mode d'Utilisation ─────────────────────────────────
  Widget _buildStep2License() {
    return Form(
      key: _licenseFormKey,
      child: Column(
        key: const ValueKey('step_license'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOptionCard(
            selected: _useTrialMode,
            icon: Icons.card_giftcard_rounded,
            title: 'Période d\'essai gratuite (7 jours)',
            subtitle: 'Découvrez toutes les fonctionnalités de N\'MaShop gratuitement sans engagement.',
            onTap: () => setState(() => _useTrialMode = true),
          ),
          const SizedBox(height: 12),

          _buildOptionCard(
            selected: !_useTrialMode,
            icon: Icons.verified_user_rounded,
            title: 'J\'ai une clé de licence',
            subtitle: 'Activez votre clé de licence officielle fournie par l\'équipe N\'MaShop.',
            onTap: () => setState(() => _useTrialMode = false),
          ),

          if (!_useTrialMode) ...[
            const SizedBox(height: 14),

            // Boîte d'identification matérielle de l'appareil (Device ID comme sur Desktop)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandNavy,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RÉFÉRENCE MATÉRIELLE DE CET APPAREIL',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.onSurfaceVariant, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hardwareId ?? 'Détection en cours...',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.brandNavy, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.brandOrange, size: 20),
                    tooltip: 'Copier la référence',
                    onPressed: () {
                      if (_hardwareId != null) {
                        Clipboard.setData(ClipboardData(text: _hardwareId!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Référence matérielle copiée dans le presse-papier !'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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
                  _buildLabel('Clé d\'activation officielle (format NMAS-...)'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _licenseKeyController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          decoration: _inputDeco('NMAS-YYYYMMDD-XXXXXXXX', Icons.vpn_key_rounded),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.paste_rounded, color: AppColors.brandOrange),
                        tooltip: 'Coller',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null && data!.text!.trim().isNotEmpty) {
                            setState(() {
                              _licenseKeyController.text = data.text!.trim().toUpperCase();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: _activateLicenseKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Activer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ],
                  ),
                  if (_licenseKeySuccessMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.brandEmerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.brandEmerald.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.brandEmerald, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _licenseKeySuccessMessage!,
                              style: const TextStyle(color: AppColors.brandEmerald, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_licenseKeyErrorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _licenseKeyErrorMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            const adminPhone = '224624193069';
                            final shopName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'ma boutique';
                            final refCode = _hardwareId ?? 'Non détecté';
                            final msg = 'Bonjour Hassimiou Thioye, je souhaite obtenir une clé de licence N\'MaShop pour $shopName.\nRéférence appareil : $refCode';
                            final uri = Uri.parse('https://wa.me/$adminPhone?text=${Uri.encodeComponent(msg)}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.chat_rounded, size: 16, color: Color(0xFF25D366)),
                          label: const Text('Commander sur WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF25D366)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final uri = Uri.parse('tel:+224624193069');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.brandNavy),
                        tooltip: 'Appeler l\'assistance',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── ÉTAPE 3 : Compte Administrateur Maître (Exactement comme Desktop) ──────
  Widget _buildStep3Account() {
    return Form(
      key: _accountFormKey,
      child: Column(
        key: const ValueKey('step_account'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                _buildLabel('Nom & Prénom de l\'administrateur *'),
                TextFormField(
                  controller: _ownerNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco('Ex: Mamadou Diallo', Icons.person_rounded),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Le nom de l\'administrateur est obligatoire' : null,
                ),
                const SizedBox(height: 14),

                _buildLabel('Mot de passe maître ou Code PIN (4 à 8 chiffres) *'),
                TextFormField(
                  controller: _passwordController,
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Code secret de connexion',
                    prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.brandNavy),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Le mot de passe / PIN est obligatoire';
                    if (v.trim().length < 4) return 'Au moins 4 caractères ou chiffres requis';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _buildLabel('Confirmer le mot de passe / PIN *'),
                TextFormField(
                  controller: _confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Répétez le code secret',
                    prefixIcon: const Icon(Icons.lock_clock_rounded, color: AppColors.brandNavy),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _buildLabel('Code secret de récupération (Optionnel)'),
                TextFormField(
                  controller: _recoveryCodeController,
                  decoration: _inputDeco('Ex: Mot ou question en cas d\'oubli', Icons.key_rounded),
                ),
                const SizedBox(height: 16),

                // Case à cocher Conditions Générales
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptedTerms,
                        activeColor: AppColors.brandOrange,
                        onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.3),
                          children: [
                            const TextSpan(text: 'J\'accepte les '),
                            TextSpan(
                              text: 'conditions d\'utilisation',
                              style: const TextStyle(color: AppColors.brandOrange, fontWeight: FontWeight.bold),
                              recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                            ),
                            const TextSpan(text: ' et la politique de confidentialité locale N\'MaShop.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.brandNavy, size: 20),
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
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
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.brandOrange : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.05 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandOrange.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: selected ? AppColors.brandOrange : AppColors.brandNavy, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: selected ? AppColors.brandOrange : AppColors.brandNavy)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant, height: 1.3)),
                  ],
                ),
              ),
              Radio<bool>(
                value: true,
                groupValue: selected,
                activeColor: AppColors.brandOrange,
                onChanged: (_) => onTap(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : (_currentStep > 0
                          ? _prevStep
                          : () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                              );
                            }),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(
                    _currentStep > 0 ? 'Précédent' : 'Retour',
                    style: const TextStyle(color: AppColors.brandNavy, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: Icon(
                    _currentStep == 2 ? Icons.storefront_rounded : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _currentStep == 2 ? 'Finaliser et Ouvrir ma Boutique' : 'Suivant',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
