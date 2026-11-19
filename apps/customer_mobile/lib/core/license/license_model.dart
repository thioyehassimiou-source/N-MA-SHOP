enum LicenseStatus {
  trial,
  trialExpired,
  commercialActive,
  commercialGrace,
  commercialExpired,
}

enum LicenseType {
  trial,
  monthly,
  annual,
  lifetime,
}

class LicenseInfo {
  final LicenseStatus status;
  final LicenseType type;
  final DateTime? expiryDate;
  final int daysLeft;
  final String? key;
  final String deviceId;
  final DateTime installationDate;

  const LicenseInfo({
    required this.status,
    required this.type,
    this.expiryDate,
    required this.daysLeft,
    this.key,
    required this.deviceId,
    required this.installationDate,
  });

  bool get isPosUnlocked =>
      status == LicenseStatus.commercialActive ||
      status == LicenseStatus.commercialGrace ||
      (status == LicenseStatus.trial && daysLeft > 0);

  bool get isTrial => status == LicenseStatus.trial || status == LicenseStatus.trialExpired;
  bool get isCommercial => !isTrial;
  bool get isLifetime => type == LicenseType.lifetime;

  String get bannerText {
    if (status == LicenseStatus.trial) {
      return "Période d'essai gratuite : $daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}";
    } else if (status == LicenseStatus.trialExpired) {
      return "Période d'essai terminée (0 jour restant)";
    } else if (status == LicenseStatus.commercialActive) {
      if (isLifetime) {
        return "Licence Commerciale Active : Illimitée À Vie";
      }
      return "Licence Commerciale Active : $daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}";
    } else if (status == LicenseStatus.commercialGrace) {
      return "Délai de grâce commercial : $daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}";
    } else {
      return "Licence Commerciale Expirée";
    }
  }

  String get statusBadgeLabel {
    switch (status) {
      case LicenseStatus.trial:
        return 'Essai Gratuit ($daysLeft j)';
      case LicenseStatus.trialExpired:
        return 'Essai Expiré';
      case LicenseStatus.commercialActive:
        return isLifetime ? 'Licence À Vie' : 'Licence Active';
      case LicenseStatus.commercialGrace:
        return 'Grâce ($daysLeft j)';
      case LicenseStatus.commercialExpired:
        return 'Licence Expirée';
    }
  }
}
