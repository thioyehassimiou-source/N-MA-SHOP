import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bouton d'action standardisé N'MaShop Mobile.
///
/// Variantes :
/// - [NmaButtonVariant.primary] : Orange officiel (#E85D04), texte blanc
/// - [NmaButtonVariant.navy] : Bleu marine N'MaShop (#0F1B3D), texte blanc
/// - [NmaButtonVariant.outlined] : Fond transparent, bordure #E2E8F0, texte Navy
class NmaMobileButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NmaButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final double height;

  const NmaMobileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = NmaButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case NmaButtonVariant.primary:
        bg = AppColors.brandOrange;
        fg = Colors.white;
        break;
      case NmaButtonVariant.navy:
        bg = AppColors.brandNavy;
        fg = Colors.white;
        break;
      case NmaButtonVariant.outlined:
        bg = Colors.white;
        fg = AppColors.brandNavy;
        border = const BorderSide(color: AppColors.outline, width: 1);
        break;
    }

    Widget child = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    return SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: child,
      ),
    );
  }
}

enum NmaButtonVariant {
  primary,
  navy,
  outlined,
}
