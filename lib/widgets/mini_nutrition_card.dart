import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    final caloriesRemaining = caloriesGoal - caloriesConsumed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            // Calorias restantes (destaque)
            _buildMiniMacro(
              value: caloriesRemaining.toString(),
              label: 'kcal',
              color: Color(0xFFFF6B9D),
              isDarkMode: isDarkMode,
              isHighlighted: true,
            ),
            SizedBox(width: 16),
            // Separador vertical
            Container(
              width: 1,
              height: 24,
              color: isDarkMode ? Colors.white24 : Colors.black12,
            ),
            SizedBox(width: 16),
            // Proteína
            _buildMiniMacro(
              value: '${proteinConsumed}g',
              label: 'P',
              color: Color(0xFF9575CD),
              isDarkMode: isDarkMode,
            ),
            SizedBox(width: 12),
            // Carboidratos
            _buildMiniMacro(
              value: '${carbsConsumed}g',
              label: 'C',
              color: Color(0xFFFFB74D),
              isDarkMode: isDarkMode,
            ),
            SizedBox(width: 12),
            // Gorduras
            _buildMiniMacro(
              value: '${fatsConsumed}g',
              label: 'G',
              color: Color(0xFF4DB6AC),
              isDarkMode: isDarkMode,
            ),
            Spacer(),
            // Ícone de expandir
            Icon(
              Icons.keyboard_arrow_down,
              color: isDarkMode ? Colors.white54 : Colors.black38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMacro({
    required String value,
    required String label,
    required Color color,
    required bool isDarkMode,
    bool isHighlighted = false,
  }) {
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isHighlighted ? 16 : 13,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                color: textColor.withValues(alpha: 0.9),
              ),
            ),
            if (isHighlighted)
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
          ],
        ),
        if (!isHighlighted)
          Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ),
      ],
    );
  }
}
