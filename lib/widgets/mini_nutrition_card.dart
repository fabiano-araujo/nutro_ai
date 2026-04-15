import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';

/// Card compacto de macros que aparece quando o card principal está escondido
class MiniNutritionCard extends StatelessWidget {
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbsConsumed;
  final int carbsGoal;
  final int fatsConsumed;
  final int fatsGoal;
  final VoidCallback? onTap;

  const MiniNutritionCard({
    Key? key,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbsConsumed,
    required this.carbsGoal,
    required this.fatsConsumed,
    required this.fatsGoal,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final caloriesExceeded = caloriesConsumed > caloriesGoal;
    final proteinExceeded = proteinConsumed > proteinGoal;
    final carbsExceeded = carbsConsumed > carbsGoal;
    final fatsExceeded = fatsConsumed > fatsGoal;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildCaloriesMacro(
              consumed: caloriesConsumed,
              goal: caloriesGoal,
              isDarkMode: isDarkMode,
              isExceeded: caloriesExceeded,
            ),
            SizedBox(width: 8),
            Container(
              width: 1,
              height: 24,
              color: isDarkMode ? Colors.white24 : Colors.black12,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactMacro(
                    value: proteinConsumed,
                    label: 'P',
                    color: MacroTheme.proteinColor,
                    isDarkMode: isDarkMode,
                    isExceeded: proteinExceeded,
                  ),
                  _buildCompactMacro(
                    value: carbsConsumed,
                    label: 'C',
                    color: MacroTheme.carbsColor,
                    isDarkMode: isDarkMode,
                    isExceeded: carbsExceeded,
                  ),
                  _buildCompactMacro(
                    value: fatsConsumed,
                    label: 'G',
                    color: MacroTheme.fatColor,
                    isDarkMode: isDarkMode,
                    isExceeded: fatsExceeded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesMacro({
    required int consumed,
    required int goal,
    required bool isDarkMode,
    required bool isExceeded,
  }) {
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final exceededColor = Color(0xFFE57373);
    final color = MacroTheme.caloriesColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: (isExceeded ? exceededColor : color).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$consumed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isExceeded ? exceededColor : textColor,
                  ),
                ),
                Text(
                  '/$goal',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (isExceeded) ...[
                  SizedBox(width: 2),
                  Icon(Icons.warning_amber_rounded, size: 12, color: exceededColor),
                ],
              ],
            ),
            Text(
              'kcal',
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactMacro({
    required int value,
    required String label,
    required Color color,
    required bool isDarkMode,
    required bool isExceeded,
  }) {
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final exceededColor = Color(0xFFE57373);
    final displayColor = isExceeded ? exceededColor : color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: displayColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4),
        Text(
          '${value}g',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isExceeded ? exceededColor : textColor,
          ),
        ),
        SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: displayColor,
          ),
        ),
        if (isExceeded) ...[
          SizedBox(width: 2),
          Icon(Icons.warning_amber_rounded, size: 10, color: exceededColor),
        ],
      ],
    );
  }
}
