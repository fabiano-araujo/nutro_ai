import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/diet_plan_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/meal_skeleton.dart';
import '../widgets/macro_card_gradient.dart';
import '../models/diet_plan_model.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../screens/food_page.dart';

class PersonalizedDietScreen extends StatefulWidget {
  const PersonalizedDietScreen({Key? key}) : super(key: key);

  @override
  State<PersonalizedDietScreen> createState() => _PersonalizedDietScreenState();
}

class _PersonalizedDietScreenState extends State<PersonalizedDietScreen> {
  // Controle de scroll do header (nutrition summary)
  double _headerOffset = 0.0; // Offset vertical do header (0 = visível, negativo = escondido)
  double _lastScrollPosition = 0.0;
  double _maxHeaderHeight = 100.0; // Altura inicial estimada, será calculada dinamicamente
  final GlobalKey _headerKey = GlobalKey(); // Key para medir a altura real do header
  Timer? _heightCalculationTimer; // Timer para debounce do cálculo de altura
  bool _isCalculatingHeight = false; // Flag para evitar cálculos simultâneos
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Adicionar listener para controlar a visibilidade do nutrition summary
    _scrollController.addListener(_handleScroll);

    // Calcular a altura real do header após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateHeaderHeight();
    });
  }

  @override
  void dispose() {
    // Remover listener do scroll
    _scrollController.removeListener(_handleScroll);

    // Cancelar timer de cálculo de altura
    _heightCalculationTimer?.cancel();

    _scrollController.dispose();
    super.dispose();
  }

  // Método para calcular a altura real do header após o build (com debounce)
  void _calculateHeaderHeight() {
    // Cancelar timer anterior se existir
    _heightCalculationTimer?.cancel();

    // Criar novo timer com debounce de 100ms
    _heightCalculationTimer = Timer(Duration(milliseconds: 100), () {
      if (_isCalculatingHeight) return;

      _isCalculatingHeight = true;
      try {
        final RenderBox? renderBox = _headerKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final newHeight = renderBox.size.height;
          // Só atualizar se a diferença for maior que 5px (evitar recálculos por pequenas variações)
          if (newHeight > 0 && (newHeight - _maxHeaderHeight).abs() > 5) {
            setState(() {
              _maxHeaderHeight = newHeight;
              print('Nutrition summary height calculado dinamicamente: $_maxHeaderHeight px');
            });
          }
        }
      } catch (e) {
        print('Erro ao calcular altura do nutrition summary: $e');
      } finally {
        _isCalculatingHeight = false;
      }
    });
  }

  // Método para controlar o offset do header baseado no scroll (comportamento tipo toolbar Android)
  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final currentScrollPosition = _scrollController.offset;
    final scrollDelta = currentScrollPosition - _lastScrollPosition;

    setState(() {
      // Atualizar o offset do header baseado no movimento do scroll
      // scrollDelta positivo = scrollando para baixo (esconder header)
      // scrollDelta negativo = scrollando para cima (mostrar header)
      _headerOffset -= scrollDelta;

      // Limitar o offset entre -_maxHeaderHeight (totalmente escondido) e 0 (totalmente visível)
      _headerOffset = _headerOffset.clamp(-_maxHeaderHeight, 0.0);

      // Se estiver no topo (offset < 10), forçar header totalmente visível
      if (currentScrollPosition < 10) {
        _headerOffset = 0.0;
      }

      _lastScrollPosition = currentScrollPosition;
    });
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

  // Convert PlannedFood to Food for navigation to FoodPage
  Food _convertPlannedFoodToFood(PlannedFood plannedFood) {
    final nutrient = Nutrient(
      idFood: 0,
      servingSize: plannedFood.amount,
      servingUnit: plannedFood.unit,
      calories: plannedFood.calories.toDouble(),
      protein: plannedFood.protein,
      carbohydrate: plannedFood.carbs,
      fat: plannedFood.fat,
    );

    return Food(
      name: plannedFood.name,
      emoji: plannedFood.emoji,
      amount: '${plannedFood.amount.toStringAsFixed(0)} ${plannedFood.unit}',
      nutrients: [nutrient],
    );
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
                  // Recalcular altura quando o conteúdo mudar
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _calculateHeaderHeight();
                    // Recalcular após 100ms para garantir que o conteúdo foi renderizado
                    Future.delayed(Duration(milliseconds: 100), () {
                      _calculateHeaderHeight();
                    });
                  });

                  // Show incremental loading with partial plan
                  if (dietProvider.isLoading && dietProvider.partialDietPlan != null) {
                    final partialPlan = dietProvider.partialDietPlan!;
                    final loadedMealsCount = partialPlan.meals.length;
                    final expectedMealsCount = dietProvider.expectedMealsCount;

                    return Column(
                      children: [
                        // Nutrition Summary with scroll-to-hide behavior
                        SizedBox(
                          height: (_maxHeaderHeight + _headerOffset).clamp(0.0, _maxHeaderHeight),
                          child: ClipRect(
                            clipBehavior: Clip.hardEdge,
                            child: OverflowBox(
                              maxHeight: _maxHeaderHeight + 50, // +50px margem de segurança para transições
                              alignment: Alignment.topCenter,
                              child: Transform.translate(
                                offset: Offset(0, _headerOffset),
                                child: Container(
                                  key: _headerKey, // Key para medir a altura real do header
                                  child: _buildNutritionSummary(partialPlan.totalNutrition),
                                ),
                              ),
                            ),
                          ),
                        ),

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
                            controller: _scrollController,
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
                      // Nutrition Summary with scroll-to-hide behavior
                      SizedBox(
                        height: (_maxHeaderHeight + _headerOffset).clamp(0.0, _maxHeaderHeight),
                        child: ClipRect(
                          clipBehavior: Clip.hardEdge,
                          child: OverflowBox(
                            maxHeight: _maxHeaderHeight + 50, // +50px margem de segurança para transições
                            alignment: Alignment.topCenter,
                            child: Transform.translate(
                              offset: Offset(0, _headerOffset),
                              child: Container(
                                key: _headerKey, // Key para medir a altura real do header
                                child: _buildNutritionSummary(dietPlan.totalNutrition),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Meals List with button at the end
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
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
            child: MacroCardGradient(
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
            child: MacroCardGradient(
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
            child: MacroCardGradient(
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
            child: MacroCardGradient(
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


  Widget _buildMealCard(PlannedMeal meal, bool isDarkMode) {
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final secondaryTextColor = isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
            _getMealEmoji(meal.type),
            style: const TextStyle(fontSize: 28),
          ),
        ),
        title: Text(
          meal.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${meal.time} • ${meal.mealTotals.calories} kcal',
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
                onTap: () => _replaceMeal(meal.type),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.autorenew,
                    size: 18,
                    color: secondaryTextColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foods list
                ...meal.foods.map((food) => _buildFoodItem(food, isDarkMode)),

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
                        value: meal.mealTotals.calories.toStringAsFixed(0),
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
                        value: meal.mealTotals.protein.toStringAsFixed(1),
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
                        value: meal.mealTotals.carbs.toStringAsFixed(1),
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
                        value: meal.mealTotals.fat.toStringAsFixed(1),
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
        ],
      ),
    );
  }

  Widget _buildFoodItem(PlannedFood food, bool isDarkMode) {
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodPage(food: _convertPlannedFoodToFood(food)),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
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
                        color: textColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1),
                    Text(
                      '${food.amount.toStringAsFixed(0)} ${food.unit}',
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
            ],
          ),
        ),
      ),
    );
  }

}
