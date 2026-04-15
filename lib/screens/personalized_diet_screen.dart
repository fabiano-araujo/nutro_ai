import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/macro_theme.dart';
import 'package:provider/provider.dart';
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
import '../screens/meal_page.dart';
import '../screens/nutrition_goals_wizard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/subscription_screen.dart';
import '../i18n/app_localizations.dart';
import '../widgets/diet_style_message_state.dart';

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
    final nutritionGoals =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealTypesProvider =
        Provider.of<MealTypesProvider>(context, listen: false);

    // Check if user is authenticated - open login screen automatically
    if (!authService.isAuthenticated || authService.currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(popOnSuccess: true),
        ),
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

    await dietProvider.ensureLoaded();

    // Check if trying to generate daily diet without premium
    // Weekly diet is free, daily diet is paid
    if (dietProvider.dietMode == DietMode.daily && !dietProvider.isPremium) {
      _showPremiumRequiredDialog();
      return;
    }

    await nutritionGoals.ensureLoaded();

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

    if (!dietProvider.hasCompletedDietPersonalization) {
      final shouldContinue =
          await _showDietGenerationPreferencesDialog(dietProvider);
      if (!mounted || !shouldContinue) {
        return;
      }
    }

    // Get device locale
    final locale = Localizations.localeOf(context);
    final languageCode =
        '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';

    // Get userId from authenticated user
    final userId = authService.currentUser?.id.toString() ?? '';

    // Get meal types from provider
    final mealTypes = mealTypesProvider.mealTypes;
    print(
        '🍽️ PersonalizedDietScreen: Gerando dieta com ${mealTypes.length} refeições');
    print(
        '🍽️ PersonalizedDietScreen: Tipos: ${mealTypes.map((m) => m.name).join(', ')}');

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

  Future<bool> _showDietGenerationPreferencesDialog(
    DietPlanProvider dietProvider,
  ) async {
    final l10n = AppLocalizations.of(context);
    final preferences = dietProvider.preferences;
    final restrictionsController = TextEditingController(
      text: preferences.foodRestrictions.join(', '),
    );
    final favoriteFoodsController = TextEditingController(
      text: preferences.favoriteFoods.join(', '),
    );
    final avoidedFoodsController = TextEditingController(
      text: preferences.avoidedFoods.join(', '),
    );
    final routineController = TextEditingController(
      text: preferences.routineConsiderations.join(', '),
    );
    var selectedHungriestMeal = preferences.hungriestMealTime;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(
                    l10n.translate('diet_generation_preferences_title'),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate(
                            'diet_generation_preferences_description',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: restrictionsController,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_restrictions_label',
                            ),
                            hintText: l10n.translate(
                              'diet_generation_preferences_restrictions_hint',
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: favoriteFoodsController,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_favorite_foods_label',
                            ),
                            hintText: l10n.translate(
                              'diet_generation_preferences_favorite_foods_hint',
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: avoidedFoodsController,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_avoided_foods_label',
                            ),
                            hintText: l10n.translate(
                              'diet_generation_preferences_avoided_foods_hint',
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedHungriestMeal,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_hungriest_label',
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'breakfast',
                              child: Text(l10n.translate('breakfast')),
                            ),
                            DropdownMenuItem(
                              value: 'lunch',
                              child: Text(l10n.translate('lunch')),
                            ),
                            DropdownMenuItem(
                              value: 'dinner',
                              child: Text(l10n.translate('dinner')),
                            ),
                            DropdownMenuItem(
                              value: 'snack',
                              child: Text(l10n.translate('snack')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              selectedHungriestMeal = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: routineController,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_routine_label',
                            ),
                            hintText: l10n.translate(
                              'diet_generation_preferences_routine_hint',
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(l10n.translate('cancel')),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        dietProvider.updateDietGenerationPreferences(
                          foodRestrictions: _splitPreferenceList(
                            restrictionsController.text,
                          ),
                          favoriteFoods: _splitPreferenceList(
                            favoriteFoodsController.text,
                          ),
                          avoidedFoods: _splitPreferenceList(
                            avoidedFoodsController.text,
                          ),
                          routineConsiderations: _splitPreferenceList(
                            routineController.text,
                          ),
                          hungriestMealTime: selectedHungriestMeal,
                          reviewedRestrictions: true,
                          reviewedFoodPreferences: true,
                          reviewedRoutineNeeds: true,
                          mergeRestrictions: false,
                          mergeFoodPreferences: false,
                          mergeRoutineConsiderations: false,
                        );
                        Navigator.pop(dialogContext, true);
                      },
                      child: Text(l10n.translate('continue')),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    restrictionsController.dispose();
    favoriteFoodsController.dispose();
    avoidedFoodsController.dispose();
    routineController.dispose();

    return confirmed;
  }

  List<String> _splitPreferenceList(String rawValue) {
    return rawValue
        .split(RegExp(r'\s*(?:,|;|\n)\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // Show premium required dialog for daily diet
  void _showPremiumRequiredDialog() {
    final l10n = AppLocalizations.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final buttonForegroundColor = AppTheme.onColor(buttonColor);

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
                MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: buttonForegroundColor,
            ),
            child: Text(
              l10n.translate('subscribe_now'),
              style: TextStyle(color: buttonForegroundColor),
            ),
          ),
        ],
      ),
    );
  }

  // Replace a single meal
  Future<void> _replaceMeal(String mealType) async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final nutritionGoals =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealTypesProvider =
        Provider.of<MealTypesProvider>(context, listen: false);
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

    await nutritionGoals.ensureLoaded();

    // Ensure meal types are loaded
    await mealTypesProvider.ensureLoaded();

    final locale = Localizations.localeOf(context);
    final languageCode =
        '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
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
      final nutritionGoals =
          Provider.of<NutritionGoalsProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final mealTypesProvider =
          Provider.of<MealTypesProvider>(context, listen: false);

      await nutritionGoals.ensureLoaded();

      // Ensure meal types are loaded
      await mealTypesProvider.ensureLoaded();

      final locale = Localizations.localeOf(context);
      final languageCode =
          '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
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

  Future<void> _repeatDietToOtherDays() async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
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

    final selectedDates = await _showRepeatDietDialog(dietProvider);
    if (!mounted || selectedDates == null || selectedDates.isEmpty) {
      return;
    }

    final copiedCount = await dietProvider.repeatDietPlanToDates(
      dietProvider.selectedDate,
      selectedDates,
    );

    if (!mounted) return;

    if (dietProvider.error != null) {
      if (dietProvider.error == 'daily_diet_premium_required') {
        _showPremiumRequiredDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dietProvider.error!)),
        );
      }
      return;
    }

    if (copiedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n
                .translate('repeat_diet_success')
                .replaceAll('{count}', copiedCount.toString()),
          ),
        ),
      );
    }
  }

  Future<List<DateTime>?> _showRepeatDietDialog(
    DietPlanProvider dietProvider,
  ) async {
    final l10n = AppLocalizations.of(context);
    final baseDate = DateUtils.dateOnly(dietProvider.selectedDate);
    final candidateDates = List.generate(
      14,
      (index) => baseDate.add(Duration(days: index + 1)),
    );
    final selectedKeys = <String>{};

    return showDialog<List<DateTime>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.translate('repeat_diet_other_days')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.translate('repeat_diet_select_days')),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: candidateDates.map((date) {
                            final dateKey = _formatDateKey(date);
                            final hasExistingPlan =
                                dietProvider.hasDietPlanForDate(date);

                            return CheckboxListTile(
                              value: selectedKeys.contains(dateKey),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(_formatRepeatDateLabel(date)),
                              subtitle: hasExistingPlan
                                  ? Text(
                                      l10n.translate(
                                        'repeat_diet_replace_existing',
                                      ),
                                    )
                                  : null,
                              onChanged: (selected) {
                                setDialogState(() {
                                  if (selected == true) {
                                    selectedKeys.add(dateKey);
                                  } else {
                                    selectedKeys.remove(dateKey);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: selectedKeys.isEmpty
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                            candidateDates
                                .where(
                                  (date) => selectedKeys
                                      .contains(_formatDateKey(date)),
                                )
                                .toList(),
                          ),
                  child: Text(l10n.translate('repeat_diet_apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatRepeatDateLabel(DateTime date) {
    final localeName = Localizations.localeOf(context).toString();
    final formatted = DateFormat('EEE, dd/MM', localeName).format(date);
    return toBeginningOfSentenceCase(formatted) ?? formatted;
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

  String _getMealDisplayName(PlannedMeal meal, AppLocalizations l10n) {
    switch (meal.type) {
      case 'breakfast':
      case 'lunch':
      case 'dinner':
      case 'snack':
        return l10n.translate(meal.type);
      default:
        return meal.name;
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
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
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
                  child:
                      _buildContent(isDarkMode, l10n, dietProvider, isLoading),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDietModeSelector(
      DietPlanProvider dietProvider, bool isDarkMode) {
    final isWeekly = dietProvider.dietMode == DietMode.weekly;
    final selectedColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final selectedTextColor = AppTheme.onColor(selectedColor);
    final unselectedBorderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
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
            color: isWeekly
                ? selectedTextColor
                : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
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
            color: !isWeekly
                ? selectedTextColor
                : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
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

  Widget _buildContent(bool isDarkMode, AppLocalizations l10n,
      DietPlanProvider dietProvider, bool isLoading) {
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

  Widget _buildLoadingWithPartialPlan(
      bool isDarkMode, AppLocalizations l10n, DietPlanProvider dietProvider) {
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

  Widget _buildEmptyState(
      bool isDarkMode, AppLocalizations l10n, DietPlanProvider dietProvider) {
    final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
    final buttonColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    return DietStyleMessageState(
      title: isWeeklyMode
          ? l10n.translate('no_weekly_diet')
          : l10n.translate('no_daily_diet'),
      message: isWeeklyMode
          ? l10n.translate('no_weekly_diet_description')
          : l10n.translate('no_daily_diet_description'),
      fallbackIcon: Icons.restaurant_menu,
      primaryActionLabel: l10n.translate('generate_diet_ai'),
      primaryActionIcon: Icons.auto_awesome,
      onPrimaryAction: _generateDietPlan,
      topSpacing: 40,
      accentColor: buttonColor,
      pinActionsToBottom: true,
    );
  }

  Widget _buildDietContent(bool isDarkMode, AppLocalizations l10n,
      DietPlanProvider dietProvider, DietPlan dietPlan) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
    final accentColor = Theme.of(context).colorScheme.primary;

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
          Text(
            l10n.translate('meals'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (dietPlan.meals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (!isWeeklyMode)
                    TextButton.icon(
                      onPressed: _repeatDietToOtherDays,
                      icon: Icon(
                        Icons.repeat,
                        size: 18,
                        color: accentColor,
                      ),
                      label: Text(
                        l10n.translate('repeat_diet_other_days'),
                        style: TextStyle(color: accentColor),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _replaceAllMeals,
                    icon: Icon(Icons.refresh, size: 18, color: accentColor),
                    label: Text(
                      l10n.translate('replace_all'),
                      style: TextStyle(color: accentColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Lista de refeições
          if (dietPlan.meals.isEmpty)
            _buildEmptyMealsCard(
                isDarkMode, l10n, cardColor, textColor, secondaryTextColor)
          else
            ...dietPlan.meals.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMealCardStyled(
                      meal, isDarkMode, textColor, secondaryTextColor),
                )),

          const SizedBox(height: 80), // Espaço para o FAB
        ],
      ),
    );
  }

  Widget _buildMacroCards(DailyNutrition nutrition, bool isDarkMode) {
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final secondaryColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMacroStat(MacroTheme.caloriesIcon, nutrition.calories.toString(),
              'kcal', MacroTheme.caloriesColor, secondaryColor),
          _buildMacroDivider(isDarkMode),
          _buildMacroStat(MacroTheme.proteinIcon, nutrition.protein.toStringAsFixed(0),
              'g prot', MacroTheme.proteinColor, secondaryColor),
          _buildMacroDivider(isDarkMode),
          _buildMacroStat(MacroTheme.carbsIcon, nutrition.carbs.toStringAsFixed(0),
              'g carb', MacroTheme.carbsColor, secondaryColor),
          _buildMacroDivider(isDarkMode),
          _buildMacroStat(MacroTheme.fatIcon, nutrition.fat.toStringAsFixed(0),
              'g gord', MacroTheme.fatColor, secondaryColor),
        ],
      ),
    );
  }

  Widget _buildMacroStat(IconData icon, String value, String unit, Color color,
      Color secondaryColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroDivider(bool isDarkMode) {
    return Container(
      width: 1,
      height: 32,
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
    );
  }

  Widget _buildMacroCardCompact({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required bool isDarkMode,
    bool isSmall = false,
  }) {
    final secondaryColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isSmall ? 13 : 18),
        SizedBox(height: isSmall ? 2 : 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isSmall ? 11 : 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: isSmall ? 8 : 10,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMealsCard(bool isDarkMode, AppLocalizations l10n,
      Color cardColor, Color textColor, Color secondaryTextColor) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 48,
              color: secondaryTextColor.withValues(alpha: 0.5),
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

  void _openMealPage(PlannedMeal meal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealPage.fromPlannedMeal(meal: meal),
      ),
    );
  }

  Widget _buildMealCardStyled(PlannedMeal meal, bool isDarkMode,
      Color textColor, Color secondaryTextColor) {
    final hasFoods = meal.foods.isNotEmpty;
    final isExpanded = _expandedMeals.contains(meal.type);
    final l10n = AppLocalizations.of(context);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return InkWell(
      onTap: hasFoods ? () => _openMealPage(meal) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Text(
                    _getMealEmoji(meal.type),
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getMealDisplayName(meal, l10n),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasFoods
                              ? '${meal.foods.length} ${meal.foods.length == 1 ? 'item' : 'itens'} • ${meal.mealTotals.calories.toStringAsFixed(0)} kcal'
                              : meal.time,
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
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedMeals.remove(meal.type);
                          } else {
                            _expandedMeals.add(meal.type);
                          }
                        });
                      },
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
                    onPressed: () => _replaceMeal(meal.type),
                    icon: Icon(
                      Icons.refresh,
                      size: 20,
                      color: secondaryTextColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: hasFoods
                  ? _buildExpandedFoodList(
                      meal, isDarkMode, textColor, secondaryTextColor)
                  : const SizedBox.shrink(),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFoodList(PlannedMeal meal, bool isDarkMode,
      Color textColor, Color secondaryTextColor) {
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
            children: meal.foods
                .map((food) => _buildFoodItemStyled(
                    food, isDarkMode, textColor, secondaryTextColor))
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
                value: meal.mealTotals.calories.toStringAsFixed(0),
                unit: 'kcal',
                color: MacroTheme.caloriesColor,
                isDarkMode: isDarkMode,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.proteinIcon,
                value: meal.mealTotals.protein.toStringAsFixed(1),
                unit: 'g prot',
                color: MacroTheme.proteinColor,
                isDarkMode: isDarkMode,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.carbsIcon,
                value: meal.mealTotals.carbs.toStringAsFixed(1),
                unit: 'g carb',
                color: MacroTheme.carbsColor,
                isDarkMode: isDarkMode,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.fatIcon,
                value: meal.mealTotals.fat.toStringAsFixed(1),
                unit: 'g gord',
                color: MacroTheme.fatColor,
                isDarkMode: isDarkMode,
                isSmall: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodItemStyled(PlannedFood food, bool isDarkMode,
      Color textColor, Color secondaryTextColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FoodPage(food: _convertPlannedFoodToFood(food)),
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
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${food.amount.toStringAsFixed(0)} ${food.unit}',
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
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealCard(PlannedMeal meal, bool isDarkMode) {
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final l10n = AppLocalizations.of(context);

    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        tilePadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        childrenPadding: EdgeInsets.zero,
        leading: Text(
          _getMealEmoji(meal.type),
          style: const TextStyle(fontSize: 26),
        ),
        title: Text(
          _getMealDisplayName(meal, l10n),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.2,
            color: (isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor)
                .withValues(alpha: 0.85),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${meal.time} • ${meal.mealTotals.calories} kcal',
            style: GoogleFonts.inter(
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
                  padding: const EdgeInsets.all(6),
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
                ...meal.foods.map((food) => _buildFoodItem(food, isDarkMode)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          (isDarkMode ? Colors.white : Colors.black)
                              .withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMacroCardCompact(
                      icon: MacroTheme.caloriesIcon,
                      value: meal.mealTotals.calories.toStringAsFixed(0),
                      unit: 'kcal',
                      color: MacroTheme.caloriesColor,
                      isDarkMode: isDarkMode,
                      isSmall: true,
                    ),
                    _buildMacroDivider(isDarkMode),
                    _buildMacroCardCompact(
                      icon: MacroTheme.proteinIcon,
                      value: meal.mealTotals.protein.toStringAsFixed(1),
                      unit: 'g prot',
                      color: MacroTheme.proteinColor,
                      isDarkMode: isDarkMode,
                      isSmall: true,
                    ),
                    _buildMacroDivider(isDarkMode),
                    _buildMacroCardCompact(
                      icon: MacroTheme.carbsIcon,
                      value: meal.mealTotals.carbs.toStringAsFixed(1),
                      unit: 'g carb',
                      color: MacroTheme.carbsColor,
                      isDarkMode: isDarkMode,
                      isSmall: true,
                    ),
                    _buildMacroDivider(isDarkMode),
                    _buildMacroCardCompact(
                      icon: MacroTheme.fatIcon,
                      value: meal.mealTotals.fat.toStringAsFixed(1),
                      unit: 'g gord',
                      color: MacroTheme.fatColor,
                      isDarkMode: isDarkMode,
                      isSmall: true,
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
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FoodPage(food: _convertPlannedFoodToFood(food)),
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
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.85),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${food.amount.toStringAsFixed(0)} ${food.unit}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: secondaryTextColor.withValues(alpha: 0.75),
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
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text(
                    'kcal',
                    style: GoogleFonts.inter(
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
