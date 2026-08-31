import 'package:flutter/material.dart';
import '../../features/auth/domain/app_user.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';

/// Widget universel d'avatar utilisateur pour N'MaShop.
///
/// Affiche la photo de profil si elle est définie et existe,
/// sinon affiche les initiales de l'utilisateur avec un style élégant.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 36,
    this.fontSize,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1.0,
    this.enableZoomOnTap = false,
  });

  final AppUser? user;
  final double size;
  final double? fontSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final bool enableZoomOnTap;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(size / 2);
    final effectiveBg = backgroundColor ?? context.colors.primaryContainer;
    final effectiveFg = foregroundColor ?? context.colors.primary;
    final effectiveFontSize = fontSize ?? (size * 0.4);

    final String? avatarPath = user?.avatarPath;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: AppImage(
          imagePath: avatarPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fallbackWidget: _buildInitialsFallback(effectiveFg, effectiveFontSize),
          enableZoomOnTap: enableZoomOnTap,
        ),
      ),
    );
  }

  Widget _buildInitialsFallback(Color fgColor, double fSize) {
    return Center(
      child: Text(
        user?.initials ?? '?',
        style: TextStyle(
          color: fgColor,
          fontWeight: FontWeight.bold,
          fontSize: fSize,
        ),
      ),
    );
  }
}
