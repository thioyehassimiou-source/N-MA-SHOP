import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/client_model.dart';
import '../../core/models/license_record.dart';
import '../../core/providers/admin_providers.dart';
import '../../core/theme/app_theme.dart';
import 'client_form_dialog.dart';

class ClientListView extends ConsumerStatefulWidget {
  const ClientListView({super.key});

  @override
  ConsumerState<ClientListView> createState() => _ClientListViewState();
}

class _ClientListViewState extends ConsumerState<ClientListView> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'active', 'trial', 'deactivated'

  LicenseRecord? _findLicenseForClient(ClientModel client, List<LicenseRecord> licenses) {
    if (licenses.isEmpty) return null;

    // 1. Match par hardwareId si renseigné
    final hwId = client.hardwareId.trim();
    if (hwId.isNotEmpty) {
      try {
        return licenses.firstWhere(
          (l) => l.hardwareId.trim().isNotEmpty && l.hardwareId.trim() == hwId,
        );
      } catch (_) {}
    }

    // 2. Match par clientId si non nul et pas 'guest'
    final cId = client.id.trim();
    if (cId.isNotEmpty && cId != 'guest') {
      try {
        return licenses.firstWhere(
          (l) => l.clientId.trim().isNotEmpty && l.clientId.trim() == cId,
        );
      } catch (_) {}
    }

    // 3. Match par nom de boutique (sensible aux espaces/casse)
    final storeName = client.storeName.trim().toLowerCase();
    if (storeName.isNotEmpty) {
      try {
        return licenses.firstWhere((l) {
          final licName = l.clientName.trim().toLowerCase();
          return licName == storeName ||
                 storeName.contains(licName) ||
                 (licName != 'boutique client' && licName.contains(storeName));
        });
      } catch (_) {}
    }

    // 4. Fallback : S'il n'y a qu'une seule boutique et une seule licence enregistrée
    if (licenses.length == 1) {
      return licenses.first;
    }

    return null;
  }

  void _showAddClientDialog([ClientModel? client]) {
    showDialog(
      context: context,
      builder: (ctx) => ClientFormDialog(client: client),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'initier l\'appel téléphonique direct'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phone, String storeName) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final text = Uri.encodeComponent("Bonjour $storeName, l'équipe N'MaShop vous contacte.");
    final waUri1 = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    final waUri2 = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$text');
    final waUri3 = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$text');

    try {
      if (await canLaunchUrl(waUri1)) {
        await launchUrl(waUri1, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(waUri2)) {
        await launchUrl(waUri2, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(waUri3, mode: LaunchMode.externalApplication);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: "Bonjour $storeName, l'équipe N'MaShop vous contacte."));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp introuvable. Message copié dans le presse-papier !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendSms(String phone, String storeName) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final text = Uri.encodeComponent("Bonjour $storeName, l'équipe N'MaShop vous contacte.");
    final smsUri1 = Uri.parse('sms:$cleanPhone?body=$text');
    final smsUri2 = Uri.parse('sms:$cleanPhone&body=$text');

    try {
      if (await canLaunchUrl(smsUri1)) {
        await launchUrl(smsUri1);
        return;
      }
      await launchUrl(smsUri2);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: "Bonjour $storeName, l'équipe N'MaShop vous contacte."));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application SMS introuvable. Message copié !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showContactOptions(BuildContext context, String phone, String storeName) {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun numéro de téléphone disponible pour cette boutique'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.borderSlate, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Contacter $storeName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Numéro : $phone',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Option 1: Appel direct
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLightBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: AppTheme.primaryIndigo),
              ),
              title: const Text('Appel Téléphonique Direct', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Composer le numéro sur votre téléphone'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                _makePhoneCall(phone);
              },
            ),
            const Divider(height: 1),

            // Option 2: WhatsApp
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              ),
              title: const Text('Message WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Démarrer une discussion instantanée WhatsApp'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                _openWhatsApp(phone, storeName);
              },
            ),
            const Divider(height: 1),

            // Option 3: SMS
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sms_rounded, color: Colors.blue),
              ),
              title: const Text('Envoyer un SMS', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Envoyer un message texte SMS natif'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                _sendSms(phone, storeName);
              },
            ),
            const Divider(height: 1),

            // Option 4: Copier numéro
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.bgSlate,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.copy_rounded, color: AppTheme.textDark),
              ),
              title: const Text('Copier le numéro', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Numéro de téléphone copié !'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final licenses = ref.watch(licensesProvider);

    final filtered = clients.where((c) {
      final query = _searchQuery.toLowerCase();
      final matchesQuery = c.storeName.toLowerCase().contains(query) ||
          c.ownerName.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query) ||
          c.city.toLowerCase().contains(query);

      if (!matchesQuery) return false;
      if (_filterStatus == 'all') return true;

      final lic = _findLicenseForClient(c, licenses);
      
      // Statut réel
      final bool isDeactivated = lic != null && !lic.isActive;
      final bool isStoreActive = lic != null && lic.isActive && !lic.isExpired && lic.type != AdminLicenseType.trial;
      final bool isTrial = lic == null || (lic.isActive && (lic.type == AdminLicenseType.trial || lic.isExpired));

      if (_filterStatus == 'active') {
        return isStoreActive;
      } else if (_filterStatus == 'trial') {
        return isTrial;
      } else if (_filterStatus == 'deactivated') {
        return isDeactivated;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgSlate,
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une boutique, gérant, ville...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryIndigo),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.borderSlate),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _filterStatus == 'all',
                        label: Text('Toutes (${clients.length})'),
                        onSelected: (_) => setState(() => _filterStatus = 'all'),
                        selectedColor: AppTheme.primaryLightBg,
                        checkmarkColor: AppTheme.primaryIndigo,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _filterStatus == 'active',
                        label: const Text('Licence Active'),
                        onSelected: (_) => setState(() => _filterStatus = 'active'),
                        selectedColor: AppTheme.emeraldBg,
                        checkmarkColor: AppTheme.emeraldActive,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _filterStatus == 'trial',
                        label: const Text('Mode Essai'),
                        onSelected: (_) => setState(() => _filterStatus = 'trial'),
                        selectedColor: AppTheme.amberBg,
                        checkmarkColor: AppTheme.amberTrial,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _filterStatus == 'deactivated',
                        label: const Text('Désactivées'),
                        onSelected: (_) => setState(() => _filterStatus = 'deactivated'),
                        selectedColor: AppTheme.roseBg,
                        checkmarkColor: AppTheme.roseAlert,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Client Store List
          Expanded(
            child: filtered.isEmpty
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
                          child: const Icon(Icons.storefront_rounded, size: 48, color: AppTheme.primaryIndigo),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune boutique enregistrée',
                          style: TextStyle(color: AppTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ajoutez vos magasins pour gérer leurs clés N\'MaShop PC',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddClientDialog(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter une Boutique'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      return _buildNmaStoreCard(context, client);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddClientDialog(),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Nouvelle Boutique'),
      ),
    );
  }

  Widget _buildNmaStoreCard(BuildContext context, ClientModel client) {
    final hasPhone = client.phone.trim().isNotEmpty;
    final licenses = ref.watch(licensesProvider);

    final clientLicense = _findLicenseForClient(client, licenses);

    final bool isDeactivated = clientLicense != null && !clientLicense.isActive;
    final bool isStoreActive = clientLicense != null && clientLicense.isActive && !clientLicense.isExpired && clientLicense.type != AdminLicenseType.trial;

    final String statusLabel = isDeactivated
        ? 'Désactivée'
        : (isStoreActive ? 'Active' : 'Mode Essai');

    final Color statusBg = isDeactivated
        ? AppTheme.roseBg
        : (isStoreActive ? AppTheme.emeraldBg : AppTheme.amberBg);

    final Color statusColor = isDeactivated
        ? AppTheme.roseAlert
        : (isStoreActive ? AppTheme.emeraldActive : AppTheme.amberTrial);

    final IconData statusIcon = isDeactivated
        ? Icons.cancel_rounded
        : (isStoreActive ? Icons.check_circle_rounded : Icons.timer_outlined);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    client.storeName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Owner & Location Info
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Gérant : ${client.ownerName}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.location_on_outlined, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    client.city.isNotEmpty ? client.city : 'Conakry',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons Row: Direct Contact & Editing
            Row(
              children: [
                // Bouton Numéro de Téléphone avec Menu de Contact Direct (Appel / WhatsApp / SMS)
                ElevatedButton.icon(
                  onPressed: () => _showContactOptions(context, client.phone, client.storeName),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: Text(hasPhone ? client.phone : 'Contacter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),

                // Raccourci Direct WhatsApp
                if (hasPhone)
                  IconButton(
                    icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
                    onPressed: () => _openWhatsApp(client.phone, client.storeName),
                    tooltip: 'Ouvrir WhatsApp',
                  ),

                const Spacer(),

                // Edit Action
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryIndigo, size: 20),
                  onPressed: () => _showAddClientDialog(client),
                  tooltip: 'Modifier',
                ),

                // Delete Action
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.roseAlert, size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Supprimer la boutique ?'),
                        content: Text('Voulez-vous supprimer ${client.storeName} de la liste ?'),
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
                      ref.read(clientsProvider.notifier).removeClient(client.id);
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
