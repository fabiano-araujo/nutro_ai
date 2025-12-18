import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/diet_plan_model.dart';
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

  // Partial diet plan being constructed during streaming
  DietPlan? _partialDietPlan;
  int _expectedMealsCount = 0;

  // Getters
  Map<String, DietPlan> get dietPlans => _dietPlans;
  DietPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  DietPlan? get partialDietPlan => _partialDietPlan;
  int get expectedMealsCount => _expectedMealsCount;

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
    _expectedMealsCount = _preferences.mealsPerDay;
    _parsedMealIndices.clear(); // Reset parsed meals tracker
    _partialDietPlan = DietPlan(
      date: _formatDate(date),
      totalNutrition: DailyNutrition(
        calories: nutritionGoals.caloriesGoal,
        protein: nutritionGoals.proteinGoal.toDouble(),
        carbs: nutritionGoals.carbsGoal.toDouble(),
        fat: nutritionGoals.fatGoal.toDouble(),
      ),
      meals: [],
    );
    notifyListeners();

    try {
      // Build the prompt for AI
      final prompt = _buildDietPlanPrompt(nutritionGoals);

      print('🍽️ Gerando plano de dieta para ${_formatDate(date)}');
      print('📋 Prompt: $prompt');
      print('🌍 Locale: $languageCode');
      print('👤 UserId: $userId');
      print('🤖 AgentType: my_diet, Model: google/gemini-3-flash-preview');

      // Call backend API using NDJSON streaming for diet agent
      print('⏳ Iniciando stream NDJSON da API...');

      // Create HTTP request
      final endpoint = '${const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://study.snapdark.com:3001')}/ai/generate-text';
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json; charset=utf-8',
      });

      final requestBody = {
        'prompt': prompt,
        'temperature': 0.5,
        'model': 'google/gemini-3-flash-preview',
        'streaming': true,
        'userId': userId,
        'agentType': 'my_diet',
        'language': languageCode,
      };

      request.bodyBytes = utf8.encode(jsonEncode(requestBody));

      print('📤 Enviando requisição NDJSON para: $endpoint');
      final httpResponse = await http.Client().send(request);

      if (httpResponse.statusCode != 200) {
        throw Exception('Erro na API: ${httpResponse.statusCode}');
      }

      print('✅ Conexão NDJSON estabelecida');

      // Process NDJSON stream (each line is a complete JSON object)
      final StringBuffer responseBuffer = StringBuffer();
      int chunkCount = 0;
      String? connectionId;
      String lineBuffer = '';

      await for (var chunk in httpResponse.stream.transform(utf8.decoder)) {
        // Add chunk to line buffer
        lineBuffer += chunk;

        // Process complete lines (split by \n)
        while (lineBuffer.contains('\n')) {
          final newlineIndex = lineBuffer.indexOf('\n');
          final line = lineBuffer.substring(0, newlineIndex).trim();
          lineBuffer = lineBuffer.substring(newlineIndex + 1);

          if (line.isEmpty) continue;

          try {
            // Strip SSE "data: " prefix if present
            String jsonLine = line;
            if (line.startsWith('data: ')) {
              jsonLine = line.substring(6); // Remove "data: " prefix
            }

            // Parse JSON line
            final jsonData = jsonDecode(jsonLine);
            chunkCount++;
            print('📦 Diet NDJSON - Linha #$chunkCount: $jsonData');

            // Handle different event types
            if (jsonData.containsKey('status') && jsonData.containsKey('connectionId')) {
              // Connection established event
              connectionId = jsonData['connectionId'];
              print('🔑 Diet - Connection ID: $connectionId');
            } else if (jsonData.containsKey('text') && jsonData['text'] != null) {
              // Text chunk event
              final text = jsonData['text'];
              responseBuffer.write(text);
              print('📝 Diet - Adicionado texto: ${text.length} chars');

              // Try to detect and parse complete meals incrementally
              _tryParseIncrementalMeals(responseBuffer.toString());
            } else if (jsonData.containsKey('done') && jsonData['done'] == true) {
              // Stream completed
              print('✅ Diet - Stream concluído');
            } else if (jsonData.containsKey('error')) {
              // Error event
              throw Exception(jsonData['error']);
            }
          } catch (e) {
            print('❌ Diet - Erro ao processar linha NDJSON: $e');
            print('   Linha: $line');
          }
        }
      }

      print('✓ Diet - Stream NDJSON finalizado! Chunks: $chunkCount, ConnectionId: $connectionId');
      final response = responseBuffer.toString();

      print('📥 Resposta completa da IA (${response.length} chars):');
      print('═' * 80);
      print(response);
      print('═' * 80);

      // Try to extract JSON from response
      print('🔍 Tentando extrair JSON da resposta...');
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) {
        print('❌ ERRO: Não foi possível extrair JSON da resposta!');
        throw Exception('Não foi possível extrair JSON da resposta da IA');
      }

      final jsonString = jsonMatch.group(0)!;
      print('📄 JSON extraído (${jsonString.length} chars):');
      print('─' * 80);
      print(jsonString);
      print('─' * 80);

      print('🔧 Fazendo parse do JSON...');
      final jsonData = jsonDecode(jsonString);
      print('✓ JSON parseado com sucesso!');
      print('📊 Estrutura do JSON: ${jsonData.keys.toList()}');

      // Create diet plan from JSON
      print('🍱 Criando objeto DietPlan a partir do JSON...');
      final dietPlan = DietPlan.fromJson(jsonData);
      print('✓ DietPlan criado: ${dietPlan.meals.length} refeições');

      // Update date to match requested date
      final updatedPlan = dietPlan.copyWith(date: _formatDate(date));
      print('✓ Data atualizada para: ${_formatDate(date)}');

      // Store the diet plan
      final dateKey = _formatDate(date);
      _dietPlans[dateKey] = updatedPlan;

      _isLoading = false;
      _error = null;
      _partialDietPlan = null; // Clear partial state

      // Save to preferences
      await _saveToPreferences();

      notifyListeners();

      print('✅ Plano de dieta gerado com sucesso para $dateKey');
    } catch (e) {
      _isLoading = false;
      _error = 'Erro ao gerar plano de dieta: $e';
      _partialDietPlan = null; // Clear partial state on error
      notifyListeners();

      print('❌ Erro ao gerar plano de dieta: $e');
    }
  }

  // Try to parse and add complete meals incrementally from partial JSON
  Set<int> _parsedMealIndices = {};

  void _tryParseIncrementalMeals(String partialJson) {
    if (_partialDietPlan == null) return;

    try {
      // Try to extract the meals array from partial JSON
      final mealsMatch = RegExp(r'"meals"\s*:\s*\[(.*)', dotAll: true).firstMatch(partialJson);
      if (mealsMatch == null) return;

      final mealsContent = mealsMatch.group(1)!;

      // Find complete meal objects (those with closing })
      final mealPattern = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', dotAll: true);
      final mealMatches = mealPattern.allMatches(mealsContent).toList();

      print('🍽️ Detectadas ${mealMatches.length} refeições completas no JSON parcial');

      for (var i = 0; i < mealMatches.length; i++) {
        // Skip if already parsed
        if (_parsedMealIndices.contains(i)) continue;

        try {
          final mealJson = mealMatches[i].group(0)!;
          final mealData = jsonDecode(mealJson) as Map<String, dynamic>;

          // Validate that it's a complete meal with required fields
          if (mealData.containsKey('type') &&
              mealData.containsKey('foods') &&
              mealData.containsKey('mealTotals')) {

            final meal = PlannedMeal.fromJson(mealData);

            // Add to partial diet plan if not already there
            if (_partialDietPlan!.meals.length <= i) {
              final updatedMeals = List<PlannedMeal>.from(_partialDietPlan!.meals)..add(meal);
              _partialDietPlan = _partialDietPlan!.copyWith(meals: updatedMeals);
              _parsedMealIndices.add(i);

              print('✅ Refeição #${i + 1} adicionada: ${meal.name} (${meal.type})');
              notifyListeners(); // Update UI immediately
            }
          }
        } catch (e) {
          // Silently skip invalid meals during streaming
          print('⚠️ Erro ao parsear refeição #${i + 1}: $e');
        }
      }
    } catch (e) {
      // Silently fail during incremental parsing
      print('⚠️ Erro durante parsing incremental: $e');
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
Create a complete daily diet plan. Daily totals: $calories calories, ${protein}g protein, ${carbs}g carbs, ${fat}g fat. There are $mealsPerDay meals per day. Hungriest meal is $hungriestMeal (give it 35% of daily calories). Return ONLY valid JSON (no markdown):
{
  "date": "YYYY-MM-DD",
  "totalNutrition": {"calories": $calories, "protein": $protein, "carbs": $carbs, "fat": $fat},
  "meals": [
    {
      "type": "breakfast|lunch|dinner|snack",
      "time": "HH:MM",
      "name": "Meal Name",
      "foods": [{"name": "Food", "emoji": "🍳", "amount": number, "unit": "g|ml|unidade", "calories": number, "protein": number, "carbs": number, "fat": number}],
      "mealTotals": {"calories": number, "protein": number, "carbs": number, "fat": number}
    }
  ]
}

CRITICAL: Sum of all mealTotals MUST equal totalNutrition EXACTLY.
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
      print('⏳ Iniciando stream NDJSON da API...');

      // Create HTTP request using NDJSON
      final endpoint = '${const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://study.snapdark.com:3001')}/ai/generate-text';
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json; charset=utf-8',
      });

      final requestBody = {
        'prompt': prompt,
        'temperature': 0.5,
        'model': 'google/gemini-3-flash-preview',
        'streaming': true,
        'userId': userId,
        'agentType': 'my_diet',
        'language': languageCode,
      };

      request.bodyBytes = utf8.encode(jsonEncode(requestBody));

      print('📤 Enviando requisição NDJSON para: $endpoint');
      final httpResponse = await http.Client().send(request);

      if (httpResponse.statusCode != 200) {
        throw Exception('Erro na API: ${httpResponse.statusCode}');
      }

      print('✅ Conexão NDJSON estabelecida');

      // Process NDJSON stream
      final StringBuffer responseBuffer = StringBuffer();
      int chunkCount = 0;
      String? connectionId;
      String lineBuffer = '';

      await for (var chunk in httpResponse.stream.transform(utf8.decoder)) {
        lineBuffer += chunk;

        while (lineBuffer.contains('\n')) {
          final newlineIndex = lineBuffer.indexOf('\n');
          final line = lineBuffer.substring(0, newlineIndex).trim();
          lineBuffer = lineBuffer.substring(newlineIndex + 1);

          if (line.isEmpty) continue;

          try {
            // Strip SSE "data: " prefix if present
            String jsonLine = line;
            if (line.startsWith('data: ')) {
              jsonLine = line.substring(6); // Remove "data: " prefix
            }

            final jsonData = jsonDecode(jsonLine);
            chunkCount++;

            if (jsonData.containsKey('status') && jsonData.containsKey('connectionId')) {
              connectionId = jsonData['connectionId'];
              print('🔑 Replace - Connection ID: $connectionId');
            } else if (jsonData.containsKey('text') && jsonData['text'] != null) {
              final text = jsonData['text'];
              responseBuffer.write(text);
            } else if (jsonData.containsKey('done') && jsonData['done'] == true) {
              print('✅ Replace - Stream concluído');
            } else if (jsonData.containsKey('error')) {
              throw Exception(jsonData['error']);
            }
          } catch (e) {
            print('❌ Replace - Erro ao processar linha NDJSON: $e');
          }
        }
      }

      print('✓ Replace - Stream NDJSON finalizado! Chunks: $chunkCount');
      final response = responseBuffer.toString();

      print('📥 Resposta completa da IA (${response.length} chars):');
      print('═' * 80);
      print(response);
      print('═' * 80);

      // Extract JSON from response
      print('🔍 Tentando extrair JSON da resposta...');
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
