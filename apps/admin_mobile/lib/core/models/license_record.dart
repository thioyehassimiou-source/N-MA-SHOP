import 'dart:convert';

enum AdminLicenseType {
  lifetime,
  days30,
  days90,
  days365,
  annual,
  trial,
}

extension AdminLicenseTypeExt on AdminLicenseType {
  String get label {
    switch (this) {
      case AdminLicenseType.lifetime:
        return 'illimite';
      case AdminLicenseType.days30:
        return '30jours';
      case AdminLicenseType.days90:
        return '90jours';
      case AdminLicenseType.days365:
      case AdminLicenseType.annual:
        return '365jours';
      case AdminLicenseType.trial:
        return '14jours';
    }
  }
}

class LicenseRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String hardwareId;
  final String licenseKey;
  final AdminLicenseType type;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final double amountPaid;
  final bool isActive;

  LicenseRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.hardwareId,
    required this.licenseKey,
    required this.type,
    required this.createdAt,
    this.expiresAt,
    required this.amountPaid,
    this.isActive = true,
  });

  static const int offlineGracePeriodDays = 5;

  bool get isLifetime => type == AdminLicenseType.lifetime || (effectiveExpiresAt != null && effectiveExpiresAt!.year >= 9000);

  /// Date d'expiration effective (déduite de `expiresAt` ou extraite de la clé `YYYYMMDD`).
  DateTime? get effectiveExpiresAt {
    if (type == AdminLicenseType.lifetime) return null;
    if (expiresAt != null) return expiresAt;
    // Déduction automatique depuis le format NMAS-HWID-YYYYMMDD-HMAC ou NMAS-YYYYMMDD-HMAC
    final parts = licenseKey.trim().toUpperCase().split('-');
    String? dateStr;
    if (parts.length == 4 && parts[0] == 'NMAS') {
      dateStr = parts[2];
    } else if (parts.length == 3 && parts[0] == 'NMAS') {
      dateStr = parts[1];
    }
    if (dateStr != null && dateStr.length == 8) {
      try {
        final y = int.parse(dateStr.substring(0, 4));
        final m = int.parse(dateStr.substring(4, 6));
        final d = int.parse(dateStr.substring(6, 8));
        if (y >= 9000) return null; // Clé à vie
        return DateTime(y, m, d, 23, 59, 59);
      } catch (_) {}
    }
    return null;
  }

  /// Nombre de jours restants avant l'échéance contractuelle.
  int? get daysRemaining {
    final exp = effectiveExpiresAt;
    if (exp == null) return null;
    final now = DateTime.now();
    final end = DateTime(exp.year, exp.month, exp.day, 23, 59, 59);
    return end.difference(now).inDays + 1;
  }

  bool get isExpired {
    final exp = effectiveExpiresAt;
    if (isLifetime || exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  /// Détecte si le poste client est actuellement dans sa période de grâce hors-ligne (5 jours).
  bool get isInGracePeriod {
    final exp = effectiveExpiresAt;
    if (isLifetime || exp == null || type == AdminLicenseType.trial) return false;
    final now = DateTime.now();
    final graceEnd = DateTime(exp.year, exp.month, exp.day, 23, 59, 59)
        .add(const Duration(days: offlineGracePeriodDays));
    return now.isAfter(exp) && now.isBefore(graceEnd);
  }

  /// Nombre de jours de grâce hors-ligne restants pour le commerçant.
  int get graceDaysLeft {
    final exp = effectiveExpiresAt;
    if (!isInGracePeriod || exp == null) return 0;
    final graceEnd = DateTime(exp.year, exp.month, exp.day, 23, 59, 59)
        .add(const Duration(days: offlineGracePeriodDays));
    return graceEnd.difference(DateTime.now()).inDays + 1;
  }

  /// Détecte si le poste a dépassé la licence ET le délai de grâce (verrouillage strict).
  bool get isStrictlyExpired {
    final exp = effectiveExpiresAt;
    if (isLifetime || exp == null) return false;
    if (type == AdminLicenseType.trial) {
      return DateTime.now().isAfter(exp);
    }
    final graceEnd = DateTime(exp.year, exp.month, exp.day, 23, 59, 59)
        .add(const Duration(days: offlineGracePeriodDays));
    return DateTime.now().isAfter(graceEnd);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'hardwareId': hardwareId,
      'licenseKey': licenseKey,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'amountPaid': amountPaid,
      'isActive': isActive,
    };
  }

  factory LicenseRecord.fromMap(Map<String, dynamic> map) {
    return LicenseRecord(
      id: map['id'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      hardwareId: map['hardwareId'] ?? '',
      licenseKey: map['licenseKey'] ?? '',
      type: AdminLicenseType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AdminLicenseType.annual,
      ),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: map['expiresAt'] != null ? DateTime.parse(map['expiresAt']) : null,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      isActive: map['isActive'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory LicenseRecord.fromJson(String source) => LicenseRecord.fromMap(json.decode(source));

  LicenseRecord copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? hardwareId,
    String? licenseKey,
    AdminLicenseType? type,
    DateTime? createdAt,
    DateTime? expiresAt,
    double? amountPaid,
    bool? isActive,
  }) {
    return LicenseRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      hardwareId: hardwareId ?? this.hardwareId,
      licenseKey: licenseKey ?? this.licenseKey,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      amountPaid: amountPaid ?? this.amountPaid,
      isActive: isActive ?? this.isActive,
    );
  }
}
