import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MacroNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const MacroNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
