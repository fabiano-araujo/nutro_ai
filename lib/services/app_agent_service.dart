import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../models/diet_plan_model.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import 'auth_service.dart';
import 'server_chat_state_service.dart';

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
    final batch = tryParseBatch(responseContent);
    if (batch == null || batch.commands.isEmpty) {
      return null;
    }
    return batch.commands.first;
  }

  static AppAgentCommandBatch? tryParseBatch(String responseContent) {
    final jsonString = _extractCommandJson(responseContent);
    if (jsonString == null) {
      return null;
    }

    try {
      final decoded = _decodeCommandJson(jsonString);
      if (decoded is List) {
        final commands = <AppAgentCommand>[];
        for (final item in decoded) {
          if (item is! Map) {
            continue;
          }

          final command = _buildCommandFromMap(
            Map<String, dynamic>.from(item),
            jsonEncode(item),
          );
          if (command != null) {
            commands.add(command);
          }
        }

        if (commands.isEmpty) {
          return null;
        }

        return AppAgentCommandBatch(commands: commands, rawJson: jsonString);
      }

      if (decoded is! Map) {
        return null;
      }

      final root = Map<String, dynamic>.from(decoded);
      final commands = <AppAgentCommand>[];

      final batchNode = root['app_commands'] ?? root['appcommands'];
      if (batchNode is List) {
        for (final item in batchNode) {
          if (item is! Map) {
            continue;
          }

          final command = _buildCommandFromMap(
            Map<String, dynamic>.from(item),
            jsonEncode({'app_command': item}),
          );
          if (command != null) {
            commands.add(command);
          }
        }
      }

      final commandNode =
          root['app_command'] ?? root['appCommand'] ?? root['appcommand'];
      if (commandNode is Map) {
        final command = _buildCommandFromMap(
          Map<String, dynamic>.from(commandNode),
          jsonString,
        );
        if (command != null) {
          commands.add(command);
        }
      }

      if (commands.isEmpty) {
        return null;
      }

      return AppAgentCommandBatch(
        commands: commands,
        rawJson: jsonString,
      );
    } catch (_) {
      return null;
    }
  }

  static dynamic _decodeCommandJson(String jsonString) {
    try {
      return jsonDecode(jsonString);
    } catch (_) {
      final normalized = jsonString
          .replaceAll(r'\"', '"')
          .replaceAll(r"\'", "'")
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\t', '\t');
      return jsonDecode(normalized);
    }
  }

  static bool containsCommandCandidate(String responseContent) {
    final normalized = responseContent.toLowerCase();
    return normalized.contains('"app_command"') ||
        normalized.contains('"appcommand"') ||
        normalized.contains('"app_commands"') ||
        normalized.contains('"appcommands"') ||
        normalized.contains('"commandname"');
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
            trimmedStart.contains('"appcommand"') ||
            trimmedStart.contains('"appcommands"') ||
            trimmedStart.contains('"app') ||
            trimmedStart.contains('\\"app'))) {
      return firstNonWhitespace;
    }

    if (trimmedStart.startsWith('[') &&
        (trimmedStart.contains('"commandName"') ||
            trimmedStart.contains('"name"'))) {
      return firstNonWhitespace;
    }

    final inlineMatch = RegExp(r'\{\s*\\?"app').firstMatch(responseContent);
    if (inlineMatch != null) {
      return inlineMatch.start;
    }

    final arrayInlineMatch =
        RegExp(r'\[\s*\{\s*\\?"(?:commandName|name)"').firstMatch(
      responseContent,
    );
    return arrayInlineMatch?.start;
  }

  static String? _extractCommandJson(String responseContent) {
    final sanitized =
        responseContent.replaceAll('```json', '').replaceAll('```', '').trim();
    final firstNonWhitespace = sanitized.indexOf(RegExp(r'\S'));
    final trimmedStart =
        firstNonWhitespace == -1 ? '' : sanitized.substring(firstNonWhitespace);

    final candidatePatterns = [
      RegExp(r'\{\s*\\?"app_commands\\?"', dotAll: true),
      RegExp(r'\{\s*\\?"appcommands\\?"', dotAll: true),
      RegExp(r'\{\s*\\?"app_command\\?"', dotAll: true),
      RegExp(r'\{\s*\\?"appcommand\\?"', dotAll: true),
      RegExp(r'\{\s*\\?"appCommand\\?"', dotAll: true),
    ];

    int? startIndex;
    for (final pattern in candidatePatterns) {
      final match = pattern.firstMatch(sanitized);
      if (match != null) {
        startIndex = match.start;
        break;
      }
    }

    if (startIndex == null && trimmedStart.startsWith('[')) {
      final rootArrayMatch =
          RegExp(r'^\[\s*\{\s*\\?"(commandName|name)\\?"', dotAll: true)
              .firstMatch(trimmedStart);
      if (rootArrayMatch != null) {
        startIndex = firstNonWhitespace;
      }
    }

    if (startIndex == null) {
      final looseBatchMatch = RegExp(
        r'\\?"?app_commands\\?"?\s*:\s*\[',
        caseSensitive: false,
      ).firstMatch(sanitized);
      if (looseBatchMatch != null) {
        final arrayStart = sanitized.indexOf('[', looseBatchMatch.start);
        final arrayJson = _extractBalancedJsonBlock(sanitized, arrayStart);
        if (arrayJson != null) {
          return '{"app_commands":$arrayJson}';
        }
      }

      final looseSingleMatch = RegExp(
        r'\\?"?app_command\\?"?\s*:\s*\{',
        caseSensitive: false,
      ).firstMatch(sanitized);
      if (looseSingleMatch != null) {
        final objectStart = sanitized.indexOf('{', looseSingleMatch.start);
        final objectJson = _extractBalancedJsonBlock(sanitized, objectStart);
        if (objectJson != null) {
          return '{"app_command":$objectJson}';
        }
      }

      return null;
    }

    return _extractBalancedJsonBlock(sanitized, startIndex);
  }

  static String? _extractBalancedJsonBlock(String content, int startIndex) {
    if (startIndex < 0 || startIndex >= content.length) {
      return null;
    }

    final openingChar = content[startIndex];
    final closingChar = openingChar == '[' ? ']' : '}';
    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = startIndex; i < content.length; i++) {
      final char = content[i];

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

      if (char == openingChar) {
        depth++;
      } else if (char == closingChar) {
        depth--;
        if (depth == 0) {
          return content.substring(startIndex, i + 1);
        }
      }
    }

    return null;
  }

  static AppAgentCommand? _buildCommandFromMap(
    Map<String, dynamic> commandMap,
    String rawJson,
  ) {
    final rawName = commandMap['name']?.toString().trim() ??
        commandMap['commandName']?.toString().trim() ??
        commandMap['command_name']?.toString().trim() ??
        (commandMap['app_command'] is String
            ? commandMap['app_command']?.toString().trim()
            : null);
    final name = _canonicalCommandName(rawName);
    if (name == null || name.isEmpty) {
      return null;
    }

    final args = _extractArguments(commandMap, name);
    return AppAgentCommand(
      name: name,
      arguments: args,
      rawJson: rawJson,
    );
  }

  static Map<String, dynamic> _extractArguments(
    Map<String, dynamic> commandMap,
    String commandName,
  ) {
    final argsNode = commandMap['arguments'] ?? commandMap['args'];
    Map<String, dynamic> args;
    if (argsNode is Map) {
      args = Map<String, dynamic>.from(argsNode);
    } else {
      args = Map<String, dynamic>.from(commandMap)
        ..remove('name')
        ..remove('commandName')
        ..remove('command_name')
        ..remove('app_command')
        ..remove('appCommand')
        ..remove('appcommand')
        ..remove('arguments')
        ..remove('args');
    }

    return _normalizeCommandArguments(commandName, args);
  }

  static Map<String, dynamic> _normalizeCommandArguments(
    String commandName,
    Map<String, dynamic> args,
  ) {
    final normalized = Map<String, dynamic>.from(args)
      ..removeWhere((key, value) => value == null);

    switch (commandName) {
      case AppAgentService.updateGoalSetupProfile:
        final sex = AppAgentService._normalizeSex(
          AppAgentService._readFirstValue(
            normalized,
            const ['sex', 'gender', 'sexo'],
          ),
        );
        final age = AppAgentService._tryParseInt(
          AppAgentService._readFirstValue(normalized, const ['age', 'idade']),
        );
        final weight = AppAgentService._tryParseDouble(
          AppAgentService._readFirstValue(
            normalized,
            const ['weightKg', 'weight_kg', 'weight', 'peso', 'peso_kg'],
          ),
        );
        final height = AppAgentService._tryParseDouble(
          AppAgentService._readFirstValue(
            normalized,
            const ['heightCm', 'height_cm', 'height', 'altura', 'altura_cm'],
          ),
        );
        final bodyFat = AppAgentService._tryParseDouble(
          AppAgentService._readFirstValue(
            normalized,
            const ['bodyFat', 'body_fat'],
          ),
        );

        return {
          if (sex != null) 'sex': sex,
          if (age != null) 'age': age,
          if (weight != null) 'weightKg': weight,
          if (height != null) 'heightCm': height,
          if (bodyFat != null) 'bodyFat': bodyFat,
        };

      case AppAgentService.updateGoalSetupPreferences:
        final activityLevel = AppAgentService._parseActivityLevel(
          AppAgentService._readFirstValue(
            normalized,
            const [
              'activityLevel',
              'activity_level',
              'activity',
              'activityLevelName',
              'nivel_atividade',
            ],
          ),
        );
        final fitnessGoal = AppAgentService._parseFitnessGoal(
          AppAgentService._readFirstValue(
            normalized,
            const [
              'fitnessGoal',
              'fitness_goal',
              'goal',
              'objective',
              'objetivo',
            ],
          ),
        );

        return {
          if (activityLevel != null) 'activityLevel': activityLevel.name,
          if (fitnessGoal != null) 'fitnessGoal': fitnessGoal.name,
        };

      case AppAgentService.updateDietGenerationPreferences:
        final mealsPerDay = AppAgentService._tryParseInt(
          AppAgentService._readFirstValue(
            normalized,
            const ['mealsPerDay', 'meals_per_day'],
          ),
        );
        final skipPreferenceStep = AppAgentService._tryParseBool(
          AppAgentService._readFirstValue(
            normalized,
            const [
              'skipPreferenceStep',
              'skip_preference_step',
              'markAllReviewed',
              'mark_all_reviewed',
              'noExtraPreferences',
              'no_extra_preferences',
            ],
          ),
        );
        final mealWindow = AppAgentService._normalizeMealWindow(
          AppAgentService._readFirstValue(
            normalized,
            const ['hungriestMealTime', 'hungriest_meal_time', 'hungriestMeal'],
          ),
        );

        return {
          if (skipPreferenceStep == true) 'skipPreferenceStep': true,
          if (mealsPerDay != null) 'mealsPerDay': mealsPerDay,
          if (AppAgentService._hasAnyKey(normalized, const [
            'foodRestrictions',
            'restrictions',
            'dietaryRestrictions',
            'allergies',
          ]))
            'foodRestrictions': AppAgentService._extractStringList(
              AppAgentService._readFirstValue(
                normalized,
                const [
                  'foodRestrictions',
                  'restrictions',
                  'dietaryRestrictions',
                  'allergies',
                ],
              ),
            ),
          if (AppAgentService._hasAnyKey(normalized, const [
            'favoriteFoods',
            'preferredFoods',
            'likedFoods',
            'foodPreferences',
          ]))
            'favoriteFoods': AppAgentService._extractStringList(
              AppAgentService._readFirstValue(
                normalized,
                const [
                  'favoriteFoods',
                  'preferredFoods',
                  'likedFoods',
                  'foodPreferences',
                ],
              ),
            ),
          if (AppAgentService._hasAnyKey(normalized, const [
            'avoidedFoods',
            'dislikedFoods',
            'foodsToAvoid',
          ]))
            'avoidedFoods': AppAgentService._extractStringList(
              AppAgentService._readFirstValue(
                normalized,
                const ['avoidedFoods', 'dislikedFoods', 'foodsToAvoid'],
              ),
            ),
          if (AppAgentService._hasAnyKey(normalized, const [
            'routineConsiderations',
            'routineNotes',
            'appetiteNotes',
          ]))
            'routineConsiderations': AppAgentService._extractStringList(
              AppAgentService._readFirstValue(
                normalized,
                const [
                  'routineConsiderations',
                  'routineNotes',
                  'appetiteNotes',
                ],
              ),
            ),
          if (mealWindow != null) 'hungriestMealTime': mealWindow,
        };

      default:
        return normalized;
    }
  }

  static String? _canonicalCommandName(String? rawName) {
    final trimmed = rawName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final normalized =
        trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    const aliases = <String, String>{
      'getdailynutritionstatus': 'get_daily_nutrition_status',
      'getweeklynutritionsummary': 'get_weekly_nutrition_summary',
      'getweightstatus': 'get_weight_status',
      'recalculatenutritiongoals': 'recalculate_nutrition_goals',
      'generatenewdietplan': 'generate_new_diet_plan',
      'getgoalsetupstatus': 'get_goal_setup_status',
      'updategoalsetupprofile': 'update_goal_setup_profile',
      'updategoalsetuppreferences': 'update_goal_setup_preferences',
      'getdietgenerationpreferencesstatus':
          'get_diet_generation_preferences_status',
      'updatedietgenerationpreferences': 'update_diet_generation_preferences',
      'getmacrotargetsstatus': 'get_macro_targets_status',
      'updatemacrotargetspercentage': 'update_macro_targets_percentage',
      'updatemacrotargetsgrams': 'update_macro_targets_grams',
      'updatemacrotargetsgramsperkg': 'update_macro_targets_grams_per_kg',
    };

    return aliases[normalized];
  }
}

class AppAgentCommandBatch {
  const AppAgentCommandBatch({
    required this.commands,
    required this.rawJson,
  });

  final List<AppAgentCommand> commands;
  final String rawJson;
}

class AppAgentUiHint {
  const AppAgentUiHint({
    required this.actions,
    required this.rawBlock,
  });

  static const actionLogin = 'login';
  static const actionConfigureGoalsUi = 'configure_goals_ui';
  static const actionEditMacrosUi = 'edit_macros_ui';

  final List<String> actions;
  final String rawBlock;

  static AppAgentUiHint? tryParse(String responseContent) {
    final rawBlock = _extractBlock(responseContent);
    if (rawBlock == null) {
      return null;
    }

    final jsonStart = rawBlock.indexOf('{');
    final jsonEnd = rawBlock.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd < jsonStart) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawBlock.substring(jsonStart, jsonEnd + 1));
      if (decoded is! Map) {
        return null;
      }

      final actionsNode = decoded['actions'];
      if (actionsNode is! List) {
        return null;
      }

      final actions = actionsNode
          .map((item) => _canonicalAction(item?.toString()))
          .whereType<String>()
          .toSet()
          .toList();
      if (actions.isEmpty) {
        return null;
      }

      return AppAgentUiHint(
        actions: actions,
        rawBlock: rawBlock,
      );
    } catch (_) {
      return null;
    }
  }

  static bool containsHint(String responseContent) {
    return _extractBlock(responseContent) != null ||
        responseContent.contains(
          RegExp(r'\[APP_UI_HINT_BEGIN\]', caseSensitive: false),
        );
  }

  static String removeHintBlock(String responseContent) {
    var sanitized = responseContent.replaceAll(
      RegExp(
        r'\[APP_UI_HINT_BEGIN\][\s\S]*?\[APP_UI_HINT_END\]',
        caseSensitive: false,
      ),
      '',
    );

    sanitized = sanitized.replaceAll(
      RegExp(
        r'\[APP_UI_HINT_BEGIN\][\s\S]*$',
        caseSensitive: false,
      ),
      '',
    );

    sanitized = sanitized.replaceAll(
      RegExp(
        r'\[APP_UI(?:_[A-Z]+)*[\s\S]*$',
        caseSensitive: false,
      ),
      '',
    );

    return sanitized.trim();
  }

  static String? _extractBlock(String responseContent) {
    final completeMatch = RegExp(
      r'\[APP_UI_HINT_BEGIN\][\s\S]*?\[APP_UI_HINT_END\]',
      caseSensitive: false,
    ).firstMatch(responseContent);
    if (completeMatch != null) {
      return completeMatch.group(0);
    }

    return null;
  }

  static String? _canonicalAction(String? rawAction) {
    final trimmed = rawAction?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final normalized =
        trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    switch (normalized) {
      case 'login':
      case 'signin':
      case 'logintocontinue':
        return actionLogin;
      case 'configuregoalsui':
      case 'configuregoals':
      case 'goalsetupui':
        return actionConfigureGoalsUi;
      case 'editmacrosui':
      case 'editmacros':
      case 'macroeditorui':
        return actionEditMacrosUi;
      default:
        return null;
    }
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
  static final ServerChatStateService _serverChatStateService =
      ServerChatStateService();
  static Map<String, dynamic>? _cachedServerState;

  static const getDailyNutritionStatus = 'get_daily_nutrition_status';
  static const getWeeklyNutritionSummary = 'get_weekly_nutrition_summary';
  static const getWeightStatus = 'get_weight_status';
  static const recalculateNutritionGoals = 'recalculate_nutrition_goals';
  static const generateNewDietPlan = 'generate_new_diet_plan';
  static const getGoalSetupStatus = 'get_goal_setup_status';
  static const updateGoalSetupProfile = 'update_goal_setup_profile';
  static const updateGoalSetupPreferences = 'update_goal_setup_preferences';
  static const getDietGenerationPreferencesStatus =
      'get_diet_generation_preferences_status';
  static const updateDietGenerationPreferences =
      'update_diet_generation_preferences';
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
      case getDietGenerationPreferencesStatus:
        return _getDietGenerationPreferencesStatus(command, context);
      case updateDietGenerationPreferences:
        return _updateDietGenerationPreferences(command, context);
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
              getDietGenerationPreferencesStatus,
              updateDietGenerationPreferences,
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
      case getDietGenerationPreferencesStatus:
        return l10n.translate('agent_loading_diet_preferences_status');
      case updateDietGenerationPreferences:
        return l10n.translate('agent_loading_update_diet_preferences');
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
    final sanitizedAgentArtifacts = _removeAgentArtifacts(rawContent);
    if (sanitizedAgentArtifacts != rawContent) {
      return fallbackSanitizer(sanitizedAgentArtifacts).trim();
    }

    if (AppAgentCommand.containsCommandCandidate(rawContent)) {
      return fallbackSanitizer(AppAgentCommand.removeCommandJson(rawContent))
          .trim();
    }

    return fallbackSanitizer(rawContent).trim();
  }

  static String _removeAgentArtifacts(String rawContent) {
    var sanitized = AppAgentUiHint.removeHintBlock(rawContent);

    sanitized = sanitized.replaceAll(
      RegExp(
        r'\[APP_COMMAND_RESULTS?_BEGIN\][\s\S]*?\[APP_COMMAND_RESULTS?_END\]',
        caseSensitive: false,
      ),
      '',
    );

    sanitized = sanitized.replaceAll(
      RegExp(
        r'\[APP_COMMAND_RESULTS?_BEGIN\][\s\S]*$',
        caseSensitive: false,
      ),
      '',
    );

    if (AppAgentCommand.containsCommandCandidate(sanitized)) {
      sanitized = AppAgentCommand.removeCommandJson(sanitized);
    }

    sanitized = sanitized.replaceAll(
      RegExp(
        r'^\s*\{\s*"?app_?commands?"?[\s\S]*$',
        caseSensitive: false,
      ),
      '',
    );

    sanitized = sanitized.replaceAll(
      RegExp(
        r'^\s*\[\s*\{\s*"(commandName|name)"[\s\S]*\]\s*$',
        caseSensitive: false,
      ),
      '',
    );

    return sanitized.trim();
  }

  static String? buildCreditExhaustedFallbackMessage({
    required BuildContext context,
    required List<AppAgentExecutionResult> executionResults,
    required String responseContent,
  }) {
    if (!_isCreditExhaustedResponse(responseContent)) {
      return null;
    }

    final successfulResults =
        executionResults.where((result) => result.success).toList();
    if (successfulResults.isEmpty) {
      return null;
    }

    final lastResult = successfulResults.last;
    final isPortuguese =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'pt',
            );

    switch (lastResult.commandName) {
      case generateNewDietPlan:
        final mealCount = _tryParseInt(lastResult.payload['mealCount']) ?? 0;
        final totalCalories =
            _tryParseInt(lastResult.payload['totalCalories']) ?? 0;
        final totalProtein =
            _tryParseDouble(lastResult.payload['totalProtein']) ?? 0;
        final totalCarbs =
            _tryParseDouble(lastResult.payload['totalCarbs']) ?? 0;
        final totalFat = _tryParseDouble(lastResult.payload['totalFat']) ?? 0;
        final meals =
            (lastResult.payload['meals'] as List<dynamic>? ?? const [])
                .cast<dynamic>();
        final mealNames = meals
            .map((meal) => meal is Map ? meal['name']?.toString() : null)
            .whereType<String>()
            .where((name) => name.trim().isNotEmpty)
            .take(3)
            .toList();
        final preview = mealNames.isEmpty ? '' : mealNames.join(', ');

        if (isPortuguese) {
          final previewLine =
              preview.isEmpty ? '' : '\n\nPrimeiras refeições: $preview.';
          return 'Seu novo plano de dieta foi gerado com sucesso. '
              'Ele tem $mealCount refeições e cerca de $totalCalories kcal no dia '
              '(${_formatOneDecimal(totalProtein)}g de proteína, '
              '${_formatOneDecimal(totalCarbs)}g de carboidratos e '
              '${_formatOneDecimal(totalFat)}g de gorduras). '
              'Você já pode ver a dieta na aba Minha Dieta.$previewLine'
              '\n\nNão consegui completar a resposta do chat porque seus créditos acabaram.';
        }

        final previewLine = preview.isEmpty ? '' : '\n\nFirst meals: $preview.';
        return 'Your new diet plan was generated successfully. '
            'It has $mealCount meals and about $totalCalories kcal for the day '
            '(${_formatOneDecimal(totalProtein)}g protein, '
            '${_formatOneDecimal(totalCarbs)}g carbs, '
            '${_formatOneDecimal(totalFat)}g fat). '
            'You can already view it in the My Diet tab.$previewLine'
            '\n\nI could not finish the chat reply because you ran out of credits.';
      case getDailyNutritionStatus:
        final caloriesRemaining =
            _tryParseInt(lastResult.payload['caloriesRemaining']) ?? 0;
        final proteinRemaining =
            _tryParseDouble(lastResult.payload['proteinRemaining']) ?? 0;
        final carbsRemaining =
            _tryParseDouble(lastResult.payload['carbsRemaining']) ?? 0;
        final fatRemaining =
            _tryParseDouble(lastResult.payload['fatRemaining']) ?? 0;
        if (isPortuguese) {
          return 'Consultei seu status de hoje: você ainda pode consumir '
              '$caloriesRemaining kcal, ${_formatOneDecimal(proteinRemaining)}g de proteína, '
              '${_formatOneDecimal(carbsRemaining)}g de carboidratos e '
              '${_formatOneDecimal(fatRemaining)}g de gorduras.'
              '\n\nNão consegui completar a resposta do chat porque seus créditos acabaram.';
        }
        return 'I checked your status for today: you still have '
            '$caloriesRemaining kcal, ${_formatOneDecimal(proteinRemaining)}g protein, '
            '${_formatOneDecimal(carbsRemaining)}g carbs, and '
            '${_formatOneDecimal(fatRemaining)}g fat remaining.'
            '\n\nI could not finish the chat reply because you ran out of credits.';
      case updateGoalSetupProfile:
      case updateGoalSetupPreferences:
      case getGoalSetupStatus:
        final missingFields =
            (lastResult.payload['requiredFieldsForInitialSetup']
                        as List<dynamic>? ??
                    const [])
                .map((field) => field.toString())
                .toList();
        if (isPortuguese) {
          if (missingFields.isEmpty) {
            return 'Suas informações iniciais já estão completas no app.'
                '\n\nNão consegui completar a resposta do chat porque seus créditos acabaram.';
          }
          return 'Atualizei suas informações iniciais. Ainda faltam: ${missingFields.join(', ')}.'
              '\n\nNão consegui completar a resposta do chat porque seus créditos acabaram.';
        }
        if (missingFields.isEmpty) {
          return 'Your initial setup is already complete in the app.'
              '\n\nI could not finish the chat reply because you ran out of credits.';
        }
        return 'I updated your initial setup. Still missing: ${missingFields.join(', ')}.'
            '\n\nI could not finish the chat reply because you ran out of credits.';
      case updateMacroTargetsPercentage:
      case updateMacroTargetsGrams:
      case updateMacroTargetsGramsPerKg:
      case getMacroTargetsStatus:
      case recalculateNutritionGoals:
        final caloriesGoal =
            _tryParseInt(lastResult.payload['caloriesGoal']) ?? 0;
        final grams =
            (lastResult.payload['grams'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
        final protein = _tryParseDouble(grams['protein']) ??
            _tryParseDouble(lastResult.payload['proteinGoal']) ??
            0;
        final carbs = _tryParseDouble(grams['carbs']) ??
            _tryParseDouble(lastResult.payload['carbsGoal']) ??
            0;
        final fat = _tryParseDouble(grams['fat']) ??
            _tryParseDouble(lastResult.payload['fatGoal']) ??
            0;
        if (isPortuguese) {
          return 'Seus alvos nutricionais atuais são $caloriesGoal kcal, '
              '${_formatOneDecimal(protein)}g de proteína, '
              '${_formatOneDecimal(carbs)}g de carboidratos e '
              '${_formatOneDecimal(fat)}g de gorduras.'
              '\n\nNão consegui completar a resposta do chat porque seus créditos acabaram.';
        }
        return 'Your current nutrition targets are $caloriesGoal kcal, '
            '${_formatOneDecimal(protein)}g protein, '
            '${_formatOneDecimal(carbs)}g carbs, and '
            '${_formatOneDecimal(fat)}g fat.'
            '\n\nI could not finish the chat reply because you ran out of credits.';
      default:
        return isPortuguese
            ? 'Consegui concluir a ação no app, mas não consegui completar a resposta do chat porque seus créditos acabaram.'
            : 'I completed the action in the app, but I could not finish the chat reply because you ran out of credits.';
    }
  }

  static Future<String> buildFollowUpPrompt({
    required String originalUserMessage,
    required List<AppAgentExecutionResult> executionResults,
    required BuildContext context,
    String conversationContext = '',
  }) async {
    final resultJson = jsonEncode(
      executionResults.map(_summarizeExecutionResultForPrompt).toList(),
    );
    final sanitizedConversationContext =
        shouldIncludeConversationContext(originalUserMessage)
            ? compactConversationContext(
                conversationContext,
                maxBlocks: 2,
                maxChars: 260,
              )
            : '';
    final currentAppStateJson = jsonEncode(
      _buildPromptStatePayload(await _getCurrentAppStatePayload(context)),
    );

    return '''
[APP_COMMAND_RESULTS_BEGIN]
$resultJson
[APP_COMMAND_RESULTS_END]

[APP_CURRENT_STATE_BEGIN]
$currentAppStateJson
[APP_CURRENT_STATE_END]

${sanitizedConversationContext.isEmpty ? '' : 'Contexto recente da conversa:\n$sanitizedConversationContext\n'}

Pedido do usuário:
$originalUserMessage

Use APP_COMMAND_RESULTS e APP_CURRENT_STATE como fonte de verdade. Se outra ação de app ainda for necessária para concluir o pedido, retorne somente app_command/app_commands válidos. Caso contrário, responda naturalmente sem JSON nem nomes internos de comando.
Responda no mesmo idioma do pedido original do usuário.
''';
  }

  static Future<String> buildPromptWithCurrentAppState({
    required BuildContext context,
    required String basePrompt,
  }) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.token == null) {
      return basePrompt;
    }

    final currentAppStateJson = jsonEncode(
      _buildPromptStatePayload(await _getCurrentAppStatePayload(context)),
    );

    return '''
[APP_CURRENT_STATE_BEGIN]
$currentAppStateJson
[APP_CURRENT_STATE_END]

$basePrompt
''';
  }

  static Map<String, dynamic> _buildPromptStatePayload(
    Map<String, dynamic> state,
  ) {
    final auth = (state['auth'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final goalSetup = (state['goalSetup'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final setupCompletionStatus =
        (goalSetup['setupCompletionStatus'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final profile = (goalSetup['profile'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final goalSetupMacroTargets =
        (goalSetup['macroTargets'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final goalSetupMacroGrams =
        (goalSetupMacroTargets['grams'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final macroTargets =
        (state['macroTargets'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final macroPercentages =
        (macroTargets['percentages'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final dietPreferences =
        (state['dietGenerationPreferences'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    return _pruneNullEntries({
      'auth': {
        'isAuthenticated': auth['isAuthenticated'] == true,
        'userId': auth['userId'],
      },
      'goalSetup': _pruneNullEntries({
        'configurationStatus': goalSetup['configurationStatus'],
        'defaultMacroTargetsApplied': goalSetup['defaultMacroTargetsApplied'],
        'missingSetupFields': _limitStringList(goalSetup['missingSetupFields']),
        'requiredFieldsForInitialSetup':
            _limitStringList(goalSetup['requiredFieldsForInitialSetup']) ??
                _limitStringList(goalSetup['missingSetupFields']),
        'setupCompletionStatus': _pruneNullEntries({
          'sex': setupCompletionStatus['sex'],
          'age': setupCompletionStatus['age'],
          'weight_kg': setupCompletionStatus['weight_kg'],
          'height_cm': setupCompletionStatus['height_cm'],
          'activity_level': setupCompletionStatus['activity_level'],
          'fitness_goal': setupCompletionStatus['fitness_goal'],
        }),
        'profile': _pruneNullEntries({
          'sex': profile['sex'],
          'age': profile['age'],
          'weightKg': profile['weightKg'],
          'heightCm': profile['heightCm'],
          'activityLevel': profile['activityLevel'],
          'fitnessGoal': profile['fitnessGoal'],
        }),
        'macroSummary': _pruneNullEntries({
          'goalMode':
              goalSetupMacroTargets['goalMode'] ?? macroTargets['goalMode'],
          'caloriesGoal': goalSetupMacroTargets['caloriesGoal'] ??
              macroTargets['caloriesGoal'],
          'proteinGoal':
              goalSetupMacroGrams['protein'] ?? macroTargets['proteinGoal'],
          'carbsGoal':
              goalSetupMacroGrams['carbs'] ?? macroTargets['carbsGoal'],
          'fatGoal': goalSetupMacroGrams['fat'] ?? macroTargets['fatGoal'],
          'percentages': _pruneNullEntries({
            'carbs': macroPercentages['carbs'],
            'protein': macroPercentages['protein'],
            'fat': macroPercentages['fat'],
          }),
        }),
      }),
      'dietGenerationPreferences': _pruneNullEntries({
        'isPreferenceStepOptional':
            dietPreferences['isPreferenceStepOptional'] == true,
        'hasReviewedAnyDietPreference':
            dietPreferences['hasReviewedAnyDietPreference'] == true,
        'isReadyForDietGeneration':
            dietPreferences['isReadyForDietGeneration'] == true,
        'missingPreferenceTopics':
            _limitStringList(dietPreferences['missingPreferenceTopics']),
        'reviewedTopics': _limitStringList(dietPreferences['reviewedTopics']),
      }),
    });
  }

  static Map<String, dynamic> _summarizeExecutionResultForPrompt(
    AppAgentExecutionResult result,
  ) {
    final payload = result.payload;

    Map<String, dynamic> summarizedPayload() {
      switch (result.commandName) {
        case getGoalSetupStatus:
        case updateGoalSetupProfile:
        case updateGoalSetupPreferences:
          final setupCompletion = (payload['setupCompletionStatus'] as Map?)
                  ?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          return _pruneNullEntries({
            'updatedFields': _limitStringList(payload['updatedFields']),
            'configurationStatus': payload['configurationStatus'],
            'missingSetupFields':
                _limitStringList(payload['missingSetupFields']),
            'requiredFieldsForInitialSetup':
                _limitStringList(payload['requiredFieldsForInitialSetup']) ??
                    _limitStringList(payload['missingSetupFields']),
            'setupCompletionStatus': _pruneNullEntries({
              'sex': setupCompletion['sex'],
              'age': setupCompletion['age'],
              'weight_kg': setupCompletion['weight_kg'],
              'height_cm': setupCompletion['height_cm'],
              'activity_level': setupCompletion['activity_level'],
              'fitness_goal': setupCompletion['fitness_goal'],
            }),
          });
        case getDietGenerationPreferencesStatus:
        case updateDietGenerationPreferences:
          return _pruneNullEntries({
            'updatedFields': _limitStringList(payload['updatedFields']),
            'isPreferenceStepOptional':
                payload['isPreferenceStepOptional'] == true,
            'hasReviewedAnyDietPreference':
                payload['hasReviewedAnyDietPreference'] == true,
            'isReadyForDietGeneration':
                payload['isReadyForDietGeneration'] == true,
            'missingPreferenceTopics':
                _limitStringList(payload['missingPreferenceTopics']),
          });
        case getMacroTargetsStatus:
        case updateMacroTargetsPercentage:
        case updateMacroTargetsGrams:
        case updateMacroTargetsGramsPerKg:
          final percentages =
              (payload['percentages'] as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{};
          final grams = (payload['grams'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          return _pruneNullEntries({
            'updatedByMode': payload['updatedByMode'],
            'autoFilledFields': _limitStringList(payload['autoFilledFields']),
            'goalMode': payload['goalMode'],
            'caloriesGoal': payload['caloriesGoal'],
            'grams': _pruneNullEntries({
              'protein': grams['protein'],
              'carbs': grams['carbs'],
              'fat': grams['fat'],
            }),
            'percentages': _pruneNullEntries({
              'protein': percentages['protein'],
              'carbs': percentages['carbs'],
              'fat': percentages['fat'],
            }),
          });
        case getDailyNutritionStatus:
          return _pruneNullEntries({
            'selectedDate': payload['selectedDate'],
            'caloriesGoal': payload['caloriesGoal'],
            'caloriesConsumed': payload['caloriesConsumed'],
            'caloriesRemaining': payload['caloriesRemaining'],
            'proteinRemaining': payload['proteinRemaining'],
            'carbsRemaining': payload['carbsRemaining'],
            'fatRemaining': payload['fatRemaining'],
            'waterRemaining': payload['waterRemaining'],
            'mealCount': (payload['meals'] as List?)?.length,
          });
        case getWeeklyNutritionSummary:
          return _pruneNullEntries({
            'daysTracked': payload['daysTracked'],
            'averageCalories': payload['averageCalories'],
            'averageProtein': payload['averageProtein'],
            'averageCarbs': payload['averageCarbs'],
            'averageFat': payload['averageFat'],
            'weeklyGoalCalories': payload['weeklyGoalCalories'],
          });
        case getWeightStatus:
          return _pruneNullEntries({
            'weightKg': payload['weightKg'],
            'heightCm': payload['heightCm'],
            'sex': payload['sex'],
            'age': payload['age'],
            'bmi': payload['bmi'],
            'bodyFat': payload['bodyFat'],
          });
        case recalculateNutritionGoals:
          return _pruneNullEntries({
            'caloriesGoal': payload['caloriesGoal'],
            'proteinGoal': payload['proteinGoal'],
            'carbsGoal': payload['carbsGoal'],
            'fatGoal': payload['fatGoal'],
            'activityLevel': payload['activityLevel'],
            'fitnessGoal': payload['fitnessGoal'],
            'dietType': payload['dietType'],
          });
        case generateNewDietPlan:
          final personalization = (payload['dietPersonalization'] as Map?)
                  ?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          final meals = (payload['meals'] as List?)?.cast<Map>() ?? const [];
          return _pruneNullEntries({
            'dietMode': payload['dietMode'],
            'selectedDate': payload['selectedDate'],
            'totalCalories': payload['totalCalories'],
            'totalProtein': payload['totalProtein'],
            'totalCarbs': payload['totalCarbs'],
            'totalFat': payload['totalFat'],
            'mealCount': payload['mealCount'],
            'mealTitles': meals
                .map((meal) => meal['mealType']?.toString())
                .whereType<String>()
                .take(4)
                .toList(),
            'dietPersonalization': _pruneNullEntries({
              'mealsPerDay': personalization['mealsPerDay'],
              'hungriestMealTime': personalization['hungriestMealTime'],
              'foodRestrictions': _limitStringList(
                personalization['foodRestrictions'],
              ),
              'favoriteFoods':
                  _limitStringList(personalization['favoriteFoods']),
              'avoidedFoods': _limitStringList(personalization['avoidedFoods']),
              'routineConsiderations': _limitStringList(
                personalization['routineConsiderations'],
              ),
            }),
          });
        default:
          return _pruneNullEntries(payload);
      }
    }

    return _pruneNullEntries({
      'commandName': result.commandName,
      'success': result.success,
      if (result.errorMessage != null) 'errorMessage': result.errorMessage,
      'payload': summarizedPayload(),
    });
  }

  static Map<String, dynamic> _pruneNullEntries(Map<String, dynamic> value) {
    final pruned = <String, dynamic>{};
    for (final entry in value.entries) {
      final currentValue = entry.value;
      if (currentValue == null) {
        continue;
      }
      if (currentValue is Map<String, dynamic>) {
        final nested = _pruneNullEntries(currentValue);
        if (nested.isEmpty) {
          continue;
        }
        pruned[entry.key] = nested;
        continue;
      }
      if (currentValue is List) {
        final nested = currentValue.where((item) => item != null).toList();
        if (nested.isEmpty) {
          continue;
        }
        pruned[entry.key] = nested;
        continue;
      }
      pruned[entry.key] = currentValue;
    }
    return pruned;
  }

  static List<String>? _limitStringList(
    dynamic value, {
    int maxItems = 4,
  }) {
    if (value is! List) {
      return null;
    }

    final items = value
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .take(maxItems)
        .toList();

    return items.isEmpty ? null : items;
  }

  static bool _isCreditExhaustedResponse(String responseContent) {
    final normalized = responseContent.toLowerCase();
    return normalized.contains('sem créditos') ||
        normalized.contains('sem creditos') ||
        normalized.contains('créditos acabaram') ||
        normalized.contains('creditos acabaram') ||
        normalized.contains('créditos insuficientes') ||
        normalized.contains('creditos insuficientes') ||
        normalized.contains('out of credits') ||
        normalized.contains('insufficient credits');
  }

  static String compactConversationContext(
    String conversationContext, {
    int maxBlocks = 3,
    int maxChars = 420,
  }) {
    final trimmed = conversationContext.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final blocks = RegExp(
      r'^(?:Humano|IA):\s[\s\S]*?(?=^(?:Humano|IA):\s|\z)',
      multiLine: true,
    ).allMatches(trimmed).map((match) => match.group(0)!.trim()).toList();

    if (blocks.isEmpty) {
      final sanitized = _removeAgentArtifacts(trimmed);
      if (sanitized.length <= maxChars) {
        return sanitized;
      }
      return sanitized.substring(sanitized.length - maxChars).trimLeft();
    }

    final sanitizedBlocks = blocks
        .map(_sanitizeConversationBlock)
        .where((block) => block.isNotEmpty)
        .toList();
    if (sanitizedBlocks.isEmpty) {
      return '';
    }

    final recentBlocks = sanitizedBlocks.length <= maxBlocks
        ? sanitizedBlocks
        : sanitizedBlocks.sublist(sanitizedBlocks.length - maxBlocks);
    final compacted = recentBlocks.join('\n');
    if (compacted.length <= maxChars) {
      return compacted;
    }

    final overflow =
        compacted.substring(compacted.length - maxChars).trimLeft();
    final firstBreak = overflow.indexOf('\n');
    if (firstBreak == -1) {
      return overflow;
    }
    return overflow.substring(firstBreak + 1).trimLeft();
  }

  static String _sanitizeConversationBlock(String block) {
    final separatorIndex = block.indexOf(':');
    if (separatorIndex == -1) {
      return _removeAgentArtifacts(block);
    }

    final speaker = block.substring(0, separatorIndex).trim();
    final content = block.substring(separatorIndex + 1).trim();
    final sanitizedContent =
        _removeAgentArtifacts(content).replaceAll(RegExp(r'\s+'), ' ').trim();

    if (sanitizedContent.isEmpty) {
      return '';
    }

    return '$speaker: $sanitizedContent';
  }

  static bool shouldIncludeConversationContext(String userMessage) {
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty) {
      return false;
    }

    if (_containsAnyTerm(normalized, const [
      'pode seguir',
      'pode continuar',
      'segue',
      'continue',
      'go ahead',
      'qualquer uma',
      'qualquer um',
      'tanto faz',
      'sem preferencia',
      'sem preferências',
      'sem restricoes',
      'sem restrições',
      'sim',
      'nao',
      'não',
      'ok',
      'certo',
      'e agora',
      'e ai',
      'e aí',
    ])) {
      return true;
    }

    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.length > 6) {
      return false;
    }

    final firstWord = words.first;
    return {
      'e',
      'entao',
      'então',
      'isso',
      'essa',
      'esse',
      'essas',
      'esses',
      'agora',
      'depois',
    }.contains(firstWord);
  }

  static Future<Map<String, dynamic>> _getCurrentAppStatePayload(
    BuildContext context,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.isAuthenticated || authService.token == null) {
      _cachedServerState = null;
      return _buildUnauthenticatedCurrentStatePayload();
    }

    final currentUserId = authService.currentUser?.id;
    if (_cachedServerState != null &&
        _cachedServerState!['auth'] is Map &&
        (_cachedServerState!['auth'] as Map)['userId'] == currentUserId) {
      return _cachedServerState!;
    }

    try {
      final remoteState = await _serverChatStateService.fetchState(
        token: authService.token!,
      );
      await _cacheAndApplyServerState(context, remoteState);
      return remoteState;
    } catch (error) {
      debugPrint('AppAgentService - erro ao buscar chat-state: $error');
      if (_cachedServerState != null) {
        return _cachedServerState!;
      }
      return {
        ..._buildUnauthenticatedCurrentStatePayload(),
        'auth': {
          'isAuthenticated': true,
          'userId': currentUserId,
        },
        'serverState': {
          'available': false,
        },
      };
    }
  }

  static Map<String, dynamic> _buildUnauthenticatedCurrentStatePayload() {
    return {
      'auth': {
        'isAuthenticated': false,
        'userId': null,
      },
    };
  }

  static Future<void> _cacheAndApplyServerState(
    BuildContext context,
    Map<String, dynamic> state,
  ) async {
    _cachedServerState = Map<String, dynamic>.from(state);
    await _applyServerStateToProviders(context, _cachedServerState!);
  }

  static Future<void> _applyServerStateToProviders(
    BuildContext context,
    Map<String, dynamic> state,
  ) async {
    final goalSetup = (state['goalSetup'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final macroTargets =
        (state['macroTargets'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final dietPreferences =
        (state['dietGenerationPreferences'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);

    await goalsProvider.ensureLoaded();
    await dietProvider.ensureLoaded();

    if (goalSetup.isNotEmpty) {
      await goalsProvider.applyServerSnapshot(
        goalSetup: goalSetup,
        macroTargets: macroTargets,
      );
    }

    if (dietPreferences.isNotEmpty) {
      await dietProvider.applyServerPreferencesSnapshot(dietPreferences);
    }
  }

  static Future<AppAgentExecutionResult> _executeServerStateCommand(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.token == null) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: 'login_required',
        payload: const {
          'reason': 'login_required',
        },
      );
    }

    try {
      final response = await _serverChatStateService.executeCommand(
        token: authService.token!,
        commandName: command.name,
        arguments: command.arguments,
      );
      final state = (response['state'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      if (state.isNotEmpty) {
        await _cacheAndApplyServerState(context, state);
      }

      final payload = (response['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final commandName = response['commandName']?.toString() ?? command.name;
      final success = response['success'] == true;
      final errorMessage = response['errorMessage']?.toString();

      return AppAgentExecutionResult(
        commandName: commandName,
        success: success,
        errorMessage: errorMessage,
        payload: payload,
      );
    } catch (error) {
      return AppAgentExecutionResult(
        commandName: command.name,
        success: false,
        errorMessage: error.toString(),
        payload: const {
          'reason': 'server_chat_state_error',
        },
      );
    }
  }

  static Future<AppAgentExecutionResult> _getDailyNutritionStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _getWeeklyNutritionSummary(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _getWeightStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _recalculateNutritionGoals(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
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
    await dietProvider.ensureLoaded();
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

    await _getCurrentAppStatePayload(context);

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
        'dietPersonalization': _buildDietGenerationPreferencesPayload(
          dietProvider,
        ),
        'meals': plan.meals.map(_serializePlannedMeal).toList(),
      },
    );
  }

  static Future<AppAgentExecutionResult> _getDietGenerationPreferencesStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _getGoalSetupStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _updateGoalSetupProfile(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _updateGoalSetupPreferences(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _updateDietGenerationPreferences(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _getMacroTargetsStatus(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _updateMacroTargetsPercentage(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _updateMacroTargetsGrams(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
  }

  static Future<AppAgentExecutionResult> _updateMacroTargetsGramsPerKg(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    return _executeServerStateCommand(command, context);
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
    final missingFields = goalsProvider.missingSetupFields;
    final isConfigured = missingFields.isEmpty;
    final explicitProfile = <String, dynamic>{
      'sex': goalsProvider.explicitSex,
      'age': goalsProvider.explicitAge,
      'weightKg': goalsProvider.explicitWeight == null
          ? null
          : _round1(goalsProvider.explicitWeight!),
      'heightCm': goalsProvider.explicitHeight == null
          ? null
          : _round1(goalsProvider.explicitHeight!),
      'activityLevel': goalsProvider.explicitActivityLevel?.name,
      'fitnessGoal': goalsProvider.explicitFitnessGoal?.name,
    }..removeWhere((_, value) => value == null);

    return {
      'configurationStatus':
          isConfigured ? 'configured' : 'needs_initial_setup',
      'defaultMacroTargetsApplied': !goalsProvider.hasConfiguredGoals,
      'missingSetupFields': missingFields,
      'setupCompletionStatus': goalsProvider.setupCompletionStatus,
      'profile': explicitProfile,
      'dietType': goalsProvider.dietType.name,
      'macroTargets': {
        'goalMode': goalsProvider.hasConfiguredGoals
            ? 'configured'
            : 'default_template',
        'caloriesGoal': goalsProvider.caloriesGoal,
        'grams': {
          'protein': goalsProvider.proteinGoal,
          'carbs': goalsProvider.carbsGoal,
          'fat': goalsProvider.fatGoal,
        },
      },
    };
  }

  static Map<String, dynamic> _buildDietGenerationPreferencesPayload(
    DietPlanProvider dietProvider,
  ) {
    final preferences = dietProvider.preferences;
    final missingTopics = dietProvider.missingDietPersonalizationTopics;
    return {
      'isReadyForDietGeneration': dietProvider.hasCompletedDietPersonalization,
      'isPreferenceStepOptional': true,
      'hasReviewedAnyDietPreference':
          dietProvider.hasReviewedDietGenerationPreferences,
      'missingTopics': missingTopics,
      'mealsPerDay': preferences.mealsPerDay,
      'hungriestMealTime': preferences.hungriestMealTime,
      'foodRestrictions': preferences.foodRestrictions,
      'favoriteFoods': preferences.favoriteFoods,
      'avoidedFoods': preferences.avoidedFoods,
      'routineConsiderations': preferences.routineConsiderations,
    };
  }

  static bool shouldSkipCommand(AppAgentCommand command) {
    final arguments = command.arguments;
    final hasArguments = arguments.isNotEmpty;

    switch (command.name) {
      case updateGoalSetupProfile:
      case updateGoalSetupPreferences:
      case updateMacroTargetsPercentage:
      case updateMacroTargetsGrams:
      case updateMacroTargetsGramsPerKg:
        return !hasArguments;
      case updateDietGenerationPreferences:
        if (arguments['skipPreferenceStep'] == true) {
          return false;
        }
        return !hasArguments;
      default:
        return false;
    }
  }

  static String _formatOneDecimal(double value) {
    final rounded = _round1(value);
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(1);
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
    final normalized = _normalizeLooseText(value);
    switch (normalized) {
      case 'sedentary':
      case 'sedentario':
      case 'sedentário':
        return ActivityLevel.sedentary;
      case 'lightlyactive':
      case 'lightly_active':
      case 'lightly active':
      case 'light':
      case 'leve':
      case 'levemente ativo':
      case 'levemente_ativo':
        return ActivityLevel.lightlyActive;
      case 'moderatelyactive':
      case 'moderately_active':
      case 'moderately active':
      case 'moderate':
      case 'moderado':
      case 'moderadamente ativo':
      case 'moderadamente_ativo':
        return ActivityLevel.moderatelyActive;
      case 'veryactive':
      case 'very_active':
      case 'very active':
      case 'very':
      case 'muito ativo':
      case 'muito_ativo':
      case 'intenso':
        return ActivityLevel.veryActive;
      case 'extremelyactive':
      case 'extremely_active':
      case 'extremely active':
      case 'extreme':
      case 'extremo':
      case 'extremamente ativo':
      case 'extremamente_ativo':
        return ActivityLevel.extremelyActive;
      default:
        if (normalized.isEmpty) {
          return null;
        }
        if (_containsAnyTerm(normalized, const [
          'extremamente ativo',
          'atividade extrema',
          'muito intenso',
          'trabalho fisico pesado',
          'treino muito intenso',
        ])) {
          return ActivityLevel.extremelyActive;
        }
        if (_containsAnyTerm(normalized, const [
          'muito ativo',
          'atividade intensa',
          'intenso',
          'treino pesado',
          'ativo bastante',
        ])) {
          return ActivityLevel.veryActive;
        }
        if (_containsAnyTerm(normalized, const [
          'moderadamente ativo',
          'atividade moderada',
          'moderado',
          'moderadamente',
          'ativo moderadamente',
        ])) {
          return ActivityLevel.moderatelyActive;
        }
        if (_containsAnyTerm(normalized, const [
          'levemente ativo',
          'atividade leve',
          'leve',
          'pouco ativo',
        ])) {
          return ActivityLevel.lightlyActive;
        }
        if (_containsAnyTerm(normalized, const [
          'sedentario',
          'parado',
          'sem exercicio',
          'sem atividade',
          'inativo',
        ])) {
          return ActivityLevel.sedentary;
        }
        return null;
    }
  }

  static FitnessGoal? _parseFitnessGoal(dynamic value) {
    final normalized = _normalizeLooseText(value);
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
      case 'weight gain slowly':
      case 'weight_gain_slowly':
      case 'slow weight gain':
      case 'slow_weight_gain':
      case 'ganhar peso lentamente':
      case 'ganhar_peso_lentamente':
        return FitnessGoal.gainWeightSlowly;
      case 'gainweight':
      case 'gain_weight':
      case 'weight gain':
      case 'weight_gain':
      case 'bulk':
      case 'ganhar peso':
      case 'ganhar_peso':
        return FitnessGoal.gainWeight;
      default:
        if (normalized.isEmpty) {
          return null;
        }
        if (_containsAnyTerm(normalized, const [
          'ganhar massa',
          'ganhar massa muscular',
          'hipertrofia',
          'crescer',
          'bulk limpo',
          'aumentar massa',
        ])) {
          return FitnessGoal.gainWeightSlowly;
        }
        if (_containsAnyTerm(normalized, const [
              'ganhar peso',
              'aumentar peso',
              'subir peso',
              'engordar',
              'weight gain',
              'gain weight',
            ]) &&
            _containsAnyTerm(normalized, const [
              'devagar',
              'lentamente',
              'aos poucos',
              'de leve',
              'pouco a pouco',
              'slowly',
            ])) {
          return FitnessGoal.gainWeightSlowly;
        }
        if (_containsAnyTerm(normalized, const [
          'ganhar peso',
          'aumentar peso',
          'subir peso',
          'engordar',
          'bulk',
          'weight gain',
          'gain weight',
        ])) {
          return FitnessGoal.gainWeight;
        }
        if (_containsAnyTerm(normalized, const [
          'manter peso',
          'manutencao',
          'manutenção',
          'recomposicao',
          'recomp',
          'ficar como estou',
        ])) {
          return FitnessGoal.maintainWeight;
        }
        if (_containsAnyTerm(normalized, const [
              'perder peso',
              'emagrecer',
              'secar',
              'perder gordura',
            ]) &&
            _containsAnyTerm(normalized, const [
              'devagar',
              'lentamente',
              'aos poucos',
              'leve',
            ])) {
          return FitnessGoal.loseWeightSlowly;
        }
        if (_containsAnyTerm(normalized, const [
          'perder peso',
          'emagrecer',
          'secar',
          'perder gordura',
          'cut',
          'definir',
        ])) {
          return FitnessGoal.loseWeight;
        }
        return null;
    }
  }

  static bool _hasAnyKey(Map<String, dynamic> args, List<String> keys) {
    for (final key in keys) {
      if (args.containsKey(key)) {
        return true;
      }
    }
    return false;
  }

  static dynamic _readFirstValue(Map<String, dynamic> args, List<String> keys) {
    for (final key in keys) {
      if (args.containsKey(key)) {
        return args[key];
      }
    }
    return null;
  }

  static String _normalizeLooseText(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    const replacements = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
      '_': ' ',
      '-': ' ',
    };

    var normalized = raw;
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  static bool _containsAnyTerm(String normalized, List<String> candidates) {
    for (final candidate in candidates) {
      if (normalized.contains(_normalizeLooseText(candidate))) {
        return true;
      }
    }
    return false;
  }

  static List<String> _extractStringList(dynamic value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final separatorPattern = RegExp(r'\s*(?:,|;|\n)\s*');
    final parts = normalized.split(separatorPattern);
    return parts.where((item) => item.trim().isNotEmpty).toList();
  }

  static List<String> _extractListAfterKeywords(
    String normalizedMessage, {
    required List<String> keywords,
    required List<String> stopKeywords,
  }) {
    for (final keyword in keywords) {
      final normalizedKeyword = _normalizeLooseText(keyword);
      final keywordIndex = normalizedMessage.indexOf(normalizedKeyword);
      if (keywordIndex == -1) {
        continue;
      }

      var slice = normalizedMessage.substring(
        keywordIndex + normalizedKeyword.length,
      );
      var stopIndex = slice.length;

      for (final stopKeyword in stopKeywords) {
        final normalizedStop = _normalizeLooseText(stopKeyword);
        final currentIndex = slice.indexOf(' $normalizedStop');
        if (currentIndex != -1 && currentIndex < stopIndex) {
          stopIndex = currentIndex;
        }
      }

      slice = slice.substring(0, stopIndex).trim();
      if (slice.isEmpty) {
        continue;
      }

      final items = slice
          .split(RegExp(r'\s*(?:,| e | ou |/|;)\s*'))
          .map((item) => item.trim())
          .where((item) =>
              item.isNotEmpty && item != 'de' && item != 'do' && item != 'da')
          .toList();

      if (items.isNotEmpty) {
        return items;
      }
    }

    return const [];
  }

  static String? _normalizeMealWindow(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'breakfast':
      case 'cafe da manha':
      case 'café da manhã':
      case 'morning':
      case 'manhã':
      case 'manha':
        return 'breakfast';
      case 'lunch':
      case 'almoco':
      case 'almoço':
      case 'midday':
        return 'lunch';
      case 'dinner':
      case 'jantar':
      case 'night':
      case 'noite':
        return 'dinner';
      case 'snack':
      case 'lanche':
      case 'afternoon':
      case 'tarde':
        return 'snack';
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

  static bool? _tryParseBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }

    switch (value.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'sim':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'nao':
      case 'não':
        return false;
      default:
        return null;
    }
  }

  static bool _isReplaceRequested(
    Map<String, dynamic> args,
    List<String> keys,
  ) {
    for (final key in keys) {
      final parsed = _tryParseBool(args[key]);
      if (parsed == true) {
        return true;
      }
    }
    return false;
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
