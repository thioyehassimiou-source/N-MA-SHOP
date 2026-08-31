import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_image.dart';

/// Vignette produit réutilisable.
/// Affiche l'image locale, asset ou réseau si elle existe, sinon une icône de fallback.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.borderRadius = 8,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.fallbackColor,
    this.enableZoomOnTap = false,
  });

  final String? imageUrl;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final bool enableZoomOnTap;

  @override
  Widget build(BuildContext context) {
    return AppImage(
      imagePath: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(borderRadius),
      fallbackIcon: fallbackIcon,
      fallbackColor: fallbackColor ?? AppColors.primary,
      enableZoomOnTap: enableZoomOnTap,
    );
  }
}
