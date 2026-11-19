import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/nma_mobile_header.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_landing_screen.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../backup/presentation/backup_restore_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _shopName = 'Chargement...';
  String _currency = 'GNF';
  String _serverUrl = '...';
  String _deviceId = '...';
  bool _dataSaverMode = true;
  bool _soundAlerts = true;
  int _lowStockThreshold = 5;
  int _largeSaleThreshold = 2000000;
  bool _isTestingPing = false;
  String? _pingResult;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(storageServiceProvider);
    final shopName = await storage.getShopName();
    final currency = await storage.getCurrency();
    final serverUrl = await storage.getServerUrl();
    final deviceId = await storage.getOrCreateDeviceId();

    if (mounted) {
      setState(() {
        _shopName = shopName;
        _currency = currency;
        _serverUrl = serverUrl;
        _deviceId = deviceId;
      });
    }
  }

  Future<void> _testPing() async {
    setState(() {
      _isTestingPing = true;
      _pingResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get('/api/v1/sync/status');
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _isTestingPing = false;
          _pingResult = res.statusCode == 200
              ? 'Connecté au Cloud (${stopwatch.elapsedMilliseconds} ms)'
              : 'Serveur indisponible (HTTP ${res.statusCode})';
        });
      }
    } catch (_) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isTestingPing = false;
          _pingResult = 'Échec de connexion au serveur.';
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final response = await dio.get('https://api.github.com/repos/thioyehassimiou-source/N-MA-SHOP/releases/latest');
      setState(() => _isCheckingUpdate = false);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final tagName = data['tag_name'] as String? ?? '1.2.0';
        final cleanTag = tagName.replaceAll(RegExp(r'[^0-9.]'), '');
        final body = data['body'] as String? ?? 'Améliorations et corrections générales de N\'MaShop.';
        final htmlUrl = data['html_url'] as String? ?? 'https://github.com/thioyehassimiou-source/N-MA-SHOP/releases';

        String? apkUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }

        if (mounted) {
          _showUpdateDialog(cleanTag, body, apkUrl ?? htmlUrl);
        }
      }
    } catch (_) {
      setState(() => _isCheckingUpdate = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de vérifier les mises à jour (vérifiez votre connexion internet).'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showUpdateDialog(String latestVersion, String notes, String downloadUrl) {
    const currentVersion = '1.2.0';
    final hasNewVersion = latestVersion != currentVersion;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              hasNewVersion ? Icons.new_releases_rounded : Icons.check_circle_rounded,
              color: hasNewVersion ? AppColors.brandOrange : AppColors.brandEmerald,
            ),
            const SizedBox(width: 8),
            Text(hasNewVersion ? 'Mise à jour disponible' : 'Application à jour'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasNewVersion
                  ? 'Une nouvelle version (v$latestVersion) est disponible ! Vous utilisez actuellement la version v$currentVersion.'
                  : 'Votre application N\'MaShop est à jour (v$currentVersion). Vous bénéficiez de toutes les dernières fonctionnalités.',
              style: const TextStyle(fontSize: 13),
            ),
            if (hasNewVersion && notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Nouveautés :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    notes,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
          if (hasNewVersion)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Télécharger l\'APK'),
              onPressed: () {
                Navigator.of(ctx).pop();
                launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsAppSupport() async {
    final message = "Bonjour Support N'MaShop, j'utilise l'application mobile (Boutique : $_shopName). J'ai besoin d'une assistance.";
    final uri = Uri.parse('whatsapp://send?phone=224624193069&text=${Uri.encodeComponent(message)}');
    final fallbackUri = Uri.parse('https://wa.me/224624193069?text=${Uri.encodeComponent(message)}');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:+224624193069');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showEditShopDialog() {
    final nameCtrl = TextEditingController(text: _shopName);
    final currencyCtrl = TextEditingController(text: _currency);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier ma Boutique'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Renseignez les coordonnées de votre boutique :',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nom de la boutique',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.storefront_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currencyCtrl,
              decoration: InputDecoration(
                labelText: 'Devise principale (ex: GNF, FCFA, USD)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.payments_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newCurrency = currencyCtrl.text.trim();
              Navigator.of(ctx).pop();
              if (newName.isNotEmpty) {
                final storage = ref.read(storageServiceProvider);
                final currentPin = await storage.getLocalPin() ?? '1234';
                await storage.saveLocalShop(
                  shopName: newName,
                  currency: newCurrency.isEmpty ? 'GNF' : newCurrency,
                  pin: currentPin,
                );
                _loadSettings();
                ref.read(dashboardControllerProvider.notifier).refresh();
              }
            },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showEditServerUrlDialog() {
    final controller = TextEditingController(text: _serverUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Serveur de Sauvegarde Distant (Optionnel)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indiquez l\'adresse du serveur cloud de sauvegarde distant si vous souhaitez synchroniser vos données localement :',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'http://192.168.1.XX:3000 ou https://api.nmashop.gn',
                prefixIcon: const Icon(Icons.dns_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              Navigator.of(ctx).pop();
              if (newUrl.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('nmashop_server_url', newUrl);
                _loadSettings();
                ref.read(dashboardControllerProvider.notifier).refresh();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Se déconnecter de la boutique ?'),
        content: const Text(
          'Votre session locale sera fermée. Vous pourrez vous reconnecter à tout moment sur ce smartphone avec votre code PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authServiceProvider).logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthLandingScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const NmaMobileAppBar(
        title: 'Paramètres & Configuration',
        subtitle: 'Boutique, imprimantes & synchronisation',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte En-tête Boutique
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroNavyGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandNavy.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.5), width: 2),
                  ),
                  child: const Icon(Icons.store_mall_directory_rounded, color: AppColors.brandOrange, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shopName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brandEmerald.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Licence Active',
                              style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Devise : $_currency',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white70),
                  onPressed: _showEditShopDialog,
                  tooltip: 'Modifier les informations de la boutique',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 1 : Mode de Fonctionnement Local & Réseau
          _buildSectionHeader('MODE DE FONCTIONNEMENT & DONNÉES LOCALES', Icons.sd_storage_rounded),
          _buildCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phonelink_setup_rounded, color: AppColors.brandEmerald),
                title: const Text('Mode de fonctionnement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('100% Autonome Local (SQLite Drift sur ce smartphone)', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('100% Autonome', style: TextStyle(color: AppColors.brandEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_queue_rounded, color: AppColors.brandNavy),
                title: const Text('Serveur de Sauvegarde Distant (Optionnel)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(_serverUrl, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: TextButton(
                  onPressed: _showEditServerUrlDialog,
                  child: const Text('Configurer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const Divider(color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Diagnostic Serveur Distant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (_pingResult != null)
                        Text(
                          _pingResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _pingResult!.contains('Connecté') ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isTestingPing ? null : _testPing,
                    icon: _isTestingPing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_ping_rounded, size: 16),
                    label: const Text('Tester Ping', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceVariant,
                      foregroundColor: AppColors.brandNavy,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                title: const Text('Économie de données Mobile 4G', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Optimise les échanges réseau en cas de synchronisation distante', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                value: _dataSaverMode,
                onChanged: (val) => setState(() => _dataSaverMode = val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2 : Alertes & Seuils Commerciaux
          _buildSectionHeader('SEUILS D\'ALERTES BUSINESS', Icons.notifications_active_outlined),
          _buildCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined, color: AppColors.warning),
                title: const Text('Seuil de stock bas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Alerte si la quantité restante descend sous ce niveau', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: DropdownButton<int>(
                  value: _lowStockThreshold,
                  underline: const SizedBox(),
                  items: [3, 5, 10, 20].map((v) => DropdownMenuItem(value: v, child: Text('$v unités'))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _lowStockThreshold = val);
                  },
                ),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.trending_up, color: AppColors.success),
                title: const Text('Alerte grosse vente', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Notification prioritaire dès ce montant atteint', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: DropdownButton<int>(
                  value: _largeSaleThreshold,
                  underline: const SizedBox(),
                  items: [1000000, 2000000, 5000000]
                      .map((v) => DropdownMenuItem(value: v, child: Text('${v ~/ 1000000}M GNF')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _largeSaleThreshold = val);
                  },
                ),
              ),
              const Divider(color: AppColors.border),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                title: const Text('Signaux sonores & vibrations', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                value: _soundAlerts,
                onChanged: (val) => setState(() => _soundAlerts = val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 3 : Sécurité & Appareil
          _buildSectionHeader('SÉCURITÉ & DONNÉES', Icons.security_rounded),
          _buildCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.backup_rounded, color: AppColors.brandEmerald),
                title: const Text('Sauvegardes & Restauration', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Exports de sécurité et vérification d\'intégrité SQLite', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
                  );
                },
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_android_rounded, color: AppColors.onSurfaceVariant),
                title: const Text('Identifiant de cet appareil', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(_deviceId, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_stories_rounded, color: Colors.blue),
                title: const Text('Revoir l\'onboarding de bienvenue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                },
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: const Text('Se déconnecter', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Ferme la session locale sur ce téléphone', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                onTap: _confirmLogout,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 4 : Support & Mises à jour
          _buildSectionHeader('SUPPORT & MISES À JOUR', Icons.support_agent_rounded),
          _buildCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _isCheckingUpdate
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.brandOrange),
                      )
                    : const Icon(Icons.system_update_rounded, color: AppColors.brandOrange),
                title: const Text('Vérifier les mises à jour', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Recherche les dernières versions APK de N\'MaShop', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isCheckingUpdate ? null : _checkForUpdates,
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_rounded, color: AppColors.brandEmerald),
                title: const Text('Assistance WhatsApp Directe', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Échangez avec l\'équipe technique (+224 624 19 30 69)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.brandEmerald),
                onTap: _launchWhatsAppSupport,
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_rounded, color: AppColors.brandNavy),
                title: const Text('Appeler l\'assistance téléphonique', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Ligne directe : +224 624 19 30 69', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: const Icon(Icons.call_rounded, size: 18, color: AppColors.brandNavy),
                onTap: _callSupport,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Assistance & Version
          Center(
            child: Column(
              children: const [
                Text(
                  'N\'MaShop — Gestion Commerciale & Caisse POS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.2.0 • Support : +224 624 19 30 69',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.brandOrange),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
