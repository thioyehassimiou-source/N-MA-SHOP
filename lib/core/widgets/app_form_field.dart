import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Champ de formulaire premium pour N'MaShop.
///
/// Encapsule un label au-dessus, une icône prefix colorée, des coins arrondis,
/// et un style cohérent avec le design de référence.
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.icon,
    this.isRequired = false,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.initialValue,
    this.suffixIcon,
    this.iconColor,
    this.obscureText = false,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? icon;
  final bool isRequired;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? initialValue;
  final Widget? suffixIcon;
  final Color? iconColor;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label au-dessus du champ
        _FieldLabel(label: label, isRequired: isRequired),
        const SizedBox(height: 8),

        // Le champ
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          style: AppTypography.bodyMd.copyWith(
            color: context.colors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: iconColor ?? context.colors.primary)
                : null,
            suffixIcon: suffixIcon,
            alignLabelWithHint: maxLines > 1,
          ),
        ),
      ],
    );
  }
}

/// Champ de formulaire dropdown premium.
class AppFormDropdown<T> extends StatelessWidget {
  const AppFormDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.isRequired = false,
    this.hint,
    this.iconColor,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final IconData? icon;
  final bool isRequired;
  final String? hint;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(label: label, isRequired: isRequired),
        const SizedBox(height: 8),

        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.colors.onSurfaceVariant,
          ),
          style: AppTypography.bodyMd.copyWith(
            color: context.colors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: iconColor ?? context.colors.primary)
                : null,
          ),
        ),
      ],
    );
  }
}

/// Widget label réutilisable au-dessus des champs.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.isRequired});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: AppTypography.labelMd.copyWith(
          color: context.colors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        children: isRequired
            ? [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: context.colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Helper pour construire une rangée de 2 champs côte à côte.
class FormFieldRow extends StatelessWidget {
  const FormFieldRow({
    super.key,
    required this.left,
    required this.right,
    this.spacing = AppSpacing.md,
  });

  final Widget left;
  final Widget right;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: spacing),
        Expanded(child: right),
      ],
    );
  }
}
