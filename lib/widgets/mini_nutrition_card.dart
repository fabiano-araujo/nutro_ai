import 'package:flutter/material.dart';
import '../i18n/app_localizations_extension.dart';
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
  final VoidCallback? onExpand;

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
    this.onExpand,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final caloriesExceeded = caloriesConsumed > caloriesGoal;
    final proteinExceeded = proteinConsumed > proteinGoal;
    final carbsExceeded = carbsConsumed > carbsGoal;
    final fatsExceeded = fatsConsumed > fatsGoal;
    final borderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
    final iconColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
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
                    label: _macroInitial(context.tr.translate('protein')),
                    color: MacroTheme.proteinColor,
                    isDarkMode: isDarkMode,
                    isExceeded: proteinExceeded,
                  ),
                  _buildCompactMacro(
                    value: carbsConsumed,
                    label: _macroInitial(context.tr.translate('carbs')),
                    color: MacroTheme.carbsColor,
                    isDarkMode: isDarkMode,
                    isExceeded: carbsExceeded,
                  ),
                  _buildCompactMacro(
                    value: fatsConsumed,
                    label: _macroInitial(context.tr.translate('fats')),
                    color: MacroTheme.fatColor,
                    isDarkMode: isDarkMode,
                    isExceeded: fatsExceeded,
                  ),
                ],
              ),
            ),
            if (onExpand != null) ...[
              SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onExpand,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _macroInitial(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.substring(0, 1).toUpperCase();
  }

  Widget _buildCaloriesMacro({
    required int consumed,
    required int goal,
    required bool isDarkMode,
    required bool isExceeded,
  }) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
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
                    height: 1.0,
                    fontWeight: FontWeight.bold,
                    color: isExceeded ? exceededColor : textColor,
                  ),
                ),
                Text(
                  '/$goal',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.0,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (isExceeded) ...[
                  SizedBox(width: 2),
                  Icon(Icons.warning_amber_rounded,
                      size: 12, color: exceededColor),
                ],
              ],
            ),
            Text(
              'kcal',
              style: TextStyle(
                fontSize: 10,
                height: 1.0,
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
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
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
            height: 1.0,
            fontWeight: FontWeight.w600,
            color: isExceeded ? exceededColor : textColor,
          ),
        ),
        SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 1.0,
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
