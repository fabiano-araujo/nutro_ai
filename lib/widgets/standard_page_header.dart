import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StandardPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final String? actionTooltip;

  const StandardPageHeader({
    super.key,
    required this.title,
    this.onOpenDrawer,
    this.onActionPressed,
    this.actionIcon,
    this.actionTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 56,
      color:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (onOpenDrawer != null)
            IconButton(
              icon: Icon(
                Icons.menu,
                color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              ),
              onPressed: onOpenDrawer,
              tooltip: 'Menu',
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                ),
              ),
            ),
          ),
          if (onActionPressed != null && actionIcon != null)
            IconButton(
              icon: Icon(
                actionIcon,
                color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              ),
              onPressed: onActionPressed,
              tooltip: actionTooltip,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
