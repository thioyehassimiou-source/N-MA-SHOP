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
  final bool showBottomBorder;
  final bool showShadow;

  const NmaMobileAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.customTitle,
    this.onLeadingPressed,
    this.leadingIcon = Icons.menu_rounded,
    this.actions,
    this.showBrandLogo = false,
    this.showBottomBorder = false,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B132B),
            Color(0xFF0F1B3D),
            Color(0xFF172854),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: showBottomBorder
            ? const Border(
                bottom: BorderSide(color: Color(0xFFE85D04), width: 2.5),
              )
            : null,
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
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
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      leadingIcon,
                      color: Colors.white,
                      size: 20,
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
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subtitle != null) ...[
                                      const SizedBox(height: 1),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: AppColors.brandEmerald,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              subtitle!,
                                              style: const TextStyle(
                                                color: Color(0xFFCBD5E1),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
                                fontWeight: FontWeight.w800,
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
                                  fontWeight: FontWeight.w500,
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

/// Bouton d'action d'en-tête ultra-professionnel glassmorphe.
class NmaMobileHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final int badgeCount;

  const NmaMobileHeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

