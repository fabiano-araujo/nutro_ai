import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/diet_plan_model.dart';
import '../providers/nutrition_goals_provider.dart' show NutritionGoalsProvider;
import '../providers/meal_types_provider.dart' show MealTypeConfig;
import '../util/app_constants.dart';

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
  late final Future<void> _loadFuture;

  // Chave fixa para dieta semanal única
  static const String _weeklyKey = 'weekly';

  // Autenticação
  String? _authToken;
  int? _userId;
  bool _isPremium = false;

  // Getters para status de autenticação
  bool get isAuthenticated => _authToken != null && _userId != null;
  bool get isPremium => _isPremium;

  // Getters
  Map<String, DietPlan> get dietPlans => _dietPlans;
  DietPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  DietPlan? get partialDietPlan => _partialDietPlan;
  int get expectedMealsCount => _expectedMealsCount;
  DietMode get dietMode => _preferences.dietMode;
  bool get hasCompletedDietPersonalization =>
      missingDietPersonalizationTopics.isEmpty;
  List<String> get missingDietPersonalizationTopics {
    final missing = <String>[];
    if (!_preferences.hasReviewedRestrictions) {
      missing.add('dietary_restrictions');
    }
    if (!_preferences.hasReviewedFoodPreferences) {
      missing.add('food_preferences');
    }
    if (!_preferences.hasReviewedRoutineNeeds) {
      missing.add('routine_and_appetite');
    }
    return missing;
  }

  // Check if has any diet plan (for any date or weekly)
  bool get hasAnyDietPlan => _dietPlans.isNotEmpty;

  // Get diet plan for selected date (or weekly plan if in weekly mode)
  DietPlan? get currentDietPlan {
    if (_preferences.dietMode == DietMode.weekly) {
      return _dietPlans[_weeklyKey];
    }
    final dateKey = _formatDate(_selectedDate);
    return _dietPlans[dateKey];
  }

  // Check if has diet plan for date (or weekly plan)
  bool hasDietPlanForDate(DateTime date) {
    if (_preferences.dietMode == DietMode.weekly) {
      return _dietPlans.containsKey(_weeklyKey);
    }
    final dateKey = _formatDate(date);
    return _dietPlans.containsKey(dateKey);
  }

  // Set diet mode
  void setDietMode(DietMode mode) {
    _preferences = _preferences.copyWith(dietMode: mode);
    _saveToPreferences();
    notifyListeners();
  }

  DietPlanProvider() {
    _loadFuture = _loadFromPreferences();
  }

  Future<void> ensureLoaded() => _loadFuture;

  /// Define as credenciais de autenticação e carrega dados do servidor
  Future<void> setAuth(String token, int userId) async {
    _authToken = token;
    _userId = userId;
    print('🔐 DietPlanProvider: Auth configurado para userId: $userId');

    // Verificar status premium e carregar dietas do servidor
    await _checkPremiumStatus();
    await _loadFromServer();
    notifyListeners();
  }

  /// Limpa as credenciais de autenticação
  void clearAuth() {
    _authToken = null;
    _userId = null;
    _isPremium = false;
    print('🔓 DietPlanProvider: Auth limpo');
    notifyListeners();
  }

  /// Verifica se o usuário é premium
  Future<void> _checkPremiumStatus() async {
    if (!isAuthenticated) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.API_BASE_URL}/diet/premium-status'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isPremium = data['isPremium'] ?? false;
        print('👑 DietPlanProvider: Status premium: $_isPremium');
      }
    } catch (e) {
      print('❌ DietPlanProvider: Erro ao verificar status premium: $e');
    }
  }

  /// Carrega dietas do servidor
  Future<void> _loadFromServer() async {
    if (!isAuthenticated) return;

    try {
      print('📥 DietPlanProvider: Carregando dietas do servidor...');

      final response = await http.get(
        Uri.parse('${AppConstants.API_BASE_URL}/diet/plans'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> plansData = jsonDecode(response.body);

        for (final planData in plansData) {
          final dateKey = planData['dateKey'] as String;
          final dietPlan = _parseDietPlanFromServer(planData);
          _dietPlans[dateKey] = dietPlan;
        }

        await _saveToPreferences();
        print(
            '✅ DietPlanProvider: ${plansData.length} dietas carregadas do servidor');
      }
    } catch (e) {
      print('❌ DietPlanProvider: Erro ao carregar do servidor: $e');
    }
  }

  /// Converte dados do servidor para DietPlan
  DietPlan _parseDietPlanFromServer(Map<String, dynamic> data) {
    final meals = (data['meals'] as List<dynamic>?)?.map((mealData) {
          final foods = (mealData['foods'] as List<dynamic>?)?.map((foodData) {
                return PlannedFood(
                  name: foodData['name'] ?? '',
                  emoji: resolveFoodEmoji(
                    foodData['name'] ?? '',
                    preferred: foodData['emoji']?.toString(),
                  ),
                  amount: (foodData['amount'] is String)
                      ? double.tryParse(foodData['amount']) ?? 100
                      : (foodData['amount'] as num?)?.toDouble() ?? 100,
                  unit: foodData['unit'] ?? 'g',
                  calories: (foodData['calories'] as num?)?.toInt() ?? 0,
                  protein: (foodData['protein'] is String)
                      ? double.tryParse(foodData['protein']) ?? 0
                      : (foodData['protein'] as num?)?.toDouble() ?? 0,
                  carbs: (foodData['carbs'] is String)
                      ? double.tryParse(foodData['carbs']) ?? 0
                      : (foodData['carbs'] as num?)?.toDouble() ?? 0,
                  fat: (foodData['fat'] is String)
                      ? double.tryParse(foodData['fat']) ?? 0
                      : (foodData['fat'] as num?)?.toDouble() ?? 0,
                );
              }).toList() ??
              [];

          return PlannedMeal(
            type: mealData['type'] ?? '',
            time: mealData['time'] ?? '',
            name: mealData['name'] ?? '',
            foods: foods,
            mealTotals: DailyNutrition(
              calories: (mealData['calories'] as num?)?.toInt() ?? 0,
              protein: (mealData['protein'] is String)
                  ? double.tryParse(mealData['protein']) ?? 0
                  : (mealData['protein'] as num?)?.toDouble() ?? 0,
              carbs: (mealData['carbs'] is String)
                  ? double.tryParse(mealData['carbs']) ?? 0
                  : (mealData['carbs'] as num?)?.toDouble() ?? 0,
              fat: (mealData['fat'] is String)
                  ? double.tryParse(mealData['fat']) ?? 0
                  : (mealData['fat'] as num?)?.toDouble() ?? 0,
            ),
          );
        }).toList() ??
        [];

    return DietPlan(
      date: data['dateKey'] ?? '',
      totalNutrition: DailyNutrition(
        calories: (data['totalCalories'] as num?)?.toInt() ?? 0,
        protein: (data['totalProtein'] is String)
            ? double.tryParse(data['totalProtein']) ?? 0
            : (data['totalProtein'] as num?)?.toDouble() ?? 0,
        carbs: (data['totalCarbs'] is String)
            ? double.tryParse(data['totalCarbs']) ?? 0
            : (data['totalCarbs'] as num?)?.toDouble() ?? 0,
        fat: (data['totalFat'] is String)
            ? double.tryParse(data['totalFat']) ?? 0
            : (data['totalFat'] as num?)?.toDouble() ?? 0,
      ),
      meals: meals,
    );
  }

  /// Salva dieta no servidor
  Future<void> _saveToServer(String dateKey, DietPlan plan) async {
    if (!isAuthenticated) {
      print('⚠️ DietPlanProvider: Não autenticado, pulando sync com servidor');
      return;
    }

    try {
      print('📤 DietPlanProvider: Salvando dieta no servidor...');

      final body = {
        'dateKey': dateKey,
        'dietMode':
            _preferences.dietMode == DietMode.weekly ? 'weekly' : 'daily',
        'totalCalories': plan.totalNutrition.calories,
        'totalProtein': plan.totalNutrition.protein,
        'totalCarbs': plan.totalNutrition.carbs,
        'totalFat': plan.totalNutrition.fat,
        'meals': plan.meals.asMap().entries.map((entry) {
          final index = entry.key;
          final meal = entry.value;
          return {
            'type': meal.type,
            'name': meal.name,
            'time': meal.time,
            'sortOrder': index,
            'calories': meal.mealTotals.calories,
            'protein': meal.mealTotals.protein,
            'carbs': meal.mealTotals.carbs,
            'fat': meal.mealTotals.fat,
            'foods': meal.foods.asMap().entries.map((foodEntry) {
              final foodIndex = foodEntry.key;
              final food = foodEntry.value;
              return {
                'name': food.name,
                'emoji': food.emoji,
                'amount': food.amount,
                'unit': food.unit,
                'sortOrder': foodIndex,
                'calories': food.calories,
                'protein': food.protein,
                'carbs': food.carbs,
                'fat': food.fat,
              };
            }).toList(),
          };
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('${AppConstants.API_BASE_URL}/diet/plan'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print('✅ DietPlanProvider: Dieta salva no servidor');
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'PREMIUM_REQUIRED') {
          _error = 'daily_diet_premium_required';
          _isPremium = false;
          notifyListeners();
        }
      } else {
        print(
            '❌ DietPlanProvider: Erro ao salvar no servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DietPlanProvider: Erro ao salvar no servidor: $e');
    }
  }

  /// Deleta dieta do servidor
  Future<void> _deleteFromServer(String dateKey) async {
    if (!isAuthenticated) return;

    try {
      await http.delete(
        Uri.parse('${AppConstants.API_BASE_URL}/diet/plan/$dateKey'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );
      print('✅ DietPlanProvider: Dieta deletada do servidor');
    } catch (e) {
      print('❌ DietPlanProvider: Erro ao deletar do servidor: $e');
    }
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

  void updateDietGenerationPreferences({
    int? mealsPerDay,
    String? hungriestMealTime,
    List<String>? foodRestrictions,
    List<String>? favoriteFoods,
    List<String>? avoidedFoods,
    List<String>? routineConsiderations,
    bool? reviewedRestrictions,
    bool? reviewedFoodPreferences,
    bool? reviewedRoutineNeeds,
    bool mergeRestrictions = true,
    bool mergeFoodPreferences = true,
    bool mergeRoutineConsiderations = true,
  }) {
    _preferences = _preferences.copyWith(
      mealsPerDay: mealsPerDay,
      hungriestMealTime: hungriestMealTime,
      foodRestrictions: foodRestrictions == null
          ? _preferences.foodRestrictions
          : _resolveUpdatedList(
              current: _preferences.foodRestrictions,
              incoming: foodRestrictions,
              merge: mergeRestrictions,
            ),
      favoriteFoods: favoriteFoods == null
          ? _preferences.favoriteFoods
          : _resolveUpdatedList(
              current: _preferences.favoriteFoods,
              incoming: favoriteFoods,
              merge: mergeFoodPreferences,
            ),
      avoidedFoods: avoidedFoods == null
          ? _preferences.avoidedFoods
          : _resolveUpdatedList(
              current: _preferences.avoidedFoods,
              incoming: avoidedFoods,
              merge: mergeFoodPreferences,
            ),
      routineConsiderations: routineConsiderations == null
          ? _preferences.routineConsiderations
          : _resolveUpdatedList(
              current: _preferences.routineConsiderations,
              incoming: routineConsiderations,
              merge: mergeRoutineConsiderations,
            ),
      hasReviewedRestrictions:
          reviewedRestrictions ?? _preferences.hasReviewedRestrictions,
      hasReviewedFoodPreferences:
          reviewedFoodPreferences ?? _preferences.hasReviewedFoodPreferences,
      hasReviewedRoutineNeeds:
          reviewedRoutineNeeds ?? _preferences.hasReviewedRoutineNeeds,
    );
    _saveToPreferences();
    notifyListeners();
  }

  // Generate diet plan for a specific date
  Future<void> generateDietPlan(
    DateTime date,
    NutritionGoalsProvider nutritionGoals, {
    List<MealTypeConfig> mealTypes = const [],
    String userId = '',
    String languageCode = 'pt_BR',
  }) async {
    // Verificar se está autenticado
    if (!isAuthenticated) {
      _error = 'É necessário estar logado para gerar dietas personalizadas';
      notifyListeners();
      return;
    }

    // Verificar se está tentando usar modo diário sem ser premium
    // Dieta semanal é gratuita, dieta diária é paga
    if (_preferences.dietMode == DietMode.daily && !_isPremium) {
      _error = 'daily_diet_premium_required';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _activeMealTypes = _resolveMealTypes(mealTypes);
    _expectedMealsCount = _activeMealTypes.length;
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
      final prompt =
          _buildDietPlanPrompt(nutritionGoals, languageCode, _activeMealTypes);

      print('🍽️ Gerando plano de dieta para ${_formatDate(date)}');
      print('📊 Refeições: $_expectedMealsCount');
      print('🍴 Tipos: ${_activeMealTypes.map((m) => m.name).join(', ')}');
      print('📋 Prompt: $prompt');
      print('🌍 Locale: $languageCode');
      print('👤 UserId: $userId');
      print('🤖 AgentType: diet, Model: google/gemini-3-flash-preview');

      // Call backend API using NDJSON streaming for diet agent
      print('⏳ Iniciando stream NDJSON da API...');

      // Create HTTP request
      final endpoint = '${AppConstants.API_BASE_URL}/ai/generate-text';
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
        'agentType': 'diet',
        'language': languageCode,
        'mealTypes':
            _activeMealTypes.map((m) => {'id': m.id, 'name': m.name}).toList(),
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
            if (jsonData.containsKey('status') &&
                jsonData.containsKey('connectionId')) {
              // Connection established event
              connectionId = jsonData['connectionId'];
              print('🔑 Diet - Connection ID: $connectionId');
            } else if (jsonData.containsKey('text') &&
                jsonData['text'] != null) {
              // Text chunk event
              final text = jsonData['text'];
              responseBuffer.write(text);
              print('📝 Diet - Adicionado texto: ${text.length} chars');

              // Try to detect and parse complete meals incrementally
              _tryParseIncrementalMeals(responseBuffer.toString());
            } else if (jsonData.containsKey('done') &&
                jsonData['done'] == true) {
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

      print(
          '✓ Diet - Stream NDJSON finalizado! Chunks: $chunkCount, ConnectionId: $connectionId');
      final response = responseBuffer.toString();

      print('📥 Resposta completa da IA (${response.length} chars):');
      print('═' * 80);
      print(response);
      print('═' * 80);

      // Try to extract JSON from response
      print('🔍 Tentando extrair JSON da resposta...');
      final jsonString = _extractJsonPayload(response);
      if (jsonString == null) {
        print('❌ ERRO: Não foi possível extrair JSON da resposta!');
        throw Exception('Não foi possível extrair JSON da resposta da IA');
      }

      print('📄 JSON extraído (${jsonString.length} chars):');
      print('─' * 80);
      print(jsonString);
      print('─' * 80);

      print('🔧 Fazendo parse do JSON...');
      final jsonData = _normalizeAiJson(_decodeAiJson(jsonString));
      print('✓ JSON parseado com sucesso!');
      print('📊 Estrutura do JSON: ${jsonData.keys.toList()}');

      // Create diet plan from JSON
      print('🍱 Criando objeto DietPlan a partir do JSON...');
      final dietPlan = DietPlan.fromAiJson(
        jsonData,
        date: _formatDate(date),
        mealNames: _buildMealNameMap(_activeMealTypes),
      );
      print('✓ DietPlan criado: ${dietPlan.meals.length} refeições');

      // Store the diet plan (using weekly key if in weekly mode)
      final dateKey = _preferences.dietMode == DietMode.weekly
          ? _weeklyKey
          : _formatDate(date);
      _dietPlans[dateKey] = dietPlan;

      _isLoading = false;
      _error = null;
      _partialDietPlan = null; // Clear partial state
      _activeMealTypes = const [];

      // Save to preferences
      await _saveToPreferences();

      // Save to server
      await _saveToServer(dateKey, dietPlan);

      notifyListeners();

      print('✅ Plano de dieta gerado com sucesso para $dateKey');
    } catch (e) {
      _isLoading = false;
      _error = 'Erro ao gerar plano de dieta: $e';
      _partialDietPlan = null; // Clear partial state on error
      _activeMealTypes = const [];
      notifyListeners();

      print('❌ Erro ao gerar plano de dieta: $e');
    }
  }

  // Try to parse and add complete meals incrementally from partial JSON
  Set<int> _parsedMealIndices = {};
  List<MealTypeConfig> _activeMealTypes = const [];

  void _tryParseIncrementalMeals(String partialJson) {
    if (_partialDietPlan == null) return;

    try {
      // Try to extract the meals array from partial JSON
      final mealsMatch = RegExp(r'"(?:meals|m)"\s*:\s*\[(.*)', dotAll: true)
          .firstMatch(partialJson);
      if (mealsMatch == null) return;

      final mealsContent = mealsMatch.group(1)!;

      // Find complete meal objects (those with closing })
      final mealPattern =
          RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', dotAll: true);
      final mealMatches = mealPattern.allMatches(mealsContent).toList();

      print(
          '🍽️ Detectadas ${mealMatches.length} refeições completas no JSON parcial');

      for (var i = 0; i < mealMatches.length; i++) {
        // Skip if already parsed
        if (_parsedMealIndices.contains(i)) continue;

        try {
          final mealJson = mealMatches[i].group(0)!;
          final mealData = jsonDecode(mealJson) as Map<String, dynamic>;

          // Validate that it's a complete meal with required fields
          final hasLegacyFields =
              mealData.containsKey('type') && mealData.containsKey('foods');
          final hasCompactFields =
              mealData.containsKey('t') && mealData.containsKey('f');
          if (hasLegacyFields || hasCompactFields) {
            final meal = PlannedMeal.fromAiJson(
              mealData,
              mealNames: _buildMealNameMap(_activeMealTypes),
            );

            // Add to partial diet plan if not already there
            if (_partialDietPlan!.meals.length <= i) {
              final updatedMeals =
                  List<PlannedMeal>.from(_partialDietPlan!.meals)..add(meal);
              _partialDietPlan =
                  _partialDietPlan!.copyWith(meals: updatedMeals);
              _parsedMealIndices.add(i);

              print(
                  '✅ Refeição #${i + 1} adicionada: ${meal.name} (${meal.type})');
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

  // Get country name from language code
  String _getCountryFromLanguage(String languageCode) {
    final Map<String, String> countryMap = {
      'pt_BR': 'Brazil',
      'pt_PT': 'Portugal',
      'en_US': 'United States',
      'en_GB': 'United Kingdom',
      'es_ES': 'Spain',
      'es_MX': 'Mexico',
      'es_AR': 'Argentina',
      'fr_FR': 'France',
      'de_DE': 'Germany',
      'it_IT': 'Italy',
      'ja_JP': 'Japan',
      'zh_CN': 'China',
      'ko_KR': 'South Korea',
    };
    return countryMap[languageCode] ?? 'Brazil';
  }

  List<MealTypeConfig> _resolveMealTypes(List<MealTypeConfig> mealTypes) {
    if (mealTypes.isNotEmpty) {
      return mealTypes;
    }

    return [
      MealTypeConfig(
        id: 'breakfast',
        name: 'Café da Manhã',
        emoji: '🍳',
        order: 0,
      ),
      MealTypeConfig(
        id: 'lunch',
        name: 'Almoço',
        emoji: '🍽️',
        order: 1,
      ),
      MealTypeConfig(
        id: 'dinner',
        name: 'Jantar',
        emoji: '🍝',
        order: 2,
      ),
    ];
  }

  Map<String, String> _buildMealNameMap(List<MealTypeConfig> mealTypes) {
    return {
      for (final meal in _resolveMealTypes(mealTypes)) meal.id: meal.name,
    };
  }

  Map<String, dynamic> _normalizeAiJson(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is List) {
      return {'m': raw};
    }

    throw const FormatException('Formato JSON inesperado da IA');
  }

  dynamic _decodeAiJson(String jsonString) {
    try {
      return jsonDecode(jsonString);
    } catch (_) {
      final sanitized = jsonString
          .replaceAll(RegExp(r',\s*([\]}])'), r'$1')
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(sanitized);
    }
  }

  String? _extractJsonPayload(String response) {
    final trimmed = response.trim();
    final objectStart = trimmed.indexOf('{');
    final arrayStart = trimmed.indexOf('[');

    var start = -1;
    if (objectStart >= 0 && arrayStart >= 0) {
      start = objectStart < arrayStart ? objectStart : arrayStart;
    } else if (objectStart >= 0) {
      start = objectStart;
    } else {
      start = arrayStart;
    }

    if (start < 0) {
      return null;
    }

    final openChar = trimmed[start];
    final closeChar = openChar == '{' ? '}' : ']';
    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < trimmed.length; i++) {
      final char = trimmed[i];

      if (escaped) {
        escaped = false;
        continue;
      }

      if (char == r'\') {
        escaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        continue;
      }

      if (inString) {
        continue;
      }

      if (char == openChar) {
        depth++;
      } else if (char == closeChar) {
        depth--;
        if (depth == 0) {
          return trimmed.substring(start, i + 1);
        }
      }
    }

    return null;
  }

  // Build prompt for AI diet generation
  String _buildDietPlanPrompt(NutritionGoalsProvider nutritionGoals,
      String languageCode, List<MealTypeConfig> mealTypes) {
    // Nutrition goals from provider (already calculated)
    final calories = nutritionGoals.caloriesGoal;
    final protein = nutritionGoals.proteinGoal;
    final carbs = nutritionGoals.carbsGoal;
    final fat = nutritionGoals.fatGoal;

    // Country for cuisine
    final country = _getCountryFromLanguage(languageCode);

    // Build meals list from user's configured meal types
    final mealsCount =
        mealTypes.isNotEmpty ? mealTypes.length : _preferences.mealsPerDay;

    final mealIds = _resolveMealTypes(mealTypes).map((m) => m.id).join(', ');
    final preferenceLines = _buildDietPreferenceLines();

    return '''
Create a daily diet using $country foods.

Target near: $calories kcal, ${protein}p, ${carbs}c, ${fat}f.
Meals: exactly $mealsCount using these t values only: [$mealIds].
$preferenceLines

Return ONLY compact JSON:
{"m":[["breakfast","08:00",[["Food",100,"g",300,10,40,8]]]]}

Rules:
- meal = [type, time, foods]
- food = [name, amount, unit, kcal, protein, carbs, fat]
- Use realistic portions
- Adapt food choices, portion density, and meal timing to the personalization notes above
- If breakfast appetite is low or there is morning sleepiness, keep breakfast simpler and easier to consume
- If hunger is high, prefer higher-satiety foods; if eating is difficult or weight gain is hard, prefer more practical and energy-dense foods
- No totals, no date, no icons, no markdown, no extra text
''';
  }

  // Replace a single meal with AI
  Future<void> replaceMeal(
    DateTime date,
    String mealType,
    NutritionGoalsProvider nutritionGoals, {
    List<MealTypeConfig> mealTypes = const [],
    String userId = '',
    String languageCode = 'pt_BR',
  }) async {
    // Verificar se está autenticado
    if (!isAuthenticated) {
      _error = 'É necessário estar logado para modificar dietas';
      notifyListeners();
      return;
    }

    final dateKey = _preferences.dietMode == DietMode.weekly
        ? _weeklyKey
        : _formatDate(date);
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
      final endpoint = '${AppConstants.API_BASE_URL}/ai/generate-text';
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
        'agentType': 'diet',
        'language': languageCode,
        'mealTypes':
            mealTypes.map((m) => {'id': m.id, 'name': m.name}).toList(),
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

            if (jsonData.containsKey('status') &&
                jsonData.containsKey('connectionId')) {
              connectionId = jsonData['connectionId'];
              print('🔑 Replace - Connection ID: $connectionId');
            } else if (jsonData.containsKey('text') &&
                jsonData['text'] != null) {
              final text = jsonData['text'];
              responseBuffer.write(text);
            } else if (jsonData.containsKey('done') &&
                jsonData['done'] == true) {
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
      final jsonString = _extractJsonPayload(response);
      if (jsonString == null) {
        throw Exception('Não foi possível extrair JSON da resposta da IA');
      }

      final jsonData = _normalizeAiJson(_decodeAiJson(jsonString));
      final meals = (jsonData['m'] as List<dynamic>? ?? const []);
      if (meals.isEmpty) {
        throw Exception('A IA não retornou nenhuma refeição válida');
      }

      // Create new meal from JSON
      final newMeal = PlannedMeal.fromAiJson(
        meals.first,
        mealNames: {mealToReplace.type: mealToReplace.name},
        fallbackType: mealToReplace.type,
        fallbackTime: mealToReplace.time,
        fallbackName: mealToReplace.name,
      );

      // Update the meal in the plan
      final updatedMeals = List<PlannedMeal>.from(currentPlan.meals);
      updatedMeals[mealIndex] = newMeal;

      // Recalculate total nutrition
      final newTotalNutrition = _calculateTotalNutrition(updatedMeals);

      final updatedPlan = currentPlan.copyWith(
        meals: updatedMeals,
        totalNutrition: newTotalNutrition,
      );
      _dietPlans[dateKey] = updatedPlan;

      _isLoading = false;
      _error = null;

      await _saveToPreferences();

      // Save to server
      await _saveToServer(dateKey, updatedPlan);

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
    final currentFoods =
        mealToReplace.foods.map((food) => food.name).join(', ');
    return '''
Crie uma nova refeição brasileira/portuguesa com macros próximos desta meta:
${mealToReplace.mealTotals.calories} kcal, ${mealToReplace.mealTotals.protein}p, ${mealToReplace.mealTotals.carbs}c, ${mealToReplace.mealTotals.fat}f.

Mantenha:
- t="${mealToReplace.type}"
- h="${mealToReplace.time}"

Evite repetir estes alimentos: $currentFoods

Retorne ONLY:
{"m":[["${mealToReplace.type}","${mealToReplace.time}",[["Food",100,"g",300,10,40,8]]]]}

Rules:
- meal = [type, time, foods]
- food = [name, amount, unit, kcal, protein, carbs, fat]
- No totals, no name field, no icons, no markdown, no extra text
''';
  }

  // Replace all meals for a day
  Future<void> replaceAllMeals(
    DateTime date,
    NutritionGoalsProvider nutritionGoals, {
    List<MealTypeConfig> mealTypes = const [],
    String userId = '',
    String languageCode = 'pt_BR',
  }) async {
    // Simply generate a new diet plan for this date
    await generateDietPlan(date, nutritionGoals,
        mealTypes: mealTypes, userId: userId, languageCode: languageCode);
  }

  /// Duplica uma dieta diária existente para outras datas
  Future<int> repeatDietPlanToDates(
    DateTime sourceDate,
    List<DateTime> targetDates,
  ) async {
    if (_preferences.dietMode != DietMode.daily) {
      _error = 'A repetição está disponível apenas para dietas diárias';
      notifyListeners();
      return 0;
    }

    if (!_isPremium) {
      _error = 'daily_diet_premium_required';
      notifyListeners();
      return 0;
    }

    final sourceKey = _formatDate(sourceDate);
    final sourcePlan = _dietPlans[sourceKey];

    if (sourcePlan == null) {
      _error = 'Nenhum plano de dieta encontrado para esta data';
      notifyListeners();
      return 0;
    }

    final copiedPlans = <String, DietPlan>{};

    for (final targetDate in targetDates) {
      final targetKey = _formatDate(targetDate);
      if (targetKey == sourceKey || copiedPlans.containsKey(targetKey)) {
        continue;
      }

      copiedPlans[targetKey] = sourcePlan.copyWith(date: targetKey);
    }

    if (copiedPlans.isEmpty) {
      _error = null;
      notifyListeners();
      return 0;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dietPlans.addAll(copiedPlans);
      await _saveToPreferences();

      for (final entry in copiedPlans.entries) {
        await _saveToServer(entry.key, entry.value);
      }

      _isLoading = false;
      notifyListeners();
      return copiedPlans.length;
    } catch (e) {
      _isLoading = false;
      _error = 'Erro ao repetir plano de dieta: $e';
      notifyListeners();
      return 0;
    }
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

  // Delete diet plan for a date (or weekly plan if in weekly mode)
  Future<void> deleteDietPlan(DateTime date) async {
    final dateKey = _preferences.dietMode == DietMode.weekly
        ? _weeklyKey
        : _formatDate(date);
    _dietPlans.remove(dateKey);
    _saveToPreferences();

    // Delete from server
    await _deleteFromServer(dateKey);

    notifyListeners();
  }

  /// Cria uma dieta semanal vazia com as refeições configuradas
  Future<void> createEmptyWeeklyDiet({
    List<MealTypeConfig> mealTypes = const [],
    NutritionGoalsProvider? nutritionGoals,
  }) async {
    // Definir modo como semanal
    _preferences = _preferences.copyWith(dietMode: DietMode.weekly);

    // Criar lista de refeições vazias baseadas nos tipos configurados
    final List<PlannedMeal> emptyMeals = [];

    // Se mealTypes foi fornecido, usar. Senão, usar padrões
    final mealsToCreate = mealTypes.isNotEmpty
        ? mealTypes
        : [
            MealTypeConfig(
                id: 'breakfast', name: 'Café da Manhã', emoji: '🍳', order: 0),
            MealTypeConfig(id: 'lunch', name: 'Almoço', emoji: '🍽️', order: 1),
            MealTypeConfig(id: 'dinner', name: 'Jantar', emoji: '🍝', order: 2),
          ];

    // Horários padrão para cada refeição
    final defaultTimes = {
      'breakfast': '07:00',
      'morning_snack': '10:00',
      'lunch': '12:00',
      'afternoon_snack': '15:00',
      'dinner': '19:00',
      'supper': '21:00',
    };

    for (final mealType in mealsToCreate) {
      emptyMeals.add(PlannedMeal(
        type: mealType.id,
        time: defaultTimes[mealType.id] ?? '12:00',
        name: mealType.name,
        foods: [],
        mealTotals: DailyNutrition(
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
        ),
      ));
    }

    // Criar plano de dieta vazio
    final emptyPlan = DietPlan(
      date: _weeklyKey,
      totalNutrition: DailyNutrition(
        calories: nutritionGoals?.caloriesGoal ?? 0,
        protein: nutritionGoals?.proteinGoal.toDouble() ?? 0,
        carbs: nutritionGoals?.carbsGoal.toDouble() ?? 0,
        fat: nutritionGoals?.fatGoal.toDouble() ?? 0,
      ),
      meals: emptyMeals,
    );

    // Salvar o plano
    _dietPlans[_weeklyKey] = emptyPlan;

    await _saveToPreferences();

    // Salvar no servidor se autenticado
    if (isAuthenticated) {
      await _saveToServer(_weeklyKey, emptyPlan);
    }

    notifyListeners();
    print(
        '✅ DietPlanProvider: Dieta semanal vazia criada com ${emptyMeals.length} refeições');
  }

  /// Limpa todos os dados de dieta (usado no logout)
  Future<void> clearAll() async {
    print('[🔄 AUTH_DATA] DietPlanProvider.clearAll() - Iniciando limpeza...');
    print(
        '[🔄 AUTH_DATA] DietPlanProvider.clearAll() - Dietas antes: ${_dietPlans.length}');

    _dietPlans.clear();
    _preferences = DietPreferences();
    _partialDietPlan = null;
    _isLoading = false;
    _error = null;
    _parsedMealIndices.clear();

    // Limpar autenticação
    _authToken = null;
    _userId = null;
    _isPremium = false;

    // Limpar SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final removedPrefs = await prefs.remove('diet_preferences');
      final removedPlans = await prefs.remove('diet_plans');
      print(
          '[🔄 AUTH_DATA] DietPlanProvider.clearAll() - SharedPreferences: prefs=$removedPrefs, plans=$removedPlans');

      // Verificar se foi removido
      final checkPrefs = prefs.getString('diet_preferences');
      final checkPlans = prefs.getString('diet_plans');
      print(
          '[🔄 AUTH_DATA] DietPlanProvider.clearAll() - Verificação: prefs=${checkPrefs == null ? "NULL (OK)" : "TEM DADOS!"}, plans=${checkPlans == null ? "NULL (OK)" : "TEM DADOS!"}');
    } catch (e) {
      print(
          '[🔄 AUTH_DATA] DietPlanProvider.clearAll() - ❌ ERRO ao limpar SharedPreferences: $e');
    }

    notifyListeners();
    print(
        '[🔄 AUTH_DATA] DietPlanProvider.clearAll() - ✅ Todos os dados de dieta foram limpos');
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
      await prefs.setString(
          'diet_preferences', jsonEncode(_preferences.toJson()));

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

  List<String> _resolveUpdatedList({
    required List<String> current,
    required List<String> incoming,
    required bool merge,
  }) {
    final normalizedIncoming = incoming
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (!merge) {
      return normalizedIncoming;
    }

    final seen = <String>{};
    final merged = <String>[];
    for (final item in [...current, ...normalizedIncoming]) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        merged.add(trimmed);
      }
    }
    return merged;
  }

  String _buildDietPreferenceLines() {
    final lines = <String>[];

    if (_preferences.hasReviewedRestrictions) {
      lines.add(_preferences.foodRestrictions.isEmpty
          ? '- Restrictions: none reported'
          : '- Restrictions: ${_preferences.foodRestrictions.join(', ')}');
    }

    if (_preferences.hasReviewedFoodPreferences) {
      lines.add(_preferences.favoriteFoods.isEmpty
          ? '- Preferred foods: none specifically requested'
          : '- Preferred foods: ${_preferences.favoriteFoods.join(', ')}');
      lines.add(_preferences.avoidedFoods.isEmpty
          ? '- Foods to avoid by preference: none reported'
          : '- Foods to avoid by preference: ${_preferences.avoidedFoods.join(', ')}');
    }

    if (_preferences.hasReviewedRoutineNeeds) {
      lines.add(_preferences.routineConsiderations.isEmpty
          ? '- Appetite/routine considerations: none reported'
          : '- Appetite/routine considerations: ${_preferences.routineConsiderations.join(', ')}');
      lines.add('- Hungriest meal window: ${_preferences.hungriestMealTime}');
    }

    if (lines.isEmpty) {
      return '';
    }

    return 'Personalization notes:\n${lines.join('\n')}';
  }
}
