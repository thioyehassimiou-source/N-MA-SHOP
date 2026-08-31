import '../../../core/database/tables/users.dart';

/// Utilisateur de l'application (Admin ou Vendeur).
///
/// Cette entité ne porte jamais le mot de passe ni son condensat : ceux-ci
/// restent cantonnés à la couche données.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.createdAt,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    this.avatarPath,
  });

  final String id;
  final String fullName;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final UserRole role;
  final bool isActive;
  final String? avatarPath;

  /// Initiales affichées dans l'avatar (« Mamadou Diallo » → « MD »).
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final first = parts.first;
      return (first.length >= 2 ? first.substring(0, 2) : first).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
