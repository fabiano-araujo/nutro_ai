import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../widgets/weekly_calendar.dart';
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
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNutritionItem('🔥', '${dietPlan.totalNutrition.calories} cal'),
                            _buildNutritionItem('💪', '${dietPlan.totalNutrition.protein.toStringAsFixed(1)}g P'),
                            _buildNutritionItem('🌾', '${dietPlan.totalNutrition.carbs.toStringAsFixed(1)}g C'),
                            _buildNutritionItem('🥑', '${dietPlan.totalNutrition.fat.toStringAsFixed(1)}g G'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Replace All Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          onPressed: _replaceAllMeals,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Substituir Todas as Refeições'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Meals List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: dietPlan.meals.length,
                          itemBuilder: (context, index) {
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

  Widget _buildNutritionItem(String emoji, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
