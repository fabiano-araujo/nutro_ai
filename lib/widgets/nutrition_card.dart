import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../i18n/app_localizations_extension.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';

class NutritionCard extends StatefulWidget {
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
  final bool hasConfiguredGoals;

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
    this.hasConfiguredGoals = true,
  }) : super(key: key);

  @override
  State<NutritionCard> createState() => _NutritionCardState();
}

class _NutritionCardState extends State<NutritionCard> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isCaloriesExceeded = widget.caloriesConsumed > widget.caloriesGoal;
    final borderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;

    // Cores para quando excede a meta
    final exceededColor = Color(0xFFE57373);

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: borderColor,
          ),
        ),
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              // Lado esquerdo - Calorias
              Expanded(
                flex: 2,
                child: Column(
                      children: [
                        // Gráfico circular de calorias - simplificado
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CustomPaint(
                            painter: CalorieCirclePainter(
                              consumed: widget.caloriesConsumed,
                              goal: widget.caloriesGoal,
                              isDarkMode: isDarkMode,
                              isExceeded: isCaloriesExceeded,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${widget.caloriesConsumed}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: isCaloriesExceeded
                                          ? exceededColor
                                          : (isDarkMode
                                              ? AppTheme.darkTextColor
                                              : AppTheme.textPrimaryColor),
                                    ),
                                  ),
                                  Text(
                                    'kcal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDarkMode
                                          ? Color(0xFFAEB7CE)
                                          : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Meta de calorias (sempre visível) + botão alterar
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'de ${widget.caloriesGoal}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isCaloriesExceeded
                                    ? exceededColor
                                    : (isDarkMode
                                        ? Color(0xFFAEB7CE)
                                        : AppTheme.textSecondaryColor),
                              ),
                            ),
                            if (!widget.hasConfiguredGoals &&
                                widget.onEditGoals != null) ...[
                              SizedBox(width: 6),
                              InkWell(
                                onTap: widget.onEditGoals,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 2, vertical: 2),
                                  child: Text(
                                    'alterar meta',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                      color: isDarkMode
                                          ? Color(0xFFAEB7CE)
                                          : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                          consumed: widget.proteinConsumed,
                          goal: widget.proteinGoal,
                          unit: 'g',
                          color: MacroTheme.proteinColor,
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: 3),
                        _MacroRow(
                          label: context.tr.translate('carbs'),
                          consumed: widget.carbsConsumed,
                          goal: widget.carbsGoal,
                          unit: 'g',
                          color: MacroTheme.carbsColor,
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: 3),
                        _MacroRow(
                          label: context.tr.translate('fats'),
                          consumed: widget.fatsConsumed,
                          goal: widget.fatsGoal,
                          unit: 'g',
                          color: MacroTheme.fatColor,
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
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
    final exceededColor = Color(0xFFE57373);

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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor,
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
              '$consumed/$goal$unit',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isExceeded ? FontWeight.w600 : FontWeight.w500,
                color: isExceeded
                    ? exceededColor
                    : (isDarkMode
                        ? Colors.white70
                        : AppTheme.textSecondaryColor),
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        // Stack para mostrar overflow visual
        Stack(
          children: [
            // Barra de fundo
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF2F2F2F) : Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Barra de progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: FractionallySizedBox(
                widthFactor: clampedProgress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isExceeded
                        ? exceededColor.withValues(alpha: 0.7)
                        : color.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // Indicador de overflow (listras quando excede)
            if (isExceeded)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
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
    final radius = math.min(size.width, size.height) / 2 - 5;
    final progress = (consumed / goal).clamp(0.0, 1.0);

    // Background circle (cinza claro)
    final bgPaint = Paint()
      ..color = isDarkMode ? Color(0xFF3A3A3A) : Color(0xFFF2F4F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc - vermelho se excedeu, rosa se normal
    final progressColor = isExceeded
        ? Color(0xFFE57373)
        : MacroTheme.caloriesColor;

    final progressPaint = Paint()
      ..color = progressColor.withValues(alpha: isExceeded ? 0.7 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
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
