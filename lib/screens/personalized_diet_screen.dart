import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/meal_skeleton.dart';
import '../models/diet_plan_model.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../screens/food_page.dart';
import '../screens/nutrition_goals_wizard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/subscription_screen.dart';
import '../i18n/app_localizations.dart';

class PersonalizedDietScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onSearchPressed;

  const PersonalizedDietScreen({
    Key? key,
    this.onOpenDrawer,
    this.onSearchPressed,
  }) : super(key: key);

  @override
  State<PersonalizedDietScreen> createState() => _PersonalizedDietScreenState();
}

class _PersonalizedDietScreenState extends State<PersonalizedDietScreen> {
  final ScrollController _scrollController = ScrollController();

  // Controle de refeições expandidas
  final Set<String> _expandedMeals = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Generate diet plan for selected date
  Future<void> _generateDietPlan() async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final nutritionGoals = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealTypesProvider = Provider.of<MealTypesProvider>(context, listen: false);

    // Check if user is authenticated - open login screen automatically
    if (!authService.isAuthenticated || authService.currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    // Set auth on diet provider
    if (!dietProvider.isAuthenticated) {
      await dietProvider.setAuth(
        authService.token ?? '',
        authService.currentUser!.id,
      );
    }

    // Check if trying to generate daily diet without premium
    // Weekly diet is free, daily diet is paid
    if (dietProvider.dietMode == DietMode.daily && !dietProvider.isPremium) {
      _showPremiumRequiredDialog();
      return;
    }

    // Check if nutrition goals are configured
    if (!nutritionGoals.hasConfiguredGoals) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NutritionGoalsWizardScreen(),
        ),
      );
      return;
    }

    // Ensure meal types are loaded
    await mealTypesProvider.ensureLoaded();

    // Get device locale
    final locale = Localizations.localeOf(context);
    final languageCode = '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';

    // Get userId from authenticated user
    final userId = authService.currentUser?.id.toString() ?? '';

    // Get meal types from provider
    final mealTypes = mealTypesProvider.mealTypes;
    print('🍽️ PersonalizedDietScreen: Gerando dieta com ${mealTypes.length} refeições');
    print('🍽️ PersonalizedDietScreen: Tipos: ${mealTypes.map((m) => m.name).join(', ')}');

    // Generate diet plan
    await dietProvider.generateDietPlan(
      dietProvider.selectedDate,
      nutritionGoals,
      mealTypes: mealTypes,
      userId: userId,
      languageCode: languageCode,
    );

    if (dietProvider.error != null) {
      // Check if error is premium required
      if (dietProvider.error == 'daily_diet_premium_required') {
        _showPremiumRequiredDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dietProvider.error!)),
        );
      }
    }
  }

  // Show premium required dialog for daily diet
  void _showPremiumRequiredDialog() {
    final l10n = AppLocalizations.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: buttonColor),
            const SizedBox(width: 8),
            Text(l10n.translate('daily_diet_premium_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('daily_diet_premium_description')),
            const SizedBox(height: 12),
            Text(
              l10n.translate('weekly_diet_free'),
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
            ),
            child: Text(
              l10n.translate('subscribe_now'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Replace a single meal
  Future<void> _replaceMeal(String mealType) async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final nutritionGoals = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealTypesProvider = Provider.of<MealTypesProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_required_for_diet'))),
      );
      return;
    }

    if (!dietProvider.isAuthenticated) {
      await dietProvider.setAuth(
        authService.token ?? '',
        authService.currentUser!.id,
      );
    }

    // Ensure meal types are loaded
    await mealTypesProvider.ensureLoaded();

    final locale = Localizations.localeOf(context);
    final languageCode = '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
    final userId = authService.currentUser?.id.toString() ?? '';

    await dietProvider.replaceMeal(
      dietProvider.selectedDate,
      mealType,
      nutritionGoals,
      mealTypes: mealTypesProvider.mealTypes,
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
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('replace_all_meals')),
        content: Text(isWeeklyMode
            ? l10n.translate('replace_all_meals_weekly_confirm')
            : l10n.translate('replace_all_meals_daily_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.translate('yes_generate_new')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final nutritionGoals = Provider.of<NutritionGoalsProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final mealTypesProvider = Provider.of<MealTypesProvider>(context, listen: false);

      // Ensure meal types are loaded
      await mealTypesProvider.ensureLoaded();

      final locale = Localizations.localeOf(context);
      final languageCode = '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
      final userId = authService.currentUser?.id.toString() ?? '';

      await dietProvider.replaceAllMeals(
        dietProvider.selectedDate,
        nutritionGoals,
        mealTypes: mealTypesProvider.mealTypes,
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer<DietPlanProvider>(
          builder: (context, dietProvider, _) {
            final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
            final isLoading = dietProvider.isLoading;

            return Column(
              children: [
                // AppBar sempre visível
                WeeklyCalendar(
                  selectedDate: dietProvider.selectedDate,
                  onDaySelected: (date) {
                    dietProvider.setSelectedDate(date);
                  },
                  showAppBar: true,
                  showCalendar: !isWeeklyMode,
                  onOpenDrawer: widget.onOpenDrawer,
                  onSearchPressed: widget.onSearchPressed,
                ),

                // Chips sempre visíveis
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildDietModeSelector(dietProvider, isDarkMode),
                ),

                // Conteúdo principal
                Expanded(
                  child: _buildContent(isDarkMode, l10n, dietProvider, isLoading),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDietModeSelector(DietPlanProvider dietProvider, bool isDarkMode) {
    final isWeekly = dietProvider.dietMode == DietMode.weekly;
    final selectedColor = isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final unselectedBorderColor = isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: SizedBox(
            width: 100,
            child: Text(
              l10n.translate('weekly_diet'),
              textAlign: TextAlign.center,
            ),
          ),
          selected: isWeekly,
          onSelected: (selected) {
            if (selected) dietProvider.setDietMode(DietMode.weekly);
          },
          selectedColor: selectedColor,
          backgroundColor: cardColor,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isWeekly ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
          ),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isWeekly ? selectedColor : unselectedBorderColor,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: SizedBox(
            width: 100,
            child: Text(
              l10n.translate('daily_diet'),
              textAlign: TextAlign.center,
            ),
          ),
          selected: !isWeekly,
          onSelected: (selected) {
            if (selected) dietProvider.setDietMode(DietMode.daily);
          },
          selectedColor: selectedColor,
          backgroundColor: cardColor,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: !isWeekly ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
          ),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: !isWeekly ? selectedColor : unselectedBorderColor,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ],
    );
  }

  Widget _buildContent(bool isDarkMode, AppLocalizations l10n, DietPlanProvider dietProvider, bool isLoading) {
    // Carregamento incremental
    if (isLoading && dietProvider.partialDietPlan != null) {
      return _buildLoadingWithPartialPlan(isDarkMode, l10n, dietProvider);
    }

    // Carregamento simples
    if (isLoading) {
      return _buildSimpleLoading(l10n);
    }

    final dietPlan = dietProvider.currentDietPlan;

    // Sem dieta - mostrar estado vazio
    if (dietPlan == null) {
      return _buildEmptyState(isDarkMode, l10n, dietProvider);
    }

    // Com dieta - mostrar conteúdo
    return _buildDietContent(isDarkMode, l10n, dietProvider, dietPlan);
  }

  Widget _buildSimpleLoading(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.translate('generating_diet_plan')),
        ],
      ),
    );
  }

  Widget _buildLoadingWithPartialPlan(bool isDarkMode, AppLocalizations l10n, DietPlanProvider dietProvider) {
    final partialPlan = dietProvider.partialDietPlan!;
    final loadedMealsCount = partialPlan.meals.length;
    final expectedMealsCount = dietProvider.expectedMealsCount;

    return Column(
      children: [
        // Macros parciais
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildMacroCards(partialPlan.totalNutrition, isDarkMode),
        ),
        const SizedBox(height: 12),

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
                '${l10n.translate('generating_meals')} ($loadedMealsCount/$expectedMealsCount)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Lista de refeições com skeletons
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            itemCount: expectedMealsCount,
            itemBuilder: (context, index) {
              if (index < loadedMealsCount) {
                final meal = partialPlan.meals[index];
                return _buildMealCard(meal, isDarkMode);
              } else {
                return const MealSkeleton();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDarkMode, AppLocalizations l10n, DietPlanProvider dietProvider) {
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
    final buttonColor = isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Animação Lottie de comida/dieta
          Lottie.network(
            'https://assets9.lottiefiles.com/packages/lf20_tljjahng.json',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: 72,
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Título
          Text(
            isWeeklyMode
                ? l10n.translate('no_weekly_diet')
                : l10n.translate('no_daily_diet'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Descrição
          Text(
            isWeeklyMode
                ? l10n.translate('no_weekly_diet_description')
                : l10n.translate('no_daily_diet_description'),
            style: TextStyle(
              fontSize: 14,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Botão para gerar dieta
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateDietPlan,
              icon: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
              ),
              label: Text(
                l10n.translate('generate_diet_ai'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietContent(bool isDarkMode, AppLocalizations l10n, DietPlanProvider dietProvider, DietPlan dietPlan) {
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cards de macros nutricionais
          _buildMacroCards(dietPlan.totalNutrition, isDarkMode),
          const SizedBox(height: 24),

          // Título da seção de refeições
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.translate('meals'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (dietPlan.meals.isNotEmpty)
                TextButton.icon(
                  onPressed: _replaceAllMeals,
                  icon: Icon(Icons.refresh, size: 18, color: AppTheme.primaryColor),
                  label: Text(
                    l10n.translate('replace_all'),
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista de refeições
          if (dietPlan.meals.isEmpty)
            _buildEmptyMealsCard(isDarkMode, l10n, cardColor, textColor, secondaryTextColor)
          else
            ...dietPlan.meals.map((meal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMealCardStyled(meal, isDarkMode, cardColor, textColor, secondaryTextColor),
            )),

          const SizedBox(height: 80), // Espaço para o FAB
        ],
      ),
    );
  }

  Widget _buildMacroCards(DailyNutrition nutrition, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildMacroCardCompact(
            emoji: '🔥',
            value: nutrition.calories.toString(),
            unit: 'kcal',
            color: const Color(0xFFFF6B9D),
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMacroCardCompact(
            emoji: '💪',
            value: nutrition.protein.toStringAsFixed(0),
            unit: 'g prot',
            color: const Color(0xFF9575CD),
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMacroCardCompact(
            emoji: '🌾',
            value: nutrition.carbs.toStringAsFixed(0),
            unit: 'g carb',
            color: const Color(0xFFFFB74D),
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMacroCardCompact(
            emoji: '🥑',
            value: nutrition.fat.toStringAsFixed(0),
            unit: 'g gord',
            color: const Color(0xFF4DB6AC),
            isDarkMode: isDarkMode,
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
    required bool isDarkMode,
    bool isSmall = false,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmall ? 6 : 12,
        horizontal: isSmall ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: TextStyle(fontSize: isSmall ? 14 : 20)),
          SizedBox(height: isSmall ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 12 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: isSmall ? 8 : 10,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMealsCard(bool isDarkMode, AppLocalizations l10n, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 48,
              color: secondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate('no_meals_yet'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.translate('add_meals_description'),
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCardStyled(PlannedMeal meal, bool isDarkMode, Color cardColor, Color textColor, Color secondaryTextColor) {
    final hasFoods = meal.foods.isNotEmpty;
    final isExpanded = _expandedMeals.contains(meal.type);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: hasFoods ? () {
          setState(() {
            if (isExpanded) {
              _expandedMeals.remove(meal.type);
            } else {
              _expandedMeals.add(meal.type);
            }
          });
        } : null,
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
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getMealEmoji(meal.type),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasFoods
                                ? '${meal.foods.length} ${meal.foods.length == 1 ? 'item' : 'itens'} • ${meal.mealTotals.calories.toStringAsFixed(0)} kcal'
                                : meal.time,
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
                          color: secondaryTextColor.withOpacity(0.7),
                        ),
                      ),
                    IconButton(
                      onPressed: () => _replaceMeal(meal.type),
                      icon: Icon(
                        Icons.refresh,
                        size: 20,
                        color: secondaryTextColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: hasFoods ? _buildExpandedFoodList(meal, isDarkMode, textColor, secondaryTextColor) : const SizedBox.shrink(),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedFoodList(PlannedMeal meal, bool isDarkMode, Color textColor, Color secondaryTextColor) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                (isDarkMode ? Colors.white : Colors.black).withOpacity(0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: meal.foods.map((food) => _buildFoodItemStyled(food, isDarkMode, textColor, secondaryTextColor)).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _buildMacroCardCompact(
                  emoji: '🔥',
                  value: meal.mealTotals.calories.toStringAsFixed(0),
                  unit: 'kcal',
                  color: const Color(0xFFFF6B9D),
                  isDarkMode: isDarkMode,
                  isSmall: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMacroCardCompact(
                  emoji: '💪',
                  value: meal.mealTotals.protein.toStringAsFixed(1),
                  unit: 'g prot',
                  color: const Color(0xFF9575CD),
                  isDarkMode: isDarkMode,
                  isSmall: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMacroCardCompact(
                  emoji: '🌾',
                  value: meal.mealTotals.carbs.toStringAsFixed(1),
                  unit: 'g carb',
                  color: const Color(0xFFFFB74D),
                  isDarkMode: isDarkMode,
                  isSmall: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMacroCardCompact(
                  emoji: '🥑',
                  value: meal.mealTotals.fat.toStringAsFixed(1),
                  unit: 'g gord',
                  color: const Color(0xFF4DB6AC),
                  isDarkMode: isDarkMode,
                  isSmall: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodItemStyled(PlannedFood food, bool isDarkMode, Color textColor, Color secondaryTextColor) {
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
                        color: textColor.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${food.amount.toStringAsFixed(0)} ${food.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor.withOpacity(0.7),
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
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealCard(PlannedMeal meal, bool isDarkMode) {
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final secondaryTextColor = isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shadowColor: isDarkMode
          ? Colors.black.withOpacity(0.3)
          : Colors.black.withOpacity(0.08),
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
            color: (isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor).withOpacity(0.85),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${meal.time} • ${meal.mealTotals.calories} kcal',
            style: TextStyle(
              color: secondaryTextColor.withOpacity(0.7),
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
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.autorenew,
                    size: 18,
                    color: secondaryTextColor.withOpacity(0.5),
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
                ...meal.foods.map((food) => _buildFoodItem(food, isDarkMode)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          (isDarkMode ? Colors.white : Colors.black).withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildMacroCardCompact(
                        emoji: '🔥',
                        value: meal.mealTotals.calories.toStringAsFixed(0),
                        unit: 'kcal',
                        color: const Color(0xFFFF6B9D),
                        isDarkMode: isDarkMode,
                        isSmall: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMacroCardCompact(
                        emoji: '💪',
                        value: meal.mealTotals.protein.toStringAsFixed(1),
                        unit: 'g prot',
                        color: const Color(0xFF9575CD),
                        isDarkMode: isDarkMode,
                        isSmall: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMacroCardCompact(
                        emoji: '🌾',
                        value: meal.mealTotals.carbs.toStringAsFixed(1),
                        unit: 'g carb',
                        color: const Color(0xFFFFB74D),
                        isDarkMode: isDarkMode,
                        isSmall: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMacroCardCompact(
                        emoji: '🥑',
                        value: meal.mealTotals.fat.toStringAsFixed(1),
                        unit: 'g gord',
                        color: const Color(0xFF4DB6AC),
                        isDarkMode: isDarkMode,
                        isSmall: true,
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
    final secondaryTextColor = isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: Text(
                  food.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 10),
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
                        color: textColor.withOpacity(0.85),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${food.amount.toStringAsFixed(0)} ${food.unit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryTextColor.withOpacity(0.75),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    '${food.calories}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text(
                    'kcal',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.7),
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
