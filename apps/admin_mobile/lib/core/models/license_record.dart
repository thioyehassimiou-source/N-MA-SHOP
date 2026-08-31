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
        return '7jours';
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

  bool get isLifetime => type == AdminLicenseType.lifetime;
  bool get isExpired {
    if (isLifetime || expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
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
