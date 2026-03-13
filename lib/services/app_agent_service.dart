import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../models/diet_plan_model.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import 'auth_service.dart';

class AppAgentCommand {
  const AppAgentCommand({
    required this.name,
    required this.arguments,
    required this.rawJson,
  });

  final String name;
  final Map<String, dynamic> arguments;
  final String rawJson;

  static AppAgentCommand? tryParse(String responseContent) {
    final jsonString = _extractCommandJson(responseContent);
    if (jsonString == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) {
        return null;
      }

      final root = Map<String, dynamic>.from(decoded);
      final commandNode = root['app_command'] ?? root['appCommand'];
      if (commandNode is! Map) {
        return null;
      }

      final commandMap = Map<String, dynamic>.from(commandNode);
      final name = commandMap['name']?.toString().trim();
      if (name == null || name.isEmpty) {
        return null;
      }

      final args = commandMap['arguments'];
      return AppAgentCommand(
        name: name,
        arguments: args is Map ? Map<String, dynamic>.from(args) : const {},
        rawJson: jsonString,
      );
    } catch (_) {
      return null;
    }
  }

  static bool containsCommandCandidate(String responseContent) {
    final normalized = responseContent.toLowerCase();
    return normalized.contains('"app_command"') ||
        normalized.contains('"appcommand"');
  }

  static String removeCommandJson(String responseContent) {
    final jsonString = _extractCommandJson(responseContent);
    if (jsonString == null) {
      final candidateStart = _findCommandCandidateStart(responseContent);
      if (candidateStart == null) {
        return responseContent;
      }
      return responseContent.substring(0, candidateStart).trimRight();
    }

    return responseContent.replaceAll(jsonString, '').trim();
  }

  static int? _findCommandCandidateStart(String responseContent) {
    final completeJson = _extractCommandJson(responseContent);
    if (completeJson != null) {
      final completeStart = responseContent.indexOf(completeJson);
      if (completeStart != -1) {
        return completeStart;
      }
    }

    final firstNonWhitespace = responseContent.indexOf(RegExp(r'\S'));
    if (firstNonWhitespace == -1) {
      return null;
    }

    final trimmedStart = responseContent.substring(firstNonWhitespace);
    if (trimmedStart.startsWith('{') &&
        (trimmedStart.contains('"app_command"') ||
            trimmedStart.contains('"appCommand"') ||
            trimmedStart.contains('"app') ||
            trimmedStart.contains('\\"app'))) {
      return firstNonWhitespace;
    }

    final inlineMatch = RegExp(r'\{\s*\\?"app').firstMatch(responseContent);
    return inlineMatch?.start;
  }

  static String? _extractCommandJson(String responseContent) {
    final sanitized =
        responseContent.replaceAll('```json', '').replaceAll('```', '').trim();

    final candidatePatterns = [
      RegExp(r'\{\s*"app_command"', dotAll: true),
      RegExp(r'\{\s*"appCommand"', dotAll: true),
    ];

    int? startIndex;
    for (final pattern in candidatePatterns) {
      final match = pattern.firstMatch(sanitized);
      if (match != null) {
        startIndex = match.start;
        break;
      }
    }

    if (startIndex == null) {
      return null;
    }

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = startIndex; i < sanitized.length; i++) {
      final char = sanitized[i];

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

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return sanitized.substring(startIndex, i + 1);
        }
      }
    }

    return null;
  }
}

class AppAgentExecutionResult {
  const AppAgentExecutionResult({
    required this.commandName,
    required this.success,
    required this.payload,
    this.errorMessage,
  });

  final String commandName;
  final bool success;
  final Map<String, dynamic> payload;
  final String? errorMessage;

  Map<String, dynamic> toJson() {
    return {
      'commandName': commandName,
      'success': success,
      'errorMessage': errorMessage,
      'payload': payload,
    };
  }
}

class _ResolvedMacroTargets {
  const _ResolvedMacroTargets({
    required this.carbs,
    required this.protein,
    required this.fat,
    this.autoFilledFields = const [],
  });

  final double carbs;
  final double protein;
  final double fat;
  final List<String> autoFilledFields;
}

class AppAgentService {
  static const getDailyNutritionStatus = 'get_daily_nutrition_status';
  static const getWeeklyNutritionSummary = 'get_weekly_nutrition_summary';
  static const getWeightStatus = 'get_weight_status';
  static const recalculateNutritionGoals = 'recalculate_nutrition_goals';
  static const generateNewDietPlan = 'generate_new_diet_plan';
  static const getGoalSetupStatus = 'get_goal_setup_status';
  static const updateGoalSetupProfile = 'update_goal_setup_profile';
  static const updateGoalSetupPreferences = 'update_goal_setup_preferences';
  static const getMacroTargetsStatus = 'get_macro_targets_status';
  static const updateMacroTargetsPercentage = 'update_macro_targets_percentage';
  static const updateMacroTargetsGrams = 'update_macro_targets_grams';
  static const updateMacroTargetsGramsPerKg =
      'update_macro_targets_grams_per_kg';

  static Future<AppAgentExecutionResult> executeCommand(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    switch (command.name) {
      case getDailyNutritionStatus:
        return _getDailyNutritionStatus(command, context);
      case getWeeklyNutritionSummary:
        return _getWeeklyNutritionSummary(command, context);
      case getWeightStatus:
        return _getWeightStatus(command, context);
      case recalculateNutritionGoals:
        return _recalculateNutritionGoals(command, context);
      case generateNewDietPlan:
        return _generateNewDietPlan(command, context);
      case getGoalSetupStatus:
        return _getGoalSetupStatus(command, context);
      case updateGoalSetupProfile:
        return _updateGoalSetupProfile(command, context);
      case updateGoalSetupPreferences:
        return _updateGoalSetupPreferences(command, context);
      case getMacroTargetsStatus:
        return _getMacroTargetsStatus(command, context);
      case updateMacroTargetsPercentage:
        return _updateMacroTargetsPercentage(command, context);
      case updateMacroTargetsGrams:
        return _updateMacroTargetsGrams(command, context);
      case updateMacroTargetsGramsPerKg:
        return _updateMacroTargetsGramsPerKg(command, context);
      default:
        return AppAgentExecutionResult(
          commandName: command.name,
          success: false,
          errorMessage: 'Comando do app não suportado',
          payload: {
            'supportedCommands': const [
              getDailyNutritionStatus,
              getWeeklyNutritionSummary,
              getWeightStatus,
              recalculateNutritionGoals,
              generateNewDietPlan,
              getGoalSetupStatus,
              updateGoalSetupProfile,
              updateGoalSetupPreferences,
              getMacroTargetsStatus,
              updateMacroTargetsPercentage,
              updateMacroTargetsGrams,
              updateMacroTargetsGramsPerKg,
            ],
          },
        );
    }
  }

  static String buildLoadingMessage(BuildContext context, String commandName) {
    final l10n = AppLocalizations.of(context);
    switch (commandName) {
      case getDailyNutritionStatus:
        return l10n.translate('agent_loading_daily_status');
      case getWeeklyNutritionSummary:
        return l10n.translate('agent_loading_weekly_status');
      case getWeightStatus:
        return l10n.translate('agent_loading_weight_status');
      case recalculateNutritionGoals:
        return l10n.translate('agent_loading_recalculate_goals');
      case generateNewDietPlan:
        return l10n.translate('agent_loading_generate_diet');
      case getGoalSetupStatus:
        return l10n.translate('agent_loading_goal_setup_status');
      case updateGoalSetupProfile:
        return l10n.translate('agent_loading_update_goal_profile');
      case updateGoalSetupPreferences:
        return l10n.translate('agent_loading_update_goal_preferences');
      case getMacroTargetsStatus:
        return l10n.translate('agent_loading_macro_status');
      case updateMacroTargetsPercentage:
        return l10n.translate('agent_loading_update_macros_percentage');
      case updateMacroTargetsGrams:
        return l10n.translate('agent_loading_update_macros_grams');
      case updateMacroTargetsGramsPerKg:
        return l10n.translate('agent_loading_update_macros_per_kg');
      default:
        return l10n.translate('agent_loading_generic');
    }
  }

  static String sanitizeDisplayMessage(
    String rawContent, {
    required bool autoRegisterFoods,
    required String Function(String rawContent) fallbackSanitizer,
  }) {
    if (AppAgentCommand.containsCommandCandidate(rawContent)) {
      return AppAgentCommand.removeCommandJson(rawContent);
    }

    return fallbackSanitizer(rawContent);
  }

  static String buildFollowUpPrompt({
    required String originalUserMessage,
    required AppAgentExecutionResult executionResult,
  }) {
    final resultJson = jsonEncode(executionResult.toJson());

    return '''
[APP_COMMAND_RESULT_BEGIN]
$resultJson
[APP_COMMAND_RESULT_END]

Pedido original do usuário:
$originalUserMessage

Use o resultado do app acima para responder ao usuário em linguagem natural. Não revele nomes internos de comandos, não use JSON na resposta final e não peça os mesmos dados novamente se eles já vieram no resultado.
Responda no mesmo idioma do pedido original do usuário.
''';
  }

  static Future<AppAgentExecutionResult> _getDailyNutritionStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final meals = mealsProvider.todayMeals
        .map((meal) => {
              'type': meal.type.name,
              'foods': meal.foods.map((food) => food.name).toList(),
              'calories': meal.totalCalories,
              'protein': meal.totalProtein,
              'carbs': meal.totalCarbs,
              'fat': meal.totalFat,
            })
        .toList();

    final payload = {
      'selectedDate': mealsProvider.selectedDate.toIso8601String(),
      'hasConfiguredGoals': goalsProvider.hasConfiguredGoals,
      'caloriesGoal': goalsProvider.caloriesGoal,
      'caloriesConsumed': mealsProvider.totalCalories,
      'caloriesRemaining':
          goalsProvider.caloriesGoal - mealsProvider.totalCalories,
      'proteinGoal': goalsProvider.proteinGoal,
      'proteinConsumed': _round1(mealsProvider.totalProtein),
      'proteinRemaining':
          goalsProvider.proteinGoal - _round1(mealsProvider.totalProtein),
      'carbsGoal': goalsProvider.carbsGoal,
      'carbsConsumed': _round1(mealsProvider.totalCarbs),
      'carbsRemaining':
          goalsProvider.carbsGoal - _round1(mealsProvider.totalCarbs),
      'fatGoal': goalsProvider.fatGoal,
      'fatConsumed': _round1(mealsProvider.totalFat),
      'fatRemaining': goalsProvider.fatGoal - _round1(mealsProvider.totalFat),
      'waterGoal': mealsProvider.waterGoal,
      'waterConsumed': mealsProvider.todayWaterGlasses,
      'meals': meals,
    };

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: payload,
    );
  }

  static Future<AppAgentExecutionResult> _getWeeklyNutritionSummary(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final history = mealsProvider.getCaloriesHistory(7);
    final macrosHistory = mealsProvider.getMacrosHistory(7);
    final averageMacros = mealsProvider.getAverageMacros(7);
    final daysWithinGoal = history
        .where((day) =>
            (day['calories'] as int) > 0 &&
            ((day['calories'] as int) - goalsProvider.caloriesGoal).abs() <=
                150)
        .length;

    final payload = {
      'caloriesGoal': goalsProvider.caloriesGoal,
      'averageCalories': mealsProvider.getAverageCalories(7).round(),
      'averageMacros': {
        'protein': _round1(averageMacros['protein'] ?? 0),
        'carbs': _round1(averageMacros['carbs'] ?? 0),
        'fat': _round1(averageMacros['fat'] ?? 0),
        'fiber': _round1(averageMacros['fiber'] ?? 0),
      },
      'currentStreak': mealsProvider.getCurrentStreak(),
      'totalDaysLogged': mealsProvider.getTotalDaysLogged(),
      'totalMealsLogged': mealsProvider.getTotalMealsLogged(),
      'daysWithinGoal': daysWithinGoal,
      'history': List.generate(history.length, (index) {
        final day = history[index];
        final macros = macrosHistory[index];
        return {
          'date': (day['date'] as DateTime).toIso8601String(),
          'calories': day['calories'],
          'hasData': day['hasData'],
          'protein': _round1(macros['protein'] as double? ?? 0),
          'carbs': _round1(macros['carbs'] as double? ?? 0),
          'fat': _round1(macros['fat'] as double? ?? 0),
          'fiber': _round1(macros['fiber'] as double? ?? 0),
        };
      }),
    };

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: payload,
    );
  }

  static Future<AppAgentExecutionResult> _getWeightStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final heightInMeters = goalsProvider.height / 100;
    final bmi = heightInMeters > 0
        ? goalsProvider.weight / math.pow(heightInMeters, 2)
        : 0.0;

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'hasConfiguredGoals': goalsProvider.hasConfiguredGoals,
        'weightKg': goalsProvider.weight,
        'formattedWeight': goalsProvider.getFormattedWeight(),
        'heightCm': goalsProvider.height,
        'formattedHeight': goalsProvider.getFormattedHeight(),
        'bmi': _round2(bmi),
        'goal': goalsProvider.fitnessGoal.name,
        'dietType': goalsProvider.dietType.name,
        'caloriesGoal': goalsProvider.caloriesGoal,
        'proteinGoal': goalsProvider.proteinGoal,
        'carbsGoal': goalsProvider.carbsGoal,
        'fatGoal': goalsProvider.fatGoal,
      },
    );
  }

  static Future<AppAgentExecutionResult> _recalculateNutritionGoals(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final previousMode = goalsProvider.useCalculatedGoals;
    goalsProvider.setUseCalculatedGoals(true);

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'switchedToCalculatedGoals': !previousMode,
        'caloriesGoal': goalsProvider.caloriesGoal,
        'proteinGoal': goalsProvider.proteinGoal,
        'carbsGoal': goalsProvider.carbsGoal,
        'fatGoal': goalsProvider.fatGoal,
        'formula': goalsProvider.formula.name,
        'activityLevel': goalsProvider.activityLevel.name,
        'fitnessGoal': goalsProvider.fitnessGoal.name,
        'dietType': goalsProvider.dietType.name,
      },
    );
  }

  static Future<AppAgentExecutionResult> _generateNewDietPlan(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealTypesProvider =
        Provider.of<MealTypesProvider>(context, listen: false);

    await goalsProvider.ensureLoaded();
    await mealTypesProvider.ensureLoaded();

    if (!authService.isAuthenticated || authService.currentUser == null) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'login_required',
        payload: {
          'reason': 'login_required',
        },
      );
    }

    if (!goalsProvider.hasConfiguredGoals) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'nutrition_goals_required',
        payload: {
          'reason': 'nutrition_goals_required',
        },
      );
    }

    if (!dietProvider.isAuthenticated) {
      await dietProvider.setAuth(
        authService.token ?? '',
        authService.currentUser!.id,
      );
    }

    if (dietProvider.dietMode == DietMode.daily && !dietProvider.isPremium) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'daily_diet_premium_required',
        payload: {
          'reason': 'daily_diet_premium_required',
          'dietMode': dietProvider.dietMode.name,
        },
      );
    }

    final locale = Localizations.localeOf(context);
    final languageCode =
        '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
    final userId = authService.currentUser?.id.toString() ?? '';

    await dietProvider.generateDietPlan(
      dietProvider.selectedDate,
      goalsProvider,
      mealTypes: mealTypesProvider.mealTypes,
      userId: userId,
      languageCode: languageCode,
    );

    if (dietProvider.error != null || dietProvider.currentDietPlan == null) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: dietProvider.error ?? 'diet_generation_failed',
        payload: {
          'reason': dietProvider.error ?? 'diet_generation_failed',
          'dietMode': dietProvider.dietMode.name,
        },
      );
    }

    final plan = dietProvider.currentDietPlan!;
    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'dietMode': dietProvider.dietMode.name,
        'selectedDate': dietProvider.selectedDate.toIso8601String(),
        'totalCalories': plan.totalNutrition.calories,
        'totalProtein': _round1(plan.totalNutrition.protein),
        'totalCarbs': _round1(plan.totalNutrition.carbs),
        'totalFat': _round1(plan.totalNutrition.fat),
        'mealCount': plan.meals.length,
        'meals': plan.meals.map(_serializePlannedMeal).toList(),
      },
    );
  }

  static Future<AppAgentExecutionResult> _getGoalSetupStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: _buildGoalSetupPayload(goalsProvider),
    );
  }

  static Future<AppAgentExecutionResult> _updateGoalSetupProfile(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final normalizedSex = _normalizeSex(
      command.arguments['sex'] ?? command.arguments['gender'],
    );
    final age = _tryParseInt(command.arguments['age']);
    final weight = _tryParseDouble(
      command.arguments['weightKg'] ??
          command.arguments['weight_kg'] ??
          command.arguments['weight'],
    );
    final height = _tryParseDouble(
      command.arguments['heightCm'] ??
          command.arguments['height_cm'] ??
          command.arguments['height'],
    );
    final bodyFat = _tryParseDouble(
      command.arguments['bodyFat'] ?? command.arguments['body_fat'],
    );

    final updatedFields = <String>[];
    if (normalizedSex != null) {
      updatedFields.add('sex');
    }
    if (age != null) {
      updatedFields.add('age');
    }
    if (weight != null) {
      updatedFields.add('weightKg');
    }
    if (height != null) {
      updatedFields.add('heightCm');
    }
    if (bodyFat != null) {
      updatedFields.add('bodyFat');
    }

    if (updatedFields.isEmpty) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'missing_profile_arguments',
        payload: {
          'acceptedArguments': const [
            'sex',
            'gender',
            'age',
            'weightKg',
            'weight_kg',
            'heightCm',
            'height_cm',
            'bodyFat',
          ],
        },
      );
    }

    goalsProvider.updatePersonalInfo(
      sex: normalizedSex,
      age: age,
      weight: weight,
      height: height,
      bodyFat: bodyFat,
    );

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'updatedFields': updatedFields,
        ..._buildGoalSetupPayload(goalsProvider),
      },
    );
  }

  static Future<AppAgentExecutionResult> _updateGoalSetupPreferences(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final activityLevel = _parseActivityLevel(
      command.arguments['activityLevel'] ?? command.arguments['activity_level'],
    );
    final fitnessGoal = _parseFitnessGoal(
      command.arguments['fitnessGoal'] ?? command.arguments['fitness_goal'],
    );
    final formula = _parseCalculationFormula(command.arguments['formula']);

    final updatedFields = <String>[];
    if (activityLevel != null) {
      updatedFields.add('activityLevel');
    }
    if (fitnessGoal != null) {
      updatedFields.add('fitnessGoal');
    }
    if (formula != null) {
      updatedFields.add('formula');
    }

    if (updatedFields.isEmpty) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'missing_goal_preference_arguments',
        payload: {
          'acceptedArguments': const [
            'activityLevel',
            'activity_level',
            'fitnessGoal',
            'fitness_goal',
            'formula',
          ],
        },
      );
    }

    goalsProvider.updateActivityAndGoals(
      activityLevel: activityLevel,
      fitnessGoal: fitnessGoal,
      formula: formula,
    );

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'updatedFields': updatedFields,
        ..._buildGoalSetupPayload(goalsProvider),
      },
    );
  }

  static Future<AppAgentExecutionResult> _getMacroTargetsStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: goalsProvider.getMacroSnapshot(),
    );
  }

  static Future<AppAgentExecutionResult> _updateMacroTargetsPercentage(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final resolved = _resolvePercentageTargets(
      carbs: _tryParseDouble(
        command.arguments['carbsPercentage'] ??
            command.arguments['carbs_percentage'] ??
            command.arguments['carbs'],
      ),
      protein: _tryParseDouble(
        command.arguments['proteinPercentage'] ??
            command.arguments['protein_percentage'] ??
            command.arguments['protein'],
      ),
      fat: _tryParseDouble(
        command.arguments['fatPercentage'] ??
            command.arguments['fat_percentage'] ??
            command.arguments['fat'],
      ),
    );

    if (resolved == null) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'invalid_macro_percentage_arguments',
        payload: {
          'acceptedArguments': const [
            'carbsPercentage',
            'proteinPercentage',
            'fatPercentage',
          ],
          'rule':
              'Informe os 3 percentuais ou pelo menos 2 para completar o terceiro automaticamente.',
        },
      );
    }

    goalsProvider.updateMacroTargetsFromPercentages(
      carbsPercentage: resolved.carbs,
      proteinPercentage: resolved.protein,
      fatPercentage: resolved.fat,
    );

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'updatedByMode': 'percentage',
        'autoFilledFields': resolved.autoFilledFields,
        ...goalsProvider.getMacroSnapshot(),
      },
    );
  }

  static Future<AppAgentExecutionResult> _updateMacroTargetsGrams(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final resolved = _resolveGramTargets(
      carbs: _tryParseDouble(
        command.arguments['carbsGrams'] ??
            command.arguments['carbs_grams'] ??
            command.arguments['carbs'],
      ),
      protein: _tryParseDouble(
        command.arguments['proteinGrams'] ??
            command.arguments['protein_grams'] ??
            command.arguments['protein'],
      ),
      fat: _tryParseDouble(
        command.arguments['fatGrams'] ??
            command.arguments['fat_grams'] ??
            command.arguments['fat'],
      ),
      calorieTarget: goalsProvider.caloriesGoal.toDouble(),
    );

    if (resolved == null) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'invalid_macro_gram_arguments',
        payload: {
          'acceptedArguments': const [
            'carbsGrams',
            'proteinGrams',
            'fatGrams',
          ],
          'rule':
              'Informe os 3 macros em gramas ou pelo menos 2 para completar o restante com base na meta atual.',
        },
      );
    }

    goalsProvider.updateMacroTargetsFromGrams(
      carbsGrams: resolved.carbs,
      proteinGrams: resolved.protein,
      fatGrams: resolved.fat,
    );

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'updatedByMode': 'grams',
        'autoFilledFields': resolved.autoFilledFields,
        ...goalsProvider.getMacroSnapshot(),
      },
    );
  }

  static Future<AppAgentExecutionResult> _updateMacroTargetsGramsPerKg(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await goalsProvider.ensureLoaded();

    final weight = goalsProvider.weight <= 0 ? 1.0 : goalsProvider.weight;
    final carbsPerKg = _tryParseDouble(
      command.arguments['carbsPerKg'] ?? command.arguments['carbs_per_kg'],
    );
    final proteinPerKg = _tryParseDouble(
      command.arguments['proteinPerKg'] ?? command.arguments['protein_per_kg'],
    );
    final fatPerKg = _tryParseDouble(
      command.arguments['fatPerKg'] ?? command.arguments['fat_per_kg'],
    );
    final resolvedInGrams = _resolveGramTargets(
      carbs: carbsPerKg == null ? null : carbsPerKg * weight,
      protein: proteinPerKg == null ? null : proteinPerKg * weight,
      fat: fatPerKg == null ? null : fatPerKg * weight,
      calorieTarget: goalsProvider.caloriesGoal.toDouble(),
    );

    if (resolvedInGrams == null) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'invalid_macro_per_kg_arguments',
        payload: {
          'acceptedArguments': const [
            'carbsPerKg',
            'proteinPerKg',
            'fatPerKg',
          ],
          'rule':
              'Informe os 3 macros em g/kg ou pelo menos 2 para completar o restante com base na meta atual.',
        },
      );
    }

    goalsProvider.updateMacroTargetsFromGrams(
      carbsGrams: resolvedInGrams.carbs,
      proteinGrams: resolvedInGrams.protein,
      fatGrams: resolvedInGrams.fat,
    );

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'updatedByMode': 'grams_per_kg',
        'autoFilledFields': resolvedInGrams.autoFilledFields,
        ...goalsProvider.getMacroSnapshot(),
      },
    );
  }

  static Map<String, dynamic> _serializePlannedMeal(PlannedMeal meal) {
    return {
      'type': meal.type,
      'name': meal.name,
      'time': meal.time,
      'calories': meal.mealTotals.calories,
      'foods': meal.foods
          .map((food) => {
                'name': food.name,
                'amount': food.amount,
                'unit': food.unit,
                'calories': food.calories,
              })
          .toList(),
    };
  }

  static Map<String, dynamic> _buildGoalSetupPayload(
    NutritionGoalsProvider goalsProvider,
  ) {
    return {
      'hasConfiguredGoals': goalsProvider.hasConfiguredGoals,
      'configurationStatus': goalsProvider.hasConfiguredGoals
          ? 'configured'
          : 'needs_initial_setup',
      'requiredFieldsForInitialSetup': goalsProvider.hasConfiguredGoals
          ? const []
          : const [
              'age',
              'height_cm',
              'weight_kg',
              'sex',
              'activity_level',
              'fitness_goal',
            ],
      'sex': goalsProvider.sex,
      'age': goalsProvider.age,
      'weightKg': _round1(goalsProvider.weight),
      'heightCm': _round1(goalsProvider.height),
      'activityLevel': goalsProvider.activityLevel.name,
      'fitnessGoal': goalsProvider.fitnessGoal.name,
      'formula': goalsProvider.formula.name,
      'dietType': goalsProvider.dietType.name,
      'caloriesGoal': goalsProvider.caloriesGoal,
      'proteinGoal': goalsProvider.proteinGoal,
      'carbsGoal': goalsProvider.carbsGoal,
      'fatGoal': goalsProvider.fatGoal,
      'macroEditingAvailable': goalsProvider.hasConfiguredGoals,
      'macroTargets': goalsProvider.getMacroSnapshot(),
    };
  }

  static _ResolvedMacroTargets? _resolvePercentageTargets({
    required double? carbs,
    required double? protein,
    required double? fat,
  }) {
    final provided = {
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
    }..removeWhere((_, value) => value == null);

    if (provided.length < 2) {
      return null;
    }

    final autoFilledFields = <String>[];
    var resolvedCarbs = carbs;
    var resolvedProtein = protein;
    var resolvedFat = fat;
    final totalProvided =
        provided.values.fold<double>(0, (sum, value) => sum + value!);

    if (provided.length == 2) {
      final remaining = 100 - totalProvided;
      if (remaining <= 0) {
        return null;
      }

      if (resolvedCarbs == null) {
        resolvedCarbs = remaining;
        autoFilledFields.add('carbs');
      } else if (resolvedProtein == null) {
        resolvedProtein = remaining;
        autoFilledFields.add('protein');
      } else if (resolvedFat == null) {
        resolvedFat = remaining;
        autoFilledFields.add('fat');
      }
    }

    if (resolvedCarbs == null ||
        resolvedProtein == null ||
        resolvedFat == null) {
      return null;
    }

    final total = resolvedCarbs + resolvedProtein + resolvedFat;
    if ((total - 100).abs() > 0.5) {
      return null;
    }

    return _ResolvedMacroTargets(
      carbs: resolvedCarbs,
      protein: resolvedProtein,
      fat: resolvedFat,
      autoFilledFields: autoFilledFields,
    );
  }

  static _ResolvedMacroTargets? _resolveGramTargets({
    required double? carbs,
    required double? protein,
    required double? fat,
    required double calorieTarget,
  }) {
    final provided = {
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
    }..removeWhere((_, value) => value == null);

    if (provided.length < 2) {
      return null;
    }

    final autoFilledFields = <String>[];
    var resolvedCarbs = carbs;
    var resolvedProtein = protein;
    var resolvedFat = fat;

    if (provided.length == 2) {
      final caloriesFromKnownMacros = (resolvedCarbs ?? 0) * 4 +
          (resolvedProtein ?? 0) * 4 +
          (resolvedFat ?? 0) * 9;
      final remainingCalories = calorieTarget - caloriesFromKnownMacros;
      if (remainingCalories <= 0) {
        return null;
      }

      if (resolvedCarbs == null) {
        resolvedCarbs = remainingCalories / 4;
        autoFilledFields.add('carbs');
      } else if (resolvedProtein == null) {
        resolvedProtein = remainingCalories / 4;
        autoFilledFields.add('protein');
      } else if (resolvedFat == null) {
        resolvedFat = remainingCalories / 9;
        autoFilledFields.add('fat');
      }
    }

    if (resolvedCarbs == null ||
        resolvedProtein == null ||
        resolvedFat == null) {
      return null;
    }

    if (resolvedCarbs <= 0 || resolvedProtein <= 0 || resolvedFat <= 0) {
      return null;
    }

    return _ResolvedMacroTargets(
      carbs: resolvedCarbs,
      protein: resolvedProtein,
      fat: resolvedFat,
      autoFilledFields: autoFilledFields,
    );
  }

  static String? _normalizeSex(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'male':
      case 'man':
      case 'masculino':
      case 'homem':
        return 'male';
      case 'female':
      case 'woman':
      case 'feminino':
      case 'mulher':
        return 'female';
      default:
        return null;
    }
  }

  static ActivityLevel? _parseActivityLevel(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'sedentary':
      case 'sedentario':
      case 'sedentário':
        return ActivityLevel.sedentary;
      case 'lightlyactive':
      case 'lightly_active':
      case 'light':
      case 'leve':
      case 'levemente ativo':
      case 'levemente_ativo':
        return ActivityLevel.lightlyActive;
      case 'moderatelyactive':
      case 'moderately_active':
      case 'moderate':
      case 'moderado':
      case 'moderadamente ativo':
      case 'moderadamente_ativo':
        return ActivityLevel.moderatelyActive;
      case 'veryactive':
      case 'very_active':
      case 'very':
      case 'muito ativo':
      case 'muito_ativo':
      case 'intenso':
        return ActivityLevel.veryActive;
      case 'extremelyactive':
      case 'extremely_active':
      case 'extreme':
      case 'extremo':
      case 'extremamente ativo':
      case 'extremamente_ativo':
        return ActivityLevel.extremelyActive;
      default:
        return null;
    }
  }

  static FitnessGoal? _parseFitnessGoal(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'loseweight':
      case 'lose_weight':
      case 'lose fat':
      case 'perder peso':
      case 'perder_peso':
        return FitnessGoal.loseWeight;
      case 'loseweightslowly':
      case 'lose_weight_slowly':
      case 'perder peso lentamente':
      case 'perder_peso_lentamente':
        return FitnessGoal.loseWeightSlowly;
      case 'maintainweight':
      case 'maintain_weight':
      case 'maintain':
      case 'manter peso':
      case 'manter_peso':
        return FitnessGoal.maintainWeight;
      case 'gainweightslowly':
      case 'gain_weight_slowly':
      case 'ganhar peso lentamente':
      case 'ganhar_peso_lentamente':
        return FitnessGoal.gainWeightSlowly;
      case 'gainweight':
      case 'gain_weight':
      case 'bulk':
      case 'ganhar peso':
      case 'ganhar_peso':
        return FitnessGoal.gainWeight;
      default:
        return null;
    }
  }

  static CalculationFormula? _parseCalculationFormula(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'mifflinstjeor':
      case 'mifflin_st_jeor':
      case 'mifflin-st-jeor':
        return CalculationFormula.mifflinStJeor;
      case 'harrisbenedict':
      case 'harris_benedict':
      case 'harris-benedict':
        return CalculationFormula.harrisBenedict;
      case 'katchmcardle':
      case 'katch_mcardle':
      case 'katch-mcardle':
        return CalculationFormula.katchMcArdle;
      default:
        return null;
    }
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString().trim());
  }

  static double? _tryParseDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().trim().replaceAll(',', '.'));
  }

  static double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  static double _round1(double value) {
    return (value * 10).roundToDouble() / 10;
  }
}
