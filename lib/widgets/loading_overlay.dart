import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Color? backgroundColor;
  final Color? progressColor;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    this.backgroundColor,
    this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultBackgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.backgroundColor;

    return Positioned.fill(
      child: Container(
        color: backgroundColor ?? defaultBackgroundColor,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              progressColor ?? AppTheme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
