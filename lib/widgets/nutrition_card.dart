import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../i18n/app_localizations_extension.dart';
import '../theme/app_theme.dart';

class NutritionCard extends StatelessWidget {
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbsConsumed;
  final int carbsGoal;
  final int fatsConsumed;
  final int fatsGoal;
  final VoidCallback? onTap;
  final VoidCallback? onEditGoals;
  final VoidCallback? onMinimize;

  const NutritionCard({
    Key? key,
    this.caloriesConsumed = 1200,
    this.caloriesGoal = 2000,
    this.proteinConsumed = 80,
    this.proteinGoal = 150,
    this.carbsConsumed = 120,
    this.carbsGoal = 300,
    this.fatsConsumed = 45,
    this.fatsGoal = 70,
    this.onTap,
    this.onEditGoals,
    this.onMinimize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final caloriesRemaining = caloriesGoal - caloriesConsumed;
    final isCaloriesExceeded = caloriesRemaining < 0;
    final displayCalories = isCaloriesExceeded ? -caloriesRemaining : caloriesRemaining;

    // Cores para quando excede a meta
    final exceededColor = Color(0xFFE57373); // Vermelho suave
    final exceededTextColor = Color(0xFFFF5252); // Vermelho mais vibrante

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 1.5,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Row(
                children: [
                  // Lado esquerdo - Calorias
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Gráfico circular de calorias
                        SizedBox(
                          width: 95,
                          height: 95,
                          child: CustomPaint(
                            painter: CalorieCirclePainter(
                              consumed: caloriesConsumed,
                              goal: caloriesGoal,
                              isDarkMode: isDarkMode,
                              isExceeded: isCaloriesExceeded,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (isCaloriesExceeded)
                                        Text(
                                          '+',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: exceededTextColor,
                                          ),
                                        ),
                                      Text(
                                        displayCalories.toString(),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isCaloriesExceeded
                                              ? exceededTextColor
                                              : (isDarkMode
                                                      ? AppTheme.darkTextColor
                                                      : AppTheme.textPrimaryColor)
                                                  .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    isCaloriesExceeded
                                        ? context.tr.translate('exceeded')
                                        : context.tr.translate('remaining'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isCaloriesExceeded
                                          ? exceededColor
                                          : (isDarkMode
                                              ? Color(0xFFAEB7CE)
                                              : AppTheme.textSecondaryColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 2),
                        // Total de calorias
                        Text(
                          '$caloriesConsumed / $caloriesGoal kcal',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCaloriesExceeded
                                ? exceededColor
                                : (isDarkMode
                                    ? Color(0xFFAEB7CE)
                                    : AppTheme.textSecondaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 16),

                  // Lado direito - Macros
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Protein
                        _MacroRow(
                          label: context.tr.translate('protein'),
                          consumed: proteinConsumed,
                          goal: proteinGoal,
                          unit: 'g',
                          color: Color(0xFF9575CD),
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: 6),

                        // Carbs
                        _MacroRow(
                          label: context.tr.translate('carbs'),
                          consumed: carbsConsumed,
                          goal: carbsGoal,
                          unit: 'g',
                          color: Color(0xFFFFB74D),
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: 6),

                        // Fats
                        _MacroRow(
                          label: context.tr.translate('fats'),
                          consumed: fatsConsumed,
                          goal: fatsGoal,
                          unit: 'g',
                          color: Color(0xFF4DB6AC),
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Chevron de minimizar na parte inferior
            if (onMinimize != null)
              GestureDetector(
                onTap: onMinimize,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: 4, top: 0),
                  child: Icon(
                    Icons.expand_less,
                    color: isDarkMode ? Colors.white38 : Colors.black26,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final int consumed;
  final int goal;
  final String unit;
  final Color color;
  final bool isDarkMode;

  const _MacroRow({
    Key? key,
    required this.label,
    required this.consumed,
    required this.goal,
    required this.unit,
    required this.color,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = consumed / goal;
    final isExceeded = progress > 1.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final exceededColor = Color(0xFFE57373); // Vermelho suave

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: (isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor).withValues(alpha: 0.85),
                  ),
                ),
                if (isExceeded) ...[
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_upward,
                    size: 12,
                    color: exceededColor,
                  ),
                ],
              ],
            ),
            Text(
              '$consumed / $goal$unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isExceeded ? FontWeight.w600 : FontWeight.normal,
                color: isExceeded
                    ? exceededColor
                    : (isDarkMode
                        ? Color(0xFFAEB7CE)
                        : AppTheme.textSecondaryColor).withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        SizedBox(height: 3),
        // Stack para mostrar overflow visual
        Stack(
          children: [
            // Barra de fundo
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF2F2F2F) : Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Barra de progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: FractionallySizedBox(
                widthFactor: clampedProgress,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: isExceeded
                        ? exceededColor.withValues(alpha: 0.7)
                        : color.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // Indicador de overflow (listras quando excede)
            if (isExceeded)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CustomPaint(
                    painter: _OverflowStripesPainter(
                      color: exceededColor,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Painter para desenhar listras diagonais indicando overflow
class _OverflowStripesPainter extends CustomPainter {
  final Color color;
  final bool isDarkMode;

  _OverflowStripesPainter({required this.color, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const spacing = 6.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CalorieCirclePainter extends CustomPainter {
  final int consumed;
  final int goal;
  final bool isDarkMode;
  final bool isExceeded;

  CalorieCirclePainter({
    required this.consumed,
    required this.goal,
    required this.isDarkMode,
    this.isExceeded = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final progress = (consumed / goal).clamp(0.0, 1.0);

    // Background circle (cinza claro)
    final bgPaint = Paint()
      ..color = isDarkMode ? Color(0xFF3A3A3A) : Color(0xFFF2F4F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc - vermelho se excedeu, rosa se normal
    final progressColor = isExceeded
        ? Color(0xFFE57373) // Vermelho suave quando excede
        : Color(0xFFFF6B9D); // Rosa normal

    final progressPaint = Paint()
      ..color = progressColor.withValues(alpha: isExceeded ? 0.7 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // Começar no topo
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CalorieCirclePainter oldDelegate) {
    return oldDelegate.consumed != consumed ||
        oldDelegate.goal != goal ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.isExceeded != isExceeded;
  }
}
