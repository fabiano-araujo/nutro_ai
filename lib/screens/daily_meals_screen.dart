import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../models/meal_model.dart';
import '../models/food_model.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/month_calendar_sheet.dart';
import '../widgets/food_icon.dart';
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
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false, // Don't show default back button
        leading: widget.showBackButton
            ? IconButton(
                icon: Icon(Icons.arrow_back,
                    color: textColor.withValues(alpha: 0.85)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Consumer<DailyMealsProvider>(
          builder: (context, mealsProvider, child) {
            final appLocalizations = AppLocalizations.of(context);
            final selectedDate = mealsProvider.selectedDate;
            final today = DateTime.now();

            // Normalizar as datas para comparação (zerar horas)
            final normalizedToday =
                DateTime(today.year, today.month, today.day);
            final normalizedSelected = DateTime(
                selectedDate.year, selectedDate.month, selectedDate.day);

            // Calcular a diferença em dias
            final difference =
                normalizedSelected.difference(normalizedToday).inDays;

            // Determinar o texto baseado na diferença
            String dateText;
            if (difference == 0) {
              dateText = appLocalizations.translate('today');
            } else if (difference == -1) {
              dateText = appLocalizations.translate('yesterday');
            } else if (difference == 1) {
              dateText = appLocalizations.translate('tomorrow');
            } else {
              dateText =
                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appLocalizations.translate('meals_diary'),
                  style: AppTheme.headingLarge.copyWith(
                    color: textColor.withValues(alpha: 0.85),
                    fontSize: 20,
                  ),
                ),
                InkWell(
                  onTap: () => _showDatePickerSheet(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Consumer2<DailyMealsProvider, NutritionGoalsProvider>(
        builder: (context, mealsProvider, goalsProvider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 8),

                // Nutrition summary header with edit button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('daily_goals'),
                        style: AppTheme.headingMedium.copyWith(
                          color: textColor.withValues(alpha: 0.85),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NutritionGoalsScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.edit,
                              color: textColor.withValues(alpha: 0.85),
                              size: 24),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8),

                // Nutrition summary card
                GestureDetector(
                  onTap: () {
                    // Card is already on this screen, no navigation needed
                  },
                  child: NutritionCard(
                    caloriesConsumed: mealsProvider.totalCalories,
                    caloriesGoal: goalsProvider.caloriesGoal,
                    proteinConsumed: mealsProvider.totalProtein.toInt(),
                    proteinGoal: goalsProvider.proteinGoal,
                    carbsConsumed: mealsProvider.totalCarbs.toInt(),
                    carbsGoal: goalsProvider.carbsGoal,
                    fatsConsumed: mealsProvider.totalFat.toInt(),
                    fatsGoal: goalsProvider.fatGoal,
                    profileStyle: true,
                  ),
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
