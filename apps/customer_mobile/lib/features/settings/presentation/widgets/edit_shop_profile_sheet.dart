import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../data/shop_profile_model.dart';
import '../shop_profile_provider.dart';

class EditShopProfileSheet extends ConsumerStatefulWidget {
  const EditShopProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditShopProfileSheet(),
    );
  }

  @override
  ConsumerState<EditShopProfileSheet> createState() => _EditShopProfileSheetState();
}

class _EditShopProfileSheetState extends ConsumerState<EditShopProfileSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _managerCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;

  late String _currency;
  String? _logoPath;
  bool _isSaving = false;

  final List<String> _currencies = const ['GNF', 'XOF', 'USD', 'EUR'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(shopProfileProvider);
    _nameCtrl = TextEditingController(text: profile.shopName);
    _managerCtrl = TextEditingController(text: profile.managerName);
    _phoneCtrl = TextEditingController(text: profile.phoneNumber);
    _addressCtrl = TextEditingController(text: profile.address);
    _currency = _currencies.contains(profile.currency) ? profile.currency : 'GNF';
    _logoPath = profile.logoPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _managerCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
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

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.brandOrange),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickLogo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.brandEmerald),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickLogo(ImageSource.gallery);
              },
            ),
            if (_logoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Supprimer le logo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _logoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(shopProfileProvider.notifier).updateProfile(
            shopName: _nameCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            managerName: _managerCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            currency: _currency,
            logoPath: _logoPath,
          );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil commercial mis à jour avec succès !'),
          backgroundColor: AppColors.brandEmerald,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée supérieure
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // En-tête
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.brandOrange, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profil Commercial de la Boutique',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandNavy),
                      ),
                      Text(
                        'Informations imprimées sur les tickets de caisse',
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Formulaire scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélecteur de logo
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _showImageSourcePicker,
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.brandOrange, width: 2),
                                image: (_logoPath != null && File(_logoPath!).existsSync())
                                    ? DecorationImage(
                                        image: FileImage(File(_logoPath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: (_logoPath == null || !File(_logoPath!).existsSync())
                                  ? const Icon(Icons.store_mall_directory_rounded, size: 40, color: AppColors.brandOrange)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showImageSourcePicker,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.brandOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Logo de la boutique (reçus & en-tête)',
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nom de la boutique
                    _buildLabel('Nom de la boutique *'),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDeco('Ex: Boutique Diallo & Frères', Icons.storefront_rounded),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Le nom est obligatoire' : null,
                    ),
                    const SizedBox(height: 16),

                    // Nom du Responsable / Gérant
                    _buildLabel('Nom du Gérant / Responsable'),
                    TextFormField(
                      controller: _managerCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDeco('Ex: Mamadou Diallo', Icons.person_outline_rounded),
                    ),
                    const SizedBox(height: 16),

                    // Téléphone
                    _buildLabel('Numéro de téléphone'),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDeco('Ex: +224 624 00 00 00', Icons.phone_rounded),
                    ),
                    const SizedBox(height: 16),

                    // Adresse
                    _buildLabel('Adresse / Emplacement'),
                    TextFormField(
                      controller: _addressCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDeco('Ex: Marché Madina, Conakry', Icons.location_on_outlined),
                    ),
                    const SizedBox(height: 16),

                    // Devise Principale
                    _buildLabel('Devise principale de facturation'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currency,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.brandNavy),
                          items: _currencies.map((c) {
                            String subtitle = '';
                            if (c == 'GNF') subtitle = 'Franc Guinéen (GNF)';
                            if (c == 'XOF') subtitle = 'Franc CFA (FCFA / XOF)';
                            if (c == 'USD') subtitle = 'Dollar US (\$)';
                            if (c == 'EUR') subtitle = 'Euro (€)';
                            return DropdownMenuItem<String>(
                              value: c,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandOrange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.brandOrange)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _currency = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton Enregistrer
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Enregistrer les modifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: AppColors.brandNavy,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      prefixIcon: Icon(icon, size: 20, color: AppColors.brandNavy.withValues(alpha: 0.7)),
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: AppColors.brandOrange, width: 1.5),
      ),
    );
  }
}
