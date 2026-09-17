import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Logo N'MaShop officiel mobile — réutilise exactement le logo Desktop.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 42,
    this.onDark = false,
    this.showCard = false,
  });

  final double height;
  final bool onDark;
  final bool showCard;

  @override
  Widget build(BuildContext context) {
    if (showCard) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: height * 0.45,
          vertical: height * 0.22,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height * 0.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/logo.png',
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _fallbackLogo(darkFallback: false),
        ),
      );
    }

    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => _fallbackLogo(darkFallback: onDark),
    );
  }

  Widget _fallbackLogo({required bool darkFallback}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(height * 0.18),
          decoration: BoxDecoration(
            color: AppColors.brandOrange,
            borderRadius: BorderRadius.circular(height * 0.25),
          ),
          child: Icon(
            Icons.shopping_bag_rounded,
            color: Colors.white,
            size: height * 0.65,
          ),
        ),
        SizedBox(width: height * 0.25),
        Text(
          'N\'MaShop',
          style: TextStyle(
            color: darkFallback ? Colors.white : AppColors.brandNavy,
            fontSize: height * 0.65,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
