import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Widget de dialogue formulaire premium pour N'MaShop.
///
/// Fournit un layout cohérent avec :
/// - Header gradient avec icône, titre, sous-titre et bouton fermer
/// - Zone de contenu scrollable
/// - Boutons d'action en bas (Annuler + action principale gradient)
class AppFormDialog extends StatelessWidget {
  const AppFormDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    this.body,
    this.width = 500,
    this.height,
    this.primaryLabel = 'Enregistrer',
    this.primaryIcon = Icons.check_circle_outline,
    this.onPrimary,
    this.onCancel,
    this.isPrimaryLoading = false,
    this.sections,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Deux couleurs pour le gradient du header.
  final List<Color> gradientColors;

  /// Corps principal du dialogue (formulaire). Optionnel si [sections] est fourni.
  final Widget? body;

  /// Largeur du dialogue.
  final double width;

  /// Hauteur du dialogue (null = auto-size).
  final double? height;

  /// Label du bouton principal.
  final String primaryLabel;

  /// Icône du bouton principal.
  final IconData primaryIcon;

  /// Callback du bouton principal (null = désactivé).
  final VoidCallback? onPrimary;

  /// Callback du bouton Annuler (null = Navigator.pop).
  final VoidCallback? onCancel;

  /// Affiche un loader sur le bouton principal.
  final bool isPrimaryLoading;

  /// Sections de formulaire (alternative au body).
  final List<FormSection>? sections;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // ── Header Gradient ──────────────────────────────────
            _Header(
              title: title,
              subtitle: subtitle,
              icon: icon,
              gradientColors: gradientColors,
              onClose: onCancel ?? () => Navigator.of(context).pop(),
            ),

            // ── Contenu ──────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: sections != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: sections!
                            .map((s) => _SectionWidget(section: s))
                            .toList(),
                      )
                    : (body ?? const SizedBox.shrink()),
              ),
            ),

            // ── Boutons d'action ─────────────────────────────────
            _ActionBar(
              primaryLabel: primaryLabel,
              primaryIcon: primaryIcon,
              onPrimary: onPrimary,
              onCancel: onCancel ?? () => Navigator.of(context).pop(),
              isPrimaryLoading: isPrimaryLoading,
              gradientColors: gradientColors,
            ),
          ],
        ),
      ),
    );
  }
}

/// Représente une section de formulaire avec un titre et une icône.
class FormSection {
  const FormSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;
}

// ─────────────────────────── Header ───────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          // Icône circulaire
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),

          // Titre + sous-titre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.headlineMd.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySm.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Bouton fermer
          IconButton(
            onPressed: onClose,
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Section ──────────────────────────────────────────

class _SectionWidget extends StatelessWidget {
  const _SectionWidget({required this.section});

  final FormSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de section avec icône
          Row(
            children: [
              Icon(section.icon, size: 20, color: context.colors.primary),
              const SizedBox(width: 10),
              Text(
                section.title,
                style: AppTypography.labelMd.copyWith(
                  color: context.colors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Contenu de la section
          section.child,
        ],
      ),
    );
  }
}

// ─────────────────────────── Action Bar ───────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onCancel,
    required this.isPrimaryLoading,
    required this.gradientColors,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback onCancel;
  final bool isPrimaryLoading;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bouton Annuler (text simple)
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Bouton principal gradient
          _GradientButton(
            label: primaryLabel,
            icon: primaryIcon,
            onPressed: onPrimary,
            isLoading: isPrimaryLoading,
            gradientColors: gradientColors,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Gradient Button ─────────────────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isLoading,
    required this.gradientColors,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: onPressed != null && !isLoading
                  ? gradientColors
                  : [Colors.grey.shade400, Colors.grey.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: onPressed != null && !isLoading
                ? [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
