import 'package:flutter/material.dart';

/// Widget reutilizável para mostrar cards de macronutrientes com gradiente
/// Usado em: personalized_diet_screen, food_page, e nutrition goals
class MacroCardGradient extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String unit;
  final Color startColor;
  final Color endColor;
  final bool isDarkMode;
  final bool isCompact;

  const MacroCardGradient({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.startColor,
    required this.endColor,
    required this.isDarkMode,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Se for compact (nutrition summary no topo), usa tamanhos maiores
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              startColor.withValues(alpha: isDarkMode ? 0.3 : 0.15),
              endColor.withValues(alpha: isDarkMode ? 0.2 : 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: startColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    // Para meal totals, usa o mesmo estilo do meal_card.dart
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor.withValues(alpha: isDarkMode ? 0.2 : 0.1),
            endColor.withValues(alpha: isDarkMode ? 0.12 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: startColor.withValues(alpha: isDarkMode ? 0.2 : 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.65),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
