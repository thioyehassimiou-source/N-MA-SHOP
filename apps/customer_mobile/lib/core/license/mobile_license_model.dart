import 'package:flutter/foundation.dart';

/// Statut de la licence sur le smartphone.
enum MobileLicenseStatus {
  trial,        // Période d'essai gratuite active (7 jours)
  active,       // Licence payée officielle active (Annuelle ou À Vie)
  gracePeriod,  // Période de grâce hors-ligne (5 jours après expiration)
  expired,      // Licence ou période d'essai expirée (Verrouillage)
  tampered,     // Fraude détectée (horloge système reculée)
}

/// Type de formule de licence.
enum MobileLicenseType {
  trial,     // Essai gratuit
  monthly,   // 30 jours
  annual,    // 1 An
  lifetime,  // À Vie (Illimitée)
}

@immutable
class MobileLicenseInfo {
  final MobileLicenseStatus status;
  final MobileLicenseType type;
  final String? key;
  final DateTime? expiryDate;
  final int daysLeft;
  final int graceDaysLeft;
  final String? hardwareId;

  const MobileLicenseInfo({
    required this.status,
    required this.type,
    this.key,
    this.expiryDate,
    required this.daysLeft,
    this.graceDaysLeft = 0,
    this.hardwareId,
  });

  /// Si l'application peut continuer à vendre et enregistrer des opérations.
  bool get isValid =>
      status == MobileLicenseStatus.active ||
      status == MobileLicenseStatus.trial ||
      status == MobileLicenseStatus.gracePeriod;

  /// Si l'application doit être verrouillée (écran d'activation obligatoire).
  bool get isExpired =>
      status == MobileLicenseStatus.expired ||
      status == MobileLicenseStatus.tampered;

  bool get isLifetime => type == MobileLicenseType.lifetime;
  bool get isInGracePeriod => status == MobileLicenseStatus.gracePeriod;

  String get statusLabel {
    switch (status) {
      case MobileLicenseStatus.trial:
        return 'Essai Gratuit ($daysLeft j)';
      case MobileLicenseStatus.active:
        return isLifetime ? 'Licence À Vie' : 'Licence Active ($daysLeft j)';
      case MobileLicenseStatus.gracePeriod:
        return 'Délai de Grâce ($graceDaysLeft j)';
      case MobileLicenseStatus.expired:
        return 'Licence Expirée';
      case MobileLicenseStatus.tampered:
        return 'Date Système Modifiée';
    }
  }
}

