import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/license/license_crypto_engine.dart';
import '../../core/models/client_model.dart';
import '../../core/models/license_record.dart';
import '../../core/providers/admin_providers.dart';
import '../../core/theme/app_theme.dart';

/// Écran de génération de clé de licence N'MaShop PC.
///
/// Permet de générer des clés universelles ou strictement verrouillées
/// sur l'ordinateur du commerçant (via son Hardware ID / Réf. Boutique),
/// puis de les transmettre en 1 clic sur WhatsApp.
class HardwareKeyGeneratorScreen extends ConsumerStatefulWidget {
  final ClientModel? preselectedClient;

  const HardwareKeyGeneratorScreen({super.key, this.preselectedClient});

  @override
  ConsumerState<HardwareKeyGeneratorScreen> createState() => _HardwareKeyGeneratorScreenState();
}

class _HardwareKeyGeneratorScreenState extends ConsumerState<HardwareKeyGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  ClientModel? _selectedClient;

  late TextEditingController _hardwareIdCtrl;
  late TextEditingController _storeNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _amountCtrl;

  AdminLicenseType _selectedType = AdminLicenseType.annual;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  String? _generatedKey;

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.preselectedClient;

    _hardwareIdCtrl = TextEditingController();
    _storeNameCtrl = TextEditingController(text: _selectedClient?.storeName ?? '');
    _phoneCtrl = TextEditingController(text: _selectedClient?.phone ?? '');
    _amountCtrl = TextEditingController(text: '1500000');

    _hardwareIdCtrl.addListener(_generateKeyPreview);
    _generateKeyPreview();
  }

  @override
  void dispose() {
    _hardwareIdCtrl.dispose();
    _storeNameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _generateKeyPreview() {
    final hwId = _hardwareIdCtrl.text.trim().toUpperCase();

    setState(() {
      if (hwId.isNotEmpty) {
        // Mode Device Binding : Clé 100% verrouillée sur ce PC (4 segments)
        if (_selectedType == AdminLicenseType.lifetime) {
          _generatedKey = LicenseCryptoEngine.generateHardwareBoundLifetimeKey(hwId);
        } else {
          _generatedKey = LicenseCryptoEngine.generateHardwareBoundKey(
            hardwareId: hwId,
            expiryDate: _expiryDate,
          );
        }
      } else {
        // Mode Universel : Clé standard (3 segments)
        if (_selectedType == AdminLicenseType.lifetime) {
          _generatedKey = LicenseCryptoEngine.generateUniversalKey(DateTime(9999, 12, 31));
        } else {
          _generatedKey = LicenseCryptoEngine.generateUniversalKey(_expiryDate);
        }
      }
    });
  }

  /// Extrait automatiquement le Hardware ID / Réf Boutique depuis le presse-papier
  Future<void> _pasteAndExtractHardwareId() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;

    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presse-papier vide'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Détection regex : NMA-XXXX-XXXX-XXXX ou NMAS-XXXX-XXXX ou format guid
    final match = RegExp(
      r'NMA-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}|NMA[S]?-[A-Z0-9\-]+',
      caseSensitive: false,
    ).firstMatch(text);

    final extracted = match != null ? match.group(0)!.toUpperCase() : text.trim().toUpperCase();

    _hardwareIdCtrl.text = extracted;
    _generateKeyPreview();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Référence machine détectée : $extracted'),
          backgroundColor: AppTheme.emeraldActive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareOnWhatsApp() async {
    if (_generatedKey == null) return;

    final storeName = _selectedClient?.storeName.isNotEmpty == true
        ? _selectedClient!.storeName
        : (_storeNameCtrl.text.trim().isNotEmpty ? _storeNameCtrl.text.trim() : 'Boutique');

    final phone = _selectedClient?.phone.isNotEmpty == true
        ? _selectedClient!.phone
        : _phoneCtrl.text.trim();

    final isBound = _hardwareIdCtrl.text.trim().isNotEmpty;
    final typeLabel = switch (_selectedType) {
      AdminLicenseType.lifetime => 'Licence à vie (Illimitée)',
      AdminLicenseType.days30 => 'Abonnement Mensuel (30 jours — Expire le ${DateFormat('dd/MM/yyyy').format(_expiryDate)})',
      _ => 'Abonnement Annuel (1 An — Expire le ${DateFormat('dd/MM/yyyy').format(_expiryDate)})',
    };

    final bindingNotice = isBound
        ? '\n🔒 *Sécurité Machine* : Clé sécurisée liée spécifiquement à votre ordinateur (${_hardwareIdCtrl.text.trim()}).'
        : '';

    final message = '''
Bonjour *$storeName*,

Voici votre clé d'activation officielle N'MaShop PC :

🔑 *Code d'Activation* : $_generatedKey
⏳ *Formule* : $typeLabel$bindingNotice

📌 *Instructions d'activation sur votre PC* :
1. Ouvrez l'application N'MaShop sur votre ordinateur.
2. Cliquez sur "Activer ma licence" (ou Paramètres > Sécurité).
3. Collez ce code ci-dessus et validez.

Votre logiciel sera opérationnel immédiatement !

Merci pour votre confiance.
— Hassimiou Thioye (Développeur N'MaShop)
''';

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    String targetPhone = cleanPhone;
    if (cleanPhone.length == 9 && cleanPhone.startsWith('6')) {
      targetPhone = '224$cleanPhone'; // Format international Guinée
    }

    final uri = targetPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$targetPhone?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _copyFallback(message);
      }
    } catch (_) {
      await _copyFallback(message);
    }

    await _saveRecord();
  }

  Future<void> _copyFallback(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message WhatsApp et clé copiés dans le presse-papier !'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveRecord() async {
    if (_generatedKey == null) return;

    final hwId = _hardwareIdCtrl.text.trim();
    final clientName = _selectedClient?.storeName.isNotEmpty == true
        ? _selectedClient!.storeName
        : (_storeNameCtrl.text.trim().isNotEmpty ? _storeNameCtrl.text.trim() : 'Boutique Client');

    final record = LicenseRecord(
      id: const Uuid().v4(),
      clientId: _selectedClient?.id ?? 'guest',
      clientName: clientName,
      hardwareId: hwId,
      licenseKey: _generatedKey!,
      type: _selectedType,
      createdAt: DateTime.now(),
      expiresAt: _selectedType == AdminLicenseType.lifetime ? null : _expiryDate,
      amountPaid: double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
      isActive: true,
    );

    await ref.read(licensesProvider.notifier).addLicense(record);
    ref.read(adminSyncServiceProvider).updateLicenseRemoteStatus(
      _generatedKey!,
      true,
      hardwareId: hwId,
      storeName: clientName,
      expiresAt: _selectedType == AdminLicenseType.lifetime ? null : _expiryDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final isBound = _hardwareIdCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.bgSlate,
      appBar: AppBar(
        title: const Text('Générateur N\'MaShop PC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Régénérer la clé',
            onPressed: _generateKeyPreview,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Réf. Boutique / Hardware ID Machine PC ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Réf. Boutique / ID Machine PC',
                      style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    TextButton.icon(
                      onPressed: _pasteAndExtractHardwareId,
                      icon: const Icon(Icons.content_paste_rounded, size: 16, color: AppTheme.primaryIndigo),
                      label: const Text('Coller Réf.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _hardwareIdCtrl,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ex: NMA-8F3A-92B1-4C07 (ou vide pour universelle)',
                    hintStyle: const TextStyle(fontFamily: 'sans-serif', fontSize: 13, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.computer_rounded, color: AppTheme.primaryIndigo),
                    suffixIcon: _hardwareIdCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _hardwareIdCtrl.clear();
                              _generateKeyPreview();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),

                // Indicateur Verrouillage Matériel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isBound ? AppTheme.emeraldBg : AppTheme.amberBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isBound
                          ? AppTheme.emeraldActive.withValues(alpha: 0.3)
                          : AppTheme.amberTrial.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isBound ? Icons.lock_rounded : Icons.public_rounded,
                        size: 16,
                        color: isBound ? AppTheme.emeraldActive : AppTheme.amberTrial,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isBound
                              ? 'Clé verrouillée à 100% sur cette machine (Format 4 segments)'
                              : 'Clé universelle (Peut être activée sur n\'importe quel PC)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isBound ? AppTheme.emeraldActive : AppTheme.amberTrial,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Client / Boutique ────────────────────────────────────────
                const Text('Sélectionner ou Saisir la Boutique', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<ClientModel?>(
                  initialValue: _selectedClient,
                  dropdownColor: Colors.white,
                  items: [
                    const DropdownMenuItem<ClientModel?>(
                      value: null,
                      child: Text('➕ Nouvelle saisie directe...', style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold)),
                    ),
                    ...clients.map((c) {
                      return DropdownMenuItem<ClientModel?>(
                        value: c,
                        child: Text('${c.storeName} (${c.ownerName})'),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedClient = val;
                      if (val != null) {
                        _storeNameCtrl.text = val.storeName;
                        _phoneCtrl.text = val.phone;
                        if (val.hardwareId.isNotEmpty) {
                          _hardwareIdCtrl.text = val.hardwareId;
                        }
                      }
                      _generateKeyPreview();
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.storefront_rounded, color: AppTheme.primaryIndigo),
                  ),
                ),

                if (_selectedClient == null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _storeNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nom boutique',
                            hintText: 'Ex: Alimentation...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone client',
                            hintText: 'Ex: 624193069',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),

                // ── Formule de Licence (Mensuelle / Annuelle / À Vie) ──────────
                const Text('Formule de Licence', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildFormulaCard(
                      title: 'Mensuelle',
                      subtitle: '150 000 GNF',
                      type: AdminLicenseType.days30,
                      days: 30,
                      defaultAmount: '150000',
                    ),
                    const SizedBox(width: 8),
                    _buildFormulaCard(
                      title: 'Annuelle',
                      subtitle: '1 500 000 GNF',
                      type: AdminLicenseType.annual,
                      days: 365,
                      defaultAmount: '1500000',
                    ),
                    const SizedBox(width: 8),
                    _buildFormulaCard(
                      title: 'À Vie',
                      subtitle: '3 500 000 GNF',
                      type: AdminLicenseType.lifetime,
                      days: null,
                      defaultAmount: '3500000',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Expiration & Montant
                Row(
                  children: [
                    if (_selectedType != AdminLicenseType.lifetime)
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiryDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2099),
                            );
                            if (picked != null) {
                              setState(() {
                                _expiryDate = picked;
                                _generateKeyPreview();
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date d\'expiration',
                              suffixIcon: Icon(Icons.calendar_month_rounded, color: AppTheme.primaryIndigo),
                              isDense: true,
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_expiryDate),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    if (_selectedType != AdminLicenseType.lifetime) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Montant (GNF)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Clé Générée & Signée ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryIndigo, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'CLÉ OFFICIELLE PRÊTE À L\'ACTIVATION',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppTheme.emeraldActive, size: 12),
                                SizedBox(width: 4),
                                Text('HMAC VALIDÉ', style: TextStyle(color: AppTheme.emeraldActive, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _generatedKey ?? 'GÉNÉRATION...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: AppTheme.primaryIndigo,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppTheme.borderSlate, width: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (_generatedKey != null) {
                      await Clipboard.setData(ClipboardData(text: _generatedKey!));
                      await _saveRecord();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Clé copiée dans le presse-papier !'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryIndigo, size: 16),
                  label: const Text('Copier Clé'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _shareOnWhatsApp,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Envoyer sur WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormulaCard({
    required String title,
    required String subtitle,
    required AdminLicenseType type,
    required int? days,
    required String defaultAmount,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedType = type;
            if (days != null) {
              _expiryDate = DateTime.now().add(Duration(days: days));
            }
            _amountCtrl.text = defaultAmount;
            _generateKeyPreview();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryIndigo : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryIndigo : AppTheme.borderSlate,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryIndigo.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: isSelected ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
