import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diet_plan_model.dart';
import '../services/ai_service.dart';
import '../providers/nutrition_goals_provider.dart';

class DietPlanProvider extends ChangeNotifier {
  // Map de planos de dieta por data (YYYY-MM-DD)
  final Map<String, DietPlan> _dietPlans = {};

  // Preferências de dieta
  DietPreferences _preferences = DietPreferences();

  // Estado de carregamento
  bool _isLoading = false;
  String? _error;

  // Data selecionada
  DateTime _selectedDate = DateTime.now();

  // AIService para gerar dietas
  final AIService _aiService = AIService();

  // Getters
  Map<String, DietPlan> get dietPlans => _dietPlans;
  DietPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;

  // Get diet plan for selected date
  DietPlan? get currentDietPlan {
    final dateKey = _formatDate(_selectedDate);
    return _dietPlans[dateKey];
  }

  // Check if has diet plan for date
  bool hasDietPlanForDate(DateTime date) {
    final dateKey = _formatDate(date);
    return _dietPlans.containsKey(dateKey);
  }

  DietPlanProvider() {
    _loadFromPreferences();
  }

  // Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Set selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // Update preferences
  void updatePreferences(DietPreferences newPreferences) {
    _preferences = newPreferences;
    _saveToPreferences();
    notifyListeners();
  }

  // Generate diet plan for a specific date
  Future<void> generateDietPlan(
    DateTime date,
    NutritionGoalsProvider nutritionGoals,
    String userId,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Build the prompt for AI
      final prompt = _buildDietPlanPrompt(nutritionGoals);

      print('🍽️ Gerando plano de dieta para ${_formatDate(date)}');
      print('📋 Prompt: $prompt');

      // Call AI service to generate diet plan
      final response = await _aiService.getAnswerStream(
        prompt,
        quality: 'bom',
        userId: userId,
        agentType: 'diet',
        provider: 'google',
      ).join();

      print('📥 Resposta da IA: ${response.substring(0, response.length > 500 ? 500 : response.length)}...');

      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) {
        throw Exception('Não foi possível extrair JSON da resposta da IA');
      }

      final jsonString = jsonMatch.group(0)!;
      final jsonData = jsonDecode(jsonString);

      // Create diet plan from JSON
      final dietPlan = DietPlan.fromJson(jsonData);

      // Update date to match requested date
      final updatedPlan = dietPlan.copyWith(date: _formatDate(date));

      // Store the diet plan
      final dateKey = _formatDate(date);
      _dietPlans[dateKey] = updatedPlan;

      _isLoading = false;
      _error = null;

      // Save to preferences
      await _saveToPreferences();

      notifyListeners();

      print('✅ Plano de dieta gerado com sucesso para $dateKey');
    } catch (e) {
      _isLoading = false;
      _error = 'Erro ao gerar plano de dieta: $e';
      notifyListeners();

      print('❌ Erro ao gerar plano de dieta: $e');
    }
  }

  // Build prompt for AI diet generation
  String _buildDietPlanPrompt(NutritionGoalsProvider nutritionGoals) {
    final userProfile = {
      'age': nutritionGoals.age,
      'sex': nutritionGoals.sex,
      'weight': nutritionGoals.weight,
      'height': nutritionGoals.height,
      'activityLevel': nutritionGoals.activityLevel.toString().split('.').last,
      'fitnessGoal': nutritionGoals.fitnessGoal.toString().split('.').last,
      'dietType': nutritionGoals.dietType.toString().split('.').last,
    };

    final nutritionGoalsMap = {
      'calories': nutritionGoals.caloriesGoal,
      'protein': nutritionGoals.proteinGoal,
      'carbs': nutritionGoals.carbsGoal,
      'fat': nutritionGoals.fatGoal,
    };

    final preferencesMap = _preferences.toJson();

    final inputData = {
      'userProfile': userProfile,
      'nutritionGoals': nutritionGoalsMap,
      'preferences': preferencesMap,
    };

    return '''
Crie um plano de dieta personalizado baseado nos seguintes dados:

${jsonEncode(inputData)}

Você deve retornar APENAS um objeto JSON válido (sem markdown, sem explicações adicionais) com a estrutura:
{
  "date": "YYYY-MM-DD",
  "totalNutrition": {"calories": number, "protein": number, "carbs": number, "fat": number},
  "meals": [
    {
      "type": "breakfast|lunch|dinner|snack",
      "time": "HH:MM",
      "name": "Nome da Refeição",
      "foods": [
        {"name": "Nome do Alimento", "emoji": "🍳", "amount": number, "unit": "g|ml|unidade", "calories": number, "protein": number, "carbs": number, "fat": number}
      ],
      "mealTotals": {"calories": number, "protein": number, "carbs": number, "fat": number}
    }
  ]
}

IMPORTANTE:
- Distribua as calorias de acordo com o número de refeições (${_preferences.mealsPerDay}) e o horário de maior fome (${_preferences.hungriestMealTime})
- Dê 30-40% das calorias diárias para a refeição de maior fome
- A nutrição total deve corresponder às metas dentro de ±5%
- Escolha alimentos da culinária brasileira/portuguesa
- Inclua variedade - não repita muito os mesmos alimentos
- Porções realistas e práticas
- Emojis apropriados para cada alimento
- Retorne APENAS JSON válido - sem blocos de código markdown, sem explicações
''';
  }

  // Replace a single meal with AI
  Future<void> replaceMeal(
    DateTime date,
    String mealType,
    NutritionGoalsProvider nutritionGoals,
    String userId,
  ) async {
    final dateKey = _formatDate(date);
    final currentPlan = _dietPlans[dateKey];

    if (currentPlan == null) {
      _error = 'Nenhum plano de dieta encontrado para esta data';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find the meal to replace
      final mealIndex = currentPlan.meals.indexWhere((m) => m.type == mealType);
      if (mealIndex == -1) {
        throw Exception('Refeição não encontrada');
      }

      final mealToReplace = currentPlan.meals[mealIndex];

      // Build prompt for AI to replace this specific meal
      final prompt = _buildReplaceMealPrompt(mealToReplace, nutritionGoals);

      print('🔄 Substituindo refeição $mealType para $dateKey');

      final response = await _aiService.getAnswerStream(
        prompt,
        quality: 'bom',
        userId: userId,
        agentType: 'diet',
        provider: 'google',
      ).join();

      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) {
        throw Exception('Não foi possível extrair JSON da resposta da IA');
      }

      final jsonString = jsonMatch.group(0)!;
      final jsonData = jsonDecode(jsonString);

      // Create new meal from JSON
      final newMeal = PlannedMeal.fromJson(jsonData);

      // Update the meal in the plan
      final updatedMeals = List<PlannedMeal>.from(currentPlan.meals);
      updatedMeals[mealIndex] = newMeal;

      // Recalculate total nutrition
      final newTotalNutrition = _calculateTotalNutrition(updatedMeals);

      _dietPlans[dateKey] = currentPlan.copyWith(
        meals: updatedMeals,
        totalNutrition: newTotalNutrition,
      );

      _isLoading = false;
      _error = null;

      await _saveToPreferences();
      notifyListeners();

      print('✅ Refeição substituída com sucesso');
    } catch (e) {
      _isLoading = false;
      _error = 'Erro ao substituir refeição: $e';
      notifyListeners();

      print('❌ Erro ao substituir refeição: $e');
    }
  }

  // Build prompt for replacing a single meal
  String _buildReplaceMealPrompt(
    PlannedMeal mealToReplace,
    NutritionGoalsProvider nutritionGoals,
  ) {
    return '''
Crie uma nova refeição mantendo os mesmos macros nutricionais da refeição atual:

Refeição atual:
${jsonEncode(mealToReplace.toJson())}

IMPORTANTE:
- Mantenha o tipo de refeição (${mealToReplace.type}) e horário (${mealToReplace.time})
- Mantenha os totais nutricionais MUITO próximos: ${mealToReplace.mealTotals.calories} cal, ${mealToReplace.mealTotals.protein}g proteína, ${mealToReplace.mealTotals.carbs}g carbs, ${mealToReplace.mealTotals.fat}g gordura
- Use alimentos DIFERENTES dos atuais
- Alimentos da culinária brasileira/portuguesa
- Retorne APENAS um objeto JSON válido (sem markdown) com a estrutura:
{
  "type": "${mealToReplace.type}",
  "time": "${mealToReplace.time}",
  "name": "Nome da Nova Refeição",
  "foods": [
    {"name": "Nome", "emoji": "🍽️", "amount": number, "unit": "g|ml|unidade", "calories": number, "protein": number, "carbs": number, "fat": number}
  ],
  "mealTotals": {"calories": number, "protein": number, "carbs": number, "fat": number}
}
''';
  }

  // Replace all meals for a day
  Future<void> replaceAllMeals(
    DateTime date,
    NutritionGoalsProvider nutritionGoals,
    String userId,
  ) async {
    // Simply generate a new diet plan for this date
    await generateDietPlan(date, nutritionGoals, userId);
  }

  // Calculate total nutrition from meals
  DailyNutrition _calculateTotalNutrition(List<PlannedMeal> meals) {
    int totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final meal in meals) {
      totalCalories += meal.mealTotals.calories;
      totalProtein += meal.mealTotals.protein;
      totalCarbs += meal.mealTotals.carbs;
      totalFat += meal.mealTotals.fat;
    }

    return DailyNutrition(
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
    );
  }

  // Delete diet plan for a date
  void deleteDietPlan(DateTime date) {
    final dateKey = _formatDate(date);
    _dietPlans.remove(dateKey);
    _saveToPreferences();
    notifyListeners();
  }

  // Load from SharedPreferences
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load preferences
      final preferencesJson = prefs.getString('diet_preferences');
      if (preferencesJson != null) {
        _preferences = DietPreferences.fromJson(jsonDecode(preferencesJson));
      }

      // Load diet plans
      final plansJson = prefs.getString('diet_plans');
      if (plansJson != null) {
        final Map<String, dynamic> plansMap = jsonDecode(plansJson);
        _dietPlans.clear();

        plansMap.forEach((dateKey, planJson) {
          _dietPlans[dateKey] = DietPlan.fromJson(planJson);
        });
      }

      notifyListeners();
    } catch (e) {
      print('❌ Erro ao carregar planos de dieta: $e');
    }
  }

  // Save to SharedPreferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save preferences
      await prefs.setString('diet_preferences', jsonEncode(_preferences.toJson()));

      // Save diet plans
      final plansMap = <String, dynamic>{};
      _dietPlans.forEach((dateKey, plan) {
        plansMap[dateKey] = plan.toJson();
      });

      await prefs.setString('diet_plans', jsonEncode(plansMap));
    } catch (e) {
      print('❌ Erro ao salvar planos de dieta: $e');
    }
  }
}
