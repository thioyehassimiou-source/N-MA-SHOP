import 'package:flutter/material.dart';

import 'package:nmashop/core/theme/app_theme.dart';

/// Écran placeholder pour les modules en cours de développement.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, this.icon = Icons.construction_rounded});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 40, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ce module est en cours de développement.',
              style: TextStyle(fontSize: 14, color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Il sera disponible très prochainement.',
              style: TextStyle(fontSize: 14, color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
    );
  }
}
