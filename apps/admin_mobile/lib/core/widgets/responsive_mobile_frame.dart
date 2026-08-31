import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Un wrapper réactif qui s'adapte automatiquement :
/// - Plein écran natif fluide sur smartphones Android / iOS.
/// - Cadre de démonstration responsive sur écrans d'ordinateurs (Desktop / Web).
class ResponsiveMobileFrame extends StatelessWidget {
  final Widget child;

  const ResponsiveMobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Si l'application tourne nativement sur Android ou iOS, on affiche TOUJOURS en plein écran.
    final isNativeMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Sur ordinateur (Desktop / Web) avec écran large (> 600px), afficher dans un conteneur mobile responsive
        if (!isNativeMobile && constraints.maxWidth > 600) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Center(
              child: Container(
                width: 440,
                height: constraints.maxHeight * 0.94,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.bgSlate,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppTheme.primaryIndigo.withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: child,
                ),
              ),
            ),
          );
        }

        // Sur smartphone Android réel / iOS ou petits écrans : Plein Écran Natif
        return child;
      },
    );
  }
}
