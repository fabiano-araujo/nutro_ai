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
    NutritionGoalsProvider nutritionGoals, {
    String userId = '',
    String languageCode = 'pt_BR',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Build the prompt for AI
      final prompt = _buildDietPlanPrompt(nutritionGoals);

      print('🍽️ Gerando plano de dieta para ${_formatDate(date)}');
      print('📋 Prompt: $prompt');
      print('🌍 Locale: $languageCode');
      print('👤 UserId: $userId');
      print('🤖 AgentType: diet, Provider: Hyperbolic');

      // Call AI service to generate diet plan
      print('⏳ Iniciando stream da API...');

      final stream = _aiService.getAnswerStream(
        prompt,
        languageCode: languageCode,
        quality: 'google/gemma-3-27b-it',
        userId: userId,
        agentType: 'diet',
        provider: 'Hyperbolic',
      );

      // Initialize progressive diet plan
      final dateKey = _formatDate(date);
      final List<PlannedMeal> progressiveMeals = [];
      DailyNutrition? finalTotalNutrition;

      final StringBuffer lineBuffer = StringBuffer();
      String? connectionId;
      int chunkCount = 0;

      await for (var chunk in stream) {
        chunkCount++;
        print('📦 Diet - Chunk #$chunkCount recebido: ${chunk.length} chars');

        // Remove connection ID marker if present
        if (chunk.contains('[CONEXAO_ID]')) {
          try {
            final marcadorIndex = chunk.indexOf('[CONEXAO_ID]');
            connectionId = chunk.substring(marcadorIndex + 12);
            print('🔑 Diet - Connection ID extracted: $connectionId');
            chunk = chunk.replaceAll('[CONEXAO_ID]$connectionId', '');
            if (chunk.isEmpty) continue;
          } catch (e) {
            print('❌ Diet - Error processing connection ID: $e');
          }
        }

        // Add chunk to line buffer
        lineBuffer.write(chunk);

        // Process complete lines (NDJSON format)
        final lines = lineBuffer.toString().split('\n');

        // Keep the last incomplete line in buffer
        lineBuffer.clear();
        if (!lines.last.trim().endsWith('}')) {
          lineBuffer.write(lines.last);
          lines.removeLast();
        }

        // Process each complete line
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          try {
            print('🔍 Tentando parsear linha NDJSON: $trimmedLine');
            final jsonData = jsonDecode(trimmedLine);

            // Check if it's a meal or total nutrition
            if (jsonData.containsKey('type') && jsonData.containsKey('foods')) {
              // It's a meal
              final meal = PlannedMeal.fromJson(jsonData);
              progressiveMeals.add(meal);
              print('✅ Refeição recebida: ${meal.name} (${meal.type})');

              // Update UI with progressive meals
              _dietPlans[dateKey] = DietPlan(
                date: dateKey,
                meals: List.from(progressiveMeals),
                totalNutrition: finalTotalNutrition ?? _calculateTotalNutrition(progressiveMeals),
              );

              // Notify listeners to update UI immediately
              notifyListeners();

            } else if (jsonData.containsKey('totalNutrition')) {
              // It's the final total nutrition
              finalTotalNutrition = DailyNutrition.fromJson(jsonData['totalNutrition']);
              print('✅ Total nutricional recebido: ${finalTotalNutrition.calories} cal');
            }
          } catch (e) {
            print('⚠️ Erro ao parsear linha NDJSON: $e');
            print('   Linha: $trimmedLine');
            // Continue processing other lines
          }
        }
      }

      print('✓ Diet - Stream finalizado! Chunks: $chunkCount');

      // Finalize the diet plan
      if (progressiveMeals.isNotEmpty) {
        _dietPlans[dateKey] = DietPlan(
          date: dateKey,
          meals: progressiveMeals,
          totalNutrition: finalTotalNutrition ?? _calculateTotalNutrition(progressiveMeals),
        );

        _isLoading = false;
        _error = null;

        // Save to preferences
        await _saveToPreferences();
        notifyListeners();

        print('✅ Plano de dieta gerado com sucesso para $dateKey');
        print('   Total de refeições: ${progressiveMeals.length}');
      } else {
        throw Exception('Nenhuma refeição foi gerada');
      }

    } catch (e) {
      _isLoading = false;
      _error = 'Erro ao gerar plano de dieta: $e';
      notifyListeners();

      print('❌ Erro ao gerar plano de dieta: $e');
    }
  }

  // Build prompt for AI diet generation
  String _buildDietPlanPrompt(NutritionGoalsProvider nutritionGoals) {
    // Valores dinâmicos vindos do app
    final calories = nutritionGoals.caloriesGoal;
    final protein = nutritionGoals.proteinGoal;
    final carbs = nutritionGoals.carbsGoal;
    final fat = nutritionGoals.fatGoal;
    final mealsPerDay = _preferences.mealsPerDay;
    final hungriestMeal = _preferences.hungriestMealTime;

    return '''
Create a complete daily diet plan. Daily totals: $calories calories, ${protein}g protein, ${carbs}g carbs, ${fat}g fat. There are $mealsPerDay meals per day. Hungriest meal is $hungriestMeal (give it 35% of daily calories).

IMPORTANT: Return in NDJSON format (Newline Delimited JSON). Each line must be a valid JSON object:
- First $mealsPerDay lines: One meal per line
- Last line: Total nutrition summary

Format for each meal line:
{"type":"breakfast|lunch|dinner|snack","time":"HH:MM","name":"Meal Name","foods":[{"name":"Food","emoji":"🍳","amount":100,"unit":"g","calories":200,"protein":10,"carbs":20,"fat":5}],"mealTotals":{"calories":200,"protein":10,"carbs":20,"fat":5}}

Format for final line:
{"totalNutrition":{"calories":$calories,"protein":$protein,"carbs":$carbs,"fat":$fat},"date":"YYYY-MM-DD"}

CRITICAL:
- Each line must be a complete, valid JSON object (no nested arrays/objects across lines)
- Sum of all mealTotals MUST equal totalNutrition EXACTLY
- NO markdown, NO extra text, ONLY NDJSON lines
''';
  }

  // Replace a single meal with AI
  Future<void> replaceMeal(
    DateTime date,
    String mealType,
    NutritionGoalsProvider nutritionGoals, {
    String userId = '',
    String languageCode = 'pt_BR',
  }) async {
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
      print('⏳ Iniciando stream da API...');

      final stream = _aiService.getAnswerStream(
        prompt,
        languageCode: languageCode,
        quality: 'google/gemma-3-27b-it',
        userId: userId,
        agentType: 'diet',
        provider: 'Hyperbolic',
      );

      // Process stream for NDJSON format
      final StringBuffer lineBuffer = StringBuffer();
      String? connectionId;
      int chunkCount = 0;
      PlannedMeal? newMeal;

      await for (var chunk in stream) {
        chunkCount++;

        // Remove connection ID marker if present
        if (chunk.contains('[CONEXAO_ID]')) {
          final marcadorIndex = chunk.indexOf('[CONEXAO_ID]');
          connectionId = chunk.substring(marcadorIndex + 12);
          chunk = chunk.replaceAll('[CONEXAO_ID]$connectionId', '');
          if (chunk.isEmpty) continue;
        }

        // Add chunk to line buffer
        lineBuffer.write(chunk);

        // Process complete lines (NDJSON format)
        final lines = lineBuffer.toString().split('\n');

        // Keep the last incomplete line in buffer
        lineBuffer.clear();
        if (!lines.last.trim().endsWith('}')) {
          lineBuffer.write(lines.last);
          lines.removeLast();
        }

        // Process each complete line
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          try {
            print('🔍 Tentando parsear linha NDJSON: $trimmedLine');
            final jsonData = jsonDecode(trimmedLine);

            // Check if it's a meal
            if (jsonData.containsKey('type') && jsonData.containsKey('foods')) {
              newMeal = PlannedMeal.fromJson(jsonData);
              print('✅ Nova refeição recebida: ${newMeal.name}');
            }
          } catch (e) {
            print('⚠️ Erro ao parsear linha NDJSON: $e');
          }
        }
      }

      print('✓ Replace - Stream finalizado! Chunks: $chunkCount');

      if (newMeal != null) {
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
      } else {
        throw Exception('Nenhuma refeição foi gerada');
      }

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

Return in NDJSON format (single line of valid JSON, no markdown):
{"type":"${mealToReplace.type}","time":"${mealToReplace.time}","name":"Nome da Nova Refeição","foods":[{"name":"Nome","emoji":"🍽️","amount":100,"unit":"g","calories":200,"protein":10,"carbs":20,"fat":5}],"mealTotals":{"calories":200,"protein":10,"carbs":20,"fat":5}}

NO markdown, NO extra text, ONLY one line of JSON.
''';
  }

  // Replace all meals for a day
  Future<void> replaceAllMeals(
    DateTime date,
    NutritionGoalsProvider nutritionGoals, {
    String userId = '',
    String languageCode = 'pt_BR',
  }) async {
    // Simply generate a new diet plan for this date
    await generateDietPlan(date, nutritionGoals, userId: userId, languageCode: languageCode);
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
