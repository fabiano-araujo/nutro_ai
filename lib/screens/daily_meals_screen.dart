import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/activity_tracking_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../models/meal_model.dart';
import '../models/food_model.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../widgets/month_calendar_sheet.dart';
import '../widgets/food_icon.dart';
import '../widgets/daily_activity_water_section.dart';
import 'manage_meal_types_screen.dart';
import 'nutrition_goals_screen.dart';
import 'food_search_screen.dart';
import 'food_page.dart';
import '../i18n/app_localizations.dart';

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
  final Map<MealType, bool> _expandedMeals = {};

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

                SizedBox(height: 12),

                // Meals section header with edit button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('meals'),
                        style: AppTheme.headingMedium.copyWith(
                          color: textColor.withValues(alpha: 0.85),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit,
                            color: textColor.withValues(alpha: 0.85)),
                        tooltip: AppLocalizations.of(context)
                            .translate('edit_meals'),
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

                SizedBox(height: 8),

                // Meals list
                _buildMealsList(mealsProvider, isDarkMode, textColor),

                SizedBox(height: 16),

                // Daily activity and hydration tracking
                DailyActivityWaterSection(
                  selectedDate: mealsProvider.selectedDate,
                ),

                SizedBox(height: 16),

                // Daily Nutrition Details Card
                if (mealsProvider.todayMeals.isNotEmpty)
                  _buildDailyNutritionCard(
                      mealsProvider, isDarkMode, textColor),

                SizedBox(height: 16),
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
    Color textColor,
  ) {
    return Consumer<MealTypesProvider>(
      builder: (context, mealTypesProvider, child) {
        final mealTypes = mealTypesProvider.mealTypes;

        if (mealTypes.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
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
                  SizedBox(height: 24),
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
                  SizedBox(height: 12),
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
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageMealTypesScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.add),
                    label: Text(
                      AppLocalizations.of(context).translate('configure_meals'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              name: mealTypeConfig.name,
              emoji: mealTypeConfig.emoji,
            );

            final hasFoods = meal != null && meal.foods.isNotEmpty;
            final isExpanded = _expandedMeals[type] ?? false;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _MealCard(
                mealInfo: mealInfo,
                meal: meal,
                hasFoods: hasFoods,
                isExpanded: isExpanded,
                isDarkMode: isDarkMode,
                textColor: textColor,
                onExpand: () {
                  setState(() {
                    _expandedMeals[type] = !isExpanded;
                  });
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
    Color textColor,
  ) {
    // Aggregate all nutrients from all foods in all meals
    final allFoods = provider.todayMeals.expand((meal) => meal.foods).toList();

    if (allFoods.isEmpty) return SizedBox.shrink();

    // Calculate totals
    double totalProtein = provider.totalProtein;
    double totalCarbs = provider.totalCarbs;
    double totalFat = provider.totalFat;
    int totalCalories = provider.totalCalories;

    // Calculate micronutrients (sum from all foods)
    double totalFiber = 0;
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
        totalFiber += nutrient.dietaryFiber ?? 0;
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: AppTheme.profileCardDecoration(isDarkMode),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Macronutrients Section Header
              Text(
                AppLocalizations.of(context).translate('daily_summary'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor.withValues(alpha: 0.85),
                ),
              ),

              Divider(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                height: 24,
                thickness: 1,
              ),

              // Calories
              _MacroNutrientRow(
                label: AppLocalizations.of(context).translate('calories'),
                value: '$totalCalories kcal',
                isDarkMode: isDarkMode,
              ),

              SizedBox(height: 12),

              // Protein
              _MacroNutrientRow(
                label: AppLocalizations.of(context).translate('protein_full'),
                value: '${totalProtein.toStringAsFixed(0)} g',
                isDarkMode: isDarkMode,
              ),

              SizedBox(height: 12),

              // Total Carbohydrates
              _MacroNutrientRow(
                label: AppLocalizations.of(context)
                    .translate('total_carbohydrates'),
                value: '${totalCarbs.toStringAsFixed(0)} g',
                isDarkMode: isDarkMode,
              ),
              Container(
                margin: EdgeInsets.only(left: 0, top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Color(0xFFA1887F).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    _SubNutrientRow(
                      label: AppLocalizations.of(context)
                          .translate('dietary_fiber'),
                      value: '${totalFiber.toStringAsFixed(0)} g',
                      isDarkMode: isDarkMode,
                    ),
                    _SubNutrientRow(
                      label: AppLocalizations.of(context).translate('sugars'),
                      value: '${totalSugars.toStringAsFixed(0)} g',
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12),

              // Total Fat
              _MacroNutrientRow(
                label: AppLocalizations.of(context).translate('total_fat'),
                value: '${totalFat.toStringAsFixed(0)} g',
                isDarkMode: isDarkMode,
              ),
              Container(
                margin: EdgeInsets.only(left: 0, top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: MacroTheme.proteinColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: _SubNutrientRow(
                  label:
                      AppLocalizations.of(context).translate('saturated_fat'),
                  value: '${totalSaturatedFat.toStringAsFixed(1)} g',
                  isDarkMode: isDarkMode,
                ),
              ),

              SizedBox(height: 24),

              // Micronutrients Section Header
              Text(
                AppLocalizations.of(context).translate('micronutrients'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor.withValues(alpha: 0.85),
                ),
              ),

              Divider(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                height: 24,
                thickness: 1,
              ),

              // Micronutrients List
              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('cholesterol'),
                value: '${totalCholesterol.toStringAsFixed(0)} mg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('sodium'),
                value: '${totalSodium.toStringAsFixed(0)} mg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('potassium'),
                value: '${totalPotassium.toStringAsFixed(0)} mg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('calcium'),
                value: '${totalCalcium.toStringAsFixed(0)} mg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('iron'),
                value: '${totalIron.toStringAsFixed(1)} mg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('vitamin_d'),
                value: '${totalVitaminD.toStringAsFixed(1)} mcg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('vitamin_a'),
                value: '${totalVitaminA.toStringAsFixed(1)} mcg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('vitamin_c'),
                value: '${totalVitaminC.toStringAsFixed(1)} mg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('vitamin_b6'),
                value: '${totalVitaminB6.toStringAsFixed(1)} mg',
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 12),

              _MicroNutrientRow(
                label: AppLocalizations.of(context).translate('vitamin_b12'),
                value: '${totalVitaminB12.toStringAsFixed(1)} mcg',
                isDarkMode: isDarkMode,
              ),
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

class _MealCard extends StatelessWidget {
  final MealTypeOption mealInfo;
  final Meal? meal;
  final bool hasFoods;
  final bool isExpanded;
  final bool isDarkMode;
  final Color textColor;
  final VoidCallback onExpand;
  final VoidCallback onAddFood;

  const _MealCard({
    Key? key,
    required this.mealInfo,
    required this.meal,
    required this.hasFoods,
    required this.isExpanded,
    required this.isDarkMode,
    required this.textColor,
    required this.onExpand,
    required this.onAddFood,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final actionIconColor = Theme.of(context).colorScheme.primary;
    final cardBorderRadius = BorderRadius.circular(24);

    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode),
      child: Material(
        color: Colors.transparent,
        borderRadius: cardBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasFoods ? onExpand : null,
          borderRadius: cardBorderRadius,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Text(
                      mealInfo.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mealInfo.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasFoods
                                ? '${meal!.foods.length} ${meal!.foods.length == 1 ? 'item' : 'itens'} • ${meal!.totalCalories.toStringAsFixed(0)} kcal'
                                : '0 kcal',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasFoods)
                      IconButton(
                        onPressed: onExpand,
                        icon: AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 24,
                            color: secondaryTextColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: onAddFood,
                      icon: Icon(
                        Icons.add_circle_outline,
                        size: 20,
                        color: actionIconColor,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: hasFoods
                    ? _buildExpandedFoodList(context, secondaryTextColor)
                    : const SizedBox.shrink(),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedFoodList(
    BuildContext context,
    Color secondaryTextColor,
  ) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                (isDarkMode ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: meal!.foods
                .map(
                    (food) => _buildFoodItem(food, context, secondaryTextColor))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroCardCompact(
                icon: MacroTheme.caloriesIcon,
                value: meal!.totalCalories.toStringAsFixed(0),
                unit: 'kcal',
                color: MacroTheme.caloriesColor,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.proteinIcon,
                value: meal!.totalProtein.toStringAsFixed(1),
                unit: 'g prot',
                color: MacroTheme.proteinColor,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.carbsIcon,
                value: meal!.totalCarbs.toStringAsFixed(1),
                unit: 'g carb',
                color: MacroTheme.carbsColor,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.fatIcon,
                value: meal!.totalFat.toStringAsFixed(1),
                unit: 'g gord',
                color: MacroTheme.fatColor,
                isSmall: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroCardCompact({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    bool isSmall = false,
  }) {
    final secondaryColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MacroTheme.iconBadge(
          icon: icon,
          color: color,
          isDarkMode: isDarkMode,
          size: isSmall ? 22 : 26,
          iconSize: isSmall ? 13 : 15,
        ),
        SizedBox(height: isSmall ? 3 : 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isSmall ? 13 : 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: isSmall ? 9.5 : 10,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroDivider(bool isDarkMode) {
    return VerticalDivider(
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
      width: 1,
      thickness: 1,
      indent: 4,
      endIndent: 4,
    );
  }

  Widget _buildFoodItem(
      Food food, BuildContext context, Color secondaryTextColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodPage(food: food),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: FoodIcon(name: food.name, emoji: food.emoji, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      food.amount ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: secondaryTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${food.calories} kcal',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                onPressed: () {
                  Provider.of<DailyMealsProvider>(context, listen: false)
                      .removeFoodFromMeal(mealInfo.type, food);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Macronutrient row widget (for main nutrients)
class _MacroNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _MacroNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.85),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

// Micronutrient row widget (for minerals and vitamins - without bold)
class _MicroNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _MicroNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor.withValues(alpha: 0.85),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

// Sub-nutrient row widget (indented)
class _SubNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _SubNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor =
        isDarkMode ? Color(0xFF9CA3AF) : Color(0xFF6B7280);

    return Padding(
      padding: EdgeInsets.only(left: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: secondaryTextColor,
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (showBackButton)
                IconButton(
                  onPressed: onBack,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: textColor.withValues(alpha: 0.86),
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.translate('meals_diary'),
                  style: AppTheme.headingLarge.copyWith(
                    color: textColor.withValues(alpha: 0.92),
                    fontSize: 21,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEditGoals,
                tooltip: l10n.translate('daily_goals'),
                icon: const Icon(Icons.tune_rounded),
                color: textColor.withValues(alpha: 0.86),
              ),
            ],
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
          const SizedBox(height: 4),
          SizedBox(
            height: 154,
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: _DiarySideMetric(
                    key: const ValueKey('diary-calories-consumed'),
                    label: l10n.translate('diary_calories_consumed_short'),
                    value: '$caloriesConsumed',
                    textColor: textColor,
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    painter: _CalorieArcPainter(
                      progress: progress,
                      color: accentColor,
                      trackColor: accentColor.withValues(alpha: 0.18),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 26),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.translate('remaining'),
                              style: GoogleFonts.inter(
                                color: textColor.withValues(alpha: 0.68),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$remaining',
                              style: GoogleFonts.poppins(
                                color: textColor,
                                fontSize: 42,
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
                ),
                SizedBox(
                  width: 62,
                  child: _DiarySideMetric(
                    key: const ValueKey('diary-calories-burned'),
                    label: l10n.translate('diary_calories_burned_short'),
                    value: '$caloriesBurned',
                    textColor: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
  final String label;
  final String value;
  final Color textColor;

  const _DiarySideMetric({
    super.key,
    required this.label,
    required this.value,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: textColor.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: textColor.withValues(alpha: 0.9),
              fontSize: 20,
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
  final int goal;
  final Color color;
  final Color surfaceColor;
  final Color textColor;
  final bool isDarkMode;

  const _DiaryMacroCard({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
    required this.surfaceColor,
    required this.textColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: textColor.withValues(alpha: 0.86),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$consumed/$goal g',
              style: GoogleFonts.inter(
                color: textColor.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _CalorieArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = math.pi * 0.82;
    const sweepAngle = math.pi * 1.36;
    final strokeWidth = math.min(14.0, size.width * 0.07);
    final radius = math.min(size.width * 0.42, size.height * 0.45);
    final center = Offset(size.width / 2, size.height * 0.55);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.72), color],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
          rect, startAngle, sweepAngle * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
