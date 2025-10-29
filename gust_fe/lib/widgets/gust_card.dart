import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// GustCard - Reusable card component with consistent styling
class GustCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double? borderRadius;

  const GustCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.gradient,
    this.onTap,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? AppTheme.cardWhite) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMedium),
        boxShadow: elevation != null
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: elevation! * 2,
                  offset: Offset(0, elevation!),
                ),
              ]
            : AppTheme.shadowLevel2,
      ),
      margin: margin ?? EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      padding: padding ?? EdgeInsets.all(AppTheme.spaceMD),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMedium),
        child: card,
      );
    }

    return card;
  }
}
