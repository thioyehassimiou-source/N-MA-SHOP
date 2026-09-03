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

class HardwareKeyGeneratorScreen extends ConsumerStatefulWidget {
  final ClientModel? preselectedClient;

  const HardwareKeyGeneratorScreen({super.key, this.preselectedClient});

  @override
  ConsumerState<HardwareKeyGeneratorScreen> createState() => _HardwareKeyGeneratorScreenState();
}

class _HardwareKeyGeneratorScreenState extends ConsumerState<HardwareKeyGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  ClientModel? _selectedClient;
  late TextEditingController _amountCtrl;

  AdminLicenseType _selectedType = AdminLicenseType.annual;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  String? _generatedKey;

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.preselectedClient;
    _amountCtrl = TextEditingController(text: '1500000');
    _generateKeyPreview();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _generateKeyPreview() {
    if (_selectedType == AdminLicenseType.lifetime) {
      _generatedKey = LicenseCryptoEngine.generateUniversalKey(DateTime(9999, 12, 31));
    } else {
      _generatedKey = LicenseCryptoEngine.generateUniversalKey(_expiryDate);
    }
  }

  Future<void> _shareOnWhatsApp() async {
    if (_generatedKey == null) return;

    final storeName = _selectedClient?.storeName ?? 'Boutique Client';
    final phone = _selectedClient?.phone ?? '';

    final typeLabel = _selectedType == AdminLicenseType.lifetime
        ? 'Licence à vie (Illimitée)'
        : 'Abonnement Annuel (Expire le ${DateFormat('dd/MM/yyyy').format(_expiryDate)})';

    final message = '''
Bonjour *$storeName*,

Voici votre clé d'activation officielle N'MaShop PC :

🔑 *Clé de Licence* : $_generatedKey
⏳ *Formule* : $typeLabel

📌 *Instructions d'activation* :
1. Ouvrez N'MaShop sur votre ordinateur.
2. Allez dans *Paramètres* > *Clé de licence* (ou sur l'écran d'activation).
3. Collez votre clé ci-dessus et cliquez sur *Activer*.

Merci pour votre confiance !
— L'Équipe N'MaShop
''';

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message et clé copiés dans le presse-papier !'), behavior: SnackBarBehavior.floating),
        );
      }
    }

    _saveRecord();
  }

  Future<void> _saveRecord() async {
    if (_generatedKey == null) return;

    final record = LicenseRecord(
      id: const Uuid().v4(),
      clientId: _selectedClient?.id ?? 'guest',
      clientName: _selectedClient?.storeName ?? 'Client Inconnu',
      hardwareId: '',
      licenseKey: _generatedKey!,
      type: _selectedType,
      createdAt: DateTime.now(),
      expiresAt: _selectedType == AdminLicenseType.lifetime ? null : _expiryDate,
      amountPaid: double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
    );

    await ref.read(licensesProvider.notifier).addLicense(record);
    ref.read(adminSyncServiceProvider).updateLicenseRemoteStatus(_generatedKey!, true);
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgSlate,
      appBar: AppBar(
        title: const Text('Générateur N\'MaShop PC'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLightBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: AppTheme.primaryIndigo, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Générateur de Clé Sécurisée',
                            style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Liaison automatique sur le PC du client lors de l\'activation.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Select Client Dropdown
              const Text('Sélectionner le Client / Boutique', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<ClientModel>(
                initialValue: _selectedClient,
                dropdownColor: Colors.white,
                items: clients.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text('${c.storeName} (${c.ownerName})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedClient = val;
                    _generateKeyPreview();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Choisir un client enregistré...',
                  prefixIcon: Icon(Icons.storefront_rounded, color: AppTheme.primaryIndigo),
                ),
              ),
              const SizedBox(height: 20),

              // Licence Type Segmented Choice Chips
              const Text('Formule de Licence', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Annuelle (1 An)'),
                      selected: _selectedType == AdminLicenseType.annual,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedType = AdminLicenseType.annual;
                            _amountCtrl.text = '1500000';
                            _generateKeyPreview();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('À Vie (Illimitée)'),
                      selected: _selectedType == AdminLicenseType.lifetime,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedType = AdminLicenseType.lifetime;
                            _amountCtrl.text = '3500000';
                            _generateKeyPreview();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date Expiry Picker (for Annual)
              if (_selectedType == AdminLicenseType.annual)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date d\'expiration', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy').format(_expiryDate),
                    style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryIndigo),
                    onPressed: () async {
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
                  ),
                ),

              const SizedBox(height: 20),

              // Generated Key Display Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.primaryIndigo, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CLÉ GÉNÉRÉE ET SIGNÉE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        Icon(Icons.lock_rounded, color: AppTheme.emeraldActive, size: 16),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _generatedKey ?? 'GÉNÉRATION...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: AppTheme.primaryIndigo,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (_generatedKey != null) {
                          await Clipboard.setData(ClipboardData(text: _generatedKey!));
                          await _saveRecord();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Clé copiée dans le presse-papier !'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryIndigo),
                      label: const Text('Copier'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _shareOnWhatsApp,
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: const Text('Transmettre WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
