import 'dart:io';

import 'package:flutter/material.dart';

/// Widget universel d'affichage d'images pour N'MaShop.
/// Gère les chemins locaux (`/path/to/file`), les assets (`assets/images/...`),
/// les URLs réseau (`http://`, `https://`) ainsi qu'un fallback personnalisé.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_not_supported_outlined,
    this.fallbackColor,
    this.fallbackWidget,
    this.enableZoomOnTap = false,
  });

  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final Widget? fallbackWidget;
  final bool enableZoomOnTap;

  static bool isAssetPath(String path) {
    return path.startsWith('assets/');
  }

  static bool isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  static bool isLocalFile(String path) {
    if (isAssetPath(path) || isNetworkUrl(path)) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveFallbackColor = fallbackColor ?? theme.colorScheme.primary;

    Widget imageWidget = _buildContent(context, effectiveFallbackColor);

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    if (enableZoomOnTap && imagePath != null && imagePath!.isNotEmpty) {
      return InkWell(
        onTap: () => AppImageViewerDialog.show(context, imagePath: imagePath!),
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildContent(BuildContext context, Color color) {
    if (imagePath == null || imagePath!.trim().isEmpty) {
      return _buildFallback(context, color);
    }

    final path = imagePath!.trim();

    if (isAssetPath(path)) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(context, color),
      );
    }

    if (isNetworkUrl(path)) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildFallback(context, color),
      );
    }

    if (isLocalFile(path)) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(context, color),
      );
    }

    return _buildFallback(context, color);
  }

  Widget _buildFallback(BuildContext context, Color color) {
    if (fallbackWidget != null) return fallbackWidget!;

    final iconSize = (width != null && height != null)
        ? (width! < height! ? width! : height!) * 0.45
        : 24.0;

    return Container(
      width: width,
      height: height,
      color: color.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: color,
          size: iconSize > 0 ? iconSize : 20,
        ),
      ),
    );
  }
}

/// Fenêtre modale d'affichage d'une image en grand format avec zoom.
class AppImageViewerDialog extends StatelessWidget {
  const AppImageViewerDialog({
    super.key,
    required this.imagePath,
    this.title,
  });

  final String imagePath;
  final String? title;

  static Future<void> show(BuildContext context, {required String imagePath, String? title}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AppImageViewerDialog(imagePath: imagePath, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: AppImage(
                imagePath: imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Fermer',
            ),
          ),
        ],
      ),
    );
  }
}
