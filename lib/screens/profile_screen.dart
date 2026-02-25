import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/auth_service.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'nutrition_goals_screen.dart';
import '../i18n/app_localizations_extension.dart';

// ========== STANDARDIZED COLORS ==========
// Harmonized palette using soft purples and muted pastels
class ProfileColors {
  // Primary purple tones (main accent)
  static const Color primary = Color(0xFF9575CD);       // Main purple
  static const Color primaryLight = Color(0xFFB39DDB);  // Light purple
  static const Color primaryMuted = Color(0xFF7E57C2);  // Deeper purple

  // Macronutrients - soft muted tones
  static const Color protein = Color(0xFF9575CD);       // Purple
  static const Color carbs = Color(0xFFE8B87D);         // Soft warm beige/amber
  static const Color fat = Color(0xFF80CBC4);           // Soft teal (muted)
  static const Color fiber = Color(0xFFA5D6A7);         // Soft green (muted)

  // Status colors - softer versions
  static const Color success = Color(0xFF81C784);       // Soft green - On target
  static const Color warning = Color(0xFFE8B87D);       // Soft amber - Under goal
  static const Color danger = Color(0xFFE57373);        // Soft red - Over goal

  // Category colors - unified purple-based with subtle variations
  static const Color calories = Color(0xFF9575CD);      // Purple (unified)
  static const Color streak = Color(0xFFE8B87D);        // Soft amber for fire
  static const Color days = Color(0xFF90CAF9);          // Very soft blue
  static const Color meals = Color(0xFF81C784);         // Soft green
  static const Color average = Color(0xFFB39DDB);       // Light purple
  static const Color insights = Color(0xFF9575CD);      // Purple
  static const Color balance = Color(0xFF90CAF9);       // Soft blue
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const ProfileScreen({Key? key, this.onOpenDrawer}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;

  String _selectedPeriod = '7';
  String _selectedMacroPeriod = '7';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildAuthenticatedContent() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Profile Header with Avatar and Stats
        _buildProfileHeader(user, theme, colorScheme),
        const SizedBox(height: 20),

        // 2. Quick Stats Row (streak, days, meals, avg)
        _buildQuickStatsRow(theme, colorScheme),
        const SizedBox(height: 20),

        // 3. Goal Adherence Card
        _buildGoalAdherenceCard(theme, colorScheme),
        const SizedBox(height: 20),

        // 4. Weekly Progress Heatmap
        _buildWeeklyProgressCard(theme, colorScheme),
        const SizedBox(height: 20),

        // 5. Caloric Balance Card
        _buildCaloricBalanceCard(theme, colorScheme),
        const SizedBox(height: 20),

        // 6. Calories History Chart
        _buildCaloriesChartCard(theme, colorScheme),
        const SizedBox(height: 20),

        // 7. Macronutrients Average Chart
        _buildMacronutrientsChartCard(theme, colorScheme),
        const SizedBox(height: 20),

        // 8. Best Days of Week Card
        _buildBestDaysCard(theme, colorScheme),
        const SizedBox(height: 20),

        // 9. Today's Macro Distribution (at the end)
        _buildMacroDistributionCard(theme, colorScheme),
        const SizedBox(height: 24),

        // 10. Logout Button
        _buildLogoutButton(authService),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildProfileHeader(user, ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer<NutritionGoalsProvider>(
      builder: (context, nutritionProvider, child) {
        final bmi = _calculateBMI(nutritionProvider.weight, nutritionProvider.height);
        final bmiColor = _getBMIColor(bmi);
        final bmiCategory = _getBMICategory(bmi, context);

        return Card(
          margin: const EdgeInsets.all(0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar and Name Row
                Row(
                  children: [
                    // Avatar with gradient border
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: backgroundColor,
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: user.photo != null ? NetworkImage(user.photo!) : null,
                          child: user.photo == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 36,
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Name and BMI
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user.name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const NutritionGoalsWizardScreen(
                                        startStep: 0,
                                        fromProfile: true,
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: colorScheme.primary.withValues(alpha: 0.7),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // BMI Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: bmiColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite_rounded,
                                  size: 14,
                                  color: bmiColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'IMC ${bmi.toStringAsFixed(1)} - $bmiCategory',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: bmiColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Goal and Calories Row
                Row(
                  children: [
                    // Goal Card
                    Expanded(
                      child: _buildInfoCard(
                        icon: _getGoalIcon(nutritionProvider.fitnessGoal),
                        iconColor: colorScheme.primary,
                        label: context.tr.translate('profile_goal'),
                        value: _getGoalText(nutritionProvider.fitnessGoal, context),
                        valueColor: colorScheme.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NutritionGoalsWizardScreen(
                                startStep: 2,
                                fromProfile: true,
                              ),
                            ),
                          );
                        },
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Daily Calories Card
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: ProfileColors.calories,
                        label: context.tr.translate('profile_daily_target'),
                        value: '${nutritionProvider.caloriesGoal} kcal',
                        valueColor: ProfileColors.calories,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NutritionGoalsScreen(),
                            ),
                          );
                        },
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: iconColor.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<DailyMealsProvider>(
      builder: (context, mealsProvider, child) {
        final streak = mealsProvider.getCurrentStreak();
        final totalDays = mealsProvider.getTotalDaysLogged();
        final totalMeals = mealsProvider.getTotalMealsLogged();
        final avgCalories = mealsProvider.getAverageCalories(7);

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.local_fire_department_rounded,
                value: streak.toString(),
                label: context.tr.translate('profile_streak'),
                color: ProfileColors.streak,
                isDarkMode: isDarkMode,
                theme: theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_today_rounded,
                value: totalDays.toString(),
                label: context.tr.translate('profile_days_logged'),
                color: ProfileColors.days,
                isDarkMode: isDarkMode,
                theme: theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.restaurant_rounded,
                value: totalMeals.toString(),
                label: context.tr.translate('profile_meals'),
                color: ProfileColors.meals,
                isDarkMode: isDarkMode,
                theme: theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.show_chart_rounded,
                value: avgCalories > 0 ? avgCalories.toStringAsFixed(0) : '-',
                label: context.tr.translate('profile_avg_cal'),
                color: ProfileColors.average,
                isDarkMode: isDarkMode,
                theme: theme,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDarkMode,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesChartCard(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer2<DailyMealsProvider, NutritionGoalsProvider>(
      builder: (context, mealsProvider, nutritionProvider, child) {
        final calorieGoal = nutritionProvider.caloriesGoal.toDouble();
        final days = int.parse(_selectedPeriod);
        final history = mealsProvider.getCaloriesHistory(days);

        // Get calories data
        final List<double> caloriesData = history.map((d) => (d['calories'] as int).toDouble()).toList();

        // Check if we have any data
        final hasData = caloriesData.any((c) => c > 0);

        if (!hasData) {
          return _buildEmptyChartCard(
            title: context.tr.translate('profile_daily_calories_consumed'),
            message: context.tr.translate('profile_no_data_yet'),
            icon: Icons.bar_chart_rounded,
            theme: theme,
            colorScheme: colorScheme,
            isDarkMode: isDarkMode,
            backgroundColor: backgroundColor,
            periodSelector: _buildPeriodSelector(theme, colorScheme),
          );
        }

        // Calculate chart bounds
        final maxDataValue = caloriesData.reduce((a, b) => a > b ? a : b);
        final maxValue = [maxDataValue, calorieGoal].reduce((a, b) => a > b ? a : b);
        final chartMaxY = (maxValue * 1.15).ceilToDouble();
        final chartMinY = 0.0;
        final interval = (chartMaxY / 4).ceilToDouble();

        return Card(
          margin: const EdgeInsets.all(0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr.translate('profile_daily_calories_consumed'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPeriodSelector(theme, colorScheme),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: days > 30 ? 15 : (days > 7 ? 5 : 1),
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < days) {
                                final date = history[value.toInt()]['date'] as DateTime;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '${date.day}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (days - 1).toDouble(),
                      minY: chartMinY,
                      maxY: chartMaxY,
                      lineBarsData: [
                        // Goal line
                        LineChartBarData(
                          spots: [
                            FlSpot(0, calorieGoal),
                            FlSpot((days - 1).toDouble(), calorieGoal),
                          ],
                          isCurved: false,
                          color: ProfileColors.calories.withValues(alpha: 0.6),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          dashArray: [6, 4],
                        ),
                        // Calories line
                        LineChartBarData(
                          spots: caloriesData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: colorScheme.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              final hasValue = spot.y > 0;
                              return FlDotCirclePainter(
                                radius: hasValue ? 4 : 2,
                                color: hasValue ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.3),
                                strokeWidth: 2,
                                strokeColor: backgroundColor,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.2),
                                colorScheme.primary.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              if (spot.barIndex == 1) {
                                return LineTooltipItem(
                                  '${spot.y.toInt()} kcal',
                                  TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return null;
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(
                      context.tr.translate('profile_consumed'),
                      colorScheme.primary,
                      theme,
                      false,
                    ),
                    const SizedBox(width: 24),
                    _buildLegendItem(
                      context.tr.translate('profile_daily_target'),
                      ProfileColors.calories,
                      theme,
                      true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPeriodChip('7', context.tr.translate('profile_7_days'), theme, colorScheme),
        const SizedBox(width: 8),
        _buildPeriodChip('30', context.tr.translate('profile_30_days'), theme, colorScheme),
        const SizedBox(width: 8),
        _buildPeriodChip('90', context.tr.translate('profile_90_days'), theme, colorScheme),
      ],
    );
  }

  Widget _buildPeriodChip(String period, String label, ThemeData theme, ColorScheme colorScheme) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPeriod = period);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, ThemeData theme, bool isDashed) {
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
              ? CustomPaint(
                  painter: DashedLinePainter(color: color),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChartCard({
    required String title,
    required String message,
    required IconData icon,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool isDarkMode,
    required Color backgroundColor,
    required Widget periodSelector,
  }) {
    return Card(
      margin: const EdgeInsets.all(0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
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
            const SizedBox(height: 16),
            periodSelector,
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMacronutrientsChartCard(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer<DailyMealsProvider>(
      builder: (context, mealsProvider, child) {
        final days = int.parse(_selectedMacroPeriod);
        final avgMacros = mealsProvider.getAverageMacros(days);

        final avgProtein = avgMacros['protein']!;
        final avgCarbs = avgMacros['carbs']!;
        final avgFat = avgMacros['fat']!;
        final avgFiber = avgMacros['fiber']!;

        // Check if we have any data
        final hasData = avgProtein > 0 || avgCarbs > 0 || avgFat > 0;

        if (!hasData) {
          return _buildEmptyChartCard(
            title: context.tr.translate('profile_daily_macros_average'),
            message: context.tr.translate('profile_no_data_yet'),
            icon: Icons.pie_chart_rounded,
            theme: theme,
            colorScheme: colorScheme,
            isDarkMode: isDarkMode,
            backgroundColor: backgroundColor,
            periodSelector: _buildMacroPeriodSelector(theme, colorScheme),
          );
        }

        // Calculate max for chart scale
        final maxMacro = [avgProtein, avgCarbs, avgFat, avgFiber].reduce((a, b) => a > b ? a : b);
        final chartMaxY = (maxMacro * 1.2).ceilToDouble();

        return Card(
          margin: const EdgeInsets.all(0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ProfileColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.pie_chart_rounded,
                        size: 20,
                        color: ProfileColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr.translate('profile_daily_macros_average'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMacroPeriodSelector(theme, colorScheme),
                const SizedBox(height: 20),
                // Macro Cards Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMacroCard(
                        label: context.tr.translate('protein_full'),
                        value: avgProtein,
                        color: ProfileColors.protein,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMacroCard(
                        label: context.tr.translate('carbohydrate'),
                        value: avgCarbs,
                        color: ProfileColors.carbs,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMacroCard(
                        label: context.tr.translate('fat'),
                        value: avgFat,
                        color: ProfileColors.fat,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMacroCard(
                        label: context.tr.translate('fiber'),
                        value: avgFiber,
                        color: ProfileColors.fiber,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Bar Chart
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: chartMaxY,
                      minY: 0,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String label = '';
                            switch (groupIndex) {
                              case 0:
                                label = context.tr.translate('protein_full');
                                break;
                              case 1:
                                label = context.tr.translate('carbohydrate');
                                break;
                              case 2:
                                label = context.tr.translate('fat');
                                break;
                              case 3:
                                label = context.tr.translate('fiber');
                                break;
                            }
                            return BarTooltipItem(
                              '$label\n${rod.toY.toStringAsFixed(1)}g',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            getTitlesWidget: (value, meta) {
                              IconData icon;
                              Color color;
                              switch (value.toInt()) {
                                case 0:
                                  icon = Icons.egg_outlined;
                                  color = ProfileColors.protein;
                                  break;
                                case 1:
                                  icon = Icons.grain;
                                  color = ProfileColors.carbs;
                                  break;
                                case 2:
                                  icon = Icons.water_drop_outlined;
                                  color = ProfileColors.fat;
                                  break;
                                case 3:
                                  icon = Icons.grass;
                                  color = ProfileColors.fiber;
                                  break;
                                default:
                                  return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Icon(icon, size: 20, color: color),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: chartMaxY / 4,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}g',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: chartMaxY / 4,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        _buildBarGroup(0, avgProtein, ProfileColors.protein),
                        _buildBarGroup(1, avgCarbs, ProfileColors.carbs),
                        _buildBarGroup(2, avgFat, ProfileColors.fat),
                        _buildBarGroup(3, avgFiber, ProfileColors.fiber),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  BarChartGroupData _buildBarGroup(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          width: 32,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ],
    );
  }

  // ========== MACRO DISTRIBUTION PIE CHART ==========
  Widget _buildMacroDistributionCard(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer2<DailyMealsProvider, NutritionGoalsProvider>(
      builder: (context, mealsProvider, nutritionProvider, child) {
        // Get today's macros
        final protein = mealsProvider.totalProtein;
        final carbs = mealsProvider.totalCarbs;
        final fat = mealsProvider.totalFat;
        final total = protein + carbs + fat;

        // Get goals
        final proteinGoal = nutritionProvider.proteinGoal.toDouble();
        final carbsGoal = nutritionProvider.carbsGoal.toDouble();
        final fatGoal = nutritionProvider.fatGoal.toDouble();

        final hasData = total > 0;

        if (!hasData) {
          return _buildEmptyChartCard(
            title: context.tr.translate('profile_macro_distribution'),
            message: context.tr.translate('profile_no_data_today'),
            icon: Icons.pie_chart_outline_rounded,
            theme: theme,
            colorScheme: colorScheme,
            isDarkMode: isDarkMode,
            backgroundColor: backgroundColor,
            periodSelector: const SizedBox.shrink(),
          );
        }

        final proteinPercent = (protein / total * 100);
        final carbsPercent = (carbs / total * 100);
        final fatPercent = (fat / total * 100);

        return Card(
          margin: const EdgeInsets.all(0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ProfileColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.pie_chart_rounded,
                        size: 20,
                        color: ProfileColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.translate('profile_macro_distribution'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.tr.translate('profile_today'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Pie Chart
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 35,
                          sections: [
                            PieChartSectionData(
                              value: protein,
                              color: ProfileColors.protein,
                              radius: 30,
                              title: '',
                            ),
                            PieChartSectionData(
                              value: carbs,
                              color: ProfileColors.carbs,
                              radius: 30,
                              title: '',
                            ),
                            PieChartSectionData(
                              value: fat,
                              color: ProfileColors.fat,
                              radius: 30,
                              title: '',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Legend with progress
                    Expanded(
                      child: Column(
                        children: [
                          _buildMacroProgressRow(
                            label: context.tr.translate('protein_full'),
                            value: protein,
                            goal: proteinGoal,
                            percent: proteinPercent,
                            color: ProfileColors.protein,
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _buildMacroProgressRow(
                            label: context.tr.translate('carbohydrate'),
                            value: carbs,
                            goal: carbsGoal,
                            percent: carbsPercent,
                            color: ProfileColors.carbs,
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _buildMacroProgressRow(
                            label: context.tr.translate('fat'),
                            value: fat,
                            goal: fatGoal,
                            percent: fatPercent,
                            color: ProfileColors.fat,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMacroProgressRow({
    required String label,
    required double value,
    required double goal,
    required double percent,
    required Color color,
    required ThemeData theme,
  }) {
    final progress = (value / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(0)}g / ${goal.toStringAsFixed(0)}g',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ========== WEEKLY PROGRESS CARD ==========
  Widget _buildWeeklyProgressCard(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer2<DailyMealsProvider, NutritionGoalsProvider>(
      builder: (context, mealsProvider, nutritionProvider, child) {
        final calorieGoal = nutritionProvider.caloriesGoal.toDouble();
        final history = mealsProvider.getCaloriesHistory(7);

        // Get weekday names
        final weekdays = [
          context.tr.translate('weekday_mon'),
          context.tr.translate('weekday_tue'),
          context.tr.translate('weekday_wed'),
          context.tr.translate('weekday_thu'),
          context.tr.translate('weekday_fri'),
          context.tr.translate('weekday_sat'),
          context.tr.translate('weekday_sun'),
        ];

        return Card(
          margin: const EdgeInsets.all(0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ProfileColors.balance.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_view_week_rounded,
                        size: 20,
                        color: ProfileColors.balance,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr.translate('profile_weekly_progress'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Weekly grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final dayData = history[index];
                    final date = dayData['date'] as DateTime;
                    final calories = (dayData['calories'] as int).toDouble();
                    final hasData = dayData['hasData'] as bool;
                    final isToday = _isToday(date);

                    // Calculate progress percentage
                    final progress = hasData ? (calories / calorieGoal).clamp(0.0, 1.5) : 0.0;

                    // Determine color based on progress
                    Color progressColor;
                    if (!hasData) {
                      progressColor = Colors.grey.withValues(alpha: 0.3);
                    } else if (progress < 0.8) {
                      progressColor = ProfileColors.warning; // Under goal
                    } else if (progress <= 1.1) {
                      progressColor = ProfileColors.success; // On target
                    } else {
                      progressColor = ProfileColors.danger; // Over goal
                    }

                    return _buildWeekdayCell(
                      day: weekdays[date.weekday - 1],
                      progress: progress,
                      color: progressColor,
                      hasData: hasData,
                      isToday: isToday,
                      theme: theme,
                      colorScheme: colorScheme,
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWeeklyLegendItem(context.tr.translate('profile_under_goal'), ProfileColors.warning, theme),
                    const SizedBox(width: 16),
                    _buildWeeklyLegendItem(context.tr.translate('profile_on_target'), ProfileColors.success, theme),
                    const SizedBox(width: 16),
                    _buildWeeklyLegendItem(context.tr.translate('profile_over_goal'), ProfileColors.danger, theme),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _buildWeekdayCell({
    required String day,
    required double progress,
    required Color color,
    required bool hasData,
    required bool isToday,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      children: [
        Text(
          day,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday ? colorScheme.primary : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: hasData ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
          ),
          child: Center(
            child: hasData
                ? Icon(
                    progress <= 1.1 ? Icons.check_rounded : Icons.warning_rounded,
                    size: 18,
                    color: color,
                  )
                : Icon(
                    Icons.remove_rounded,
                    size: 14,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasData ? '${(progress * 100).toStringAsFixed(0)}%' : '-',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: hasData ? color : Colors.grey.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyLegendItem(String label, Color color, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // ========== GOAL ADHERENCE CARD ==========
  Widget _buildGoalAdherenceCard(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer2<DailyMealsProvider, NutritionGoalsProvider>(
      builder: (context, mealsProvider, nutritionProvider, child) {
        final calorieGoal = nutritionProvider.caloriesGoal.toDouble();
        final history = mealsProvider.getCaloriesHistory(30);

        // Calculate adherence stats
        int daysOnTarget = 0;
        int daysUnder = 0;
        int daysOver = 0;
        int totalDaysWithData = 0;

        for (var day in history) {
          if (day['hasData'] as bool) {
            totalDaysWithData++;
            final calories = (day['calories'] as int).toDouble();
            final ratio = calories / calorieGoal;

            if (ratio < 0.8) {
              daysUnder++;
            } else if (ratio <= 1.1) {
              daysOnTarget++;
            } else {
              daysOver++;
            }
          }
        }

        final adherenceRate = totalDaysWithData > 0
            ? (daysOnTarget / totalDaysWithData * 100)
            : 0.0;

        return Card(
          margin: const EdgeInsets.all(0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ProfileColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        size: 20,
                        color: ProfileColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.translate('profile_goal_adherence'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.tr.translate('profile_last_30_days'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Circular progress indicator
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: adherenceRate / 100,
                              strokeWidth: 10,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getAdherenceColor(adherenceRate),
                              ),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${adherenceRate.toStringAsFixed(0)}%',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getAdherenceColor(adherenceRate),
                                ),
                              ),
                              Text(
                                context.tr.translate('profile_adherence'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Stats breakdown
                    Expanded(
                      child: Column(
                        children: [
                          _buildAdherenceStatRow(
                            icon: Icons.check_circle_rounded,
                            label: context.tr.translate('profile_on_target'),
                            value: daysOnTarget,
                            color: ProfileColors.success,
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _buildAdherenceStatRow(
                            icon: Icons.arrow_downward_rounded,
                            label: context.tr.translate('profile_under_goal'),
                            value: daysUnder,
                            color: ProfileColors.warning,
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _buildAdherenceStatRow(
                            icon: Icons.arrow_upward_rounded,
                            label: context.tr.translate('profile_over_goal'),
                            value: daysOver,
                            color: ProfileColors.danger,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (totalDaysWithData == 0) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      context.tr.translate('profile_no_data_yet'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getAdherenceColor(double rate) {
    if (rate >= 80) return ProfileColors.success;
    if (rate >= 50) return ProfileColors.warning;
    return ProfileColors.danger;
  }

  Widget _buildAdherenceStatRow({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(
          '$value ${context.tr.translate('profile_days_suffix')}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ========== CALORIC BALANCE CARD ==========
  Widget _buildCaloricBalanceCard(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer2<DailyMealsProvider, NutritionGoalsProvider>(
      builder: (context, mealsProvider, nutritionProvider, child) {
        final calorieGoal = nutritionProvider.caloriesGoal;
        final fitnessGoal = nutritionProvider.fitnessGoal;
        final history = mealsProvider.getCaloriesHistory(30);

        // Calculate total deficit/surplus
        int totalBalance = 0;
        int daysWithData = 0;

        for (var day in history) {
          if (day['hasData'] as bool) {
            daysWithData++;
            final calories = day['calories'] as int;
            totalBalance += (calories - calorieGoal);
          }
        }

        // Determine if user wants deficit or surplus
        final wantsDeficit = fitnessGoal == FitnessGoal.loseWeight ||
            fitnessGoal == FitnessGoal.loseWeightSlowly;
        final wantsSurplus = fitnessGoal == FitnessGoal.gainWeight ||
            fitnessGoal == FitnessGoal.gainWeightSlowly;

        // Check if on track
        bool isOnTrack;
        if (wantsDeficit) {
          isOnTrack = totalBalance < 0;
        } else if (wantsSurplus) {
          isOnTrack = totalBalance > 0;
        } else {
          isOnTrack = totalBalance.abs() < (calorieGoal * 0.1 * daysWithData);
        }

        final balanceColor = isOnTrack ? ProfileColors.success : ProfileColors.warning;

        // Estimate weight change (3500 kcal = ~0.45kg)
        final estimatedWeightChange = totalBalance / 7700; // kg

        return Card(
          margin: const EdgeInsets.all(0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: balanceColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        totalBalance < 0
                            ? Icons.trending_down_rounded
                            : totalBalance > 0
                                ? Icons.trending_up_rounded
                                : Icons.trending_flat_rounded,
                        size: 20,
                        color: balanceColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.translate('profile_caloric_balance'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.tr.translate('profile_last_30_days'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // On track badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: balanceColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOnTrack ? Icons.check_circle_rounded : Icons.info_rounded,
                            size: 14,
                            color: balanceColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnTrack
                                ? context.tr.translate('profile_on_track')
                                : context.tr.translate('profile_adjust_needed'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: balanceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Main balance display
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceStatCard(
                        label: context.tr.translate('profile_total_balance'),
                        value: '${totalBalance > 0 ? '+' : ''}${totalBalance.abs()}',
                        unit: 'kcal',
                        icon: totalBalance < 0 ? Icons.remove_circle_outline : Icons.add_circle_outline,
                        color: totalBalance < 0 ? ProfileColors.balance : ProfileColors.warning,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalanceStatCard(
                        label: context.tr.translate('profile_estimated_change'),
                        value: '${estimatedWeightChange > 0 ? '+' : ''}${estimatedWeightChange.toStringAsFixed(2)}',
                        unit: 'kg',
                        icon: estimatedWeightChange < 0 ? Icons.fitness_center : Icons.restaurant,
                        color: wantsDeficit
                            ? (estimatedWeightChange < 0 ? ProfileColors.success : ProfileColors.warning)
                            : wantsSurplus
                                ? (estimatedWeightChange > 0 ? ProfileColors.success : ProfileColors.warning)
                                : ProfileColors.balance,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Daily average
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr.translate('profile_daily_average'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        daysWithData > 0
                            ? '${(totalBalance / daysWithData).toStringAsFixed(0)} kcal/${context.tr.translate('profile_day')}'
                            : '-',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (daysWithData == 0) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      context.tr.translate('profile_no_data_yet'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceStatCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== BEST DAYS OF WEEK CARD ==========
  Widget _buildBestDaysCard(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer2<DailyMealsProvider, NutritionGoalsProvider>(
      builder: (context, mealsProvider, nutritionProvider, child) {
        final calorieGoal = nutritionProvider.caloriesGoal.toDouble();
        final history = mealsProvider.getCaloriesHistory(90); // Last 3 months

        // Calculate success rate per weekday
        final Map<int, List<double>> weekdayRatios = {
          1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: [],
        };

        for (var day in history) {
          if (day['hasData'] as bool) {
            final date = day['date'] as DateTime;
            final calories = (day['calories'] as int).toDouble();
            final ratio = calories / calorieGoal;
            weekdayRatios[date.weekday]!.add(ratio);
          }
        }

        // Calculate success rate (days within 80%-110% of goal)
        final Map<int, double> successRates = {};
        for (var entry in weekdayRatios.entries) {
          if (entry.value.isEmpty) {
            successRates[entry.key] = 0;
          } else {
            final successDays = entry.value.where((r) => r >= 0.8 && r <= 1.1).length;
            successRates[entry.key] = successDays / entry.value.length * 100;
          }
        }

        final weekdays = [
          context.tr.translate('weekday_mon'),
          context.tr.translate('weekday_tue'),
          context.tr.translate('weekday_wed'),
          context.tr.translate('weekday_thu'),
          context.tr.translate('weekday_fri'),
          context.tr.translate('weekday_sat'),
          context.tr.translate('weekday_sun'),
        ];

        // Find best and worst days
        int bestDay = 1;
        int worstDay = 1;
        double bestRate = 0;
        double worstRate = 100;

        for (var entry in successRates.entries) {
          if (entry.value > bestRate && weekdayRatios[entry.key]!.isNotEmpty) {
            bestRate = entry.value;
            bestDay = entry.key;
          }
          if (entry.value < worstRate && weekdayRatios[entry.key]!.isNotEmpty) {
            worstRate = entry.value;
            worstDay = entry.key;
          }
        }

        final hasData = weekdayRatios.values.any((list) => list.isNotEmpty);

        return Card(
          margin: const EdgeInsets.all(0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ProfileColors.insights.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        size: 20,
                        color: ProfileColors.insights,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.translate('profile_weekly_patterns'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.tr.translate('profile_last_90_days'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (hasData) ...[
                  // Bar chart for each day
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      final dayNum = index + 1;
                      final rate = successRates[dayNum] ?? 0;
                      final isBest = dayNum == bestDay && bestRate > 0;
                      final isWorst = dayNum == worstDay && worstRate < 100;

                      return _buildDayBar(
                        day: weekdays[index],
                        rate: rate,
                        isBest: isBest,
                        isWorst: isWorst,
                        theme: theme,
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // Best and worst day highlights
                  Row(
                    children: [
                      Expanded(
                        child: _buildDayHighlight(
                          label: context.tr.translate('profile_best_day'),
                          day: weekdays[bestDay - 1],
                          rate: bestRate,
                          color: ProfileColors.success,
                          icon: Icons.emoji_events_rounded,
                          theme: theme,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDayHighlight(
                          label: context.tr.translate('profile_needs_attention'),
                          day: weekdays[worstDay - 1],
                          rate: worstRate,
                          color: ProfileColors.warning,
                          icon: Icons.lightbulb_outline_rounded,
                          theme: theme,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr.translate('profile_no_data_yet'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayBar({
    required String day,
    required double rate,
    required bool isBest,
    required bool isWorst,
    required ThemeData theme,
  }) {
    Color barColor;
    if (isBest) {
      barColor = ProfileColors.success;
    } else if (isWorst) {
      barColor = ProfileColors.warning;
    } else if (rate >= 70) {
      barColor = ProfileColors.success.withValues(alpha: 0.6);
    } else if (rate >= 40) {
      barColor = ProfileColors.warning.withValues(alpha: 0.6);
    } else {
      barColor = Colors.grey.withValues(alpha: 0.4);
    }

    return Column(
      children: [
        Container(
          width: 28,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: (rate / 100 * 80).clamp(4, 80),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              if (isBest)
                Positioned(
                  top: 4,
                  child: Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: (isBest || isWorst) ? FontWeight.bold : FontWeight.normal,
            color: (isBest || isWorst)
                ? (isBest ? ProfileColors.success : ProfileColors.warning)
                : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
        Text(
          '${rate.toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 9,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildDayHighlight({
    required String label,
    required String day,
    required double rate,
    required Color color,
    required IconData icon,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  day,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required String label,
    required double value,
    required Color color,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${value.toStringAsFixed(1)}g',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPeriodSelector(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMacroPeriodChip('7', context.tr.translate('profile_7_days'), theme, colorScheme),
        const SizedBox(width: 8),
        _buildMacroPeriodChip('30', context.tr.translate('profile_30_days'), theme, colorScheme),
        const SizedBox(width: 8),
        _buildMacroPeriodChip('90', context.tr.translate('profile_90_days'), theme, colorScheme),
      ],
    );
  }

  Widget _buildMacroPeriodChip(String period, String label, ThemeData theme, ColorScheme colorScheme) {
    final isSelected = _selectedMacroPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMacroPeriod = period);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(AuthService authService) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ProfileColors.danger.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: ProfileColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () async {
            await authService.logout();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: ProfileColors.danger.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr.translate('sign_out'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: ProfileColors.danger.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getGoalIcon(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
      case FitnessGoal.loseWeightSlowly:
        return Icons.trending_down_rounded;
      case FitnessGoal.gainWeight:
      case FitnessGoal.gainWeightSlowly:
        return Icons.trending_up_rounded;
      case FitnessGoal.maintainWeight:
        return Icons.trending_flat_rounded;
    }
  }

  String _getGoalText(FitnessGoal goal, BuildContext context) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return context.tr.translate('goal_lose_weight');
      case FitnessGoal.loseWeightSlowly:
        return context.tr.translate('goal_lose_weight_slowly');
      case FitnessGoal.gainWeight:
        return context.tr.translate('goal_gain_weight');
      case FitnessGoal.gainWeightSlowly:
        return context.tr.translate('goal_gain_weight_slowly');
      case FitnessGoal.maintainWeight:
        return context.tr.translate('goal_maintain_weight');
    }
  }

  double _calculateBMI(double weight, double height) {
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  String _getBMICategory(double bmi, BuildContext context) {
    if (bmi < 18.5) {
      return context.tr.translate('bmi_underweight');
    } else if (bmi < 25) {
      return context.tr.translate('bmi_normal_weight');
    } else if (bmi < 30) {
      return context.tr.translate('bmi_overweight');
    } else {
      return context.tr.translate('bmi_obesity');
    }
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) {
      return ProfileColors.balance;   // Soft blue - underweight
    } else if (bmi < 25) {
      return ProfileColors.success;   // Soft green - normal
    } else if (bmi < 30) {
      return ProfileColors.warning;   // Soft amber - overweight
    } else {
      return ProfileColors.danger;    // Soft red - obese
    }
  }

  Widget _buildUnauthenticatedContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              context.tr.translate('login_to_access_profile'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr.translate('login_description'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.tr.translate('sign_in'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        automaticallyImplyLeading: false,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: Icon(
                  Icons.menu,
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                ),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Menu',
              )
            : null,
        title: Text(
          context.tr.translate('profile_and_settings'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          if (authService.isAuthenticated)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      body: authService.isAuthenticated
          ? _buildAuthenticatedContent()
          : _buildUnauthenticatedContent(),
    );
  }
}

// Custom painter for dashed line in legend
class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

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
