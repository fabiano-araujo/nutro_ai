import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../models/meal_model.dart';
import '../models/food_model.dart';
import '../theme/app_theme.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/macro_card_gradient.dart';
import 'manage_meal_types_screen.dart';
import 'nutrition_goals_screen.dart';
import 'food_search_screen.dart';
import '../i18n/app_localizations.dart';

class DailyMealsScreen extends StatefulWidget {
  const DailyMealsScreen({Key? key}) : super(key: key);

  @override
  State<DailyMealsScreen> createState() => _DailyMealsScreenState();
}

class _DailyMealsScreenState extends State<DailyMealsScreen> {
  final Map<MealType, bool> _expandedMeals = {};

  Future<void> _showDatePicker(BuildContext context) async {
    final mealsProvider = Provider.of<DailyMealsProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: mealsProvider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
                ? ColorScheme.dark(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkCardColor,
                    onSurface: AppTheme.darkTextColor,
                  )
                : ColorScheme.light(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppTheme.textPrimaryColor,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != mealsProvider.selectedDate) {
      mealsProvider.setSelectedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.backgroundColor;
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Consumer<DailyMealsProvider>(
          builder: (context, mealsProvider, child) {
            final appLocalizations = AppLocalizations.of(context);
            final selectedDate = mealsProvider.selectedDate;
            final today = DateTime.now();

            // Normalizar as datas para comparação (zerar horas)
            final normalizedToday = DateTime(today.year, today.month, today.day);
            final normalizedSelected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

            // Calcular a diferença em dias
            final difference = normalizedSelected.difference(normalizedToday).inDays;

            // Determinar o texto baseado na diferença
            String dateText;
            if (difference == 0) {
              dateText = appLocalizations.translate('today');
            } else if (difference == -1) {
              dateText = appLocalizations.translate('yesterday');
            } else if (difference == 1) {
              dateText = appLocalizations.translate('tomorrow');
            } else {
              dateText = '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appLocalizations.translate('meals_diary'),
                  style: AppTheme.headingLarge.copyWith(
                    color: textColor,
                    fontSize: 20,
                  ),
                ),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: textColor),
            tooltip: AppLocalizations.of(context).translate('select_date'),
            onPressed: () => _showDatePicker(context),
          ),
        ],
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
                        AppLocalizations.of(context).translate('nutrition_summary'),
                        style: AppTheme.headingMedium.copyWith(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NutritionGoalsScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.edit, color: textColor, size: 24),
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
                  ),
                ),

                SizedBox(height: 16),

                // Meals section header with edit button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('meals'),
                        style: AppTheme.headingMedium.copyWith(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: textColor),
                        tooltip: AppLocalizations.of(context).translate('edit_meals'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageMealTypesScreen(),
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
                  _buildDailyNutritionCard(mealsProvider, isDarkMode, textColor),

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
                  Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: textColor.withValues(alpha: 0.3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).translate('no_meals_configured'),
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).translate('configure_meals_in_settings'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.4),
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
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    // Aggregate all nutrients from all foods in all meals
    final allFoods = provider.todayMeals
        .expand((meal) => meal.foods)
        .toList();

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
      final nutrient = food.nutrients?.first;
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
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? AppTheme.darkBorderColor
                : AppTheme.dividerColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Macronutrients Section Header
            Text(
              AppLocalizations.of(context).translate('macronutrients'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
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
              label: AppLocalizations.of(context).translate('total_carbohydrates'),
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
                    label: AppLocalizations.of(context).translate('dietary_fiber'),
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
                    color: Color(0xFF9575CD).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              child: _SubNutrientRow(
                label: AppLocalizations.of(context).translate('saturated_fat'),
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
                color: textColor,
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
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final secondaryTextColor = isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shadowColor: isDarkMode
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: backgroundColor,
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Text(
            mealInfo.emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
        title: Text(
          mealInfo.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.2,
            color: (isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor).withValues(alpha: 0.85),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            hasFoods
                ? '${meal!.totalCalories} kcal'
                : '0 kcal',
            style: TextStyle(
              color: secondaryTextColor.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAddFood,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        children: hasFoods ? [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foods list
                ...meal!.foods.map((food) => _buildFoodItem(food, context)),

                // Divisor sutil
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Meal totals
                Row(
                  children: [
                    Expanded(
                      child: MacroCardGradient(
                        icon: '🔥',
                        label: 'Cal',
                        value: meal!.totalCalories.toStringAsFixed(0),
                        unit: 'kcal',
                        startColor: const Color(0xFFFF6B9D),
                        endColor: const Color(0xFFFFA06B),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: MacroCardGradient(
                        icon: '💪',
                        label: 'Prot',
                        value: meal!.totalProtein.toStringAsFixed(1),
                        unit: 'g',
                        startColor: const Color(0xFF9575CD),
                        endColor: const Color(0xFFBA68C8),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: MacroCardGradient(
                        icon: '🌾',
                        label: 'Carb',
                        value: meal!.totalCarbs.toStringAsFixed(1),
                        unit: 'g',
                        startColor: const Color(0xFFFFB74D),
                        endColor: const Color(0xFFFF9800),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: MacroCardGradient(
                        icon: '🥑',
                        label: 'Gord',
                        value: meal!.totalFat.toStringAsFixed(1),
                        unit: 'g',
                        startColor: const Color(0xFF4DB6AC),
                        endColor: const Color(0xFF26A69A),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),
        ] : [],
      ),
    );
  }

  Widget _buildFoodItem(Food food, BuildContext context) {
    final secondaryTextColor = isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Food Image/Emoji
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Text(
                food.emoji,
                style: TextStyle(fontSize: 28),
              ),
            ),
            SizedBox(width: 10),
            // Food Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.85),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1),
                  Text(
                    '${food.amount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor.withValues(alpha: 0.75),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Calories
            Row(
              children: [
                Text(
                  '${food.calories}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(width: 1),
                Text(
                  'kcal',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            // Remove button
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: Colors.red.withValues(alpha: 0.7),
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
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
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
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor,
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
    final secondaryTextColor = isDarkMode
        ? Color(0xFF9CA3AF)
        : Color(0xFF6B7280);

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
