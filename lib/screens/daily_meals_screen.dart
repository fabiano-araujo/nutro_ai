import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/activity_tracking_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../models/meal_model.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../widgets/month_calendar_sheet.dart';
import '../widgets/daily_activity_water_section.dart';
import 'manage_meal_types_screen.dart';
import 'nutrition_goals_screen.dart';
import 'food_search_screen.dart';
import 'meal_page.dart';
import '../i18n/app_localizations.dart';
import '../utils/meal_type_localization.dart';
import '../utils/premium_access.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';

class DailyMealsScreen extends StatefulWidget {
  final bool showBackButton;

  const DailyMealsScreen({
    Key? key,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  State<DailyMealsScreen> createState() => _DailyMealsScreenState();
}

class _DailyMealsScreenState extends State<DailyMealsScreen> {
  void _showDatePickerSheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer<DailyMealsProvider>(
          builder: (context, mealsProvider, child) {
            return MonthCalendarSheet(
              selectedDate: mealsProvider.selectedDate,
              hasMeals: mealsProvider.hasMealsOn,
              onVisibleMonthChanged: (month) {
                mealsProvider.ensureMonthSummariesLoaded(month);
              },
              onDaySelected: (date) {
                Navigator.of(sheetContext).pop();
                mealsProvider.setSelectedDate(date);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final purchaseService = context.watch<PurchaseService?>();
    final authService = context.watch<AuthService?>();
    final showFiber = hasPremiumAccess(
      purchaseService: purchaseService,
      authService: authService,
    );
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Consumer3<DailyMealsProvider, NutritionGoalsProvider,
          ActivityTrackingProvider>(
        builder: (
          context,
          mealsProvider,
          goalsProvider,
          activityProvider,
          child,
        ) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _DiaryNutritionHero(
                  selectedDate: mealsProvider.selectedDate,
                  caloriesConsumed: mealsProvider.totalCalories,
                  caloriesGoal: goalsProvider.caloriesGoal,
                  caloriesBurned: activityProvider.totalCaloriesBurned,
                  proteinConsumed: mealsProvider.totalProtein.toInt(),
                  proteinGoal: goalsProvider.proteinGoal,
                  carbsConsumed: mealsProvider.totalCarbs.toInt(),
                  carbsGoal: goalsProvider.carbsGoal,
                  fatsConsumed: mealsProvider.totalFat.toInt(),
                  fatsGoal: goalsProvider.fatGoal,
                  fiberConsumed: mealsProvider.totalFiber.round(),
                  showFiber: showFiber,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                  showBackButton: widget.showBackButton,
                  onBack: () => Navigator.pop(context),
                  onEditGoals: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NutritionGoalsScreen(),
                      ),
                    );
                  },
                  onPreviousDay: () => mealsProvider.setSelectedDate(
                    mealsProvider.selectedDate
                        .subtract(const Duration(days: 1)),
                  ),
                  onNextDay: () => mealsProvider.setSelectedDate(
                    mealsProvider.selectedDate.add(const Duration(days: 1)),
                  ),
                  onDateTap: () => _showDatePickerSheet(context),
                ),

                const SizedBox(height: 16),

                // Meals section header with edit button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? AppTheme.primaryColorDarkMode
                                  : AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context).translate('meals'),
                            style: AppTheme.headingMedium.copyWith(
                              color: textColor.withValues(alpha: 0.9),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      _HeaderActionButton(
                        icon: Icons.tune_rounded,
                        tooltip: AppLocalizations.of(context)
                            .translate('edit_meals'),
                        isDarkMode: isDarkMode,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ManageMealTypesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Meals list
                _buildMealsList(
                  mealsProvider,
                  isDarkMode,
                  textColor,
                  showFiber: showFiber,
                ),

                const SizedBox(height: 16),

                // Daily activity and hydration tracking
                DailyActivityWaterSection(
                  selectedDate: mealsProvider.selectedDate,
                ),

                const SizedBox(height: 16),

                // Daily Nutrition Details Card
                if (mealsProvider.todayMeals.isNotEmpty)
                  _buildDailyNutritionCard(
                    mealsProvider,
                    isDarkMode,
                    textColor,
                    showFiber: showFiber,
                  ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealsList(
    DailyMealsProvider provider,
    bool isDarkMode,
    Color textColor, {
    required bool showFiber,
  }) {
    return Consumer<MealTypesProvider>(
      builder: (context, mealTypesProvider, child) {
        final mealTypes = mealTypesProvider.mealTypes;

        if (mealTypes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withAlpha(20)
                          : Theme.of(context).colorScheme.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: isDarkMode
                          ? Colors.white70
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)
                        .translate('no_meals_configured'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)
                        .translate('configure_meals_description'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageMealTypesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                      AppLocalizations.of(context).translate('configure_meals'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: mealTypes.map((mealTypeConfig) {
            // Map custom meal type ID to enum
            final type = _getMealTypeFromId(mealTypeConfig.id);
            final meal = provider.getMealByType(type);

            // Create meal info from provider config
            final mealInfo = MealTypeOption(
              type: type,
              name: localizedMealTypeName(
                AppLocalizations.of(context),
                mealTypeConfig,
              ),
              emoji: mealTypeConfig.emoji,
            );

            final hasFoods = meal != null && meal.foods.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _MealCard(
                mealInfo: mealInfo,
                meal: meal,
                hasFoods: hasFoods,
                isDarkMode: isDarkMode,
                textColor: textColor,
                onOpenMeal: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MealPage.fromMeal(
                        meal: meal!,
                        showFiber: showFiber,
                      ),
                    ),
                  );
                },
                onAddFood: () {
                  _showAddFoodDialog(type);
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Helper method to map custom meal type IDs to enum
  MealType _getMealTypeFromId(String id) {
    switch (id) {
      case 'breakfast':
        return MealType.breakfast;
      case 'morning_snack':
        return MealType.snack;
      case 'lunch':
        return MealType.lunch;
      case 'afternoon_snack':
        return MealType.snack;
      case 'dinner':
        return MealType.dinner;
      case 'supper':
        return MealType.freeMeal;
      default:
        // For custom meal types created by user, use freeMeal
        return MealType.freeMeal;
    }
  }

  Widget _buildDailyNutritionCard(
    DailyMealsProvider provider,
    bool isDarkMode,
    Color textColor, {
    required bool showFiber,
  }) {
    // Aggregate all nutrients from all foods in all meals
    final allFoods = provider.todayMeals.expand((meal) => meal.foods).toList();

    if (allFoods.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    // Calculate totals
    final totalProtein = provider.totalProtein;
    final totalCarbs = provider.totalCarbs;
    final totalFat = provider.totalFat;
    final totalCalories = provider.totalCalories;
    final totalFiber = provider.totalFiber;

    // Calculate micronutrients (sum from all foods)
    double totalSugars = 0;
    double totalSaturatedFat = 0;
    double totalCholesterol = 0;
    double totalSodium = 0;
    double totalPotassium = 0;
    double totalCalcium = 0;
    double totalIron = 0;
    double totalVitaminD = 0;
    double totalVitaminA = 0;
    double totalVitaminC = 0;
    double totalVitaminB6 = 0;
    double totalVitaminB12 = 0;

    for (var food in allFoods) {
      final nutrient = food.primaryNutrient;
      if (nutrient != null) {
        totalSugars += nutrient.sugars ?? 0;
        totalSaturatedFat += nutrient.saturatedFat ?? 0;
        totalCholesterol += nutrient.cholesterol ?? 0;
        totalSodium += nutrient.sodium ?? 0;
        totalPotassium += nutrient.potassium ?? 0;
        totalCalcium += nutrient.calcium ?? 0;
        totalIron += nutrient.iron ?? 0;
        totalVitaminD += nutrient.vitaminD ?? 0;
        totalVitaminA += nutrient.vitaminA ?? 0;
        totalVitaminC += nutrient.vitaminC ?? 0;
        totalVitaminB6 += nutrient.vitaminB6 ?? 0;
        totalVitaminB12 += nutrient.vitaminB12 ?? 0;
      }
    }

    final microTiles = <_SummaryTileData>[
      _SummaryTileData(
        label: l10n.translate('sugars'),
        value: '${totalSugars.toStringAsFixed(0)} g',
      ),
      _SummaryTileData(
        label: l10n.translate('saturated_fat'),
        value: '${totalSaturatedFat.toStringAsFixed(1)} g',
      ),
      _SummaryTileData(
        label: l10n.translate('cholesterol'),
        value: '${totalCholesterol.toStringAsFixed(0)} mg',
      ),
      _SummaryTileData(
        label: l10n.translate('sodium'),
        value: '${totalSodium.toStringAsFixed(0)} mg',
      ),
      _SummaryTileData(
        label: l10n.translate('potassium'),
        value: '${totalPotassium.toStringAsFixed(0)} mg',
      ),
      _SummaryTileData(
        label: l10n.translate('calcium'),
        value: '${totalCalcium.toStringAsFixed(0)} mg',
      ),
      _SummaryTileData(
        label: l10n.translate('iron'),
        value: '${totalIron.toStringAsFixed(1)} mg',
      ),
      _SummaryTileData(
        label: l10n.translate('vitamin_d'),
        value: '${totalVitaminD.toStringAsFixed(1)} mcg',
      ),
      _SummaryTileData(
        label: l10n.translate('vitamin_a'),
        value: '${totalVitaminA.toStringAsFixed(1)} mcg',
      ),
      _SummaryTileData(
        label: l10n.translate('vitamin_c'),
        value: '${totalVitaminC.toStringAsFixed(1)} mg',
      ),
      _SummaryTileData(
        label: l10n.translate('vitamin_b6'),
        value: '${totalVitaminB6.toStringAsFixed(1)} mg',
      ),
      _SummaryTileData(
        label: l10n.translate('vitamin_b12'),
        value: '${totalVitaminB12.toStringAsFixed(1)} mcg',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: AppTheme.profileCardDecoration(isDarkMode),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.translate('daily_summary'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Macronutrients grid (2 x 2)
              Row(
                children: [
                  Expanded(
                    child: _SummaryMacroTile(
                      icon: MacroTheme.caloriesIcon,
                      color: MacroTheme.caloriesColor,
                      label: l10n.translate('calories'),
                      value: '$totalCalories kcal',
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMacroTile(
                      icon: MacroTheme.proteinIcon,
                      color: MacroTheme.proteinColor,
                      label: l10n.translate('protein_full'),
                      value: '${totalProtein.toStringAsFixed(0)} g',
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMacroTile(
                      icon: MacroTheme.carbsIcon,
                      color: MacroTheme.carbsColor,
                      label: l10n.translate('total_carbohydrates'),
                      value: '${totalCarbs.toStringAsFixed(0)} g',
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMacroTile(
                      icon: MacroTheme.fatIcon,
                      color: MacroTheme.fatColor,
                      label: l10n.translate('total_fat'),
                      value: '${totalFat.toStringAsFixed(0)} g',
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMacroTile(
                      icon: MacroTheme.fiberIcon,
                      color: MacroTheme.fiberColor,
                      label: l10n.translate('dietary_fiber'),
                      value: showFiber
                          ? '${totalFiber.toStringAsFixed(0)} g'
                          : l10n.translate('premium'),
                      isDarkMode: isDarkMode,
                      isLocked: !showFiber,
                      onTap: showFiber
                          ? null
                          : () =>
                              Navigator.of(context).pushNamed('/subscription'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),

              const SizedBox(height: 16),

              Divider(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                height: 1,
                thickness: 1,
              ),

              const SizedBox(height: 14),

              Text(
                l10n.translate('micronutrients'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.75),
                ),
              ),

              const SizedBox(height: 10),

              // Micronutrients grid (2 columns)
              ...List.generate((microTiles.length / 2).ceil(), (rowIndex) {
                final left = microTiles[rowIndex * 2];
                final right = rowIndex * 2 + 1 < microTiles.length
                    ? microTiles[rowIndex * 2 + 1]
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryMicroTile(
                          data: left,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: right != null
                            ? _SummaryMicroTile(
                                data: right,
                                isDarkMode: isDarkMode,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFoodDialog(MealType type) {
    // Navega para a tela de busca de alimentos, passando o tipo de refeição
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodSearchScreen(selectedMealType: type),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDarkMode;
  final VoidCallback onPressed;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.isDarkMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 19,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppTheme.textPrimaryColor.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealTypeOption mealInfo;
  final Meal? meal;
  final bool hasFoods;
  final bool isDarkMode;
  final Color textColor;
  final VoidCallback onOpenMeal;
  final VoidCallback onAddFood;

  const _MealCard({
    Key? key,
    required this.mealInfo,
    required this.meal,
    required this.hasFoods,
    required this.isDarkMode,
    required this.textColor,
    required this.onOpenMeal,
    required this.onAddFood,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context);
    final foodCount = meal?.foods.length ?? 0;
    final foodCountLabel = l10n
        .translate(
          foodCount == 1 ? 'meal_item_count_one' : 'meal_item_count_other',
        )
        .replaceAll('{count}', foodCount.toString());

    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasFoods ? onOpenMeal : onAddFood,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withValues(
                                alpha: isDarkMode ? 0.30 : 0.20),
                            primaryColor.withValues(
                                alpha: isDarkMode ? 0.12 : 0.07),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: primaryColor.withValues(
                              alpha: isDarkMode ? 0.28 : 0.16),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        mealInfo.emoji,
                        style: const TextStyle(fontSize: 23),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mealInfo.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (hasFoods)
                            Row(
                              children: [
                                Icon(
                                  MacroTheme.caloriesIcon,
                                  size: 13,
                                  color: MacroTheme.caloriesColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${meal!.totalCalories.toStringAsFixed(0)} kcal',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: MacroTheme.caloriesColor,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: secondaryTextColor.withValues(
                                          alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    foodCountLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              l10n.translate('add_food'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    secondaryTextColor.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasFoods) const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            primaryColor.withValues(alpha: 0.72),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onAddFood,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
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

class _SummaryTileData {
  final String label;
  final String value;

  const _SummaryTileData({required this.label, required this.value});
}

class _SummaryMacroTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isDarkMode;
  final bool isLocked;
  final VoidCallback? onTap;

  const _SummaryMacroTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.isDarkMode,
    this.isLocked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    final borderRadius = BorderRadius.circular(14);

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDarkMode ? 0.14 : 0.08),
            borderRadius: borderRadius,
          ),
          child: Row(
            children: [
              MacroTheme.iconBadge(
                icon: isLocked ? Icons.workspace_premium_rounded : icon,
                color: color,
                isDarkMode: isDarkMode,
                size: 28,
                iconSize: 15,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isLocked
                              ? color
                              : textColor.withValues(alpha: 0.92),
                        ),
                      ),
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

class _SummaryMicroTile extends StatelessWidget {
  final _SummaryTileData data;
  final bool isDarkMode;

  const _SummaryMicroTile({
    required this.data,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.62),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            data.value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryNutritionHero extends StatelessWidget {
  final DateTime selectedDate;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int caloriesBurned;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbsConsumed;
  final int carbsGoal;
  final int fatsConsumed;
  final int fatsGoal;
  final int fiberConsumed;
  final bool showFiber;
  final bool isDarkMode;
  final Color textColor;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onEditGoals;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onDateTap;

  const _DiaryNutritionHero({
    required this.selectedDate,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.caloriesBurned,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbsConsumed,
    required this.carbsGoal,
    required this.fatsConsumed,
    required this.fatsGoal,
    required this.fiberConsumed,
    required this.showFiber,
    required this.isDarkMode,
    required this.textColor,
    required this.showBackButton,
    required this.onBack,
    required this.onEditGoals,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final today = DateTime.now();
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    final dayLabel = isToday
        ? '${l10n.translate('today')}, ${materialL10n.formatShortMonthDay(selectedDate)}'
        : materialL10n.formatMediumDate(selectedDate);
    final availableCalories = caloriesGoal + caloriesBurned;
    final remaining = math.max(0, availableCalories - caloriesConsumed);
    final rawProgress =
        availableCalories <= 0 ? 0.0 : caloriesConsumed / availableCalories;
    final progress = rawProgress.clamp(0.0, 1.0);
    final isOverGoal =
        availableCalories > 0 && caloriesConsumed > availableCalories;
    final accentColor = isOverGoal
        ? AppTheme.errorColor
        : (isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor);
    final surfaceColor =
        isDarkMode ? const Color(0xFF121F1F) : const Color(0xFFF0FBFA);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 6,
        12,
        20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? const [Color(0xFF16302E), Color(0xFF111819)]
              : const [Color(0xFFD9F8F5), Color(0xFFF7FBFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          if (showBackButton)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back_rounded),
                color: textColor.withValues(alpha: 0.86),
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              _DiaryDateButton(
                icon: Icons.chevron_left_rounded,
                onPressed: onPreviousDay,
              ),
              Expanded(
                child: InkWell(
                  onTap: onDateTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 18, color: accentColor),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            dayLabel.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: textColor.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _DiaryDateButton(
                icon: Icons.chevron_right_rounded,
                onPressed: onNextDay,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 168,
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  child: _DiarySideMetric(
                    key: const ValueKey('diary-calories-consumed'),
                    icon: Icons.restaurant_rounded,
                    iconColor: MacroTheme.carbsColor,
                    label: l10n.translate('diary_calories_consumed_short'),
                    value: '$caloriesConsumed',
                    textColor: textColor,
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    painter: _CalorieRingPainter(
                      progress: progress,
                      color: accentColor,
                      trackColor: accentColor.withValues(alpha: 0.16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.translate('remaining'),
                            style: GoogleFonts.inter(
                              color: textColor.withValues(alpha: 0.68),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$remaining',
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontSize: 40,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.4,
                            ),
                          ),
                          Text(
                            '$caloriesGoal kcal',
                            style: GoogleFonts.inter(
                              color: textColor.withValues(alpha: 0.62),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 68,
                  child: _DiarySideMetric(
                    key: const ValueKey('diary-calories-burned'),
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFF7043),
                    label: l10n.translate('diary_calories_burned_short'),
                    value: '$caloriesBurned',
                    textColor: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DiaryMacroCard(
                  label: l10n.translate('carbs_short'),
                  consumed: carbsConsumed,
                  goal: carbsGoal,
                  color: MacroTheme.carbsColor,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DiaryMacroCard(
                  label: l10n.translate('protein_short'),
                  consumed: proteinConsumed,
                  goal: proteinGoal,
                  color: MacroTheme.proteinColor,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DiaryMacroCard(
                  label: l10n.translate('fats_short'),
                  consumed: fatsConsumed,
                  goal: fatsGoal,
                  color: MacroTheme.fatColor,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DiaryMacroCard(
                  key: const ValueKey('diary-fiber-card'),
                  label: l10n.translate('fiber'),
                  consumed: fiberConsumed,
                  color: MacroTheme.fiberColor,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  isDarkMode: isDarkMode,
                  isLocked: !showFiber,
                  onTap: showFiber
                      ? null
                      : () => Navigator.of(context).pushNamed('/subscription'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiaryDateButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _DiaryDateButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 27),
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.76),
    );
  }
}

class _DiarySideMetric extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color textColor;

  const _DiarySideMetric({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: textColor.withValues(alpha: 0.92),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiaryMacroCard extends StatelessWidget {
  final String label;
  final int consumed;
  final int? goal;
  final Color color;
  final Color surfaceColor;
  final Color textColor;
  final bool isDarkMode;
  final bool isLocked;
  final VoidCallback? onTap;

  const _DiaryMacroCard({
    super.key,
    required this.label,
    required this.consumed,
    this.goal,
    required this.color,
    required this.surfaceColor,
    required this.textColor,
    required this.isDarkMode,
    this.isLocked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        goal == null || goal! <= 0 ? 0.0 : (consumed / goal!).clamp(0.0, 1.0);

    final borderRadius = BorderRadius.circular(16);

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: borderRadius,
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textColor.withValues(alpha: 0.86),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isLocked)
                    Icon(
                      Icons.workspace_premium_rounded,
                      key: const ValueKey('diary-fiber-premium-icon'),
                      size: 14,
                      color: color,
                    ),
                ],
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isLocked
                      ? AppLocalizations.of(context).translate('premium')
                      : goal == null
                          ? '$consumed g'
                          : '$consumed/$goal g',
                  style: GoogleFonts.inter(
                    color: isLocked ? color : textColor.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: isLocked ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!isLocked && goal != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: color.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _CalorieRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = math.min(13.0, size.width * 0.075);
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) / 2) - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.65), color],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
