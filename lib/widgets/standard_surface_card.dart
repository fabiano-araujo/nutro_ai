import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StandardSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double elevation;

  const StandardSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.onTap,
    this.backgroundColor,
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        backgroundColor ?? (isDarkMode ? AppTheme.darkCardColor : Colors.white);

    Widget content = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
        ),
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      );
    }

    final material = Material(
      color: cardColor,
      borderRadius: borderRadius,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: isDarkMode ? 0.28 : 0.1),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (margin == null) {
      return material;
    }

    return Padding(
      padding: margin!,
      child: material,
    );
  }
}
