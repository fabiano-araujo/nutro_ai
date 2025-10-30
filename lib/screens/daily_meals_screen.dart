import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../models/meal_model.dart';
import '../theme/app_theme.dart';
import '../widgets/nutrition_card.dart';
import 'manage_meal_types_screen.dart';
import 'nutrition_goals_screen.dart';
import 'food_search_screen.dart';

class DailyMealsScreen extends StatefulWidget {
  const DailyMealsScreen({Key? key}) : super(key: key);

  @override
  State<DailyMealsScreen> createState() => _DailyMealsScreenState();
}

class _DailyMealsScreenState extends State<DailyMealsScreen> {
  final Map<MealType, bool> _expandedMeals = {};

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
        title: Text(
          'Diário de Refeições',
          style: AppTheme.headingLarge.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
        actions: [
          // Load sample data button (for testing)
          IconButton(
            icon: Icon(Icons.restaurant_menu, color: textColor),
            tooltip: 'Carregar dados de exemplo',
            onPressed: () {
              Provider.of<DailyMealsProvider>(context, listen: false)
                  .loadSampleData();
            },
          ),
          IconButton(
            icon: Icon(Icons.calendar_today, color: textColor),
            onPressed: () {
              // TODO: Show date picker
            },
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
                        'Resumo Nutricional',
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
                        'Refeições',
                        style: AppTheme.headingMedium.copyWith(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: textColor),
                        tooltip: 'Editar refeições',
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
                    'Nenhuma refeição configurada',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Configure suas refeições nas configurações',
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
              'Macronutrientes',
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
              label: 'Calorias',
              value: '$totalCalories kcal',
              isDarkMode: isDarkMode,
            ),

            SizedBox(height: 12),

            // Protein
            _MacroNutrientRow(
              label: 'Proteína',
              value: '${totalProtein.toStringAsFixed(0)} g',
              isDarkMode: isDarkMode,
            ),

            SizedBox(height: 12),

            // Total Carbohydrates
            _MacroNutrientRow(
              label: 'Carboidratos Totais',
              value: '${totalCarbs.toStringAsFixed(0)} g',
              isDarkMode: isDarkMode,
            ),
            if (totalFiber > 0 || totalSugars > 0)
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
                    if (totalFiber > 0)
                      _SubNutrientRow(
                        label: 'Fibra Alimentar',
                        value: '${totalFiber.toStringAsFixed(0)} g',
                        isDarkMode: isDarkMode,
                      ),
                    if (totalSugars > 0)
                      _SubNutrientRow(
                        label: 'Açúcares',
                        value: '${totalSugars.toStringAsFixed(0)} g',
                        isDarkMode: isDarkMode,
                      ),
                  ],
                ),
              ),

            SizedBox(height: 12),

            // Total Fat
            _MacroNutrientRow(
              label: 'Gordura Total',
              value: '${totalFat.toStringAsFixed(0)} g',
              isDarkMode: isDarkMode,
            ),
            if (totalSaturatedFat > 0)
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
                  label: 'Gordura Saturada',
                  value: '${totalSaturatedFat.toStringAsFixed(1)} g',
                  isDarkMode: isDarkMode,
                ),
              ),

            SizedBox(height: 24),

            // Micronutrients Section Header
            Text(
              'Micronutrientes',
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
            if (totalCholesterol > 0)
              _MicroNutrientRow(
                label: 'Colesterol',
                value: '${totalCholesterol.toStringAsFixed(0)} mg',
                isDarkMode: isDarkMode,
              ),
            if (totalCholesterol > 0)
              SizedBox(height: 12),

            if (totalSodium > 0)
              _MicroNutrientRow(
                label: 'Sódio',
                value: '${totalSodium.toStringAsFixed(0)} mg',
                isDarkMode: isDarkMode,
              ),
            if (totalSodium > 0)
              SizedBox(height: 12),

            if (totalPotassium > 0)
              _MicroNutrientRow(
                label: 'Potássio',
                value: '${totalPotassium.toStringAsFixed(0)} mg',
                isDarkMode: isDarkMode,
              ),
            if (totalPotassium > 0)
              SizedBox(height: 12),

            if (totalCalcium > 0)
              _MicroNutrientRow(
                label: 'Cálcio',
                value: '${totalCalcium.toStringAsFixed(0)} mg',
                isDarkMode: isDarkMode,
              ),
            if (totalCalcium > 0)
              SizedBox(height: 12),

            if (totalIron > 0)
              _MicroNutrientRow(
                label: 'Ferro',
                value: '${totalIron.toStringAsFixed(1)} mg',
                isDarkMode: isDarkMode,
              ),
            if (totalIron > 0)
              SizedBox(height: 12),

            if (totalVitaminD > 0)
              _MicroNutrientRow(
                label: 'Vitamina D',
                value: '${totalVitaminD.toStringAsFixed(1)} mcg',
                isDarkMode: isDarkMode,
              ),
            if (totalVitaminD > 0)
              SizedBox(height: 12),

            if (totalVitaminA > 0)
              _MicroNutrientRow(
                label: 'Vitamina A',
                value: '${totalVitaminA.toStringAsFixed(1)} mcg',
                isDarkMode: isDarkMode,
              ),
            if (totalVitaminA > 0)
              SizedBox(height: 12),

            if (totalVitaminC > 0)
              _MicroNutrientRow(
                label: 'Vitamina C',
                value: '${totalVitaminC.toStringAsFixed(1)} mg',
                isDarkMode: isDarkMode,
              ),
            if (totalVitaminC > 0)
              SizedBox(height: 12),

            if (totalVitaminB6 > 0)
              _MicroNutrientRow(
                label: 'Vitamina B6',
                value: '${totalVitaminB6.toStringAsFixed(1)} mg',
                isDarkMode: isDarkMode,
              ),
            if (totalVitaminB6 > 0)
              SizedBox(height: 12),

            if (totalVitaminB12 > 0)
              _MicroNutrientRow(
                label: 'Vitamina B12',
                value: '${totalVitaminB12.toStringAsFixed(1)} mcg',
                isDarkMode: isDarkMode,
              ),
          ],
        ),
      ),
    );
  }

  void _showAddFoodDialog(MealType type) {
    // Navega para a tela de busca de alimentos
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FoodSearchScreen(),
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
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final secondaryTextColor = isDarkMode
        ? Color(0xFFAEB7CE)
        : AppTheme.textSecondaryColor;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: hasFoods ? onExpand : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Emoji icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Color(0xFF2E2E2E)
                          : Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        mealInfo.emoji,
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),

                  // Meal name and calories
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealInfo.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          hasFoods
                              ? '${meal!.totalCalories} / ${_getRecommendedCalories(mealInfo.type)} kcal'
                              : '0 / ${_getRecommendedCalories(mealInfo.type)} kcal',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action button
                  IconButton(
                    icon: Icon(
                      hasFoods
                          ? (isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more)
                          : Icons.add_circle_outline,
                      color: hasFoods
                          ? textColor
                          : AppTheme.primaryColor,
                    ),
                    onPressed: hasFoods ? onExpand : onAddFood,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded && hasFoods) ...[
            Divider(height: 1),
            _buildExpandedContent(context),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final secondaryTextColor = isDarkMode
        ? Color(0xFFAEB7CE)
        : AppTheme.textSecondaryColor;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foods list
          ...meal!.foods.map((food) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Food emoji/icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Color(0xFF2E2E2E)
                          : Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        food.emoji,
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),

                  // Food info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${food.calories} kcal • P: ${food.protein.toStringAsFixed(0)}g • C: ${food.carbs.toStringAsFixed(0)}g • F: ${food.fat.toStringAsFixed(0)}g',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Remove button
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () {
                      Provider.of<DailyMealsProvider>(context, listen: false)
                          .removeFoodFromMeal(mealInfo.type, food);
                    },
                  ),
                ],
              ),
            );
          }).toList(),

          SizedBox(height: 12),

          // Macro breakdown
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Color(0xFF2E2E2E)
                  : Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Macros Totais',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MacroInfo(
                      label: 'Proteína',
                      value: '${meal!.totalProtein.toStringAsFixed(0)}g',
                      color: Color(0xFF9575CD),
                      isDarkMode: isDarkMode,
                    ),
                    _MacroInfo(
                      label: 'Carboidratos',
                      value: '${meal!.totalCarbs.toStringAsFixed(0)}g',
                      color: Color(0xFFA1887F),
                      isDarkMode: isDarkMode,
                    ),
                    _MacroInfo(
                      label: 'Gorduras',
                      value: '${meal!.totalFat.toStringAsFixed(0)}g',
                      color: Color(0xFF90A4AE),
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // Add more food button
          TextButton.icon(
            onPressed: onAddFood,
            icon: Icon(Icons.add, size: 18),
            label: Text('Adicionar mais alimentos'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  int _getRecommendedCalories(MealType type) {
    // Simple distribution based on meal type
    switch (type) {
      case MealType.breakfast:
        return 500;
      case MealType.lunch:
        return 700;
      case MealType.dinner:
        return 600;
      case MealType.snack:
        return 200;
      case MealType.freeMeal:
        return 300;
    }
  }
}

class _MacroInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDarkMode;

  const _MacroInfo({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor,
          ),
        ),
      ],
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
