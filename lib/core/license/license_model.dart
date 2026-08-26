/// Statut courant de la licence de l'application.
enum LicenseStatus {
  /// Période d'essai en cours (accès complet, bandeau affiché).
  trial,

  /// Clé valide activée (accès complet, aucun bandeau).
  licensed,

  /// Essai ou licence expirée → accès totalement bloqué.
  expired,
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

  bool get isExpired => status == LicenseStatus.expired;
  bool get isTrial => status == LicenseStatus.trial;
  bool get isLicensed => status == LicenseStatus.licensed;
  bool get isLifetime => type == LicenseType.lifetime;

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
    }
  }
}
