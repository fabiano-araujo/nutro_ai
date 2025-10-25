import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../i18n/app_localizations_extension.dart';

class NutritionCard extends StatelessWidget {
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbsConsumed;
  final int carbsGoal;
  final int fatsConsumed;
  final int fatsGoal;

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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final caloriesRemaining = caloriesGoal - caloriesConsumed;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? Color(0xFF2C2C2C) : Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 10, 8, 8),
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
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              caloriesRemaining.toString(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              context.tr.translate('remaining'),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDarkMode
                                    ? Colors.white60
                                    : Colors.black54,
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
                      color: isDarkMode ? Colors.white70 : Colors.black54,
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
                    color: Color(0xFF5B7FDB),
                    isDarkMode: isDarkMode,
                  ),
                  SizedBox(height: 6),

                  // Carbs
                  _MacroRow(
                    label: context.tr.translate('carbs'),
                    consumed: carbsConsumed,
                    goal: carbsGoal,
                    unit: 'g',
                    color: Color(0xFFE6A23C),
                    isDarkMode: isDarkMode,
                  ),
                  SizedBox(height: 6),

                  // Fats
                  _MacroRow(
                    label: context.tr.translate('fats'),
                    consumed: fatsConsumed,
                    goal: fatsGoal,
                    unit: 'g',
                    color: Color(0xFF9B59B6),
                    isDarkMode: isDarkMode,
                  ),
                ],
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
    final progress = (consumed / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.87)
                    : Colors.black87,
              ),
            ),
            Text(
              '$consumed / $goal$unit',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

class CalorieCirclePainter extends CustomPainter {
  final int consumed;
  final int goal;
  final bool isDarkMode;

  CalorieCirclePainter({
    required this.consumed,
    required this.goal,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final progress = (consumed / goal).clamp(0.0, 1.0);

    // Background circle (cinza claro)
    final bgPaint = Paint()
      ..color = isDarkMode ? Colors.grey[800]! : Color(0xFFE8E8E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc (verde)
    final progressPaint = Paint()
      ..color = Color(0xFF66BB6A)
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
        oldDelegate.isDarkMode != isDarkMode;
  }
}
