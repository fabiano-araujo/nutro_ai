import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card compacto de macros que aparece quando o card principal está escondido
class MiniNutritionCard extends StatefulWidget {
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
  State<MiniNutritionCard> createState() => _MiniNutritionCardState();
}

class _MiniNutritionCardState extends State<MiniNutritionCard>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _resetController;
  Animation<double>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-100.0, 100.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldExpand = _dragOffset.abs() > 50 || velocity.abs() > 200;

    if (shouldExpand && widget.onTap != null) {
      widget.onTap!();
      setState(() => _dragOffset = 0);
    } else {
      _resetAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
      )..addListener(() {
          setState(() => _dragOffset = _resetAnimation!.value);
        });
      _resetController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final caloriesExceeded = widget.caloriesConsumed > widget.caloriesGoal;
    final proteinExceeded = widget.proteinConsumed > widget.proteinGoal;
    final carbsExceeded = widget.carbsConsumed > widget.carbsGoal;
    final fatsExceeded = widget.fatsConsumed > widget.fatsGoal;

    final dragOpacity = (1.0 - (_dragOffset.abs() / 150)).clamp(0.5, 1.0);

    return GestureDetector(
      onTap: widget.onTap,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Opacity(
          opacity: dragOpacity,
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
                // Calorias (destaque)
                _buildCaloriesMacro(
                  consumed: widget.caloriesConsumed,
                  goal: widget.caloriesGoal,
                  isDarkMode: isDarkMode,
                  isExceeded: caloriesExceeded,
                ),
                SizedBox(width: 8),
                // Separador vertical
                Container(
                  width: 1,
                  height: 24,
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                ),
                SizedBox(width: 8),
                // Macros em linha compacta
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCompactMacro(
                        value: widget.proteinConsumed,
                        label: 'P',
                        color: Color(0xFF9575CD),
                        isDarkMode: isDarkMode,
                        isExceeded: proteinExceeded,
                      ),
                      _buildCompactMacro(
                        value: widget.carbsConsumed,
                        label: 'C',
                        color: Color(0xFFFFB74D),
                        isDarkMode: isDarkMode,
                        isExceeded: carbsExceeded,
                      ),
                      _buildCompactMacro(
                        value: widget.fatsConsumed,
                        label: 'G',
                        color: Color(0xFF4DB6AC),
                        isDarkMode: isDarkMode,
                        isExceeded: fatsExceeded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final color = Color(0xFFFF6B9D);

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
