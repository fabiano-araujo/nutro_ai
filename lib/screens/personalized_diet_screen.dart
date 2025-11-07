import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/meal_skeleton.dart';
import '../models/diet_plan_model.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class PersonalizedDietScreen extends StatefulWidget {
  const PersonalizedDietScreen({Key? key}) : super(key: key);

  @override
  State<PersonalizedDietScreen> createState() => _PersonalizedDietScreenState();
}

class _PersonalizedDietScreenState extends State<PersonalizedDietScreen> {
  @override
  void initState() {
    super.initState();
  }

  // Show dialog to configure diet preferences
  Future<void> _showPreferencesDialog() async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final currentPrefs = dietProvider.preferences;

    int selectedMeals = currentPrefs.mealsPerDay;
    String selectedHungriestTime = currentPrefs.hungriestMealTime;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Preferências da Dieta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quantas refeições por dia?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: selectedMeals,
                      isExpanded: true,
                      items: [3, 4, 5, 6].map((meals) {
                        return DropdownMenuItem(
                          value: meals,
                          child: Text('$meals refeições'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedMeals = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Qual horário você sente mais fome?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedHungriestTime,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'breakfast', child: Text('☀️ Café da Manhã')),
                        DropdownMenuItem(value: 'lunch', child: Text('🌞 Almoço')),
                        DropdownMenuItem(value: 'dinner', child: Text('🌙 Jantar')),
                        DropdownMenuItem(value: 'snack', child: Text('🍎 Lanche')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedHungriestTime = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Estas informações serão usadas para criar um plano de dieta personalizado com a distribuição ideal de calorias.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newPrefs = currentPrefs.copyWith(
                      mealsPerDay: selectedMeals,
                      hungriestMealTime: selectedHungriestTime,
                    );
                    dietProvider.updatePreferences(newPrefs);
                    Navigator.pop(context);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Generate diet plan for selected date
  Future<void> _generateDietPlan() async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final nutritionGoals = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if nutrition goals are configured
    if (!nutritionGoals.hasConfiguredGoals) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure seus objetivos nutricionais primeiro')),
      );
      return;
    }

    // Show preferences dialog first
    await _showPreferencesDialog();

    // Get device locale
    final locale = Localizations.localeOf(context);
    final languageCode = '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';

    // Get userId from authenticated user
    final userId = authService.currentUser?.id.toString() ?? '';

    // Generate diet plan
    await dietProvider.generateDietPlan(
      dietProvider.selectedDate,
      nutritionGoals,
      userId: userId,
      languageCode: languageCode,
    );

    if (dietProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dietProvider.error!)),
      );
    }
  }

  // Replace a single meal
  Future<void> _replaceMeal(String mealType) async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final nutritionGoals = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Get device locale
    final locale = Localizations.localeOf(context);
    final languageCode = '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';

    // Get userId from authenticated user
    final userId = authService.currentUser?.id.toString() ?? '';

    await dietProvider.replaceMeal(
      dietProvider.selectedDate,
      mealType,
      nutritionGoals,
      userId: userId,
      languageCode: languageCode,
    );

    if (dietProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dietProvider.error!)),
      );
    }
  }

  // Replace all meals
  Future<void> _replaceAllMeals() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Substituir Todas as Refeições'),
        content: const Text('Deseja gerar um novo plano de dieta completo para este dia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim, Gerar Novo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
      final nutritionGoals = Provider.of<NutritionGoalsProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      // Get device locale
      final locale = Localizations.localeOf(context);
      final languageCode = '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';

      // Get userId from authenticated user
      final userId = authService.currentUser?.id.toString() ?? '';

      await dietProvider.replaceAllMeals(
        dietProvider.selectedDate,
        nutritionGoals,
        userId: userId,
        languageCode: languageCode,
      );

      if (dietProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dietProvider.error!)),
        );
      }
    }
  }

  // Get emoji for meal type
  String _getMealEmoji(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return '🍳';
      case 'lunch':
        return '🍽️';
      case 'dinner':
        return '🍝';
      case 'snack':
        return '🍎';
      default:
        return '🍴';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Weekly Calendar
            Consumer<DietPlanProvider>(
              builder: (context, dietProvider, _) {
                return WeeklyCalendar(
                  selectedDate: dietProvider.selectedDate,
                  onDaySelected: (date) {
                    dietProvider.setSelectedDate(date);
                  },
                  showAppBar: true,
                  showCalendar: true,
                );
              },
            ),

            const SizedBox(height: 8),

            // Diet Plan Content
            Expanded(
              child: Consumer<DietPlanProvider>(
                builder: (context, dietProvider, _) {
                  // Show incremental loading with partial plan
                  if (dietProvider.isLoading && dietProvider.partialDietPlan != null) {
                    final partialPlan = dietProvider.partialDietPlan!;
                    final loadedMealsCount = partialPlan.meals.length;
                    final expectedMealsCount = dietProvider.expectedMealsCount;

                    return Column(
                      children: [
                        // Nutrition Summary
                        _buildNutritionSummary(partialPlan.totalNutrition),

                        const SizedBox(height: 4),

                        // Progress indicator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Gerando refeições... ($loadedMealsCount/$expectedMealsCount)',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Meals List with skeletons for pending meals
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: expectedMealsCount + 1, // +1 for the button at the end
                            itemBuilder: (context, index) {
                              // Last item is the button
                              if (index == expectedMealsCount) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ElevatedButton.icon(
                                    onPressed: null, // Disabled during loading
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Substituir Todas as Refeições'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 44),
                                    ),
                                  ),
                                );
                              }

                              if (index < loadedMealsCount) {
                                // Show loaded meal
                                final meal = partialPlan.meals[index];
                                return _buildMealCard(meal, isDarkMode);
                              } else {
                                // Show skeleton for pending meal
                                return const MealSkeleton();
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  }

                  // Show simple loading (no partial plan yet)
                  if (dietProvider.isLoading) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Gerando plano de dieta personalizado...'),
                        ],
                      ),
                    );
                  }

                  final dietPlan = dietProvider.currentDietPlan;

                  if (dietPlan == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum plano de dieta para este dia',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _generateDietPlan,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Gerar Plano de Dieta'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Nutrition Summary
                      _buildNutritionSummary(dietPlan.totalNutrition),

                      const SizedBox(height: 4),

                      // Meals List with button at the end
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: dietPlan.meals.length + 1, // +1 for the button at the end
                          itemBuilder: (context, index) {
                            // Last item is the button
                            if (index == dietPlan.meals.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ElevatedButton.icon(
                                  onPressed: _replaceAllMeals,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Substituir Todas as Refeições'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 44),
                                  ),
                                ),
                              );
                            }

                            final meal = dietPlan.meals[index];
                            return _buildMealCard(meal, isDarkMode);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSummary(DailyNutrition nutrition) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildMacroCardGradient(
              icon: '🔥',
              label: 'Calorias',
              value: nutrition.calories.toStringAsFixed(0),
              unit: 'kcal',
              startColor: const Color(0xFFFF6B9D),
              endColor: const Color(0xFFFFA06B),
              isDarkMode: isDarkMode,
              isCompact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMacroCardGradient(
              icon: '💪',
              label: 'Proteínas',
              value: nutrition.protein.toStringAsFixed(1),
              unit: 'g',
              startColor: const Color(0xFF9575CD),
              endColor: const Color(0xFFBA68C8),
              isDarkMode: isDarkMode,
              isCompact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMacroCardGradient(
              icon: '🌾',
              label: 'Carboidratos',
              value: nutrition.carbs.toStringAsFixed(1),
              unit: 'g',
              startColor: const Color(0xFFFFB74D),
              endColor: const Color(0xFFFF9800),
              isDarkMode: isDarkMode,
              isCompact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMacroCardGradient(
              icon: '🥑',
              label: 'Gorduras',
              value: nutrition.fat.toStringAsFixed(1),
              unit: 'g',
              startColor: const Color(0xFF4DB6AC),
              endColor: const Color(0xFF26A69A),
              isDarkMode: isDarkMode,
              isCompact: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCardGradient({
    required String icon,
    required String label,
    required String value,
    required String unit,
    required Color startColor,
    required Color endColor,
    required bool isDarkMode,
    bool isCompact = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor.withValues(alpha: isDarkMode ? 0.3 : 0.15),
            endColor.withValues(alpha: isDarkMode ? 0.2 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: startColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(PlannedMeal meal, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Text(
          _getMealEmoji(meal.type),
          style: const TextStyle(fontSize: 32),
        ),
        title: Text(
          meal.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${meal.time} • ${meal.mealTotals.calories} cal',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.autorenew),
          onPressed: () => _replaceMeal(meal.type),
          tooltip: 'Substituir esta refeição',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foods list
                ...meal.foods.map((food) => _buildFoodItem(food)),

                const Divider(height: 24),

                // Meal totals
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMealTotal('Calorias', '${meal.mealTotals.calories}'),
                    _buildMealTotal('Proteína', '${meal.mealTotals.protein.toStringAsFixed(1)}g'),
                    _buildMealTotal('Carboidratos', '${meal.mealTotals.carbs.toStringAsFixed(1)}g'),
                    _buildMealTotal('Gordura', '${meal.mealTotals.fat.toStringAsFixed(1)}g'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(PlannedFood food) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(food.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${food.amount.toStringAsFixed(0)} ${food.unit}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '${food.calories} cal',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTotal(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
