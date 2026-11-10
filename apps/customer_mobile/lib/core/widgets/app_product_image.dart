import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget d'affichage universel d'image produit, logo ou avatar.
///
/// Compatible 100% avec le Web (Chrome), Android, iOS et Linux :
/// - Base64 Data URI (`data:image/jpeg;base64,...`)
/// - Fichier local natif (`/path/to/img.jpg`)
/// - URL réseau (`http://...` ou `https://...`)
/// - Chaîne Base64 brute
/// - Fallback stylisé avec icône si aucune image n'est définie.
class AppProductImage extends StatelessWidget {
  final String? imageSource;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final Color? fallbackBgColor;

  const AppProductImage({
    super.key,
    required this.imageSource,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.inventory_2_rounded,
    this.fallbackColor,
    this.fallbackBgColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget? imageWidget;

    if (imageSource != null && imageSource!.trim().isNotEmpty) {
      final src = imageSource!.trim();

      // 1. Data URI Base64 (ex: data:image/jpeg;base64,/9j/4AAQSkZJRg...)
      if (src.startsWith('data:image')) {
        try {
          final commaIndex = src.indexOf(',');
          if (commaIndex != -1) {
            final base64Data = src.substring(commaIndex + 1).trim();
            final bytes = base64Decode(base64Data);
            imageWidget = Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, _, _) => _buildFallback(),
            );
          }
        } catch (_) {}
      }
      // 2. URL HTTP/HTTPS
      else if (src.startsWith('http://') || src.startsWith('https://')) {
        imageWidget = Image.network(
          src,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => _buildFallback(),
        );
      }
      // 3. Fichier local sur disque (uniquement sur plateforme native)
      else if (!kIsWeb) {
        try {
          final file = File(src);
          if (file.existsSync()) {
            imageWidget = Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, _, _) => _buildFallback(),
            );
          }
        } catch (_) {}
      }

      // 4. Si toujours nul et que la chaîne semble être du Base64 brut (sans en-tête data:)
      if (imageWidget == null && src.length > 50 && !src.startsWith('/')) {
        try {
          final bytes = base64Decode(src);
          imageWidget = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => _buildFallback(),
          );
        } catch (_) {}
      }
    }

    if (imageWidget != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: imageWidget,
        ),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackBgColor ?? AppColors.brandNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.brandNavy.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: width * 0.46,
          color: fallbackColor ?? AppColors.brandNavy,
        ),
      ),
    );
  }
}
