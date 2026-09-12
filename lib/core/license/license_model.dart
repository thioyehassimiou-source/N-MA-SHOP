/// Statut courant de la licence de l'application.
enum LicenseStatus {
  /// Période d'essai en cours (accès complet).
  trial,

  /// Clé valide activée (accès complet).
  licensed,

  /// Délai de grâce hors-ligne après échéance de la clé (accès complet maintenu + alerte renouvellement).
  gracePeriod,

  /// Essai ou licence expirée (au-delà du délai de grâce) → accès totalement bloqué.
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

  /// Date d'expiration contractuelle. `null` pour une licence à vie.
  final DateTime? expiryDate;

  /// Jours restants (avant expiration ou fin du délai de grâce). `null` pour une licence à vie.
  final int? daysLeft;

  /// Clé brute activée (null en mode essai).
  final String? key;

  bool get isExpired =>
      status == LicenseStatus.expired ||
      status == LicenseStatus.tampered ||
      status == LicenseStatus.deviceMismatch;
  bool get isTrial => status == LicenseStatus.trial;
  bool get isGracePeriod => status == LicenseStatus.gracePeriod;
  bool get isLicensed =>
      status == LicenseStatus.licensed || status == LicenseStatus.gracePeriod;
  bool get isStrictlyLicensed => status == LicenseStatus.licensed;
  bool get isLifetime => type == LicenseType.lifetime;
  bool get isTampered => status == LicenseStatus.tampered;

  /// Durée exacte restante avant expiration ou fin du délai de grâce.
  Duration? get remainingDuration {
    if (expiryDate == null) return null;
    final diff = expiryDate!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Libellé précis du compte à rebours pour la période d'essai (Jours et Heures).
  String get trialCountdownLabel {
    final dur = remainingDuration;
    if (dur == null || dur <= Duration.zero) return 'Essai expiré';
    final days = dur.inDays;
    final hours = dur.inHours % 24;
    final minutes = dur.inMinutes % 60;
    if (days > 0) {
      return 'Essai : ${days}j ${hours}h restant${days > 1 || hours > 1 ? 's' : ''}';
    } else if (hours > 0) {
      return 'Essai : ${hours}h ${minutes}m restante${hours > 1 || minutes > 1 ? 's' : ''}';
    } else {
      return 'Essai : ${minutes}m restante${minutes > 1 ? 's' : ''}';
    }
  }

  /// Étiquette courte pour l'UI.
  String get statusLabel {
    switch (status) {
      case LicenseStatus.trial:
        final dur = remainingDuration;
        if (dur == null || dur <= Duration.zero) return 'Essai expiré';
        final days = dur.inDays;
        final hours = dur.inHours % 24;
        final minutes = dur.inMinutes % 60;
        if (days > 0) {
          return 'Essai — ${days}j ${hours}h restant${days > 1 || hours > 1 ? 's' : ''}';
        } else if (hours > 0) {
          return 'Essai — ${hours}h ${minutes}m restante${hours > 1 || minutes > 1 ? 's' : ''}';
        } else {
          return 'Essai — ${minutes}m restante${minutes > 1 ? 's' : ''}';
        }
      case LicenseStatus.licensed:
        return isLifetime ? 'Licence à vie' : 'Licence active';
      case LicenseStatus.gracePeriod:
        final days = daysLeft ?? 0;
        return 'Délai de grâce (${days}j restant${days > 1 ? 's' : ''})';
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
    if (status == LicenseStatus.gracePeriod) {
      final dateStr = expiryDate != null
          ? '${expiryDate!.day.toString().padLeft(2, '0')}/${expiryDate!.month.toString().padLeft(2, '0')}/${expiryDate!.year}'
          : '';
      final days = daysLeft ?? 0;
      return 'Votre licence a expiré le $dateStr. Délai de grâce hors-ligne actif : encore $days jour${days > 1 ? 's' : ''} pour renouveler avant verrouillage de caisse.';
    }
    if (status == LicenseStatus.trial) {
      final dateStr = expiryDate != null
          ? '${expiryDate!.day.toString().padLeft(2, '0')}/${expiryDate!.month.toString().padLeft(2, '0')}/${expiryDate!.year}'
          : '';
      final dur = remainingDuration;
      String countStr = '';
      if (dur != null && dur > Duration.zero) {
        final d = dur.inDays;
        final h = dur.inHours % 24;
        final m = dur.inMinutes % 60;
        if (d > 0) {
          countStr = ' — ${d}j ${h}h restant${d > 1 || h > 1 ? 's' : ''}';
        } else if (h > 0) {
          countStr = ' — ${h}h ${m}m restante${h > 1 || m > 1 ? 's' : ''}';
        } else {
          countStr = ' — ${m}m restante${m > 1 ? 's' : ''}';
        }
      }
      return 'Période d\'essai gratuite (7 jours)$countStr • Expire le $dateStr';
    }
    if (status == LicenseStatus.expired) {
      return 'Période d\'essai ou licence expirée. Veuillez saisir votre clé de renouvellement.';
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
