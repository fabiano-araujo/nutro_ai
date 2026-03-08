import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../models/meal_model.dart';
import '../models/food_model.dart';
import '../theme/app_theme.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/water_tracker.dart';
import 'manage_meal_types_screen.dart';
import 'nutrition_goals_screen.dart';
import 'food_search_screen.dart';
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

  Future<void> _showDatePicker(BuildContext context) async {
    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);
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
            icon: Icon(Icons.calendar_today,
                color: textColor.withValues(alpha: 0.85)),
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
                // Weekly Calendar - dias da semana
                WeeklyCalendar(
                  selectedDate: mealsProvider.selectedDate,
                  onDaySelected: (date) {
                    mealsProvider.setSelectedDate(date);
                  },
                  showAppBar: false,
                  showCalendar: true,
                ),
                SizedBox(height: 8),

                // Nutrition summary header with edit button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('daily_goals') ??
                            'Metas Diárias',
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
                  ),
                ),

                SizedBox(height: 12),

                // Water Tracker
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      WaterTracker(
                        consumed: mealsProvider.todayWaterGlasses,
                        goal: mealsProvider.waterGoal,
                        onAdd: () => mealsProvider.addWater(),
                        onRemove: () => mealsProvider.removeWater(),
                      ),
                      const Spacer(),
                    ],
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
                          : AppTheme.primaryColor.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color:
                          isDarkMode ? Colors.white70 : AppTheme.primaryColor,
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
                            .translate('configure_meals_description') ??
                        'Crie suas refeições (café, almoço...) para começar a registrar sua dieta.',
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
                    label: Text(AppLocalizations.of(context)
                            .translate('configure_meals') ??
                        'Configurar Refeições'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
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
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

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
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: cardColor,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Macronutrients Section Header
              Text(
                AppLocalizations.of(context).translate('daily_summary') ??
                    'Resumo Diário',
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
                      color: Color(0xFF9575CD).withValues(alpha: 0.3),
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
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: hasFoods ? onExpand : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        mealInfo.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                          const SizedBox(height: 2),
                          Text(
                            hasFoods
                                ? '${meal!.foods.length} ${meal!.foods.length == 1 ? 'item' : 'itens'} • ${meal!.totalCalories.toStringAsFixed(0)} kcal'
                                : '0 kcal',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasFoods)
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 24,
                          color: secondaryTextColor.withValues(alpha: 0.7),
                        ),
                      ),
                    IconButton(
                      onPressed: onAddFood,
                      icon: Icon(
                        Icons.add_circle_outline,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: hasFoods ? _buildExpandedFoodList(context, secondaryTextColor) : const SizedBox.shrink(),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedFoodList(BuildContext context, Color secondaryTextColor) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: meal!.foods.map((food) => _buildFoodItem(food, context, secondaryTextColor)).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _buildMacroCardCompact(
                  emoji: '🔥',
                  value: meal!.totalCalories.toStringAsFixed(0),
                  unit: 'kcal',
                  color: const Color(0xFFFF6B9D),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMacroCardCompact(
                  emoji: '💪',
                  value: meal!.totalProtein.toStringAsFixed(1),
                  unit: 'g prot',
                  color: const Color(0xFF9575CD),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMacroCardCompact(
                  emoji: '🌾',
                  value: meal!.totalCarbs.toStringAsFixed(1),
                  unit: 'g carb',
                  color: const Color(0xFFFFB74D),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMacroCardCompact(
                  emoji: '🥑',
                  value: meal!.totalFat.toStringAsFixed(1),
                  unit: 'g gord',
                  color: const Color(0xFF4DB6AC),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroCardCompact({
    required String emoji,
    required String value,
    required String unit,
    required Color color,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 8,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(Food food, BuildContext context, Color secondaryTextColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: Text(
                  food.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${food.amount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${food.calories} kcal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
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
