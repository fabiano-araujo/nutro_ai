import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';

/// Card compacto de macros que aparece quando o card principal esta escondido.
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
    final surfaceColor =
        isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final borderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final caloriesExceeded = caloriesConsumed > caloriesGoal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        elevation: AppTheme.standardCardElevation(isDarkMode),
        shadowColor: AppTheme.standardCardShadowColor(isDarkMode),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            height: 48,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: AppTheme.standardCardBorder(isDarkMode),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 350;
                final ringSize = compact ? 30.0 : 32.0;
                final caloriesBlockWidth = compact ? 64.0 : 70.0;
                final iconSize = compact ? 18.0 : 20.0;
                final macroGap = compact ? 4.0 : 6.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 8 : 10,
                    5,
                    onExpand == null ? (compact ? 8 : 10) : 4,
                    5,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: caloriesBlockWidth,
                        child: _MiniCaloriesBlock(
                          consumed: caloriesConsumed,
                          goal: caloriesGoal,
                          ringSize: ringSize,
                          isDarkMode: isDarkMode,
                          textColor: textColor,
                          mutedTextColor: mutedTextColor,
                          compact: compact,
                          isExceeded: caloriesExceeded,
                        ),
                      ),
                      SizedBox(width: compact ? 7 : 9),
                      Container(
                        width: 1,
                        height: 28,
                        decoration: BoxDecoration(
                          color: borderColor.withValues(
                            alpha: isDarkMode ? 0.8 : 0.9,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      SizedBox(width: compact ? 8 : 10),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _MiniMacroBlock(
                                value: proteinConsumed,
                                goal: proteinGoal,
                                color: MacroTheme.proteinColor,
                                icon: MacroTheme.proteinIcon,
                                iconSize: iconSize,
                                isDarkMode: isDarkMode,
                                textColor: textColor,
                                compact: compact,
                              ),
                            ),
                            SizedBox(width: macroGap),
                            Expanded(
                              child: _MiniMacroBlock(
                                value: carbsConsumed,
                                goal: carbsGoal,
                                color: MacroTheme.carbsColor,
                                icon: MacroTheme.carbsIcon,
                                iconSize: iconSize,
                                isDarkMode: isDarkMode,
                                textColor: textColor,
                                compact: compact,
                              ),
                            ),
                            SizedBox(width: macroGap),
                            Expanded(
                              child: _MiniMacroBlock(
                                value: fatsConsumed,
                                goal: fatsGoal,
                                color: MacroTheme.fatColor,
                                icon: MacroTheme.fatIcon,
                                iconSize: iconSize,
                                isDarkMode: isDarkMode,
                                textColor: textColor,
                                compact: compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onExpand != null) ...[
                        SizedBox(width: compact ? 2 : 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onExpand,
                          child: SizedBox(
                            width: 24,
                            height: 32,
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: 22,
                              color: mutedTextColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCaloriesBlock extends StatelessWidget {
  final int consumed;
  final int goal;
  final double ringSize;
  final bool isDarkMode;
  final Color textColor;
  final Color mutedTextColor;
  final bool compact;
  final bool isExceeded;

  const _MiniCaloriesBlock({
    Key? key,
    required this.consumed,
    required this.goal,
    required this.ringSize,
    required this.isDarkMode,
    required this.textColor,
    required this.mutedTextColor,
    required this.compact,
    required this.isExceeded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isExceeded ? AppTheme.errorColor : MacroTheme.caloriesColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: CustomPaint(
            painter: _MiniCalorieRingPainter(
              consumed: consumed,
              goal: goal,
              isDarkMode: isDarkMode,
              isExceeded: isExceeded,
            ),
            child: Center(
              child: Icon(
                MacroTheme.caloriesIcon,
                size: compact ? 12 : 13,
                color: accentColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$consumed',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 15 : 16,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: isExceeded ? AppTheme.errorColor : textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'kcal',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 8.5 : 9,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMacroBlock extends StatelessWidget {
  final int value;
  final int goal;
  final Color color;
  final IconData icon;
  final double iconSize;
  final bool isDarkMode;
  final Color textColor;
  final bool compact;

  const _MiniMacroBlock({
    Key? key,
    required this.value,
    required this.goal,
    required this.color,
    required this.icon,
    required this.iconSize,
    required this.isDarkMode,
    required this.textColor,
    required this.compact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? value / goal : 0.0;
    final isExceeded = progress > 1.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final accentColor = isExceeded ? AppTheme.errorColor : color;
    final trackColor =
        isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFF5F7FA);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MacroTheme.iconBadge(
                icon: icon,
                color: accentColor,
                isDarkMode: isDarkMode,
                size: iconSize,
                iconSize: iconSize * 0.56,
              ),
              const SizedBox(width: 4),
              Text(
                '${value}g',
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: isExceeded ? AppTheme.errorColor : textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              Container(height: 4, color: trackColor),
              FractionallySizedBox(
                widthFactor: clampedProgress,
                child: Container(
                  height: 4,
                  color: accentColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniCalorieRingPainter extends CustomPainter {
  final int consumed;
  final int goal;
  final bool isDarkMode;
  final bool isExceeded;

  const _MiniCalorieRingPainter({
    required this.consumed,
    required this.goal,
    required this.isDarkMode,
    required this.isExceeded,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3.5;
    final progress = (goal > 0 ? consumed / goal : 0.0).clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFF2F4F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = (isExceeded ? AppTheme.errorColor : MacroTheme.caloriesColor)
          .withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_MiniCalorieRingPainter oldDelegate) {
    return oldDelegate.consumed != consumed ||
        oldDelegate.goal != goal ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.isExceeded != isExceeded;
  }
}
