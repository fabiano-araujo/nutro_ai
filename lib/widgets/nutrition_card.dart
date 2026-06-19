import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  final bool profileStyle;

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
    this.profileStyle = false,
  }) : super(key: key);

  @override
  State<NutritionCard> createState() => _NutritionCardState();
}

class _NutritionCardState extends State<NutritionCard> {
  static const double _headerSlotHeight = 108;
  static const double _outerVerticalPadding = 2;

  double _calorieValueFontSize(String value, bool compact) {
    final digitCount = value.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitCount <= 3) return compact ? 18.5 : 20.0;
    if (digitCount == 4) return compact ? 16.5 : 18.0;
    if (digitCount == 5) return compact ? 14.5 : 15.5;
    return compact ? 13.0 : 14.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isCaloriesExceeded = widget.caloriesConsumed > widget.caloriesGoal;
    final surfaceColor =
        isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final borderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    const exceededColor = Color(0xFFE57373);
    final radius = widget.profileStyle ? 24.0 : 16.0;
    final borderRadius = BorderRadius.circular(radius);
    final cardContent = Material(
      color: widget.profileStyle ? Colors.transparent : surfaceColor,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      elevation:
          widget.profileStyle ? 0 : AppTheme.standardCardElevation(isDarkMode),
      shadowColor: widget.profileStyle
          ? Colors.transparent
          : AppTheme.standardCardShadowColor(isDarkMode),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: borderRadius,
        child: Ink(
          height: _headerSlotHeight - (_outerVerticalPadding * 2),
          decoration: BoxDecoration(
            color: widget.profileStyle ? Colors.transparent : surfaceColor,
            borderRadius: borderRadius,
            border: widget.profileStyle
                ? null
                : AppTheme.standardCardBorder(isDarkMode),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  8,
                  widget.onMinimize != null ? 32 : 8,
                  8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 305;
                    final showsEditGoal = !widget.hasConfiguredGoals &&
                        widget.onEditGoals != null;
                    final circleSize = showsEditGoal
                        ? (compact ? 54.0 : 60.0)
                        : (compact ? 58.0 : 64.0);
                    final caloriesText = '${widget.caloriesConsumed}';
                    final caloriesTextWidth =
                        circleSize - (compact ? 19.0 : 22.0);
                    final caloriesTextFontSize =
                        _calorieValueFontSize(caloriesText, compact);
                    final caloriesBlockWidth = compact ? 88.0 : 96.0;
                    final iconSize = compact ? 23.0 : 24.0;
                    final macroGap = compact ? 5.0 : 4.0;
                    final dividerGap = 8.0;
                    final dividerHeight = compact ? 70.0 : 74.0;

                    return Row(
                      children: [
                        SizedBox(
                          width: caloriesBlockWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: circleSize,
                                height: circleSize,
                                child: CustomPaint(
                                  painter: CalorieCirclePainter(
                                    consumed: widget.caloriesConsumed,
                                    goal: widget.caloriesGoal,
                                    isDarkMode: isDarkMode,
                                    isExceeded: isCaloriesExceeded,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: caloriesTextWidth,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              caloriesText,
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: caloriesTextFontSize,
                                                fontWeight: FontWeight.bold,
                                                color: isCaloriesExceeded
                                                    ? exceededColor
                                                    : textColor,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'kcal',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: mutedTextColor,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'de ${widget.caloriesGoal} kcal',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: compact ? 11 : 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: isCaloriesExceeded
                                        ? exceededColor
                                        : mutedTextColor,
                                  ),
                                ),
                              ),
                              if (showsEditGoal)
                                InkWell(
                                  onTap: widget.onEditGoals,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 1,
                                    ),
                                    child: Text(
                                      'alterar meta',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                        color: mutedTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: dividerGap),
                        Container(
                          width: 1,
                          height: dividerHeight,
                          decoration: BoxDecoration(
                            color: borderColor.withValues(
                              alpha: isDarkMode ? 0.78 : 0.9,
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        SizedBox(width: dividerGap),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _MacroRow(
                                label: context.tr.translate('protein'),
                                consumed: widget.proteinConsumed,
                                goal: widget.proteinGoal,
                                unit: 'g',
                                color: MacroTheme.proteinColor,
                                icon: MacroTheme.proteinIcon,
                                iconSize: iconSize,
                                isDarkMode: isDarkMode,
                                compact: compact,
                              ),
                              SizedBox(height: macroGap),
                              _MacroRow(
                                label: context.tr.translate('carbs'),
                                consumed: widget.carbsConsumed,
                                goal: widget.carbsGoal,
                                unit: 'g',
                                color: MacroTheme.carbsColor,
                                icon: MacroTheme.carbsIcon,
                                iconSize: iconSize,
                                isDarkMode: isDarkMode,
                                compact: compact,
                              ),
                              SizedBox(height: macroGap),
                              _MacroRow(
                                label: context.tr.translate('fats'),
                                consumed: widget.fatsConsumed,
                                goal: widget.fatsGoal,
                                unit: 'g',
                                color: MacroTheme.fatColor,
                                icon: MacroTheme.fatIcon,
                                iconSize: iconSize,
                                isDarkMode: isDarkMode,
                                compact: compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (widget.onMinimize != null)
                Positioned(
                  top: 2,
                  right: 4,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tight(const Size(28, 28)),
                      onPressed: widget.onMinimize,
                      icon: Icon(
                        Icons.expand_less_rounded,
                        size: 21,
                        color: mutedTextColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: _outerVerticalPadding,
      ),
      child: widget.profileStyle
          ? DecoratedBox(
              decoration: AppTheme.profileCardDecoration(
                isDarkMode,
                radius: radius,
                color: surfaceColor,
              ),
              child: cardContent,
            )
          : cardContent,
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final int consumed;
  final int goal;
  final String unit;
  final Color color;
  final IconData icon;
  final double iconSize;
  final bool isDarkMode;
  final bool compact;

  const _MacroRow({
    Key? key,
    required this.label,
    required this.consumed,
    required this.goal,
    required this.unit,
    required this.color,
    required this.icon,
    required this.iconSize,
    required this.isDarkMode,
    required this.compact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? consumed / goal : 0.0;
    final isExceeded = progress > 1.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    const exceededColor = Color(0xFFE57373);
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final trackColor =
        isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFF5F7FA);
    final accentColor = isExceeded ? exceededColor : color;

    return Row(
      children: [
        MacroTheme.iconBadge(
          icon: icon,
          color: accentColor,
          isDarkMode: isDarkMode,
          size: iconSize,
          iconSize: iconSize * 0.56,
        ),
        SizedBox(width: compact ? 7 : 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11.5 : 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  SizedBox(
                    width: compact ? 64 : 70,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${consumed}${unit}/${goal}${unit}',
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: compact ? 10.5 : 11.5,
                          fontWeight:
                              isExceeded ? FontWeight.w700 : FontWeight.w500,
                          color: isExceeded ? exceededColor : mutedTextColor,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(
                      height: 4,
                      color: trackColor,
                    ),
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
    final progress = (goal > 0 ? consumed / goal : 0.0).clamp(0.0, 1.0);

    final bgPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFF2F4F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color =
          (isExceeded ? const Color(0xFFE57373) : MacroTheme.caloriesColor)
              .withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
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
  bool shouldRepaint(CalorieCirclePainter oldDelegate) {
    return oldDelegate.consumed != consumed ||
        oldDelegate.goal != goal ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.isExceeded != isExceeded;
  }
}
