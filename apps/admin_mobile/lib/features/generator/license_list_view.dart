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

class LicenseListView extends ConsumerStatefulWidget {
  const LicenseListView({super.key});

  @override
  ConsumerState<LicenseListView> createState() => _LicenseListViewState();
}

class _LicenseListViewState extends ConsumerState<LicenseListView> {

  void _showNewLicenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _NmaLicenseGeneratorSheet(),
    );
  }

  Future<void> _shareOnWhatsApp(LicenseRecord lic) async {
    final typeLabel = lic.isLifetime
        ? 'Licence à vie (Illimitée)'
        : 'Abonnement (Expire le ${DateFormat('dd/MM/yyyy').format(lic.expiresAt!)})';

    final message = '''
Bonjour *${lic.clientName}*,

Voici votre clé d'activation officielle N'MaShop PC :

🔑 *Clé de Licence* : ${lic.licenseKey}
⏳ *Formule* : $typeLabel

📌 *Activation* : Ouvrez N'MaShop PC > Paramètres > Clé de licence et collez la clé.

— L'Équipe N'MaShop
''';

    final text = Uri.encodeComponent(message);
    final waUri1 = Uri.parse('https://wa.me/?text=$text');
    final waUri2 = Uri.parse('whatsapp://send?text=$text');

    try {
      if (await canLaunchUrl(waUri1)) {
        await launchUrl(waUri1, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(waUri2)) {
        await launchUrl(waUri2, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(waUri1, mode: LaunchMode.externalApplication);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message et clé copiés dans le presse-papier !'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final licenses = ref.watch(licensesProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgSlate,
      body: licenses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLightBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.vpn_key_rounded, size: 48, color: AppTheme.primaryIndigo),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune clé de licence générée',
                    style: TextStyle(color: AppTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Générez des clés d\'activation PC pour vos boutiques',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showNewLicenseSheet,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Générer une Licence'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: licenses.length,
              itemBuilder: (context, index) {
                final lic = licenses[index];
                return _buildNmaLicenseCard(context, lic);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewLicenseSheet,
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.key_rounded),
        label: const Text('Nouvelle Licence'),
      ),
    );
  }

  Widget _buildNmaLicenseCard(BuildContext context, LicenseRecord lic) {
    final expiryText = lic.expiresAt != null
        ? DateFormat('dd/MM/yyyy').format(lic.expiresAt!)
        : 'À Vie (Illimitée)';

    final isActive = lic.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Store Name & Activation Switch
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLightBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: AppTheme.primaryIndigo, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        lic.clientName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Active Status Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.emeraldBg : AppTheme.roseBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? AppTheme.emeraldActive.withValues(alpha: 0.3) : AppTheme.roseAlert.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Désactivée',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppTheme.emeraldActive : AppTheme.roseAlert,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Toggle Switch for Activer / Désactiver
                Switch(
                  value: isActive,
                  activeThumbColor: AppTheme.emeraldActive,
                  onChanged: (val) {
                    ref.read(licensesProvider.notifier).updateLicense(lic.copyWith(isActive: val));
                    ref.read(adminSyncServiceProvider).updateLicenseRemoteStatus(lic.licenseKey, val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val ? '🟢 Licence activée pour ${lic.clientName}' : '🔴 Licence désactivée pour ${lic.clientName}'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Key Display Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgSlate,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSlate),
              ),
              child: SelectableText(
                lic.licenseKey,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Footer Expiry & Actions
            Row(
              children: [
                Icon(
                  lic.isLifetime ? Icons.all_inclusive_rounded : Icons.timer_outlined,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Expiration : $expiryText',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                const Spacer(),

                // Copy Action
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryIndigo, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: lic.licenseKey));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clé copiée dans le presse-papier !'), behavior: SnackBarBehavior.floating),
                    );
                  },
                  tooltip: 'Copier la clé',
                ),

                // Share WhatsApp Action
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 18),
                  onPressed: () => _shareOnWhatsApp(lic),
                  tooltip: 'Partager sur WhatsApp',
                ),

                // Delete Action
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.roseAlert, size: 18),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Supprimer la licence ?'),
                        content: Text('Voulez-vous supprimer cette clé pour ${lic.clientName} ?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.roseAlert),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(licensesProvider.notifier).removeLicense(lic.id);
                      ref.read(adminSyncServiceProvider).updateLicenseRemoteStatus(lic.licenseKey, false);
                    }
                  },
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── N'MaShop Key Generator Sheet ───────────────────────────────────────────────

class _NmaLicenseGeneratorSheet extends ConsumerStatefulWidget {
  const _NmaLicenseGeneratorSheet();

  @override
  ConsumerState<_NmaLicenseGeneratorSheet> createState() => _NmaLicenseGeneratorSheetState();
}

class _NmaLicenseGeneratorSheetState extends ConsumerState<_NmaLicenseGeneratorSheet> {
  ClientModel? _selectedClient;
  String _durationKey = '365j'; // '30j', '90j', '365j', 'lifetime'
  String? _generatedKey;

  @override
  void initState() {
    super.initState();
    _regenerateKey();
  }

  void _regenerateKey() {
    DateTime expiry;
    if (_durationKey == 'lifetime') {
      expiry = DateTime(9999, 12, 31);
    } else if (_durationKey == '30j') {
      expiry = DateTime.now().add(const Duration(days: 30));
    } else if (_durationKey == '90j') {
      expiry = DateTime.now().add(const Duration(days: 90));
    } else {
      expiry = DateTime.now().add(const Duration(days: 365));
    }

    setState(() {
      _generatedKey = LicenseCryptoEngine.generateUniversalKey(expiry);
    });
  }

  Future<void> _shareAndSave() async {
    if (_generatedKey == null) return;

    final clients = ref.read(clientsProvider);
    ClientModel? targetClient = _selectedClient;
    if (targetClient == null && clients.length == 1) {
      targetClient = clients.first;
    }

    final clientName = targetClient?.storeName ?? 'Boutique Client';
    final phone = targetClient?.phone ?? '';

    final typeLabel = _durationKey == 'lifetime' ? 'Licence à vie (Illimitée)' : 'Abonnement ($_durationKey)';

    final message = '''
Bonjour *$clientName*,

Voici votre clé d'activation officielle N'MaShop PC :

🔑 *Clé de Licence* : $_generatedKey
⏳ *Formule* : $typeLabel

📌 *Activation* : Ouvrez N'MaShop PC > Paramètres > Clé de licence et collez la clé.

— L'Équipe N'MaShop
''';

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final text = Uri.encodeComponent(message);
    final waUri1 = Uri.parse(cleanPhone.isNotEmpty ? 'https://wa.me/$cleanPhone?text=$text' : 'https://wa.me/?text=$text');
    final waUri2 = Uri.parse(cleanPhone.isNotEmpty ? 'whatsapp://send?phone=$cleanPhone&text=$text' : 'whatsapp://send?text=$text');

    try {
      if (await canLaunchUrl(waUri1)) {
        await launchUrl(waUri1, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(waUri2)) {
        await launchUrl(waUri2, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waUri1, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message et clé copiés dans le presse-papier !'), behavior: SnackBarBehavior.floating),
        );
      }
    }

    // Save record
    DateTime? expiresAt;
    AdminLicenseType type;
    if (_durationKey == 'lifetime') {
      type = AdminLicenseType.lifetime;
      expiresAt = null;
    } else if (_durationKey == '30j') {
      type = AdminLicenseType.days30;
      expiresAt = DateTime.now().add(const Duration(days: 30));
    } else if (_durationKey == '90j') {
      type = AdminLicenseType.days90;
      expiresAt = DateTime.now().add(const Duration(days: 90));
    } else {
      type = AdminLicenseType.days365;
      expiresAt = DateTime.now().add(const Duration(days: 365));
    }

    final record = LicenseRecord(
      id: const Uuid().v4(),
      clientId: targetClient?.id ?? 'guest',
      clientName: clientName,
      hardwareId: targetClient?.hardwareId ?? '',
      licenseKey: _generatedKey!,
      type: type,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      amountPaid: 0.0,
      isActive: true,
    );

    await ref.read(licensesProvider.notifier).addLicense(record);
    ref.read(adminSyncServiceProvider).updateLicenseRemoteStatus(_generatedKey!, true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppTheme.borderSlate, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Générateur de Licence N\'MaShop',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
          const SizedBox(height: 16),

          // Duration Pills Row
          const Text('Durée de la Formule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDurationChip('30j', '30 Jours'),
              const SizedBox(width: 8),
              _buildDurationChip('90j', '90 Jours'),
              const SizedBox(width: 8),
              _buildDurationChip('365j', '1 An'),
              const SizedBox(width: 8),
              _buildDurationChip('lifetime', 'À Vie'),
            ],
          ),
          const SizedBox(height: 16),

          // Client Dropdown
          const Text('Boutique Client', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ClientModel?>(
            initialValue: _selectedClient,
            items: [
              const DropdownMenuItem<ClientModel?>(
                value: null,
                child: Text('Génération Autonome (Auto-sync)', style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.primaryIndigo)),
              ),
              ...clients.map((c) => DropdownMenuItem(value: c, child: Text(c.storeName))),
            ],
            onChanged: (val) => setState(() => _selectedClient = val),
            decoration: const InputDecoration(
              hintText: 'Génération autonome...',
              prefixIcon: Icon(Icons.storefront_rounded, color: AppTheme.primaryIndigo),
            ),
          ),
          const SizedBox(height: 20),

          // Generated Key Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryLightBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CLÉ SÉCURISÉE N\'MASHOP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo)),
                    Icon(Icons.verified_rounded, color: AppTheme.emeraldActive, size: 16),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _generatedKey ?? 'Génération...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryIndigo,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit & Share Button
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _shareAndSave,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Générer & Transmettre (WhatsApp)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(String key, String label) {
    final isSelected = _durationKey == key;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _durationKey = key;
            _regenerateKey();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryIndigo : AppTheme.bgSlate,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primaryIndigo : AppTheme.borderSlate),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
