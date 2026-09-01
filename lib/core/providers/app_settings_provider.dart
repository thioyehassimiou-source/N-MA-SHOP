import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../license/license_provider.dart';
import '../theme/app_palette.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('override SharedPreferences in main.dart');
});

class AppSettings {
  const AppSettings({
    required this.isFirstRunCompleted,
    required this.isSetupCompleted,
    required this.businessName,
    required this.currency,
    required this.businessEmail,
    required this.businessNif,
    required this.businessAddress,
    required this.logoPath,
    required this.businessDomain,
    required this.businessPhone,
    required this.paletteId,
    required this.useCustomTheme,
  });

  /// Indique si l'assistant de tout premier démarrage (First-Run Setup Wizard) a été complété.
  final bool isFirstRunCompleted;

  final bool isSetupCompleted;
  final String businessName;
  final String currency;
  final String businessEmail;
  final String businessNif;
  final String businessAddress;
  final String? logoPath;
  final String? businessDomain;

  /// Téléphone du commerce, imprimé sur les reçus.
  final String businessPhone;

  /// Identifiant du template visuel choisi ([AppPalette.id]).
  final String paletteId;

  /// Active le thème personnalisé (palette) à la place de la charte N'MaShop.
  /// Réservé aux utilisateurs avec licence active.
  final bool useCustomTheme;

  AppSettings copyWith({
    bool? isFirstRunCompleted,
    bool? isSetupCompleted,
    String? businessName,
    String? currency,
    String? businessEmail,
    String? businessNif,
    String? businessAddress,
    String? logoPath,
    String? businessDomain,
    String? businessPhone,
    String? paletteId,
    bool? useCustomTheme,
  }) {
    return AppSettings(
      isFirstRunCompleted: isFirstRunCompleted ?? this.isFirstRunCompleted,
      isSetupCompleted: isSetupCompleted ?? this.isSetupCompleted,
      businessName: businessName ?? this.businessName,
      currency: currency ?? this.currency,
      businessEmail: businessEmail ?? this.businessEmail,
      businessNif: businessNif ?? this.businessNif,
      businessAddress: businessAddress ?? this.businessAddress,
      logoPath: logoPath ?? this.logoPath,
      businessDomain: businessDomain ?? this.businessDomain,
      businessPhone: businessPhone ?? this.businessPhone,
      paletteId: paletteId ?? this.paletteId,
      useCustomTheme: useCustomTheme ?? this.useCustomTheme,
    );
  }
}

// Riverpod 3 compatible – uses Notifier<T> instead of deprecated StateNotifier.
final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kIsFirstRunCompleted = 'first_run_completed';
  static const _kIsSetupCompleted = 'is_setup_completed';
  static const _kBusinessName = 'business_name';
  static const _kCurrency = 'business_currency';
  static const _kBusinessEmail = 'business_email';
  static const _kBusinessNif = 'business_nif';
  static const _kBusinessAddress = 'business_address';
  static const _kLogoPath = 'logo_path';
  static const _kBusinessDomain = 'business_domain';
  static const _kBusinessPhone = 'business_phone';
  static const _kPaletteId = 'business_palette';
  static const _kUseCustomTheme = 'use_custom_theme';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      isFirstRunCompleted: prefs.getBool(_kIsFirstRunCompleted) ?? false,
      isSetupCompleted: prefs.getBool(_kIsSetupCompleted) ?? false,
      businessName: prefs.getString(_kBusinessName) ?? 'Ma Boutique',
      currency: prefs.getString(_kCurrency) ?? 'GNF',
      businessEmail: prefs.getString(_kBusinessEmail) ?? 'contact@boutique.gn',
      businessNif: prefs.getString(_kBusinessNif) ?? '',
      businessAddress: prefs.getString(_kBusinessAddress) ?? '',
      logoPath: prefs.getString(_kLogoPath),
      businessDomain: prefs.getString(_kBusinessDomain),
      businessPhone: prefs.getString(_kBusinessPhone) ?? '',
      paletteId: prefs.getString(_kPaletteId) ?? AppPalette.fallback.id,
      useCustomTheme: prefs.getBool(_kUseCustomTheme) ?? false,
    );
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> updateSettings({
    String? businessName,
    String? currency,
    String? businessEmail,
    String? businessNif,
    String? businessAddress,
    String? logoPath,
    String? businessDomain,
    String? businessPhone,
    String? paletteId,
  }) async {
    if (businessName != null) {
      await _prefs.setString(_kBusinessName, businessName);
    }
    if (currency != null) {
      await _prefs.setString(_kCurrency, currency);
    }
    if (businessEmail != null) {
      await _prefs.setString(_kBusinessEmail, businessEmail);
    }
    if (businessNif != null) {
      await _prefs.setString(_kBusinessNif, businessNif);
    }
    if (businessAddress != null) {
      await _prefs.setString(_kBusinessAddress, businessAddress);
    }
    if (logoPath != null) {
      await _prefs.setString(_kLogoPath, logoPath);
    }
    if (businessDomain != null) {
      await _prefs.setString(_kBusinessDomain, businessDomain);
    }

    state = state.copyWith(
      businessName: businessName,
      currency: currency,
      businessEmail: businessEmail,
      businessNif: businessNif,
      businessAddress: businessAddress,
      logoPath: logoPath,
      businessDomain: businessDomain,
      businessPhone: businessPhone,
      paletteId: paletteId,
    );
  }

  Future<void> completeSetup({
    required String businessName,
    required String currency,
    String? logoPath,
    String? businessDomain,
    String? businessPhone,
    String? paletteId,
  }) async {
    // Si c'est un nouveau paramétrage (isSetupCompleted était false),
    // réinitialiser la licence pour démarrer la nouvelle boutique à neuf.
    if (!state.isSetupCompleted) {
      await ref.read(licenseProvider.notifier).resetLicense();
    }

    await _prefs.setBool(_kIsSetupCompleted, true);
    await _prefs.setString(_kBusinessName, businessName);
    await _prefs.setString(_kCurrency, currency);
    if (logoPath != null) {
      await _prefs.setString(_kLogoPath, logoPath);
    }
    if (businessDomain != null) {
      await _prefs.setString(_kBusinessDomain, businessDomain);
    }
    if (businessPhone != null) {
      await _prefs.setString(_kBusinessPhone, businessPhone);
    }

    state = state.copyWith(
      isSetupCompleted: true,
      businessName: businessName,
      currency: currency,
      logoPath: logoPath,
      businessDomain: businessDomain,
      businessPhone: businessPhone,
      // Si aucune palette fournie, on garde la valeur par défaut (fallback).
      paletteId: paletteId,
    );
  }

  /// Permet de changer de template visuel global.
  Future<void> updatePalette(String paletteId) async {
    await _prefs.setString(_kPaletteId, paletteId);
    final useCustom = paletteId != AppPalette.nmashop.id;
    await _prefs.setBool(_kUseCustomTheme, useCustom);
    state = state.copyWith(
      paletteId: paletteId,
      useCustomTheme: useCustom,
    );
  }

  /// Marque l'assistant au tout premier démarrage (First-Run Wizard) comme complété.
  Future<void> completeFirstRun({
    required bool createDesktopShortcut,
    required bool autoLaunchAtStartup,
  }) async {
    await _prefs.setBool(_kIsFirstRunCompleted, true);
    await _prefs.setBool('create_desktop_shortcut', createDesktopShortcut);
    await _prefs.setBool('auto_launch_startup', autoLaunchAtStartup);
    state = state.copyWith(isFirstRunCompleted: true);
  }

  Future<void> resetSetup() async {
    await ref.read(licenseProvider.notifier).resetLicense();

    await _prefs.remove(_kIsFirstRunCompleted);
    await _prefs.remove(_kIsSetupCompleted);
    await _prefs.remove(_kBusinessName);
    await _prefs.remove(_kCurrency);
    await _prefs.remove(_kBusinessEmail);
    await _prefs.remove(_kBusinessNif);
    await _prefs.remove(_kBusinessAddress);
    await _prefs.remove(_kLogoPath);
    await _prefs.remove(_kBusinessDomain);
    await _prefs.remove(_kBusinessPhone);
    await _prefs.remove(_kPaletteId);

    await _prefs.remove(_kUseCustomTheme);

    state = AppSettings(
      isFirstRunCompleted: false,
      isSetupCompleted: false,
      businessName: 'Ma Boutique',
      currency: 'GNF',
      businessEmail: 'contact@boutique.gn',
      businessNif: '',
      businessAddress: '',
      logoPath: null,
      businessDomain: null,
      businessPhone: '',
      paletteId: AppPalette.fallback.id,
      useCustomTheme: false,
    );
  }
}
