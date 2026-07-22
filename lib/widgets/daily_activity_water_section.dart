import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/activity_tracking_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../screens/activity_selection_screen.dart';
import '../screens/activity_tracking_apps_screen.dart';
import '../theme/app_theme.dart';
import '../utils/hydration_recommendation.dart';

class DailyActivityWaterSection extends StatefulWidget {
  final DateTime selectedDate;

  const DailyActivityWaterSection({
    super.key,
    required this.selectedDate,
  });

  @override
  State<DailyActivityWaterSection> createState() =>
      _DailyActivityWaterSectionState();
}

class _DailyActivityWaterSectionState extends State<DailyActivityWaterSection> {
  @override
  void initState() {
    super.initState();
    _scheduleActivityLoad();
  }

  @override
  void didUpdateWidget(covariant DailyActivityWaterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _scheduleActivityLoad();
    }
  }

  void _scheduleActivityLoad({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<ActivityTrackingProvider>().loadForDate(
              widget.selectedDate,
              force: force,
            ),
      );
    });
  }

  Future<void> _openAutomaticTracking() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ActivityTrackingAppsScreen(),
      ),
    );
    if (!mounted) return;
    _scheduleActivityLoad(force: true);
  }

  Future<void> _openManualActivity() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ActivitySelectionScreen(
          selectedDate: widget.selectedDate,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.tr.translate('activity_saved'))),
      );
  }

  Future<void> _openWaterGoalDialog(DailyMealsProvider provider) async {
    final nutritionGoals = context.read<NutritionGoalsProvider>();
    await nutritionGoals.ensureLoaded();
    if (!mounted) return;

    final recommendation = HydrationRecommendation.calculate(
      sex: nutritionGoals.explicitSex,
      age: nutritionGoals.explicitAge,
      weightKg: nutritionGoals.explicitWeight,
      heightCm: nutritionGoals.explicitHeight,
      activityLevelIndex: nutritionGoals.explicitActivityLevel?.index,
    );
    final selectedGoal = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (dialogContext) => _WaterGoalDialog(
        initialGoal: provider.waterGoal <= 0 ? 8 : provider.waterGoal,
        recommendedGoal: recommendation.glasses,
      ),
    );
    if (!mounted || selectedGoal == null) return;
    provider.updateWaterGoal(selectedGoal, date: widget.selectedDate);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DailyMealsProvider, ActivityTrackingProvider>(
      builder: (context, mealsProvider, trackingProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildWaterCard(mealsProvider),
              const SizedBox(height: 16),
              _buildActivityCard(trackingProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityCard(ActivityTrackingProvider provider) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;
    final cardColor =
        isDarkMode ? AppTheme.darkCardColor : const Color(0xFFF4F6FB);
    const accentColor = Color(0xFFF2C94C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDarkMode ? 0.2 : 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.translate('tracking_activities_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (provider.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        '${provider.totalCaloriesBurned} ${context.tr.translate('tracking_kcal_spent_suffix')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openAutomaticTracking,
                icon: const Icon(Icons.sync_rounded),
                color: mutedTextColor,
                tooltip: context.tr.translate('automatic_tracking_apps_title'),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            context.tr.translate('activity_daily_message'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActivityMetric(
                  icon: Icons.directions_walk_rounded,
                  value: '${provider.steps}',
                  label: context.tr.translate('tracking_metric_steps'),
                  color: const Color(0xFF2F80ED),
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActivityMetric(
                  icon: Icons.fitness_center_rounded,
                  value: '${provider.totalExerciseMinutes}',
                  label: context.tr.translate('tracking_metric_minutes'),
                  color: const Color(0xFF8B5CF6),
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openManualActivity,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                context.tr.translate('tracking_add_activity_button'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isDarkMode
                    ? AppTheme.primaryColorDarkMode
                    : const Color(0xFF203747),
                foregroundColor: isDarkMode
                    ? AppTheme.onColor(AppTheme.primaryColorDarkMode)
                    : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDarkMode,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.15 : 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$value $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard(DailyMealsProvider provider) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;
    final consumed = provider.getWaterGlassesForDate(widget.selectedDate);
    final goal = provider.waterGoal <= 0 ? 8 : provider.waterGoal;
    final locale = Localizations.localeOf(context).toString();
    final litersFormatter = NumberFormat('0.00', locale);
    final consumedLiters = '${litersFormatter.format(consumed * 0.25)} L';
    final goalLiters = '${litersFormatter.format(goal * 0.25)} L';
    const waterColor = Color(0xFF4FC3F7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.translate('water_challenge'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr.translate('water'),
                onPressed: () => _openWaterGoalDialog(provider),
                icon: const Icon(Icons.more_vert_rounded),
                color: mutedTextColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.translate('water'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${context.tr.translate('water_goal')}: $goalLiters',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                consumedLiters,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final columns = constraints.maxWidth < 310 ? 4 : 8;
              final slotWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(goal, (index) {
                  final isFilled = index < consumed;
                  return Semantics(
                    button: true,
                    label: isFilled
                        ? context.tr.translate('remove')
                        : context.tr.translate('add'),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey('water-glass-$index'),
                        onTap: () {
                          provider.setWaterGlassesForDate(
                            widget.selectedDate,
                            isFilled ? index : index + 1,
                          );
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: SizedBox(
                          width: slotWidth,
                          height: 54,
                          child: _AnimatedWaterGlass(
                            key: ValueKey('animated-water-glass-$index'),
                            isFilled: isFilled,
                            waterColor: waterColor,
                            outlineColor: isFilled ? waterColor : textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedWaterGlass extends StatefulWidget {
  const _AnimatedWaterGlass({
    super.key,
    required this.isFilled,
    required this.waterColor,
    required this.outlineColor,
  });

  final bool isFilled;
  final Color waterColor;
  final Color outlineColor;

  @override
  State<_AnimatedWaterGlass> createState() => _AnimatedWaterGlassState();
}

class _AnimatedWaterGlassState extends State<_AnimatedWaterGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
      value: widget.isFilled ? 1 : 0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedWaterGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFilled == widget.isFilled) return;
    if (widget.isFilled) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _WaterGlassPainter(
            fillLevel: _animation.value,
            waterColor: widget.waterColor,
            outlineColor: Color.lerp(
              widget.outlineColor.withValues(alpha: 0.72),
              widget.waterColor,
              _animation.value,
            )!,
          ),
          child: Opacity(
            opacity: 1 - _animation.value,
            child: Icon(
              Icons.add_rounded,
              size: 22,
              color: widget.outlineColor.withValues(alpha: 0.75),
            ),
          ),
        );
      },
    );
  }
}

class _WaterGlassPainter extends CustomPainter {
  const _WaterGlassPainter({
    required this.fillLevel,
    required this.waterColor,
    required this.outlineColor,
  });

  final double fillLevel;
  final Color waterColor;
  final Color outlineColor;

  Path _outerGlassPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.13, size.height * 0.07)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.04,
        size.width * 0.87,
        size.height * 0.07,
      )
      ..lineTo(size.width * 0.76, size.height * 0.84)
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.94,
        size.width * 0.61,
        size.height * 0.96,
      )
      ..lineTo(size.width * 0.39, size.height * 0.96)
      ..quadraticBezierTo(
        size.width * 0.26,
        size.height * 0.94,
        size.width * 0.24,
        size.height * 0.84,
      )
      ..close();
  }

  Path _innerGlassPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.18, size.height * 0.11)
      ..lineTo(size.width * 0.82, size.height * 0.11)
      ..lineTo(size.width * 0.72, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.9,
        size.width * 0.6,
        size.height * 0.91,
      )
      ..lineTo(size.width * 0.4, size.height * 0.91)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.9,
        size.width * 0.28,
        size.height * 0.82,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final glass = _outerGlassPath(size);
    final innerGlass = _innerGlassPath(size);

    canvas.drawPath(
      glass.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      glass,
      Paint()
        ..color = outlineColor.withValues(
          alpha: 0.055 + (fillLevel * 0.08),
        )
        ..style = PaintingStyle.fill,
    );

    if (fillLevel > 0) {
      canvas.save();
      canvas.clipPath(innerGlass);
      final bottom = size.height * 0.92;
      final waterHeight = size.height * 0.81 * fillLevel;
      final top = bottom - waterHeight;

      final waterPath = Path()
        ..moveTo(0, top)
        ..cubicTo(
          size.width * 0.18,
          top - 2.2,
          size.width * 0.32,
          top + 2.2,
          size.width * 0.5,
          top,
        )
        ..cubicTo(
          size.width * 0.68,
          top - 2.2,
          size.width * 0.82,
          top + 2.2,
          size.width,
          top,
        )
        ..lineTo(size.width, bottom + 3)
        ..lineTo(0, bottom + 3)
        ..close();
      final waterBounds = Rect.fromLTRB(0, top - 3, size.width, bottom + 3);
      canvas.drawPath(
        waterPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF8DE3FF),
              waterColor,
              const Color(0xFF2196D3),
            ],
          ).createShader(waterBounds),
      );

      final bubbleOpacity = ((fillLevel - 0.2) / 0.8).clamp(0.0, 1.0);
      final bubblePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.62 * bubbleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(
        Offset(size.width * 0.58, bottom - waterHeight * 0.35),
        1.7,
        bubblePaint,
      );
      canvas.drawCircle(
        Offset(size.width * 0.43, bottom - waterHeight * 0.62),
        1.2,
        bubblePaint,
      );
      canvas.restore();
    }

    canvas.drawPath(
      glass,
      Paint()
        ..color = outlineColor.withValues(
          alpha: 0.24 + (fillLevel * 0.48),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );

    final rim = Path()
      ..moveTo(size.width * 0.13, size.height * 0.07)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.1,
        size.width * 0.87,
        size.height * 0.07,
      );
    canvas.drawPath(
      rim,
      Paint()
        ..color = outlineColor.withValues(
          alpha: 0.3 + (fillLevel * 0.5),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    final shine = Path()
      ..moveTo(size.width * 0.3, size.height * 0.19)
      ..quadraticBezierTo(
        size.width * 0.31,
        size.height * 0.44,
        size.width * 0.35,
        size.height * 0.64,
      );
    canvas.drawPath(
      shine,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WaterGlassPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel ||
        oldDelegate.waterColor != waterColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}

class _WaterGoalDialog extends StatefulWidget {
  const _WaterGoalDialog({
    required this.initialGoal,
    required this.recommendedGoal,
  });

  final int initialGoal;
  final int recommendedGoal;

  @override
  State<_WaterGoalDialog> createState() => _WaterGoalDialogState();
}

class _WaterGoalDialogState extends State<_WaterGoalDialog> {
  static const int _minimumGoal = 4;
  static const int _standardMaximumGoal = 32;
  late final int _maximumGoal;
  late int _goal;

  @override
  void initState() {
    super.initState();
    _maximumGoal = [
      _standardMaximumGoal,
      widget.initialGoal,
      widget.recommendedGoal,
    ]
        .reduce((current, value) => value > current ? value : current)
        .clamp(_minimumGoal, 40);
    _goal = widget.initialGoal.clamp(_minimumGoal, _maximumGoal);
  }

  String _litersLabel(BuildContext context, [int? glasses]) {
    final liters = (glasses ?? _goal) * 0.25;
    final locale = Localizations.localeOf(context).toString();
    return '${NumberFormat('0.00', locale).format(liters)} L';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;
    final surfaceColor =
        isDarkMode ? AppTheme.darkCardColor : const Color(0xFFFFFFFF);
    final actionColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : const Color(0xFF203747);
    final exceedsRecommendation = _goal > widget.recommendedGoal;
    final recommendationWarning =
        context.tr.translate('water_above_recommended_warning').replaceAll(
              '{amount}',
              _litersLabel(context, widget.recommendedGoal),
            );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 32, 30, 28),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr.translate('water_goal_dialog_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr.translate('water_goal_dialog_subtitle'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.tr.translate('water_daily_goal'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _litersLabel(context),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFF0F3F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.drag_handle_rounded, color: actionColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: textColor,
                          ),
                          children: [
                            TextSpan(
                              text: '$_goal ',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: context.tr.translate('water_glasses_title'),
                              style: TextStyle(
                                color: mutedColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: actionColor,
                  inactiveTrackColor: isDarkMode
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFE8ECF1),
                  thumbColor: actionColor,
                  overlayColor: actionColor.withValues(alpha: 0.12),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                ),
                child: Slider(
                  value: _goal.toDouble(),
                  min: _minimumGoal.toDouble(),
                  max: _maximumGoal.toDouble(),
                  divisions: _maximumGoal - _minimumGoal,
                  onChanged: (value) {
                    setState(() => _goal = value.round());
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: exceedsRecommendation
                      ? Text(
                          recommendationWarning,
                          key: const ValueKey('water-goal-warning'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('water-goal-no-warning'),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() => _goal = widget.recommendedGoal);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: textColor,
                        backgroundColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.07)
                            : const Color(0xFFF8F9FC),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        context.tr.translate('water_recommended'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_goal),
                      style: FilledButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: AppTheme.onColor(actionColor),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        context.tr.translate('water_confirm'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
