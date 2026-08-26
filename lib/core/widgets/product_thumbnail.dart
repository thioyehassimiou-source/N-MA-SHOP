import 'dart:io';

import 'package:flutter/material.dart';

/// Vignette produit réutilisable.
/// Affiche l'image locale si elle existe, sinon une icône de fallback.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.borderRadius = 8,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.fallbackColor = const Color(0xFF6366F1),
  });

  final String? imageUrl;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty && File(imageUrl!).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.file(
                File(imageUrl!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: fallbackColor.withValues(alpha: 0.1),
      child: Icon(fallbackIcon, color: fallbackColor, size: size * 0.45),
    );
  }
}
