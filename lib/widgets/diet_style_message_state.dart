import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';

class DietStyleMessageState extends StatelessWidget {
  final String title;
  final String message;
  final IconData fallbackIcon;
  final String animationUrl;
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

  const DietStyleMessageState({
    super.key,
    required this.title,
    required this.message,
    required this.fallbackIcon,
    this.animationUrl =
        'https://assets9.lottiefiles.com/packages/lf20_tljjahng.json',
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

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topSpacing),
              Lottie.network(
                animationUrl,
                width: illustrationSize,
                height: illustrationSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: illustrationSize,
                    height: illustrationSize,
                    decoration: BoxDecoration(
                      color: buttonColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      fallbackIcon,
                      size: illustrationSize * 0.4,
                      color: buttonColor.withValues(alpha: 0.55),
                    ),
                  );
                },
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
              if (primaryActionLabel != null && onPrimaryAction != null) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPrimaryAction,
                    icon: Icon(primaryActionIcon, color: Colors.white),
                    label: Text(
                      primaryActionLabel!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}
