import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/license/license_provider.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/services/hardware_id_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Dialogue de jumelage entre N'MaShop Desktop et le smartphone du commerçant (N'MaShop Mobile).
class MobilePairingDialog extends ConsumerStatefulWidget {
  const MobilePairingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const MobilePairingDialog(),
    );
  }

  @override
  ConsumerState<MobilePairingDialog> createState() => _MobilePairingDialogState();
}

class _MobilePairingDialogState extends ConsumerState<MobilePairingDialog> {
  String? _pairingPayload;
  DateTime? _expiresAt;
  Timer? _countdownTimer;
  Duration _remainingTime = const Duration(minutes: 10);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generatePairingToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _generatePairingToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = ref.read(appSettingsProvider);
      final prefs = ref.read(sharedPreferencesProvider);
      final license = ref.read(licenseInfoProvider);
      final hwid = await HardwareIdService.getHardwareId();
      final token = const Uuid().v4();
      final now = DateTime.now();
      final expires = now.add(const Duration(minutes: 10));

      final serverUrl = prefs.getString('custom_server_url')?.trim().isNotEmpty == true
          ? prefs.getString('custom_server_url')!.trim()
          : 'http://localhost:3000';

      final payload = {
        'type': 'nmashop_pairing',
        'version': '1.0',
        'serverUrl': serverUrl,
        'machineId': hwid,
        'shopName': settings.businessName,
        'currency': settings.currency,
        'token': token,
        'expiresAt': expires.toIso8601String(),
      };

      // Pré-enregistrement auprès du serveur NestJS local (avec tolérance hors-ligne)
      try {
        final res = await http
            .post(
              Uri.parse('$serverUrl/api/v1/auth/pair/init'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'token': token,
                'machineId': hwid,
                'licenseKey': license.key ?? 'NMA-2026-GUINEE-001',
                'shopName': settings.businessName,
                'currency': settings.currency,
                'expiresAt': expires.toIso8601String(),
              }),
            )
            .timeout(const Duration(seconds: 3));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final body = jsonDecode(res.body);
          if (body is Map && body['caisseSecret'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('caisse_secret', body['caisseSecret'].toString());
          }
        }
      } catch (_) {
        // Tolérance déconnectée : le QR code reste généré et affiché
      }

      if (!mounted) return;

      setState(() {
        _pairingPayload = jsonEncode(payload);
        _expiresAt = expires;
        _remainingTime = const Duration(minutes: 10);
        _isLoading = false;
      });

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final diff = _expiresAt!.difference(DateTime.now());
        if (diff.isNegative) {
          timer.cancel();
          setState(() {
            _remainingTime = Duration.zero;
          });
        } else {
          setState(() {
            _remainingTime = diff;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _pairingPayload = jsonEncode({
            'type': 'nmashop_pairing',
            'token': const Uuid().v4(),
            'shopName': 'Boutique N\'MaShop',
            'currency': 'GNF',
            'serverUrl': 'http://localhost:3000',
          });
          _expiresAt = DateTime.now().add(const Duration(minutes: 10));
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final isExpired = _remainingTime == Duration.zero;

    final minutes = _remainingTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.smartphone_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lier N\'MaShop Mobile',
                          style: AppTypography.headlineMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          settings.businessName,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Zone du QR Code
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(),
                )
              else if (isExpired)
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_off_outlined, size: 48, color: Colors.orange),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Code QR expiré',
                        style: AppTypography.bodyLg.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _generatePairingToken,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Générer un nouveau code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _pairingPayload!,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: _remainingTime.inMinutes < 2 ? Colors.red : AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Expire dans $minutes:$seconds',
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _remainingTime.inMinutes < 2 ? Colors.red : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.lg),

              // Instructions
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Instructions pour le patron :',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Ouvrez l\'application N\'MaShop Mobile sur votre téléphone.\n'
                      '2. Cliquez sur "Lier ma boutique" puis scannez ce QR Code.\n'
                      '3. Définissez votre code PIN secret pour accéder au pilotage.',
                      style: AppTypography.bodySm.copyWith(
                        color: Colors.blue.shade900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Boutons d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: _generatePairingToken,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Régénérer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: AppColors.onSurface,
                      elevation: 0,
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
