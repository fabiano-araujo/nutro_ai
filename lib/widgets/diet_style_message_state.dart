import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'state_animation.dart';

class DietStyleMessageState extends StatelessWidget {
  final String title;
  final String message;
  final IconData fallbackIcon;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final IconData primaryActionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final IconData secondaryActionIcon;
  final EdgeInsetsGeometry padding;
  final double topSpacing;
  final double illustrationSize;
  final Color? accentColor;
  final bool pinActionsToBottom;

  const DietStyleMessageState({
    super.key,
    required this.title,
    required this.message,
    required this.fallbackIcon,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.primaryActionIcon = Icons.auto_awesome_rounded,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionIcon = Icons.add_rounded,
    this.padding = const EdgeInsets.all(24),
    this.topSpacing = 40,
    this.illustrationSize = 180,
    this.accentColor,
    this.pinActionsToBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final buttonColor = accentColor ??
        (isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor);
    final buttonForegroundColor = AppTheme.onColor(buttonColor);
    final hasPrimaryAction =
        primaryActionLabel != null && onPrimaryAction != null;
    final hasSecondaryAction =
        secondaryActionLabel != null && onSecondaryAction != null;
    final hasActions = hasPrimaryAction || hasSecondaryAction;

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shouldPinActions =
              pinActionsToBottom && constraints.hasBoundedHeight && hasActions;
          final actionAreaHeight = hasSecondaryAction ? 140.0 : 88.0;
          final bottomInset = MediaQuery.of(context).viewPadding.bottom;
          final content = _buildContent(
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
            buttonColor: buttonColor,
          );
          final actions = _buildActions(
            buttonColor: buttonColor,
            buttonForegroundColor: buttonForegroundColor,
            hasPrimaryAction: hasPrimaryAction,
            hasSecondaryAction: hasSecondaryAction,
          );

          if (shouldPinActions) {
            final availableHeight =
                (constraints.maxHeight - actionAreaHeight - bottomInset)
                    .clamp(0.0, double.infinity)
                    .toDouble();

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: actionAreaHeight + 16 + bottomInset,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: availableHeight),
                      child: Center(child: content),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: actions,
                  ),
                ),
              ],
            );
          }

          if (!hasActions) {
            return Center(child: content);
          }

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                content,
                const SizedBox(height: 32),
                actions,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required Color textColor,
    required Color secondaryTextColor,
    required Color buttonColor,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topSpacing),
          StateAnimation(
            fallbackIcon: fallbackIcon,
            size: illustrationSize,
            accentColor: buttonColor,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions({
    required Color buttonColor,
    required Color buttonForegroundColor,
    required bool hasPrimaryAction,
    required bool hasSecondaryAction,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPrimaryAction)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPrimaryAction,
                icon: Icon(primaryActionIcon, color: buttonForegroundColor),
                label: Text(
                  primaryActionLabel!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: buttonForegroundColor,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: buttonForegroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (hasSecondaryAction) ...[
            if (hasPrimaryAction) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSecondaryAction,
                icon: Icon(secondaryActionIcon, color: buttonColor),
                label: Text(
                  secondaryActionLabel!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: buttonColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: buttonColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
