/// Statut courant de la licence de l'application.
enum LicenseStatus {
  /// Période d'essai en cours (accès complet).
  trial,

  /// Clé valide activée (accès complet).
  licensed,

  /// Essai ou licence expirée → accès totalement bloqué.
  expired,

  /// Horloge système altérée / triche détectée → accès bloqué.
  tampered,

  /// Licence liée à une autre machine / appareil différent → accès bloqué.
  deviceMismatch,
}

/// Type de la licence activée.
enum LicenseType {
  /// Période d'essai gratuite (7 jours).
  trial,

  /// Licence mensuelle (expire dans ~30 jours).
  monthly,

  /// Licence annuelle (expire à une date précise).
  annual,

  /// Licence à vie (jamais expirée).
  lifetime,
}

/// Résultat d'une tentative d'activation de clé.
enum LicenseActivationResult {
  success,
  invalidKey,
  expiredKey,
  deviceMismatch,
}

/// Snapshot complet de l'état de la licence au moment de la vérification.
class LicenseInfo {
  const LicenseInfo({
    required this.status,
    required this.type,
    this.expiryDate,
    this.daysLeft,
    this.key,
  });

  final LicenseStatus status;
  final LicenseType type;

  /// Date d'expiration. `null` pour une licence à vie.
  final DateTime? expiryDate;

  /// Jours restants. `null` pour une licence à vie.
  final int? daysLeft;

  /// Clé brute activée (null en mode essai).
  final String? key;

  bool get isExpired => status == LicenseStatus.expired || status == LicenseStatus.tampered || status == LicenseStatus.deviceMismatch;
  bool get isTrial => status == LicenseStatus.trial;
  bool get isLicensed => status == LicenseStatus.licensed;
  bool get isLifetime => type == LicenseType.lifetime;
  bool get isTampered => status == LicenseStatus.tampered;

  /// Étiquette courte pour l'UI.
  String get statusLabel {
    switch (status) {
      case LicenseStatus.trial:
        return daysLeft != null && daysLeft! > 0
            ? 'Essai — ${daysLeft!} jour${daysLeft! > 1 ? 's' : ''} restant${daysLeft! > 1 ? 's' : ''}'
            : 'Essai';
      case LicenseStatus.licensed:
        return isLifetime ? 'Licence à vie' : 'Licence annuelle';
      case LicenseStatus.expired:
        return 'Licence expirée';
      case LicenseStatus.tampered:
        return 'Triche de date détectée';
      case LicenseStatus.deviceMismatch:
        return 'Appareil non autorisé';
    }
  }

  /// Description détaillée avec date d'expiration exacte et jours restants.
  String get detailedDescription {
    if (status == LicenseStatus.licensed) {
      if (isLifetime) {
        return 'Licence permanente active — Accès illimité sans expiration';
      }
      final dateStr = expiryDate != null
          ? '${expiryDate!.day.toString().padLeft(2, '0')}/${expiryDate!.month.toString().padLeft(2, '0')}/${expiryDate!.year}'
          : '';
      final days = daysLeft ?? 0;
      return 'Valide jusqu\'au $dateStr ($days jour${days > 1 ? 's' : ''} restant${days > 1 ? 's' : ''})';
    }
    if (status == LicenseStatus.trial) {
      final days = daysLeft ?? 0;
      return 'Période d\'essai gratuite (7 jours) — $days jour${days > 1 ? 's' : ''} restant${days > 1 ? 's' : ''}';
    }
    if (status == LicenseStatus.expired) {
      return 'Période d\'essai ou licence expirée. Veuillez saisir votre clé d\'activation.';
    }
    if (status == LicenseStatus.tampered) {
      return 'Modification suspecte de la date système détectée.';
    }
    if (status == LicenseStatus.deviceMismatch) {
      return 'Cette licence est liée à un autre ordinateur.';
    }
    return '';
  }

  /// Masque de la clé pour affichage sécurisé (ex: NMAS-****-****-8F3A2B1C).
  String? get maskedKey {
    if (key == null || key!.length < 8) return null;
    final parts = key!.split('-');
    if (parts.length >= 3) {
      return '${parts[0]}-****-${parts.last}';
    }
    return key;
  }
}
