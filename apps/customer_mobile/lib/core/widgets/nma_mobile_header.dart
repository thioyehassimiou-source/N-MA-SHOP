import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'brand_logo.dart';

/// Header officiel ultra-professionnel N'MaShop Mobile.
///
/// Intègre le dégradé Navy Officiel, le logo N'MaShop, le bouton menu hamburger
/// à la forme arrondie glassmorphe, et les boutons d'action d'icône épurés.
class NmaMobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final Widget? customTitle;
  final VoidCallback? onLeadingPressed;
  final IconData leadingIcon;
  final List<Widget>? actions;
  final bool showBrandLogo;

  const NmaMobileAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.customTitle,
    this.onLeadingPressed,
    this.leadingIcon = Icons.menu_rounded,
    this.actions,
    this.showBrandLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 6,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.heroNavyGradient,
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2B52), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            // Bouton de gauche (Menu / Retour)
            if (onLeadingPressed != null) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onLeadingPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      leadingIcon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Zone Centrale : Logo N'MaShop ou Titre Officiel
            Expanded(
              child: customTitle ??
                  (showBrandLogo
                      ? Row(
                          children: [
                            const BrandLogo(onDark: true, height: 26),
                            if (title != null) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subtitle != null)
                                      Text(
                                        subtitle!,
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title ?? 'N\'MaShop',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        )),
            ),

            // Actions à droite (Notifications, Refresh, Panier, etc.)
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(68);
}

