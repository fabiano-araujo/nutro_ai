import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaterTracker extends StatelessWidget {
  final int consumed;
  final int goal;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const WaterTracker({
    Key? key,
    required this.consumed,
    required this.goal,
    required this.onAdd,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final isComplete = consumed >= goal;

    return GestureDetector(
      onTap: onAdd,
      onLongPress: onRemove,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isComplete
                ? Color(0xFF4FC3F7).withValues(alpha: 0.5)
                : (isDarkMode ? Colors.white12 : Colors.black12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Water icon
            Icon(
              Icons.water_drop,
              size: 20,
              color: isComplete ? Color(0xFF4FC3F7) : Color(0xFF81D4FA),
            ),
            SizedBox(width: 8),
            // Progress info
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
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      '/$goal',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white54
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                    if (isComplete) ...[
                      SizedBox(width: 4),
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Color(0xFF4FC3F7),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                // Mini progress bar
                Container(
                  height: 4,
                  width: 50,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white12 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF4FC3F7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
