import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/daily_meals_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/streak_provider.dart';
import '../services/meals_sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/streak_helper.dart';
import '../i18n/app_localizations_extension.dart';
import 'daily_meals_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = '7';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr.translate('statistics'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer2<DailyMealsProvider, NutritionGoalsProvider>(
        builder: (context, mealsProvider, nutritionProvider, child) {
          if (!mealsProvider.isLoaded) {
            return _buildLoadingState(theme, colorScheme);
          }

          final fallbackGoals = _buildFallbackGoals(nutritionProvider);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              if (mealsProvider.isSyncing ||
                  mealsProvider.isLoadingFromServer) ...[
                _buildSyncBanner(theme, colorScheme, isDarkMode),
                const SizedBox(height: 16),
              ],

              // Period Selector
              _buildPeriodSelector(theme, colorScheme),
              const SizedBox(height: 24),

              // Summary Stats
              _buildSummaryStats(
                mealsProvider,
                theme,
                colorScheme,
                isDarkMode,
                fallbackGoals,
              ),
              const SizedBox(height: 20),

              // Period Insights
              _buildPeriodInsightsCard(
                mealsProvider,
                theme,
                colorScheme,
                isDarkMode,
                fallbackGoals,
              ),
              const SizedBox(height: 24),

              // Goal Adherence Chart
              _buildGoalAdherenceCard(
                mealsProvider,
                theme,
                colorScheme,
                isDarkMode,
                fallbackGoals,
              ),
              const SizedBox(height: 20),

              // Calories History Chart
              _buildCaloriesHistoryCard(
                mealsProvider,
                theme,
                colorScheme,
                isDarkMode,
                fallbackGoals,
              ),
              const SizedBox(height: 20),

              // Weekly Consistency
              _buildWeeklyConsistencyCard(
                mealsProvider,
                theme,
                colorScheme,
                isDarkMode,
                fallbackGoals,
              ),
              const SizedBox(height: 20),

              // Macros Average Chart
              _buildMacrosAverageCard(
                mealsProvider,
                theme,
                colorScheme,
                isDarkMode,
                fallbackGoals,
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  MealGoals _buildFallbackGoals(NutritionGoalsProvider nutritionProvider) {
    return MealGoals(
      calories: nutritionProvider.caloriesGoal,
      protein: nutritionProvider.proteinGoal,
      carbs: nutritionProvider.carbsGoal,
      fat: nutritionProvider.fatGoal,
    );
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            context.tr.translate('stats_loading'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr.translate('stats_syncing'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPeriodChip(
            '7', context.tr.translate('stats_7_days'), theme, colorScheme),
        const SizedBox(width: 12),
        _buildPeriodChip(
            '14', context.tr.translate('stats_14_days'), theme, colorScheme),
        const SizedBox(width: 12),
        _buildPeriodChip(
            '30', context.tr.translate('stats_30_days'), theme, colorScheme),
      ],
    );
  }

  Widget _buildPeriodChip(
      String period, String label, ThemeData theme, ColorScheme colorScheme) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStats(
    DailyMealsProvider mealsProvider,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDarkMode,
    MealGoals fallbackGoals,
  ) {
    final days = int.parse(_selectedPeriod);
    final history = mealsProvider.getNutritionHistory(
      days,
      fallbackGoals: fallbackGoals,
    );

    // Calculate stats
    final daysWithData = history.where((d) => d['hasData'] == true).length;
    final streak = effectiveRegistrationStreak(
      context.watch<StreakProvider>(),
      mealsProvider,
    );

    // Calculate adherence percentage
    int onTarget = 0;
    for (var day in history) {
      if (day['hasData'] == true) {
        final calories = day['calories'] as int;
        final goal = day['calorieGoal'] as int;
        if (goal <= 0) continue;
        final diff = (calories - goal).abs();
        if (diff <= goal * 0.1) onTarget++; // Within 10% of goal
      }
    }
    final adherencePercent =
        daysWithData > 0 ? (onTarget / daysWithData * 100).round() : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.local_fire_department_rounded,
            value: streak.toString(),
            label: context.tr.translate('stats_streak'),
            theme: theme,
            colorScheme: colorScheme,
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            icon: Icons.calendar_today_rounded,
            value: '$daysWithData/$days',
            label: context.tr.translate('stats_days_logged'),
            theme: theme,
            colorScheme: colorScheme,
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            icon: Icons.check_circle_outline_rounded,
            value: '$adherencePercent%',
            label: context.tr.translate('stats_on_target'),
            theme: theme,
            colorScheme: colorScheme,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool isDarkMode,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 28,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodInsightsCard(
    DailyMealsProvider mealsProvider,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDarkMode,
    MealGoals fallbackGoals,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final days = int.parse(_selectedPeriod);
    final history = mealsProvider.getNutritionHistory(
      days,
      fallbackGoals: fallbackGoals,
    );
    final loggedDays = history.where((d) => d['hasData'] == true).toList();

    final avgCalories = _averageInt(loggedDays, 'calories');
    final avgDeviation = loggedDays.isEmpty
        ? 0.0
        : loggedDays.fold<double>(0, (sum, day) {
              final calories = day['calories'] as int;
              final goal = day['calorieGoal'] as int;
              return sum + (calories - goal).abs();
            }) /
            loggedDays.length;
    final avgProtein = _averageDouble(loggedDays, 'protein');
    final avgProteinGoal = _averageInt(loggedDays, 'proteinGoal');
    final avgWater = history.isEmpty
        ? 0.0
        : history.fold<double>(
              0,
              (sum, day) => sum + (day['waterGlasses'] as int),
            ) /
            history.length;
    final avgFiber = _averageDouble(loggedDays, 'fiber');
    final missedDays = days - loggedDays.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded,
                  size: 24, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                context.tr.translate('stats_period_insights'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loggedDays.isEmpty)
            _buildNoDataMessage(theme, colorScheme)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildInsightTile(
                      width: tileWidth,
                      icon: Icons.local_fire_department_rounded,
                      label: context.tr.translate('stats_avg_calories'),
                      value: '${avgCalories.round()} kcal',
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    _buildInsightTile(
                      width: tileWidth,
                      icon: Icons.compare_arrows_rounded,
                      label: context.tr.translate('stats_avg_deviation'),
                      value: '${avgDeviation.round()} kcal',
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    _buildInsightTile(
                      width: tileWidth,
                      icon: Icons.fitness_center_rounded,
                      label: context.tr.translate('stats_avg_protein'),
                      value:
                          '${avgProtein.round()}g / ${avgProteinGoal.round()}g',
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    _buildInsightTile(
                      width: tileWidth,
                      icon: Icons.event_busy_rounded,
                      label: context.tr.translate('stats_missing_days'),
                      value:
                          '$missedDays ${context.tr.translate('stats_days')}',
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    _buildInsightTile(
                      width: tileWidth,
                      icon: Icons.water_drop_rounded,
                      label: context.tr.translate('stats_avg_water'),
                      value:
                          '${avgWater.toStringAsFixed(1)} ${context.tr.translate('stats_glasses_per_day')}',
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    _buildInsightTile(
                      width: tileWidth,
                      icon: Icons.eco_rounded,
                      label: context.tr.translate('stats_avg_fiber'),
                      value: '${avgFiber.round()}g',
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInsightTile({
    required double width,
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _averageInt(List<Map<String, dynamic>> days, String key) {
    if (days.isEmpty) return 0;
    return days.fold<double>(0, (sum, day) => sum + (day[key] as int)) /
        days.length;
  }

  double _averageDouble(List<Map<String, dynamic>> days, String key) {
    if (days.isEmpty) return 0;
    return days.fold<double>(0, (sum, day) => sum + (day[key] as double)) /
        days.length;
  }

  Widget _buildGoalAdherenceCard(
    DailyMealsProvider mealsProvider,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDarkMode,
    MealGoals fallbackGoals,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final days = int.parse(_selectedPeriod);
    final history = mealsProvider.getNutritionHistory(
      days,
      fallbackGoals: fallbackGoals,
    );

    // Count days by category
    int onTarget = 0;
    int below = 0;
    int above = 0;

    for (var day in history) {
      if (day['hasData'] != true) {
        continue;
      } else {
        final calories = day['calories'] as int;
        final goal = day['calorieGoal'] as int;
        if (goal <= 0) continue;
        final diff = calories - goal;
        if (diff.abs() <= goal * 0.1) {
          onTarget++;
        } else if (diff < 0) {
          below++;
        } else {
          above++;
        }
      }
    }

    final total = onTarget + below + above;
    final hasData = total > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded,
                  size: 24, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                context.tr.translate('stats_goal_adherence'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.translate('stats_goal_adherence_desc'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (!hasData)
            _buildNoDataMessage(theme, colorScheme)
          else
            Row(
              children: [
                // Pie Chart
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(
                          value: onTarget.toDouble(),
                          color: _getSuccessColor(colorScheme),
                          radius: 25,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: below.toDouble(),
                          color: _getWarningColor(colorScheme),
                          radius: 25,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: above.toDouble(),
                          color: _getErrorColor(colorScheme),
                          radius: 25,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendRow(
                        color: _getSuccessColor(colorScheme),
                        label: context.tr.translate('stats_on_target_days'),
                        value:
                            '$onTarget ${context.tr.translate('stats_days')}',
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildLegendRow(
                        color: _getWarningColor(colorScheme),
                        label: context.tr.translate('stats_below_goal'),
                        value: '$below ${context.tr.translate('stats_days')}',
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildLegendRow(
                        color: _getErrorColor(colorScheme),
                        label: context.tr.translate('stats_above_goal'),
                        value: '$above ${context.tr.translate('stats_days')}',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLegendRow({
    required Color color,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCaloriesHistoryCard(
    DailyMealsProvider mealsProvider,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDarkMode,
    MealGoals fallbackGoals,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final days = int.parse(_selectedPeriod);
    final history = mealsProvider.getNutritionHistory(
      days,
      fallbackGoals: fallbackGoals,
    );
    final hasData = history.any((d) => d['hasData'] == true);

    if (!hasData) {
      return _buildEmptyCard(
        icon: Icons.show_chart_rounded,
        title: context.tr.translate('stats_calories_history'),
        theme: theme,
        colorScheme: colorScheme,
        cardColor: cardColor,
        isDarkMode: isDarkMode,
      );
    }

    final calorieSpots = <FlSpot>[];
    final missingSpots = <FlSpot>[];
    final goalSpots = <FlSpot>[];

    for (final entry in history.asMap().entries) {
      final index = entry.key.toDouble();
      final day = entry.value;
      final goal = (day['calorieGoal'] as int).toDouble();
      goalSpots.add(FlSpot(index, goal));

      if (day['hasData'] == true) {
        calorieSpots.add(FlSpot(index, (day['calories'] as int).toDouble()));
      } else {
        missingSpots.add(FlSpot(index, 0));
      }
    }

    final maxDataValue = history.fold<double>(0, (max, day) {
      final calories =
          day['hasData'] == true ? (day['calories'] as int).toDouble() : 0.0;
      final goal = (day['calorieGoal'] as int).toDouble();
      final dayMax = calories > goal ? calories : goal;
      return dayMax > max ? dayMax : max;
    });
    final maxValue = maxDataValue > 0 ? maxDataValue : fallbackGoals.calories;
    final chartMaxY = (maxValue * 1.15).ceilToDouble();
    final lineBarsData = <LineChartBarData>[
      LineChartBarData(
        spots: goalSpots,
        isCurved: false,
        color: colorScheme.primary.withValues(alpha: 0.4),
        barWidth: 2,
        dotData: const FlDotData(show: false),
        dashArray: [6, 4],
      ),
      LineChartBarData(
        spots: calorieSpots,
        isCurved: true,
        curveSmoothness: 0.3,
        color: colorScheme.primary,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 4,
            color: colorScheme.primary,
            strokeWidth: 2,
            strokeColor: cardColor,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.15),
              colorScheme.primary.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      if (missingSpots.isNotEmpty)
        LineChartBarData(
          spots: missingSpots,
          isCurved: false,
          color: Colors.transparent,
          barWidth: 0,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
              radius: 3,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              strokeWidth: 0,
            ),
          ),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 24, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr.translate('stats_calories_history'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.translate('stats_calories_history_desc'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: days > 14 ? 7 : (days > 7 ? 2 : 1),
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < days) {
                          final date =
                              history[value.toInt()]['date'] as DateTime;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.day}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: chartMaxY / 4,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (days - 1).toDouble(),
                minY: 0,
                maxY: chartMaxY,
                lineBarsData: lineBarsData,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 10,
            children: [
              _buildChartLegend(
                color: colorScheme.primary,
                label: context.tr.translate('stats_consumed'),
                isDashed: false,
                theme: theme,
              ),
              _buildChartLegend(
                color: colorScheme.primary.withValues(alpha: 0.4),
                label: context.tr.translate('stats_goal'),
                isDashed: true,
                theme: theme,
              ),
              _buildChartLegend(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                label: context.tr.translate('stats_not_logged'),
                isDashed: false,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend({
    required Color color,
    required String label,
    required bool isDashed,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed
              ? CustomPaint(painter: _DashedLinePainter(color: color))
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyConsistencyCard(
    DailyMealsProvider mealsProvider,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDarkMode,
    MealGoals fallbackGoals,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final days = int.parse(_selectedPeriod);
    final history = mealsProvider.getNutritionHistory(
      days,
      fallbackGoals: fallbackGoals,
    );
    final hasAnyLoggedDay = history.any((day) => day['hasData'] == true);

    // Group by day of week (0 = Sunday, 6 = Saturday)
    final Map<int, List<bool>> dayData = {};
    for (int i = 0; i < 7; i++) {
      dayData[i] = [];
    }

    for (var day in history) {
      final date = day['date'] as DateTime;
      final hasData = day['hasData'] as bool;
      dayData[date.weekday % 7]!.add(hasData);
    }

    // Calculate consistency per day
    final List<double> consistency = [];
    for (int i = 0; i < 7; i++) {
      final dayList = dayData[i]!;
      if (dayList.isEmpty) {
        consistency.add(0);
      } else {
        final logged = dayList.where((b) => b).length;
        consistency.add(logged / dayList.length * 100);
      }
    }

    final dayLabels = [
      context.tr.translate('day_sun_short'),
      context.tr.translate('day_mon_short'),
      context.tr.translate('day_tue_short'),
      context.tr.translate('day_wed_short'),
      context.tr.translate('day_thu_short'),
      context.tr.translate('day_fri_short'),
      context.tr.translate('day_sat_short'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 24, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                context.tr.translate('stats_weekly_consistency'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.translate('stats_weekly_consistency_desc'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (!hasAnyLoggedDay)
            _buildNoDataMessage(theme, colorScheme)
          else
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.round()}%',
                          TextStyle(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              dayLabels[value.toInt()],
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    final value = consistency[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: _getConsistencyColor(value, colorScheme),
                          width: 24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMacrosAverageCard(
    DailyMealsProvider mealsProvider,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDarkMode,
    MealGoals fallbackGoals,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final days = int.parse(_selectedPeriod);
    final history = mealsProvider.getNutritionHistory(
      days,
      fallbackGoals: fallbackGoals,
    );
    final loggedDays = history.where((d) => d['hasData'] == true).toList();

    final protein = _averageDouble(loggedDays, 'protein');
    final carbs = _averageDouble(loggedDays, 'carbs');
    final fat = _averageDouble(loggedDays, 'fat');

    final proteinGoal = _averageInt(loggedDays, 'proteinGoal');
    final carbsGoal = _averageInt(loggedDays, 'carbsGoal');
    final fatGoal = _averageInt(loggedDays, 'fatGoal');

    final hasData = loggedDays.isNotEmpty;

    if (!hasData) {
      return _buildEmptyCard(
        icon: Icons.donut_large_rounded,
        title: context.tr.translate('stats_macros_average'),
        theme: theme,
        colorScheme: colorScheme,
        cardColor: cardColor,
        isDarkMode: isDarkMode,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large_rounded,
                  size: 24, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                context.tr.translate('stats_macros_average'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.translate('stats_macros_average_desc'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildMacroProgress(
            label: context.tr.translate('protein'),
            value: protein,
            goal: proteinGoal,
            color: colorScheme.primary,
            theme: theme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 16),
          _buildMacroProgress(
            label: context.tr.translate('carbs'),
            value: carbs,
            goal: carbsGoal,
            color: _getWarningColor(colorScheme),
            theme: theme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 16),
          _buildMacroProgress(
            label: context.tr.translate('fat'),
            value: fat,
            goal: fatGoal,
            color: _getSuccessColor(colorScheme),
            theme: theme,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgress({
    required String label,
    required double value,
    required double goal,
    required Color color,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}g / ${goal.toStringAsFixed(0)}g',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required Color cardColor,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildNoDataMessage(theme, colorScheme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr.translate('stats_no_data'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: _openDailyMeals,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(context.tr.translate('stats_open_diary')),
        ),
      ],
    );
  }

  void _openDailyMeals() {
    context.read<DailyMealsProvider>().setSelectedDate(DateTime.now());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DailyMealsScreen(),
      ),
    );
  }

  // Color helpers
  Color _getSuccessColor(ColorScheme colorScheme) => const Color(0xFF81C784);
  Color _getWarningColor(ColorScheme colorScheme) => const Color(0xFFE8B87D);
  Color _getErrorColor(ColorScheme colorScheme) => const Color(0xFFE57373);

  Color _getConsistencyColor(double value, ColorScheme colorScheme) {
    if (value >= 80) return _getSuccessColor(colorScheme);
    if (value >= 50) return _getWarningColor(colorScheme);
    if (value > 0) return _getErrorColor(colorScheme);
    return colorScheme.surfaceContainerHighest;
  }
}

// Custom painter for dashed lines
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
