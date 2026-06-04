import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../models/diet_plan_model.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../widgets/message_notifier.dart';
import 'auth_service.dart';
import 'app_debug_log_service.dart';
import 'server_chat_state_service.dart';

enum _PromptIntent {
  simpleChat,
  foodLogging,
  dailyStatus,
  macroGoals,
  dietGeneration,
  profileSetup,
  pendingAction,
  commandResults,
  accountScoped,
}

enum _MacroTopic {
  protein('proteinPerKg', 'proteinGrams'),
  carbs('carbsPerKg', 'carbsGrams'),
  fat('fatPerKg', 'fatGrams');

  const _MacroTopic(this.perKgArgument, this.gramsArgument);

  final String perKgArgument;
  final String gramsArgument;
}

class AppAgentCommand {
  const AppAgentCommand({
    required this.name,
    required this.arguments,
    required this.rawJson,
  });

  final String name;
  final Map<String, dynamic> arguments;
  final String rawJson;

  static final RegExp _pendingActionBlockPattern = RegExp(
    r'\[APP_PENDING_ACTION_BEGIN\][\s\S]*?\[APP_PENDING_ACTION_END\]',
    caseSensitive: false,
  );

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
    final normalized =
        _removePendingActionBlocks(responseContent).toLowerCase();
    final hasExplicitCommandMarker = normalized.contains('"app_command"') ||
        normalized.contains('"appcommand"') ||
        normalized.contains('"app_commands"') ||
        normalized.contains('"appcommands"') ||
        normalized.contains('"commandname"');
    if (hasExplicitCommandMarker) {
      return true;
    }

    final hasFoodPayloadMarker =
        RegExp(r'"(?:foods|mealtype|meals)"\s*:').hasMatch(normalized);
    if (hasFoodPayloadMarker) {
      return false;
    }

    return normalized.contains('"name"') &&
        (normalized.contains('diet') ||
            normalized.contains('macro') ||
            normalized.contains('nutrition') ||
            normalized.contains('goal'));
  }

  static String removeCommandJson(String responseContent) {
    final sanitizedResponse = _removePendingActionBlocks(responseContent);
    final jsonString = _extractCommandJson(sanitizedResponse);
    if (jsonString == null) {
      final candidateStart = _findCommandCandidateStart(sanitizedResponse);
      if (candidateStart == null) {
        return responseContent;
      }
      return sanitizedResponse.substring(0, candidateStart).trimRight();
    }

    if (sanitizedResponse.contains(jsonString)) {
      return sanitizedResponse.replaceAll(jsonString, '').trim();
    }

    final candidateStart = _findCommandCandidateStart(sanitizedResponse);
    if (candidateStart == null) {
      return responseContent;
    }
    return sanitizedResponse.substring(0, candidateStart).trimRight();
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
    if (arrayInlineMatch != null) {
      return arrayInlineMatch.start;
    }

    final namedObjectMatch =
        RegExp(r'[\[,]\s*\{\s*\\?"name\\?"\s*:').firstMatch(responseContent);
    if (namedObjectMatch != null) {
      return namedObjectMatch.start;
    }

    final rootNamedObjectMatch =
        RegExp(r'\{\s*\\?"name\\?"\s*:').firstMatch(responseContent);
    return rootNamedObjectMatch?.start;
  }

  static String? _extractCommandJson(String responseContent) {
    final sanitized = _removePendingActionBlocks(responseContent)
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
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
      final rootNamedObjectMatch =
          RegExp(r'^\{\s*\\?"name\\?"\s*:', dotAll: true)
              .firstMatch(trimmedStart);
      if (rootNamedObjectMatch != null) {
        final objectJson = _extractBalancedJsonBlock(
          sanitized,
          firstNonWhitespace,
        );
        if (objectJson != null) {
          return '{"app_command":$objectJson}';
        }
      }

      final looseNamedObjectMatch = RegExp(
        r'[\[,]\s*\{\s*\\?"name\\?"\s*:',
        caseSensitive: false,
      ).firstMatch(sanitized);
      if (looseNamedObjectMatch != null) {
        final objectStart = sanitized.indexOf('{', looseNamedObjectMatch.start);
        final objectJson = _extractBalancedJsonBlock(sanitized, objectStart);
        if (objectJson != null) {
          return '{"app_commands":[$objectJson]}';
        }
      }

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

  static String _removePendingActionBlocks(String responseContent) {
    return responseContent.replaceAll(_pendingActionBlockPattern, '');
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
        final mealsPerDay = AppAgentService._readRequestedMealsPerDay(
          normalized,
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
        final foodRestrictions =
            AppAgentService._extractDietRestrictionList(normalized);

        return {
          if (skipPreferenceStep == true) 'skipPreferenceStep': true,
          if (mealsPerDay != null) 'mealsPerDay': mealsPerDay,
          if (foodRestrictions.isNotEmpty) 'foodRestrictions': foodRestrictions,
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
            'healthConditions',
            'medicalConditions',
            'medicalIssues',
            'healthConsiderations',
            'conditions',
            'condicoesSaude',
            'problemasSaude',
          ]))
            'routineConsiderations': AppAgentService._extractStringList(
              AppAgentService._readFirstValue(
                normalized,
                const [
                  'routineConsiderations',
                  'routineNotes',
                  'appetiteNotes',
                  'healthConditions',
                  'medicalConditions',
                  'medicalIssues',
                  'healthConsiderations',
                  'conditions',
                  'condicoesSaude',
                  'problemasSaude',
                ],
              ),
            ),
          if (mealWindow != null) 'hungriestMealTime': mealWindow,
        };

      case AppAgentService.generateNewDietPlan:
        final mealsPerDay = AppAgentService._readRequestedMealsPerDay(
          normalized,
        );
        return {
          if (mealsPerDay != null) 'mealsPerDay': mealsPerDay,
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

class AppAgentPendingAction {
  const AppAgentPendingAction({
    required this.command,
    required this.rawBlock,
  });

  static final RegExp _blockPattern = RegExp(
    r'\[APP_PENDING_ACTION_BEGIN\]([\s\S]*?)\[APP_PENDING_ACTION_END\]',
    caseSensitive: false,
  );

  final AppAgentCommand command;
  final String rawBlock;

  String toPromptBlock() {
    final payload = jsonEncode({
      'app_command': {
        'name': command.name,
        'arguments': command.arguments,
      },
    });
    return '[APP_PENDING_ACTION_BEGIN]\n'
        '$payload\n'
        '[APP_PENDING_ACTION_END]';
  }

  AppAgentCommand toExecutionCommand({required String rawJson}) {
    return AppAgentCommand(
      name: command.name,
      arguments: command.arguments,
      rawJson: rawJson,
    );
  }

  bool matchesCommand(AppAgentCommand candidate) {
    if (candidate.name != command.name) {
      return false;
    }

    if (candidate.arguments.isEmpty || command.arguments.isEmpty) {
      return true;
    }

    for (final entry in candidate.arguments.entries) {
      if (!command.arguments.containsKey(entry.key)) {
        continue;
      }

      final pendingValue = command.arguments[entry.key];
      if (entry.key == 'fitnessGoal') {
        final pendingGoal = AppAgentService._parseFitnessGoal(pendingValue);
        final candidateGoal = AppAgentService._parseFitnessGoal(entry.value);
        if (pendingGoal != null && candidateGoal != null) {
          if (pendingGoal != candidateGoal) {
            return false;
          }
          continue;
        }
      }

      if (pendingValue?.toString() != entry.value?.toString()) {
        return false;
      }
    }

    return true;
  }

  static AppAgentPendingAction? tryParse(String responseContent) {
    final matches = _blockPattern.allMatches(responseContent).toList();
    if (matches.isEmpty) {
      return null;
    }

    for (final match in matches.reversed) {
      final rawBlock = match.group(0);
      final body = match.group(1);
      if (rawBlock == null || body == null) {
        continue;
      }

      final jsonStart = body.indexOf('{');
      final jsonEnd = body.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1 || jsonEnd < jsonStart) {
        continue;
      }

      try {
        final decoded = jsonDecode(body.substring(jsonStart, jsonEnd + 1));
        if (decoded is! Map) {
          continue;
        }

        final root = Map<String, dynamic>.from(decoded);
        final commandNode =
            root['app_command'] ?? root['appCommand'] ?? root['appcommand'];
        final commandMap =
            commandNode is Map ? Map<String, dynamic>.from(commandNode) : root;
        final command = AppAgentCommand._buildCommandFromMap(
          commandMap,
          rawBlock,
        );
        if (command == null) {
          continue;
        }

        return AppAgentPendingAction(
          command: command,
          rawBlock: rawBlock,
        );
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  static AppAgentPendingAction? findLatestInTrailingAssistantTurn(
    List<Map<String, dynamic>> messages,
  ) {
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      if (message['isUser'] == true) {
        return null;
      }

      final text = _messageText(message);
      if (text.trim().isEmpty) {
        continue;
      }

      return tryParse(text) ??
          _inferFromTrailingAssistantTurn(
            messages: messages,
            assistantIndex: index,
            assistantText: text,
          );
    }

    return null;
  }

  static AppAgentPendingAction? findLatestUnresolvedInConversation(
    List<Map<String, dynamic>> messages,
  ) {
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      final text = _messageText(message);
      if (text.trim().isEmpty) {
        continue;
      }

      if (message['isUser'] == true) {
        final normalized = AppAgentService._normalizeLooseText(text);
        if (AppAgentService._containsAnyTerm(normalized, const [
          'nao',
          'nao quero',
          'cancela',
          'cancelar',
          'deixa',
          'deixa pra la',
          'esquece',
          'stop',
          'cancel',
        ])) {
          return null;
        }
        continue;
      }

      if (_looksLikeCompletedPendingActionBoundary(text)) {
        return null;
      }

      final pendingAction = tryParse(text) ??
          _inferFromTrailingAssistantTurn(
            messages: messages,
            assistantIndex: index,
            assistantText: text,
          );
      if (pendingAction != null) {
        return pendingAction;
      }
    }

    return null;
  }

  static bool _looksLikeCompletedPendingActionBoundary(String assistantText) {
    final normalized = AppAgentService._normalizeLooseText(assistantText);
    return AppAgentService._containsAnyTerm(normalized, const [
      'pronto recalculei',
      'recalculei suas metas',
      'pronto atualizei',
      'atualizei suas metas',
      'metas atualizadas',
      'salvei suas metas',
      'pronto salvei',
      'gerei sua dieta',
      'dieta gerada',
    ]);
  }

  static bool isLikelyApproval(String userMessage) {
    final normalized = AppAgentService._normalizeLooseText(userMessage);
    if (normalized.isEmpty) {
      return false;
    }

    const directRejections = {
      'nao',
      'nao quero',
      'negativo',
      'cancela',
      'cancelar',
      'para',
      'pare',
      'stop',
      'cancel',
    };
    if (directRejections.contains(normalized) ||
        AppAgentService._containsAnyTerm(normalized, const [
          'nao quero',
          'nao faca',
          'nao faz',
          'nao aplique',
          'negativo',
          'cancela',
          'cancelar',
          'pare',
          'stop',
          'cancel',
        ])) {
      return false;
    }

    const directApprovals = {
      'sim',
      's',
      'ok',
      'okay',
      'pode',
      'pode sim',
      'quero',
      'quero sim',
      'isso',
      'isso mesmo',
      'confirmo',
      'confirmar',
      'calcule',
      'calcular',
      'recalcule',
      'recalcula',
      'faca isso',
      'faz isso',
      'aplica',
      'aplique',
      'aplicar',
      'salva',
      'salve',
      'salvar',
      'segue',
      'seguir',
      'continua',
      'continue',
      'manda',
      'mande',
      'vai',
      'yes',
      'do it',
      'apply',
      'save',
      'go ahead',
    };
    if (directApprovals.contains(normalized)) {
      return true;
    }

    return AppAgentService._containsAnyTerm(normalized, const [
      'pode fazer',
      'pode seguir',
      'pode continuar',
      'pode calcular',
      'pode recalcular',
      'pode ajustar',
      'pode aplicar',
      'faca isso',
      'faz isso',
      'faz essa mudanca',
      'faca essa mudanca',
      'aplica isso',
      'aplique isso',
      'segue com isso',
      'continua com isso',
      'pode seguir com isso',
      'pode continuar com isso',
      'yes do it',
      'apply it',
      'save it',
      'go ahead with it',
    ]);
  }

  bool shouldExecuteImmediately({
    required String userMessage,
    required String visibleAssistantText,
  }) {
    final normalizedVisible =
        AppAgentService._normalizeLooseText(visibleAssistantText);
    if (_looksLikeImmediateExecution(normalizedVisible)) {
      return true;
    }

    if (_asksForConfirmation(normalizedVisible)) {
      return false;
    }

    return _userExplicitlyRequestedCommand(command, userMessage);
  }

  static String removeBlock(String responseContent) {
    return responseContent.replaceAll(_blockPattern, '').trim();
  }

  static bool _asksForConfirmation(String normalizedAssistant) {
    return AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'posso seguir',
        'posso continuar',
        'posso fazer',
        'posso aplicar',
        'posso recalcular',
        'posso calcular',
        'quer que eu',
        'quer que faca',
        'quer que faça',
        'voce gostaria',
        'você gostaria',
        'confirma',
        'confirmar',
        'se quiser',
        'deseja que eu',
      ],
    );
  }

  static bool _looksLikeImmediateExecution(String normalizedAssistant) {
    return AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'vou fazer isso agora',
        'vou fazer agora',
        'vou seguir agora',
        'vou aplicar agora',
        'vou recalcular agora',
        'vou calcular agora',
        'vou ajustar agora',
        'vou atualizar agora',
        'vou alterar agora',
        'vou gerar agora',
        'vou montar agora',
        'farei agora',
        'farei isso agora',
        'aplicarei agora',
        'recalcularei agora',
        'calcularei agora',
        'ajustarei agora',
        'atualizarei agora',
        'i will do it now',
        'i will apply it now',
        'i will recalculate now',
        'i will update now',
      ],
    );
  }

  static bool _userExplicitlyRequestedCommand(
    AppAgentCommand command,
    String userMessage,
  ) {
    final normalized = AppAgentService._normalizeLooseText(userMessage);
    if (normalized.isEmpty) {
      return false;
    }

    switch (command.name) {
      case AppAgentService.recalculateNutritionGoals:
        return _looksLikeExplicitGoalChange(userMessage);
      case AppAgentService.updateMacroTargetsPercentage:
      case AppAgentService.updateMacroTargetsGrams:
      case AppAgentService.updateMacroTargetsGramsPerKg:
        return AppAgentService.buildMacroTargetsCommandFromUserMessage(
              userMessage,
              rawJson: '',
            ) !=
            null;
      case AppAgentService.generateNewDietPlan:
        return AppAgentService.isDietGenerationRequest(userMessage);
      case AppAgentService.getDailyNutritionStatus:
      case AppAgentService.getWeeklyNutritionSummary:
      case AppAgentService.getWeightStatus:
      case AppAgentService.getMacroTargetsStatus:
      case AppAgentService.getDietGenerationPreferencesStatus:
      case AppAgentService.getGoalSetupStatus:
        return true;
      default:
        return false;
    }
  }

  static bool _looksLikeExplicitGoalChange(String userMessage) {
    final raw = userMessage.trim();
    final normalizedUserMessage =
        AppAgentService._normalizeLooseText(userMessage);
    if (AppAgentService._parseFitnessGoal(normalizedUserMessage) == null) {
      return false;
    }

    const shortGoalAnswers = {
      'manter peso',
      'manutencao',
      'cutting',
      'bulking',
      'bulk',
      'emagrecer',
      'perder peso',
      'perder gordura',
      'ganhar peso',
      'ganhar massa',
      'hipertrofia',
    };
    if (shortGoalAnswers.contains(normalizedUserMessage)) {
      return true;
    }

    final hasExplicitCue = AppAgentService._containsAnyTerm(
      normalizedUserMessage,
      const [
        'quero',
        'preciso',
        'coloca',
        'coloque',
        'bota',
        'bote',
        'muda',
        'mude',
        'mudar',
        'troca',
        'troque',
        'trocar',
        'ajusta',
        'ajuste',
        'ajustar',
        'altera',
        'altere',
        'alterar',
        'define',
        'defina',
        'definir',
        'fazer cutting',
        'fazer um cutting',
        'fazer bulking',
        'fazer um bulking',
      ],
    );
    if (!hasExplicitCue) {
      return false;
    }

    if (raw.contains('?') &&
        !AppAgentService._containsAnyTerm(
          normalizedUserMessage,
          const [
            'quero',
            'preciso',
            'coloca',
            'coloque',
            'bota',
            'bote',
            'muda',
            'mude',
            'mudar',
            'troca',
            'troque',
            'trocar',
            'ajusta',
            'ajuste',
            'ajustar',
            'altera',
            'altere',
            'alterar',
            'define',
            'defina',
            'definir',
          ],
        )) {
      return false;
    }

    return true;
  }

  static AppAgentPendingAction? _inferFromTrailingAssistantTurn({
    required List<Map<String, dynamic>> messages,
    required int assistantIndex,
    required String assistantText,
  }) {
    final normalizedAssistant =
        AppAgentService._normalizeLooseText(assistantText);
    if (!_looksLikeActionConfirmation(normalizedAssistant)) {
      return null;
    }

    final recentUserText = _recentUserText(
      messages: messages,
      assistantIndex: assistantIndex,
    );
    final command = _inferCommandFromPendingQuestion(
      assistantText: assistantText,
      recentUserText: recentUserText,
    );
    if (command == null) {
      return null;
    }

    return _fromCommand(command);
  }

  static AppAgentPendingAction _fromCommand(AppAgentCommand command) {
    final payload = jsonEncode({
      'app_command': {
        'name': command.name,
        'arguments': command.arguments,
      },
    });
    return AppAgentPendingAction(
      command: command,
      rawBlock: '[APP_PENDING_ACTION_BEGIN]\n'
          '$payload\n'
          '[APP_PENDING_ACTION_END]',
    );
  }

  static AppAgentCommand? _inferCommandFromPendingQuestion({
    required String assistantText,
    required String recentUserText,
  }) {
    final normalizedAssistant =
        AppAgentService._normalizeLooseText(assistantText);
    final recentContext = [recentUserText, assistantText]
        .where((text) => text.trim().isNotEmpty)
        .join('\n');

    if (_looksLikePendingMacroTargetUpdate(normalizedAssistant)) {
      final command = AppAgentService.buildMacroTargetsCommandFromUserMessage(
        recentUserText,
        rawJson: '',
      );
      if (command != null) {
        return command;
      }
    }

    if (_looksLikePendingGoalRecalculation(normalizedAssistant)) {
      final fitnessGoal = _inferFitnessGoalFromRecentContext(
        recentUserText: recentUserText,
        assistantText: assistantText,
      );
      return AppAgentCommand(
        name: AppAgentService.recalculateNutritionGoals,
        arguments: <String, dynamic>{
          if (fitnessGoal != null) 'fitnessGoal': fitnessGoal.name,
        },
        rawJson: '',
      );
    }

    if (_looksLikePendingDietGeneration(normalizedAssistant, recentContext)) {
      final preferencesCommand =
          AppAgentService.buildDietPreferenceUpdateFromUserMessage(
        recentContext,
        rawJson: '',
      );
      final requestedMealsPerDay = AppAgentService._readRequestedMealsPerDay(
        preferencesCommand?.arguments ?? const <String, dynamic>{},
      );
      return AppAgentCommand(
        name: AppAgentService.generateNewDietPlan,
        arguments: <String, dynamic>{
          if (requestedMealsPerDay != null) 'mealsPerDay': requestedMealsPerDay,
        },
        rawJson: '',
      );
    }

    if (_looksLikePendingDailyStatus(normalizedAssistant, recentContext)) {
      return const AppAgentCommand(
        name: AppAgentService.getDailyNutritionStatus,
        arguments: <String, dynamic>{},
        rawJson: '',
      );
    }

    if (_looksLikePendingWeeklySummary(normalizedAssistant, recentContext)) {
      return const AppAgentCommand(
        name: AppAgentService.getWeeklyNutritionSummary,
        arguments: <String, dynamic>{},
        rawJson: '',
      );
    }

    if (_looksLikePendingWeightStatus(normalizedAssistant, recentContext)) {
      return const AppAgentCommand(
        name: AppAgentService.getWeightStatus,
        arguments: <String, dynamic>{},
        rawJson: '',
      );
    }

    if (_looksLikePendingMacroStatus(normalizedAssistant, recentContext)) {
      return const AppAgentCommand(
        name: AppAgentService.getMacroTargetsStatus,
        arguments: <String, dynamic>{},
        rawJson: '',
      );
    }

    return null;
  }

  static bool _looksLikeActionConfirmation(String normalizedAssistant) {
    return AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'posso seguir',
        'posso fazer',
        'posso recalcular',
        'posso calcular',
        'posso ajustar',
        'posso atualizar',
        'quer que eu',
        'voce quer que eu',
        'gostaria que eu',
        'devo seguir',
        'devo fazer',
        'confirmar',
      ],
    );
  }

  static bool _looksLikePendingGoalRecalculation(String normalizedAssistant) {
    final hasGoalTopic = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'meta',
        'metas',
        'macro',
        'macros',
        'caloria',
        'calorias',
        'nutricao',
        'objetivo',
        'dieta',
      ],
    );
    final hasMutationIntent = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'recalcular',
        'calcular',
        'ajustar',
        'mudar',
        'alterar',
        'atualizar',
        'aplicar',
      ],
    );
    return hasGoalTopic && hasMutationIntent;
  }

  static bool _looksLikePendingMacroTargetUpdate(String normalizedAssistant) {
    final hasExplicitCalories = AppAgentService._extractExplicitCaloriesTarget(
          normalizedAssistant,
        ) !=
        null;
    final hasMacroTopic = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'meta',
        'metas',
        'macro',
        'macros',
        'caloria',
        'calorias',
        'kcal',
        'proteina',
        'carboidrato',
        'gordura',
      ],
    );
    final hasMutationIntent = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'atualizar',
        'ajustar',
        'mudar',
        'alterar',
        'definir',
        'colocar',
        'aplicar',
        'salvar',
      ],
    );
    return hasExplicitCalories && hasMacroTopic && hasMutationIntent;
  }

  static bool _looksLikePendingDietGeneration(
    String normalizedAssistant,
    String recentContext,
  ) {
    final normalizedContext =
        AppAgentService._normalizeLooseText(recentContext);
    final hasDietTopic = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'dieta',
        'cardapio',
        'plano alimentar',
        'meal plan',
      ],
    );
    final hasGenerationIntent = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'gerar',
        'gera',
        'montar',
        'monta',
        'criar',
        'cria',
        'fazer',
        'faco',
        'preparar',
      ],
    );
    return hasDietTopic &&
        hasGenerationIntent &&
        AppAgentService.isDietGenerationRequest(normalizedContext);
  }

  static bool _looksLikePendingDailyStatus(
    String normalizedAssistant,
    String recentContext,
  ) {
    final normalizedContext =
        AppAgentService._normalizeLooseText(recentContext);
    final hasDailyTopic = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'hoje',
        'ainda pode',
        'restante',
        'sobrou',
        'faltam',
        'consumiu hoje',
        'consumo de hoje',
      ],
    );
    final hasNutritionTopic = AppAgentService._containsAnyTerm(
      normalizedContext,
      const [
        'caloria',
        'calorias',
        'kcal',
        'macro',
        'macros',
        'proteina',
        'carboidrato',
        'gordura',
        'comer',
        'consumir',
      ],
    );
    return hasDailyTopic && hasNutritionTopic;
  }

  static bool _looksLikePendingWeeklySummary(
    String normalizedAssistant,
    String recentContext,
  ) {
    final normalizedContext =
        AppAgentService._normalizeLooseText(recentContext);
    final hasWeeklyTopic = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'semana',
        'semanal',
        'ultimos dias',
        'resumo semanal',
      ],
    );
    final hasNutritionTopic = AppAgentService._containsAnyTerm(
      normalizedContext,
      const [
        'nutricao',
        'caloria',
        'calorias',
        'macro',
        'macros',
        'dieta',
        'semana',
      ],
    );
    return hasWeeklyTopic && hasNutritionTopic;
  }

  static bool _looksLikePendingWeightStatus(
    String normalizedAssistant,
    String recentContext,
  ) {
    final normalizedContext =
        AppAgentService._normalizeLooseText(recentContext);
    final hasWeightTopic = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'peso',
        'progresso',
        'evolucao',
        'balanca',
      ],
    );
    final hasStatusIntent = AppAgentService._containsAnyTerm(
      normalizedContext,
      const [
        'peso',
        'progresso',
        'evolucao',
        'ganhei',
        'perdi',
        'balanca',
      ],
    );
    return hasWeightTopic && hasStatusIntent;
  }

  static bool _looksLikePendingMacroStatus(
    String normalizedAssistant,
    String recentContext,
  ) {
    final normalizedContext =
        AppAgentService._normalizeLooseText(recentContext);
    final hasMacroTopic = AppAgentService._containsAnyTerm(
      normalizedAssistant,
      const [
        'metas atuais',
        'macros atuais',
        'alvos atuais',
        'suas metas',
        'seus macros',
      ],
    );
    final hasStatusIntent = AppAgentService._containsAnyTerm(
      normalizedContext,
      const [
        'meta',
        'metas',
        'macro',
        'macros',
        'caloria',
        'calorias',
      ],
    );
    return hasMacroTopic && hasStatusIntent;
  }

  static FitnessGoal? _inferFitnessGoalFromRecentContext({
    required String recentUserText,
    required String assistantText,
  }) {
    final userGoal = AppAgentService._parseFitnessGoal(recentUserText);
    if (userGoal != null) {
      return userGoal;
    }

    final normalizedAssistant =
        AppAgentService._normalizeLooseText(assistantText);
    final targetGoal = _parseGoalAfterTargetMarker(normalizedAssistant);
    if (targetGoal != null) {
      return targetGoal;
    }
    if (AppAgentService._containsAnyTerm(normalizedAssistant, const [
      'cut',
      'cutting',
      'emagrecer',
      'perder peso',
      'perder gordura',
      'secar',
    ])) {
      return FitnessGoal.loseWeight;
    }
    if (AppAgentService._containsAnyTerm(normalizedAssistant, const [
      'bulk',
      'bulking',
      'ganhar massa',
      'hipertrofia',
      'aumentar massa',
    ])) {
      return FitnessGoal.gainWeightSlowly;
    }
    return null;
  }

  static String _recentUserText({
    required List<Map<String, dynamic>> messages,
    required int assistantIndex,
  }) {
    final parts = <String>[];
    var userTurns = 0;
    for (var index = assistantIndex - 1; index >= 0; index--) {
      final message = messages[index];
      if (message['isUser'] != true) {
        continue;
      }
      final text = _messageText(message).trim();
      if (text.isNotEmpty) {
        parts.insert(0, text);
        userTurns++;
      }
      if (userTurns >= 3 || assistantIndex - index > 8) {
        break;
      }
    }
    return parts.join('\n');
  }

  static FitnessGoal? _parseGoalAfterTargetMarker(String normalizedText) {
    const markers = [
      'mudar para',
      'alterar para',
      'trocar para',
      'ajustar para',
      'atualizar para',
      'definir para',
      'metas para',
      'objetivo para',
    ];
    for (final marker in markers) {
      final normalizedMarker = AppAgentService._normalizeLooseText(marker);
      final markerIndex = normalizedText.indexOf(normalizedMarker);
      if (markerIndex == -1) {
        continue;
      }
      final endIndex = markerIndex + 96 > normalizedText.length
          ? normalizedText.length
          : markerIndex + 96;
      final segment = normalizedText.substring(markerIndex, endIndex);
      final goal = AppAgentService._parseFitnessGoal(segment);
      if (goal != null) {
        return goal;
      }
    }
    return null;
  }

  static String _messageText(Map<String, dynamic> message) {
    final rawMessage = message['message'];
    if (rawMessage != null) {
      return rawMessage.toString();
    }

    final notifier = message['notifier'];
    if (notifier is MessageNotifier) {
      return notifier.message;
    }

    return '';
  }
}

class AppAgentUiHint {
  const AppAgentUiHint({
    required this.actions,
    required this.rawBlock,
  });

  static const actionLogin = 'login';
  static const actionConfigureGoalsUi = 'configure_goals_ui';
  static const actionEditMacrosUi = 'edit_macros_ui';
  static const actionWatchRewardedAd = 'watch_rewarded_ad';
  static const actionViewMyDietUi = 'view_my_diet_ui';

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
      case 'viewmydietui':
      case 'viewmydiet':
      case 'openmydiet':
      case 'mydiet':
      case 'diettab':
        return actionViewMyDietUi;
      case 'watchrewardedad':
      case 'watchad':
      case 'watchadforcredits':
      case 'rewardedad':
      case 'earncredits':
      case 'getcredits':
        return actionWatchRewardedAd;
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

  static void logAgentDebug(String event, Map<String, dynamic> data) {
    AppDebugLogService.add('APP_AGENT_DEBUG', event, data);
  }

  static String debugPreview(String value, {int maxChars = 500}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars)}...';
  }

  static Future<AppAgentExecutionResult> executeCommand(
    AppAgentCommand command,
    BuildContext context,
  ) async {
    final startedAt = DateTime.now();
    logAgentDebug('command_start', {
      'name': command.name,
      'arguments': command.arguments,
      'rawJsonPreview': debugPreview(command.rawJson),
    });

    try {
      late final AppAgentExecutionResult result;
      switch (command.name) {
        case getDailyNutritionStatus:
          result = await _getDailyNutritionStatus(command, context);
          break;
        case getWeeklyNutritionSummary:
          result = await _getWeeklyNutritionSummary(command, context);
          break;
        case getWeightStatus:
          result = await _getWeightStatus(command, context);
          break;
        case recalculateNutritionGoals:
          result = await _recalculateNutritionGoals(command, context);
          break;
        case generateNewDietPlan:
          result = await _generateNewDietPlan(command, context);
          break;
        case getGoalSetupStatus:
          result = await _getGoalSetupStatus(command, context);
          break;
        case updateGoalSetupProfile:
          result = await _updateGoalSetupProfile(command, context);
          break;
        case updateGoalSetupPreferences:
          result = await _updateGoalSetupPreferences(command, context);
          break;
        case getDietGenerationPreferencesStatus:
          result = await _getDietGenerationPreferencesStatus(command, context);
          break;
        case updateDietGenerationPreferences:
          result = await _updateDietGenerationPreferences(command, context);
          break;
        case getMacroTargetsStatus:
          result = await _getMacroTargetsStatus(command, context);
          break;
        case updateMacroTargetsPercentage:
          result = await _updateMacroTargetsPercentage(command, context);
          break;
        case updateMacroTargetsGrams:
          result = await _updateMacroTargetsGrams(command, context);
          break;
        case updateMacroTargetsGramsPerKg:
          result = await _updateMacroTargetsGramsPerKg(command, context);
          break;
        default:
          result = AppAgentExecutionResult(
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

      logAgentDebug('command_result', {
        'name': result.commandName,
        'success': result.success,
        'errorMessage': result.errorMessage,
        'payloadKeys': result.payload.keys.toList(),
        'payloadPreview': result.payload,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      });
      return result;
    } catch (error) {
      logAgentDebug('command_throw', {
        'name': command.name,
        'error': error.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      });
      rethrow;
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

  static String _contextLanguageCode(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase();

  static bool _isPortugueseLanguage(String language) =>
      language.toLowerCase().startsWith('pt');

  static String _localizedMacroTargetsStatusMessage({
    required String language,
    required int caloriesGoal,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    final proteinText = _formatOneDecimal(protein);
    final carbsText = _formatOneDecimal(carbs);
    final fatText = _formatOneDecimal(fat);
    switch (language) {
      case 'es':
        return 'Tus metas actuales son $caloriesGoal kcal: ${proteinText}g de proteína, '
            '${carbsText}g de carbohidratos y ${fatText}g de grasas. '
            'Dime si quieres reducir o aumentar calorías, o cambiar algún macro.';
      case 'fr':
        return 'Tes objectifs actuels sont $caloriesGoal kcal : ${proteinText}g de protéines, '
            '${carbsText}g de glucides et ${fatText}g de lipides. '
            'Dis-moi si tu veux réduire ou augmenter les calories, ou modifier un macro.';
      case 'de':
        return 'Deine aktuellen Ziele sind $caloriesGoal kcal: ${proteinText}g Protein, '
            '${carbsText}g Kohlenhydrate und ${fatText}g Fett. '
            'Sag mir, ob du Kalorien senken oder erhöhen oder ein Makro ändern willst.';
      case 'it':
        return 'I tuoi obiettivi attuali sono $caloriesGoal kcal: ${proteinText}g di proteine, '
            '${carbsText}g di carboidrati e ${fatText}g di grassi. '
            'Dimmi se vuoi ridurre o aumentare le calorie, oppure cambiare un macro.';
      case 'pt':
        return 'Suas metas atuais são $caloriesGoal kcal: ${proteinText}g de proteína, '
            '${carbsText}g de carboidratos e ${fatText}g de gorduras. '
            'Me diga se quer reduzir ou aumentar calorias, ou mudar algum macro.';
      default:
        return 'Your current goals are $caloriesGoal kcal: ${proteinText}g protein, '
            '${carbsText}g carbs, and ${fatText}g fat. '
            'Tell me if you want to lower or raise calories, or change any macro.';
    }
  }

  static String _localizedDailyRemainingStatusMessage({
    required String language,
    required DateTime? selectedDate,
    required int caloriesRemaining,
    required double proteinRemaining,
    required double carbsRemaining,
    required double fatRemaining,
  }) {
    final dateLabel = _dailyStatusDateLabelForLanguage(
      selectedDate,
      language: language,
    );
    final isToday = selectedDate == null ||
        _isSameDay(
          selectedDate,
          DateTime.now(),
        );
    final proteinText = _formatOneDecimal(proteinRemaining);
    final carbsText = _formatOneDecimal(carbsRemaining);
    final fatText = _formatOneDecimal(fatRemaining);
    switch (language) {
      case 'es':
        return '$dateLabel todavía ${isToday ? 'puedes' : 'podías'} consumir '
            '$caloriesRemaining kcal, ${proteinText}g de proteína, '
            '${carbsText}g de carbohidratos y ${fatText}g de grasas.';
      case 'fr':
        return '$dateLabel, tu ${isToday ? 'peux encore' : 'pouvais encore'} consommer '
            '$caloriesRemaining kcal, ${proteinText}g de protéines, '
            '${carbsText}g de glucides et ${fatText}g de lipides.';
      case 'de':
        return '$dateLabel ${isToday ? 'kannst du noch' : 'konntest du noch'} '
            '$caloriesRemaining kcal, ${proteinText}g Protein, '
            '${carbsText}g Kohlenhydrate und ${fatText}g Fett zu dir nehmen.';
      case 'it':
        return '$dateLabel ${isToday ? 'puoi ancora' : 'potevi ancora'} consumare '
            '$caloriesRemaining kcal, ${proteinText}g di proteine, '
            '${carbsText}g di carboidrati e ${fatText}g di grassi.';
      case 'pt':
        return '$dateLabel você ainda ${isToday ? 'pode' : 'podia'} consumir '
            '$caloriesRemaining kcal, ${proteinText}g de proteína, '
            '${carbsText}g de carboidratos e ${fatText}g de gorduras.';
      default:
        return '$dateLabel you ${isToday ? 'still have' : 'had'} '
            '$caloriesRemaining kcal, ${proteinText}g protein, '
            '${carbsText}g carbs, and ${fatText}g fat remaining.';
    }
  }

  static String? buildMacroGoalsCommandResultMessage({
    required BuildContext context,
    required List<AppAgentExecutionResult> executionResults,
  }) {
    if (executionResults.isEmpty) {
      return null;
    }

    final language = _contextLanguageCode(context);
    final isPortuguese = _isPortugueseLanguage(language);
    final successfulResults =
        executionResults.where((result) => result.success).toList();

    if (successfulResults.isEmpty) {
      final lastError = executionResults.last.errorMessage ??
          executionResults.last.payload['reason']?.toString();
      if (lastError == 'login_required') {
        return isPortuguese
            ? 'Faça login para eu acessar e atualizar suas metas de calorias e macros.'
            : 'Log in so I can access and update your calorie and macro goals.';
      }
      return isPortuguese
          ? 'Não consegui acessar suas metas agora. Tente novamente em instantes.'
          : 'I could not access your goals right now. Please try again in a moment.';
    }

    final lastResult = successfulResults.last;
    final payload = lastResult.payload;
    final caloriesGoal = _tryParseInt(payload['caloriesGoal']) ?? 0;
    final grams = (payload['grams'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final protein = _tryParseDouble(grams['protein']) ??
        _tryParseDouble(payload['proteinGoal']) ??
        0;
    final carbs = _tryParseDouble(grams['carbs']) ??
        _tryParseDouble(payload['carbsGoal']) ??
        0;
    final fat = _tryParseDouble(grams['fat']) ??
        _tryParseDouble(payload['fatGoal']) ??
        0;
    final proteinPerKg = _tryParseDouble(payload['proteinPerKg']);

    switch (lastResult.commandName) {
      case getDailyNutritionStatus:
        final selectedDate = _tryParseDate(payload['selectedDate']);
        final caloriesRemaining =
            _tryParseInt(payload['caloriesRemaining']) ?? 0;
        final proteinRemaining =
            _tryParseDouble(payload['proteinRemaining']) ?? 0;
        final carbsRemaining = _tryParseDouble(payload['carbsRemaining']) ?? 0;
        final fatRemaining = _tryParseDouble(payload['fatRemaining']) ?? 0;
        return _localizedDailyRemainingStatusMessage(
          language: language,
          selectedDate: selectedDate,
          caloriesRemaining: caloriesRemaining,
          proteinRemaining: proteinRemaining,
          carbsRemaining: carbsRemaining,
          fatRemaining: fatRemaining,
        );
      case updateMacroTargetsPercentage:
      case updateMacroTargetsGrams:
      case updateMacroTargetsGramsPerKg:
        if (isPortuguese) {
          return 'Pronto, atualizei suas metas para $caloriesGoal kcal: '
              '${_formatOneDecimal(protein)}g de proteína, '
              '${_formatOneDecimal(carbs)}g de carboidratos e '
              '${_formatOneDecimal(fat)}g de gorduras.';
        }
        return 'Done, I updated your goals to $caloriesGoal kcal: '
            '${_formatOneDecimal(protein)}g protein, '
            '${_formatOneDecimal(carbs)}g carbs, and '
            '${_formatOneDecimal(fat)}g fat.';
      case recalculateNutritionGoals:
        if (isPortuguese) {
          final proteinNote = proteinPerKg == null
              ? ''
              : ' (${_formatOneDecimal(proteinPerKg)}g/kg)';
          return 'Pronto, recalculei suas metas com uma recomendação padrão '
              'para o seu objetivo: $caloriesGoal kcal, '
              '${_formatOneDecimal(protein)}g de proteína$proteinNote, '
              '${_formatOneDecimal(carbs)}g de carboidratos e '
              '${_formatOneDecimal(fat)}g de gorduras. '
              'Se quiser outro alvo, é só me dizer.';
        }
        final proteinNote = proteinPerKg == null
            ? ''
            : ' (${_formatOneDecimal(proteinPerKg)}g/kg)';
        return 'Done, I recalculated your goals with a standard '
            'recommendation for your objective: $caloriesGoal kcal, '
            '${_formatOneDecimal(protein)}g protein$proteinNote, '
            '${_formatOneDecimal(carbs)}g carbs, and '
            '${_formatOneDecimal(fat)}g fat. '
            'If you want a different target, just tell me.';
      case getMacroTargetsStatus:
        return _localizedMacroTargetsStatusMessage(
          language: language,
          caloriesGoal: caloriesGoal,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
      case getDietGenerationPreferencesStatus:
      case updateDietGenerationPreferences:
      case generateNewDietPlan:
        return isPortuguese
            ? 'Neste chat eu ajusto metas, calorias e macros. Me diga se você quer reduzir ou aumentar calorias, ou mudar proteína, carboidratos ou gorduras.'
            : 'In this chat I adjust goals, calories, and macros. Tell me if you want to lower or raise calories, or change protein, carbs, or fat.';
      default:
        return null;
    }
  }

  static String? buildCommandResultFallbackMessage({
    required BuildContext context,
    required List<AppAgentExecutionResult> executionResults,
    required String originalUserMessage,
  }) {
    final successfulResults =
        executionResults.where((result) => result.success).toList();
    if (successfulResults.isEmpty) {
      return null;
    }

    final lastResult = successfulResults.last;
    switch (lastResult.commandName) {
      case getDailyNutritionStatus:
        return _buildDailyNutritionStatusFallbackMessage(
          context: context,
          result: lastResult,
          originalUserMessage: originalUserMessage,
        );
      case updateMacroTargetsPercentage:
      case updateMacroTargetsGrams:
      case updateMacroTargetsGramsPerKg:
      case getMacroTargetsStatus:
      case recalculateNutritionGoals:
        return buildMacroGoalsCommandResultMessage(
          context: context,
          executionResults: executionResults,
        );
      case generateNewDietPlan:
        return buildDietGeneratedCommandResultMessage(
          context: context,
          executionResults: executionResults,
        );
      default:
        return null;
    }
  }

  static String _buildDailyNutritionStatusFallbackMessage({
    required BuildContext context,
    required AppAgentExecutionResult result,
    required String originalUserMessage,
  }) {
    final payload = result.payload;
    final language = _contextLanguageCode(context);
    final isPortuguese = _isPortugueseLanguage(language);
    final normalized = _normalizeLooseText(originalUserMessage);
    final caloriesGoal = _tryParseInt(payload['caloriesGoal']) ?? 0;
    final proteinGoal = _tryParseDouble(payload['proteinGoal']) ?? 0;
    final carbsGoal = _tryParseDouble(payload['carbsGoal']) ?? 0;
    final fatGoal = _tryParseDouble(payload['fatGoal']) ?? 0;
    final caloriesConsumed = _tryParseInt(payload['caloriesConsumed']) ?? 0;
    final proteinConsumed = _tryParseDouble(payload['proteinConsumed']) ?? 0;
    final carbsConsumed = _tryParseDouble(payload['carbsConsumed']) ?? 0;
    final fatConsumed = _tryParseDouble(payload['fatConsumed']) ?? 0;
    final caloriesRemaining =
        _tryParseInt(payload['caloriesRemaining']) ?? caloriesGoal;
    final proteinRemaining = _tryParseDouble(payload['proteinRemaining']) ??
        (proteinGoal - proteinConsumed);
    final carbsRemaining = _tryParseDouble(payload['carbsRemaining']) ??
        (carbsGoal - carbsConsumed);
    final fatRemaining =
        _tryParseDouble(payload['fatRemaining']) ?? (fatGoal - fatConsumed);
    final selectedDate = _tryParseDate(payload['selectedDate']);
    final dateLabel = _dailyStatusDateLabelForLanguage(
      selectedDate,
      language: language,
    );
    final meals = (payload['meals'] as List?) ?? const [];
    final hasData = payload['hasData'] == true ||
        meals.isNotEmpty ||
        caloriesConsumed > 0 ||
        proteinConsumed > 0 ||
        carbsConsumed > 0 ||
        fatConsumed > 0;

    final asksConsumed = _containsAnyTerm(normalized, const [
      'consumo',
      'consumi',
      'consumido',
      'ingeri',
      'ingerido',
      'comi',
      'comido',
      'ja estou',
      'ja bati',
      'atingi',
      'progresso',
      'how much have i had',
      'consumed',
    ]);
    final asksProtein = _containsAnyTerm(normalized, const [
      'proteina',
      'protein',
    ]);
    final asksCarbs = _containsAnyTerm(normalized, const [
      'carbo',
      'carboidrato',
      'carboidratos',
      'carb',
      'carbs',
    ]);
    final asksFat = _containsAnyTerm(normalized, const [
      'gordura',
      'gorduras',
      'fat',
      'fats',
    ]);
    final asksSnackSuggestion = _looksLikeSnackSuggestionRequest(normalized);
    final asksEvaluation = _looksLikeDailyEvaluationRequest(normalized);
    final asksFoodList = _looksLikeFoodListRequest(normalized);

    if (isPortuguese) {
      if (asksEvaluation) {
        if (!hasData) {
          return 'Não encontrei registros da sua alimentação de ${dateLabel.toLowerCase()}. '
              'Se você registrou refeições nesse dia, pode ser que elas ainda não tenham sincronizado.';
        }
        final calorieRatio =
            caloriesGoal > 0 ? caloriesConsumed / caloriesGoal : 0.0;
        final proteinRatio =
            proteinGoal > 0 ? proteinConsumed / proteinGoal : 0.0;
        final calorieAssessment = calorieRatio < 0.7
            ? 'bem abaixo da meta'
            : calorieRatio > 1.15
                ? 'acima da meta'
                : 'perto da meta';
        final proteinAssessment =
            proteinRatio >= 0.9 ? 'proteína ficou boa' : 'proteína ficou baixa';
        final mealCount = meals.length;
        final mealPhrase = mealCount > 0
            ? ' com $mealCount ${mealCount == 1 ? 'refeição registrada' : 'refeições registradas'}'
            : '';
        return '$dateLabel$mealPhrase: você consumiu $caloriesConsumed kcal de $caloriesGoal kcal, '
            '${_formatOneDecimal(proteinConsumed)}g de proteína, '
            '${_formatOneDecimal(carbsConsumed)}g de carboidratos e '
            '${_formatOneDecimal(fatConsumed)}g de gorduras. '
            'Foi um dia $calorieAssessment e a $proteinAssessment. '
            '${calorieRatio < 0.7 ? 'Pelo registro, parece uma alimentação incompleta.' : 'No geral, o ponto principal é manter proteína e calorias dentro da meta.'}';
      }
      if (asksFoodList) {
        return _formatDailyFoodListMessage(
          meals: meals,
          dateLabel: dateLabel,
          isPortuguese: true,
        );
      }
      if (asksSnackSuggestion) {
        if (caloriesRemaining < 250) {
          return 'Uma opção de lanche leve: iogurte natural ou uma fruta com '
              'um pouco de whey, em torno de 150-220 kcal. Hoje você ainda '
              'tem $caloriesRemaining kcal disponíveis.';
        }
        return 'Uma boa opção de lanche: sanduíche de frango com pão integral '
            'e iogurte natural. Fica em torno de 500 kcal, com cerca de '
            '35g de proteína, 55g de carboidratos e 12g de gorduras, dentro '
            'das $caloriesRemaining kcal que você ainda tem hoje.';
      }
      if (asksConsumed && asksProtein) {
        return '$dateLabel você consumiu ${_formatOneDecimal(proteinConsumed)}g de '
            'proteína de uma meta de ${_formatOneDecimal(proteinGoal)}g. '
            '${_formatRemainingPhrase(proteinRemaining, 'g', 'proteína', true)}';
      }
      if (asksConsumed && asksCarbs) {
        return '$dateLabel você consumiu ${_formatOneDecimal(carbsConsumed)}g de '
            'carboidratos de uma meta de ${_formatOneDecimal(carbsGoal)}g. '
            '${_formatRemainingPhrase(carbsRemaining, 'g', 'carboidratos', true)}';
      }
      if (asksConsumed && asksFat) {
        return '$dateLabel você consumiu ${_formatOneDecimal(fatConsumed)}g de '
            'gorduras de uma meta de ${_formatOneDecimal(fatGoal)}g. '
            '${_formatRemainingPhrase(fatRemaining, 'g', 'gorduras', true)}';
      }
      if (asksConsumed) {
        return '$dateLabel você consumiu $caloriesConsumed kcal de $caloriesGoal kcal, '
            '${_formatOneDecimal(proteinConsumed)}g de proteína, '
            '${_formatOneDecimal(carbsConsumed)}g de carboidratos e '
            '${_formatOneDecimal(fatConsumed)}g de gorduras. '
            'Ainda restam $caloriesRemaining kcal.';
      }
      return _localizedDailyRemainingStatusMessage(
        language: language,
        selectedDate: selectedDate,
        caloriesRemaining: caloriesRemaining,
        proteinRemaining: proteinRemaining,
        carbsRemaining: carbsRemaining,
        fatRemaining: fatRemaining,
      );
    }

    if (asksEvaluation) {
      if (!hasData) {
        return 'I did not find food records for ${dateLabel.toLowerCase()}. '
            'If you logged meals for that day, they may not have synced yet.';
      }
      final calorieRatio =
          caloriesGoal > 0 ? caloriesConsumed / caloriesGoal : 0.0;
      final proteinRatio =
          proteinGoal > 0 ? proteinConsumed / proteinGoal : 0.0;
      final calorieAssessment = calorieRatio < 0.7
          ? 'well below target'
          : calorieRatio > 1.15
              ? 'above target'
              : 'near target';
      final proteinAssessment =
          proteinRatio >= 0.9 ? 'protein was good' : 'protein was low';
      return '$dateLabel: you consumed $caloriesConsumed kcal out of $caloriesGoal kcal, '
          '${_formatOneDecimal(proteinConsumed)}g protein, '
          '${_formatOneDecimal(carbsConsumed)}g carbs, and '
          '${_formatOneDecimal(fatConsumed)}g fat. '
          'That was $calorieAssessment, and $proteinAssessment.';
    }

    if (asksFoodList) {
      return _formatDailyFoodListMessage(
        meals: meals,
        dateLabel: dateLabel,
        isPortuguese: false,
      );
    }

    if (asksSnackSuggestion) {
      return 'A practical snack that fits your remaining budget: a chicken '
          'sandwich with whole-grain bread plus plain yogurt, around 500 kcal, '
          '35g protein, 55g carbs, and 12g fat. You still have '
          '$caloriesRemaining kcal available today.';
    }
    if (asksConsumed && asksProtein) {
      return '$dateLabel you consumed ${_formatOneDecimal(proteinConsumed)}g '
          'of protein out of a ${_formatOneDecimal(proteinGoal)}g target. '
          '${_formatRemainingPhrase(proteinRemaining, 'g', 'protein', false)}';
    }
    if (asksConsumed) {
      return '$dateLabel you consumed $caloriesConsumed kcal out of '
          '$caloriesGoal kcal, ${_formatOneDecimal(proteinConsumed)}g protein, '
          '${_formatOneDecimal(carbsConsumed)}g carbs, and '
          '${_formatOneDecimal(fatConsumed)}g fat. You still have '
          '$caloriesRemaining kcal remaining.';
    }
    return _localizedDailyRemainingStatusMessage(
      language: language,
      selectedDate: selectedDate,
      caloriesRemaining: caloriesRemaining,
      proteinRemaining: proteinRemaining,
      carbsRemaining: carbsRemaining,
      fatRemaining: fatRemaining,
    );
  }

  static bool _looksLikeSnackSuggestionRequest(String normalizedText) {
    final hasSuggestion = _containsAnyTerm(normalizedText, const [
      'sugestao',
      'sugestoes',
      'sugerir',
      'sugere',
      'sugira',
      'recomenda',
      'recomendar',
      'indica',
      'indicar',
      'ideia',
      'opcao',
      'opcoes',
      'suggest',
      'recommend',
      'idea',
      'option',
    ]);
    final hasMeal = _containsAnyTerm(normalizedText, const [
      'lanche',
      'snack',
      'refeicao',
      'comida',
      'alimento',
      'comer',
      'meal',
      'food',
    ]);
    final hasRemainingBudget = _containsAnyTerm(normalizedText, const [
          'posso comer',
          'ainda posso',
          'ja posso',
          'que eu posso',
          'que posso',
          'resta',
          'restam',
          'sobrou',
          'sobram',
          'falta',
          'faltam',
          'remaining',
          'left',
          'available',
        ]) ||
        RegExp(
          r'\b(com|dentro)\s+(as|das|minhas|os|dos|meus)?\s*(calorias|kcal|macros)\b',
        ).hasMatch(normalizedText);
    return hasSuggestion && hasMeal && hasRemainingBudget;
  }

  static bool _looksLikeFoodListRequest(String normalizedText) {
    return RegExp(
          r'\b(quais|qual|que|listar|lista|liste|mostra|mostrar|ver|what|which|list|show)\b.*\b(alimento|alimentos|comida|comidas|refeicao|refeicoes|food|foods|meal|meals)\b',
        ).hasMatch(normalizedText) ||
        RegExp(
          r'\b(o que|oque|what)\b.*\b(comi|consumi|ingeri|ate|had)\b',
        ).hasMatch(normalizedText) ||
        RegExp(
          r'^\s*(quais\s+)?(alimento|alimentos|comida|comidas|refeicao|refeicoes|foods|meals)\s*\??\s*$',
        ).hasMatch(normalizedText);
  }

  static String _formatDailyFoodListMessage({
    required List<dynamic> meals,
    required String dateLabel,
    required bool isPortuguese,
  }) {
    final lines = <String>[];

    for (final meal in meals) {
      if (meal is! Map) continue;
      final foods = meal['foods'];
      if (foods is! List || foods.isEmpty) continue;

      final foodTexts = <String>[];
      for (final food in foods) {
        if (food is! Map) continue;
        final name = food['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        final calories = _tryParseInt(food['calories']);
        foodTexts.add(
            calories != null && calories > 0 ? '$name ($calories kcal)' : name);
      }
      if (foodTexts.isEmpty) continue;

      final label = _localizedMealTypeLabel(
        meal['type']?.toString(),
        isPortuguese: isPortuguese,
      );
      lines.add('$label: ${foodTexts.join(', ')}');
    }

    if (lines.isEmpty) {
      return isPortuguese
          ? 'Não encontrei alimentos registrados em ${dateLabel.toLowerCase()}.'
          : 'I did not find any foods logged for ${dateLabel.toLowerCase()}.';
    }

    return isPortuguese
        ? '$dateLabel você registrou:\n${lines.map((line) => '- $line').join('\n')}'
        : '$dateLabel you logged:\n${lines.map((line) => '- $line').join('\n')}';
  }

  static String _localizedMealTypeLabel(
    String? mealType, {
    required bool isPortuguese,
  }) {
    final normalized = _normalizeLooseText(mealType ?? '');
    if (isPortuguese) {
      switch (normalized) {
        case 'breakfast':
        case 'cafe da manha':
          return 'Café da manhã';
        case 'lunch':
        case 'almoco':
          return 'Almoço';
        case 'dinner':
        case 'jantar':
          return 'Jantar';
        case 'snack':
        case 'lanche':
          return 'Lanche';
        default:
          return 'Refeição';
      }
    }

    switch (normalized) {
      case 'breakfast':
      case 'cafe da manha':
        return 'Breakfast';
      case 'lunch':
      case 'almoco':
        return 'Lunch';
      case 'dinner':
      case 'jantar':
        return 'Dinner';
      case 'snack':
      case 'lanche':
        return 'Snack';
      default:
        return 'Meal';
    }
  }

  static DateTime? _tryParseDate(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime? _resolveDailyStatusDate(
    Map<String, dynamic> arguments, {
    DateTime? fallbackDate,
  }) {
    final offset = _tryParseInt(
      _readFirstValue(arguments, const [
        'dateOffsetDays',
        'dayOffset',
        'offsetDays',
      ]),
    );
    if (offset != null) {
      final now = DateTime.now();
      return _dateOnly(now.add(Duration(days: offset)));
    }

    final explicitDate = _tryParseDate(
      _readFirstValue(arguments, const [
        'date',
        'selectedDate',
        'targetDate',
      ]),
    );
    if (explicitDate != null) {
      return _dateOnly(explicitDate);
    }

    if (fallbackDate != null) {
      return _dateOnly(fallbackDate);
    }
    return null;
  }

  static String _dailyStatusDateLabel(
    DateTime? selectedDate, {
    required bool isPortuguese,
  }) {
    return _dailyStatusDateLabelForLanguage(
      selectedDate,
      language: isPortuguese ? 'pt' : 'en',
    );
  }

  static String _dailyStatusDateLabelForLanguage(
    DateTime? selectedDate, {
    required String language,
  }) {
    final date = _dateOnly(selectedDate ?? DateTime.now());
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(date, today)) {
      switch (language) {
        case 'es':
          return 'Hoy';
        case 'fr':
          return "Aujourd'hui";
        case 'de':
          return 'Heute';
        case 'it':
          return 'Oggi';
        case 'pt':
          return 'Hoje';
        default:
          return 'Today';
      }
    }
    if (_isSameDay(date, yesterday)) {
      switch (language) {
        case 'es':
          return 'Ayer';
        case 'fr':
          return 'Hier';
        case 'de':
          return 'Gestern';
        case 'it':
          return 'Ieri';
        case 'pt':
          return 'Ontem';
        default:
          return 'Yesterday';
      }
    }
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    switch (language) {
      case 'es':
        return 'El $formatted';
      case 'fr':
        return 'Le $formatted';
      case 'de':
        return 'Am ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
      case 'it':
        return 'Il $formatted';
      case 'pt':
        return 'Em $formatted';
      default:
        return 'On $formatted';
    }
  }

  static String _formatRemainingPhrase(
    double remaining,
    String unit,
    String label,
    bool isPortuguese,
  ) {
    final amount = _formatOneDecimal(remaining.abs());
    if (isPortuguese) {
      if (remaining >= 0) {
        return 'Ainda faltam $amount$unit de $label para bater a meta.';
      }
      return 'Você já passou $amount$unit da meta de $label.';
    }

    if (remaining >= 0) {
      return 'You still have $amount$unit of $label remaining.';
    }
    return 'You are $amount$unit over your $label target.';
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

  static String? buildDietGeneratedCommandResultMessage({
    required BuildContext context,
    required List<AppAgentExecutionResult> executionResults,
  }) {
    final successfulDietResults = executionResults.where((item) {
      return item.success && item.commandName == generateNewDietPlan;
    }).toList();
    if (successfulDietResults.isEmpty) {
      return null;
    }

    final result = successfulDietResults.last;
    final isPortuguese =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'pt',
            );
    final mealCount = _tryParseInt(result.payload['mealCount']) ?? 0;
    final totalCalories = _tryParseInt(result.payload['totalCalories']) ?? 0;
    final totalProtein = _tryParseDouble(result.payload['totalProtein']) ?? 0;
    final totalCarbs = _tryParseDouble(result.payload['totalCarbs']) ?? 0;
    final totalFat = _tryParseDouble(result.payload['totalFat']) ?? 0;
    const hint =
        '\n\n[APP_UI_HINT_BEGIN]{"actions":["view_my_diet_ui"]}[APP_UI_HINT_END]';

    if (isPortuguese) {
      return 'Dieta gerada. Montei $mealCount refeições personalizadas, '
          'com cerca de $totalCalories kcal no dia '
          '(${_formatOneDecimal(totalProtein)}g proteína, '
          '${_formatOneDecimal(totalCarbs)}g carboidratos, '
          '${_formatOneDecimal(totalFat)}g gorduras). '
          'Você pode ver e ajustar tudo em Minha Dieta.'
          '$hint';
    }

    return 'Diet generated. I created $mealCount personalized meals, '
        'with about $totalCalories kcal for the day '
        '(${_formatOneDecimal(totalProtein)}g protein, '
        '${_formatOneDecimal(totalCarbs)}g carbs, '
        '${_formatOneDecimal(totalFat)}g fat). '
        'You can view and adjust everything in My Diet.'
        '$hint';
  }

  static bool isMacroTargetAdviceQuestion(String userMessage) {
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty || isDietGenerationRequest(userMessage)) {
      return false;
    }

    final hasMacroTopic = _containsAnyTerm(normalized, const [
      'macro',
      'macros',
      'proteina',
      'protein',
      'carbo',
      'carboidrato',
      'carboidratos',
      'carb',
      'carbs',
      'gordura',
      'gorduras',
      'fat',
      'fats',
      'caloria',
      'calorias',
      'kcal',
    ]);
    if (!hasMacroTopic) {
      return false;
    }

    final isExplicitMutation = RegExp(
      r'^\s*(coloque|bote|botar|mude|altere|troque|ajuste|aplique|aplica|salve|salva|atualize|set|change|update|save|apply)\b',
      caseSensitive: false,
    ).hasMatch(normalized);
    if (isExplicitMutation) {
      return false;
    }

    return userMessage.trim().endsWith('?') ||
        _containsAnyTerm(normalized, const [
          'seria interessante',
          'vale a pena',
          'devo',
          'preciso',
          'seria bom',
          'seria melhor',
          'e melhor',
          'esta bom',
          'ta bom',
          'esta boa',
          'ta boa',
          'muito',
          'pouco',
          'pouca',
          'suficiente',
          'adequado',
          'adequada',
          'recomendado',
          'recomendada',
          'mais proteina',
          'menos proteina',
          'aumentar proteina',
          'subir proteina',
          'baixar proteina',
          'reduzir proteina',
          'should i',
          'worth',
          'enough',
        ]);
  }

  static String? buildMacroTargetAdviceFallbackMessage({
    required BuildContext context,
    required String userMessage,
  }) {
    if (!isMacroTargetAdviceQuestion(userMessage)) {
      return null;
    }

    final normalized = _normalizeLooseText(userMessage);
    final isPortuguese =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
              'pt',
            );
    final goalsProvider = Provider.of<NutritionGoalsProvider>(
      context,
      listen: false,
    );
    final caloriesGoal = goalsProvider.caloriesGoal;
    final proteinGoal = goalsProvider.proteinGoal.toDouble();
    final carbsGoal = goalsProvider.carbsGoal.toDouble();
    final fatGoal = goalsProvider.fatGoal.toDouble();
    final weightKg = goalsProvider.weight > 0 ? goalsProvider.weight : 0.0;
    final proteinPerKg = weightKg > 0 ? proteinGoal / weightKg : 0.0;

    if (_containsAnyTerm(normalized, const ['proteina', 'protein'])) {
      final range = _recommendedProteinRange(goalsProvider.fitnessGoal);
      final goalLabel = _fitnessGoalAdviceLabel(
        goalsProvider.fitnessGoal,
        isPortuguese: isPortuguese,
      );
      final formattedProtein = _formatOneDecimal(proteinGoal);
      final formattedPerKg =
          proteinPerKg > 0 ? '${_formatOneDecimal(proteinPerKg)}g/kg' : '';
      final currentProtein = formattedPerKg.isEmpty
          ? '${formattedProtein}g'
          : '${formattedProtein}g ($formattedPerKg)';
      final formattedMin = _formatOneDecimal(range[0]);
      final formattedMax = _formatOneDecimal(range[1]);

      if (isPortuguese) {
        if (proteinPerKg > 0 && proteinPerKg < range[0] - 0.05) {
          return 'Pode ser interessante subir um pouco. Sua meta atual está em '
              '$currentProtein, e para $goalLabel uma faixa simples costuma '
              'ficar perto de $formattedMin a $formattedMax g/kg. '
              'Para manter $caloriesGoal kcal, eu ajustaria carboidratos ou '
              'gorduras junto. Se quiser aplicar, diga algo como "coloque '
              '${_formatOneDecimal((range[0] * weightKg).roundToDouble())}g de proteína".';
        }

        final qualifier = proteinPerKg > range[1] + 0.05
            ? 'já está acima da faixa que eu usaria como padrão'
            : 'já está dentro de uma faixa boa';
        return 'Não precisa subir por padrão. Sua meta atual está em '
            '$currentProtein, o que $qualifier para $goalLabel. '
            'Mais proteína só faz sentido se você sentir mais saciedade ou '
            'preferir comer assim; mantendo $caloriesGoal kcal, eu teria que '
            'tirar um pouco de carboidratos ou gorduras. Se quiser testar, '
            'me diga a nova meta, por exemplo "coloque 185g de proteína".';
      }

      if (proteinPerKg > 0 && proteinPerKg < range[0] - 0.05) {
        return 'A small increase may make sense. Your current target is '
            '$currentProtein, and for $goalLabel a simple range is usually '
            '$formattedMin to $formattedMax g/kg. To keep $caloriesGoal kcal, '
            'I would adjust carbs or fat too. If you want to apply it, say '
            'something like "set protein to '
            '${_formatOneDecimal((range[0] * weightKg).roundToDouble())}g".';
      }

      final qualifier = proteinPerKg > range[1] + 0.05
          ? 'already above the range I would use by default'
          : 'already in a good range';
      return 'You do not need to raise it by default. Your current target is '
          '$currentProtein, which is $qualifier for $goalLabel. More protein '
          'only makes sense if it helps your satiety or preference; keeping '
          '$caloriesGoal kcal means I would need to take some calories from '
          'carbs or fat. If you want to test it, tell me the new target, for '
          'example "set protein to 185g".';
    }

    if (isPortuguese) {
      return 'Esses macros podem funcionar. Hoje suas metas estão em '
          '$caloriesGoal kcal, ${_formatOneDecimal(proteinGoal)}g de proteína, '
          '${_formatOneDecimal(carbsGoal)}g de carboidratos e '
          '${_formatOneDecimal(fatGoal)}g de gorduras. Se quiser mudar algum '
          'valor, me diga o alvo exato.';
    }

    return 'Those macros can work. Your current targets are $caloriesGoal kcal, '
        '${_formatOneDecimal(proteinGoal)}g protein, '
        '${_formatOneDecimal(carbsGoal)}g carbs, and '
        '${_formatOneDecimal(fatGoal)}g fat. If you want to change a value, '
        'tell me the exact target.';
  }

  static List<double> _recommendedProteinRange(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return const [1.8, 2.2];
      case FitnessGoal.loseWeightSlowly:
        return const [1.7, 2.1];
      case FitnessGoal.gainWeight:
      case FitnessGoal.gainWeightSlowly:
        return const [1.6, 2.0];
      case FitnessGoal.maintainWeight:
        return const [1.4, 1.8];
    }
  }

  static String _fitnessGoalAdviceLabel(
    FitnessGoal goal, {
    required bool isPortuguese,
  }) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return isPortuguese ? 'perder peso' : 'weight loss';
      case FitnessGoal.loseWeightSlowly:
        return isPortuguese ? 'perder peso devagar' : 'slow weight loss';
      case FitnessGoal.gainWeight:
        return isPortuguese ? 'ganhar peso' : 'weight gain';
      case FitnessGoal.gainWeightSlowly:
        return isPortuguese ? 'ganhar massa aos poucos' : 'lean mass gain';
      case FitnessGoal.maintainWeight:
        return isPortuguese ? 'manutenção' : 'maintenance';
    }
  }

  static String buildDietPersonalizationQuestion(BuildContext context) {
    return AppLocalizations.of(context).translate(
      'chat_diet_personalization_question',
    );
  }

  static bool shouldAskDietPersonalizationQuestion(
    AppAgentCommand command,
    String originalUserMessage,
  ) {
    return command.name == updateDietGenerationPreferences &&
        command.arguments.isEmpty &&
        isDietGenerationRequest(originalUserMessage) &&
        !isDietDefaultApproval(originalUserMessage);
  }

  static bool shouldAskDietPersonalizationBeforeGeneration(
    AppAgentCommand command,
    String originalUserMessage,
    BuildContext context,
  ) {
    if (command.name != generateNewDietPlan ||
        !isDietGenerationRequest(originalUserMessage) ||
        isDietDefaultApproval(originalUserMessage)) {
      return false;
    }

    if (buildDietPreferenceUpdateFromUserMessage(
          originalUserMessage,
          rawJson: command.rawJson,
        ) !=
        null) {
      return false;
    }

    final dietProvider = Provider.of<DietPlanProvider>(
      context,
      listen: false,
    );
    return !dietProvider.hasReviewedDietGenerationPreferences &&
        !dietProvider.hasCompletedDietPersonalization;
  }

  static AppAgentCommand normalizeDietPreferenceApprovalCommand(
    AppAgentCommand command,
    String originalUserMessage,
  ) {
    if (command.name != updateDietGenerationPreferences ||
        command.arguments.isNotEmpty ||
        !isDietDefaultApproval(originalUserMessage)) {
      return command;
    }

    return AppAgentCommand(
      name: command.name,
      arguments: const {'skipPreferenceStep': true},
      rawJson: command.rawJson,
    );
  }

  static AppAgentCommand? buildDietPreferenceUpdateFromUserMessage(
    String userMessage, {
    required String rawJson,
  }) {
    if (!isDietGenerationRequest(userMessage)) {
      return null;
    }

    final normalized = _normalizeLooseText(userMessage);
    final arguments = <String, dynamic>{};

    final mealCountMatch = RegExp(
      r'\b([2-8])\s*(refeicoes|refeicao|refeicoes|meals|meal)\b',
    ).firstMatch(normalized);
    if (mealCountMatch != null) {
      arguments['mealsPerDay'] = int.tryParse(mealCountMatch.group(1) ?? '');
    }

    final restrictions = <String>{};
    if (_containsAnyTerm(normalized, const ['vegano', 'vegana', 'vegan'])) {
      restrictions.add('vegano');
    } else if (_containsAnyTerm(normalized, const [
      'vegetariano',
      'vegetariana',
      'vegetarian',
    ])) {
      restrictions.add('vegetariano');
    }
    if (_containsAnyTerm(normalized, const [
      'sem lactose',
      'intolerancia lactose',
      'intolerante lactose',
      'intolerante a lactose',
      'derivados de leite',
      'laticinios',
      'lacteos',
      'nao posso lactose',
      'nao posso leite',
      'nao pode lactose',
      'nao pode leite',
      'sem leite',
      'sem derivados de leite',
      'sem laticinios',
      'sem lacteos',
      'lactose free',
      'dairy free',
    ])) {
      restrictions.add('sem lactose');
    }
    if (_containsAnyTerm(normalized, const [
      'sem gluten',
      'sem glutem',
      'intolerancia gluten',
      'intolerante gluten',
      'intolerante a gluten',
      'nao posso gluten',
      'nao posso glutem',
      'nao pode gluten',
      'nao pode glutem',
      'celiaco',
      'celiaca',
      'gluten free',
    ])) {
      restrictions.add('sem gluten');
    }
    if (restrictions.isNotEmpty) {
      arguments['foodRestrictions'] = restrictions.toList();
    }

    final favoriteFoods = <String>{};
    if (_containsAnyTerm(normalized, const [
      'prefiro',
      'preferencia',
      'preferencias',
      'gosto de',
      'inclua',
      'use',
    ])) {
      void addFavoriteIfMentioned(String food, List<String> terms) {
        if (_containsAnyTerm(normalized, terms)) {
          favoriteFoods.add(food);
        }
      }

      addFavoriteIfMentioned('frango', const ['frango']);
      addFavoriteIfMentioned('peixe', const ['peixe', 'tilapia', 'salmao']);
      addFavoriteIfMentioned('arroz', const ['arroz']);
      addFavoriteIfMentioned('batata', const ['batata', 'batata doce']);
      addFavoriteIfMentioned('frutas', const ['fruta', 'frutas']);
      addFavoriteIfMentioned('legumes', const ['legume', 'legumes']);
      addFavoriteIfMentioned('verduras', const ['verdura', 'verduras']);
      addFavoriteIfMentioned('carne', const ['carne', 'patinho']);
      addFavoriteIfMentioned('aveia sem gluten', const [
        'aveia sem gluten',
        'aveia gluten free',
      ]);
    }
    if (favoriteFoods.isNotEmpty) {
      arguments['favoriteFoods'] = favoriteFoods.toList();
    }

    final avoidedFoods = <String>{};
    final hasFoodAversion = _containsAnyTerm(normalized, const [
      'faz mal',
      'fazem mal',
      'cai mal',
      'me cai mal',
      'me sinto mal',
      'passo mal',
      'enjoo',
      'enjoa',
      'enjoado',
      'me da enjoo',
      'me da nausea',
      'nausea',
      'pesa',
      'pesado',
      'pesada',
      'nao gosto',
      'nao posso',
      'nao pode',
      'evitar',
      'evite',
      'alergia',
      'alergico',
      'alergica',
    ]);

    void addAvoidedIfMentioned(String food, List<String> terms) {
      if (hasFoodAversion && _containsAnyTerm(normalized, terms)) {
        avoidedFoods.add(food);
      }
    }

    addAvoidedIfMentioned('ovo', const ['ovo', 'ovos']);
    addAvoidedIfMentioned('feijao', const ['feijao', 'feijoes']);
    addAvoidedIfMentioned('leite', const ['leite']);
    addAvoidedIfMentioned('queijo', const ['queijo', 'cottage', 'ricota']);
    addAvoidedIfMentioned('iogurte', const ['iogurte']);
    addAvoidedIfMentioned('laticinios', const [
      'laticinio',
      'laticinios',
      'lacteo',
      'lacteos',
      'derivados de leite',
    ]);
    addAvoidedIfMentioned('trigo', const ['trigo']);
    addAvoidedIfMentioned('pao', const ['pao', 'paes']);
    addAvoidedIfMentioned('massa com gluten', const [
      'macarrao',
      'massa',
      'pasta',
    ]);
    addAvoidedIfMentioned('carne vermelha', const [
      'carne vermelha',
      'carne bovina',
      'bife',
      'boi',
    ]);

    if (restrictions.contains('sem lactose')) {
      avoidedFoods.addAll(const [
        'leite',
        'queijo',
        'iogurte',
        'cottage',
        'ricota',
        'laticinios',
      ]);
    }
    if (restrictions.contains('sem gluten')) {
      avoidedFoods.addAll(const [
        'trigo',
        'pao',
        'macarrao comum',
        'farinha de trigo',
        'aveia comum',
      ]);
    }
    if (avoidedFoods.isNotEmpty) {
      arguments['avoidedFoods'] = avoidedFoods.toList();
    }

    final routineConsiderations = <String>{};
    if (_containsAnyTerm(normalized, const [
      'renal',
      'rim',
      'rins',
      'kidney',
    ])) {
      routineConsiderations.add('problema renal informado pelo usuario');
    }
    if (_containsAnyTerm(normalized, const [
      'diabetes',
      'diabetico',
      'diabetica',
      'diabetic',
    ])) {
      routineConsiderations.add('diabetes informado pelo usuario');
    }
    if (_containsAnyTerm(normalized, const [
      'hipertensao',
      'pressao alta',
      'hypertension',
      'high blood pressure',
    ])) {
      routineConsiderations.add('hipertensao informada pelo usuario');
    }
    if (_containsAnyTerm(normalized, const [
      'colesterol alto',
      'hipercolesterolemia',
      'high cholesterol',
    ])) {
      routineConsiderations.add('colesterol alto informado pelo usuario');
    }
    if (_containsAnyTerm(normalized, const [
      'gravida',
      'gestante',
      'pregnant',
    ])) {
      routineConsiderations.add('gestacao informada pelo usuario');
    }
    if (routineConsiderations.isNotEmpty) {
      arguments['routineConsiderations'] = routineConsiderations.toList();
    }

    arguments.removeWhere((_, value) => value == null);
    if (arguments.isEmpty) {
      return null;
    }

    return AppAgentCommand(
      name: updateDietGenerationPreferences,
      arguments: arguments,
      rawJson: rawJson,
    );
  }

  static List<String> _extractDietRestrictionList(
    Map<String, dynamic> normalized,
  ) {
    final restrictions = <String>{};
    final explicitRestrictions = AppAgentService._readFirstValue(
      normalized,
      const [
        'foodRestrictions',
        'restrictions',
        'dietaryRestrictions',
        'allergies',
        'intolerances',
        'foodIntolerances',
      ],
    );
    for (final item
        in AppAgentService._extractStringList(explicitRestrictions)) {
      final canonical = AppAgentService._canonicalDietRestriction(item);
      if (canonical != null) {
        restrictions.add(canonical);
      }
    }

    final dietStyle = AppAgentService._readFirstValue(
      normalized,
      const ['dietType', 'dietStyle', 'eatingStyle'],
    );
    for (final item in AppAgentService._extractStringList(dietStyle)) {
      final canonical = AppAgentService._canonicalDietRestriction(item);
      if (canonical != null) {
        restrictions.add(canonical);
      }
    }

    return restrictions.toList();
  }

  static String? _canonicalDietRestriction(dynamic value) {
    final normalized = _normalizeLooseText(value);
    if (normalized.isEmpty ||
        _containsAnyTerm(normalized, const [
          'custom',
          'personalizado',
          'padrao',
          'normal',
          'standard',
          'none',
          'nenhuma',
          'nenhum',
        ])) {
      return null;
    }
    if (_containsAnyTerm(normalized, const ['vegan', 'vegano', 'vegana'])) {
      return 'vegano';
    }
    if (_containsAnyTerm(normalized, const [
      'vegetarian',
      'vegetariano',
      'vegetariana',
    ])) {
      return 'vegetariano';
    }
    if (_containsAnyTerm(normalized, const [
      'lactose',
      'leite',
      'dairy free',
      'sem laticinios',
      'laticinio',
      'laticinios',
      'lacteo',
      'lacteos',
      'derivados de leite',
    ])) {
      return 'sem lactose';
    }
    if (_containsAnyTerm(normalized, const [
      'gluten',
      'glutem',
      'celiaco',
      'celiaca',
      'celiac',
    ])) {
      return 'sem gluten';
    }
    return value.toString().trim();
  }

  static int? _readRequestedMealsPerDay(Map<String, dynamic> arguments) {
    final mealsPerDay = _tryParseInt(
      _readFirstValue(arguments, const [
        'mealsPerDay',
        'meals_per_day',
        'mealCount',
        'meal_count',
        'meals',
        'refeicoes',
        'refeições',
      ]),
    );
    if (mealsPerDay == null || mealsPerDay <= 0) {
      return null;
    }
    return mealsPerDay.clamp(1, 8).toInt();
  }

  static bool isDietGenerationRequest(String userMessage) {
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty) {
      return false;
    }

    final hasDietTerm = _containsAnyTerm(normalized, const [
      'dieta',
      'diet',
      'cardapio',
      'plano alimentar',
      'meal plan',
    ]);
    if (!hasDietTerm) {
      return false;
    }

    return _containsAnyTerm(normalized, const [
      'gera',
      'gerar',
      'gere',
      'cria',
      'criar',
      'crie',
      'monta',
      'montar',
      'monte',
      'faz',
      'fazer',
      'faca',
      'generate',
      'create',
      'build',
    ]);
  }

  static bool shouldTreatAsMacroRecalculationApproval(
    String userMessage,
    String conversationContext,
  ) {
    final normalizedMessage = _normalizeLooseText(userMessage);
    if (normalizedMessage.isEmpty || isDietGenerationRequest(userMessage)) {
      return false;
    }

    if (_containsAnyTerm(normalizedMessage, const [
      'dieta',
      'cardapio',
      'plano alimentar',
      'refeicao',
      'refeicoes',
      'meal plan',
    ])) {
      return false;
    }

    final isApprovalOrRecalcRequest =
        _isMacroRecalculationApproval(normalizedMessage) ||
            _containsAnyTerm(normalizedMessage, const [
              'recalcule',
              'recalcula',
              'recalcular',
              'recalculo',
              'ajuste automatico',
              'ajustar automatico',
              'calcule automatico',
              'calcular automatico',
            ]);
    if (!isApprovalOrRecalcRequest) {
      return false;
    }

    final normalizedContext = _normalizeLooseText(conversationContext);
    if (normalizedContext.isEmpty) {
      return _containsAnyTerm(normalizedMessage, const [
        'macro',
        'macros',
        'caloria',
        'calorias',
        'meta',
        'metas',
        'objetivo',
        'objetivos',
      ]);
    }

    final hasMacroTopic = _containsAnyTerm(normalizedContext, const [
      'macro',
      'macros',
      'caloria',
      'calorias',
      'proteina',
      'carboidrato',
      'gordura',
      'meta',
      'metas',
      'objetivo',
      'objetivos',
      'alvo',
      'alvos',
      'target',
      'targets',
    ]);
    final hasRecalculationIntent = _containsAnyTerm(normalizedContext, const [
      'recalcule',
      'recalcula',
      'recalcular',
      'recalculo',
      'automatico',
      'automaticamente',
      'alterar esses valores',
      'mudar esses valores',
      'ganhar massa',
      'perder peso',
      'superavit',
      'deficit',
      'manutencao',
      'bulking',
      'cutting',
      'aplicar a meta',
      'aplicar esses valores',
    ]);

    return hasMacroTopic && hasRecalculationIntent;
  }

  static bool shouldRedirectDietCommandToMacroRecalculation(
    AppAgentCommand command,
    String originalUserMessage,
    String conversationContext,
  ) {
    if (command.name != generateNewDietPlan &&
        command.name != getDietGenerationPreferencesStatus &&
        command.name != updateDietGenerationPreferences) {
      return false;
    }

    return shouldTreatAsMacroRecalculationApproval(
      originalUserMessage,
      conversationContext,
    );
  }

  static AppAgentCommand? buildMacroRecalculationCommandFromContext(
    String originalUserMessage,
    String conversationContext, {
    required String rawJson,
  }) {
    if (!shouldTreatAsMacroRecalculationApproval(
      originalUserMessage,
      conversationContext,
    )) {
      return null;
    }

    final fitnessGoal = _parseFitnessGoal(
      '$originalUserMessage\n$conversationContext',
    );
    return AppAgentCommand(
      name: recalculateNutritionGoals,
      arguments: <String, dynamic>{
        if (fitnessGoal != null) 'fitnessGoal': fitnessGoal.name,
      },
      rawJson: rawJson,
    );
  }

  static AppAgentCommand? buildMacroTargetsCommandFromContextualMessage(
    String userMessage,
    String conversationContext, {
    required String rawJson,
  }) {
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty ||
        conversationContext.trim().isEmpty ||
        isDietGenerationRequest(userMessage) ||
        _isStandaloneFoodLoggingText(normalized)) {
      return null;
    }

    final directCommand = buildMacroTargetsCommandFromUserMessage(
      userMessage,
      rawJson: rawJson,
    );
    if (directCommand != null) {
      return directCommand;
    }

    final value = _extractShortContextualMacroValue(normalized);
    if (value == null) {
      return null;
    }

    final macro = _inferPendingMacroTopicFromContext(conversationContext);
    if (macro == null) {
      return null;
    }

    final hasDailyTotalCue = RegExp(
      r'\b(total|totais|por dia|no dia|ao dia|diario|diaria|diarios|diarias|daily)\b',
    ).hasMatch(normalized);
    final hasPerKgCue = RegExp(
      r'\b(g\s*/?\s*kg|por\s*(kg|quilo|kilo)|p\s*/?\s*(kg|quilo|kilo)|per\s*kg)\b',
    ).hasMatch(normalized);
    final perKgCeiling = switch (macro) {
      _MacroTopic.protein => 30,
      _MacroTopic.carbs => 80,
      _MacroTopic.fat => 20,
    };
    final shouldUsePerKg =
        hasPerKgCue || (!hasDailyTotalCue && value < perKgCeiling);

    if (shouldUsePerKg) {
      return AppAgentCommand(
        name: updateMacroTargetsGramsPerKg,
        arguments: <String, dynamic>{
          macro.perKgArgument: value,
        },
        rawJson: rawJson,
      );
    }

    return AppAgentCommand(
      name: updateMacroTargetsGrams,
      arguments: <String, dynamic>{
        macro.gramsArgument: value,
      },
      rawJson: rawJson,
    );
  }

  static AppAgentCommand? buildDailyNutritionStatusCommandFromUserMessage(
    String userMessage, {
    required String rawJson,
  }) {
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty ||
        (!_looksLikeDailyStatusRequest(normalized) &&
            !_looksLikeDailyEvaluationRequest(normalized))) {
      return null;
    }

    return AppAgentCommand(
      name: getDailyNutritionStatus,
      arguments: _buildDailyStatusArgsFromUserMessage(normalized),
      rawJson: rawJson,
    );
  }

  static AppAgentCommand? buildMacroTargetsStatusCommandFromUserMessage(
    String userMessage, {
    required String rawJson,
    String conversationContext = '',
  }) {
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty ||
        _looksLikeTotalVsRemainingQuestion(normalized) ||
        !_looksLikeMacroTargetsStatusRequest(
          normalized,
          conversationContext: conversationContext,
        )) {
      return null;
    }

    return AppAgentCommand(
      name: getMacroTargetsStatus,
      arguments: const <String, dynamic>{},
      rawJson: rawJson,
    );
  }

  static AppAgentCommand? buildMacroTargetsCommandFromUserMessage(
    String userMessage, {
    required String rawJson,
  }) {
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty || isDietGenerationRequest(userMessage)) {
      return null;
    }

    final caloriesGoal = _extractExplicitCaloriesTarget(normalized);
    final hasMutationIntent = _containsAnyTerm(normalized, const [
      'ajuste',
      'ajustar',
      'mude',
      'mudar',
      'altere',
      'alterar',
      'atualize',
      'atualizar',
      'aumente',
      'aumentar',
      'suba',
      'sube',
      'subir',
      'reduza',
      'reduzir',
      'baixe',
      'baixar',
      'defina',
      'definir',
      'coloque',
      'colocar',
      'bote',
      'botar',
      'meta',
      'metas',
      'alvo',
      'objetivo',
      'proteina',
      'protein',
      'carbo',
      'carboidrato',
      'carbohidrato',
      'gordura',
      'grasa',
      'fat',
      'quero comer',
      'quero consumir',
      'dieta para',
      'set',
      'change',
      'update',
      'target',
    ]);
    if (!hasMutationIntent) {
      return null;
    }

    final looksLikeFoodLog = _containsAnyTerm(normalized, const [
      'comi',
      'consumi',
      'ingeri',
      'registra',
      'registrar',
      'registre',
      'adicione',
      'adicionar',
      'lancar',
      'lancei',
      'logged',
      'ate',
      'consumed',
    ]);
    if (looksLikeFoodLog) {
      return null;
    }

    final perKgTargets = _extractMacroPerKgTargets(normalized);
    if (perKgTargets.isNotEmpty) {
      return AppAgentCommand(
        name: updateMacroTargetsGramsPerKg,
        arguments: <String, dynamic>{
          if (caloriesGoal != null) 'caloriesGoal': caloriesGoal,
          ...perKgTargets,
        },
        rawJson: rawJson,
      );
    }

    final gramTargets = _extractMacroGramTargets(normalized);
    if (gramTargets.isNotEmpty) {
      return AppAgentCommand(
        name: updateMacroTargetsGrams,
        arguments: <String, dynamic>{
          if (caloriesGoal != null) 'caloriesGoal': caloriesGoal,
          ...gramTargets,
        },
        rawJson: rawJson,
      );
    }

    if (caloriesGoal == null) {
      return null;
    }

    return AppAgentCommand(
      name: updateMacroTargetsGrams,
      arguments: <String, dynamic>{
        'caloriesGoal': caloriesGoal,
      },
      rawJson: rawJson,
    );
  }

  static Map<String, dynamic> _buildDailyStatusArgsFromUserMessage(
    String normalizedMessage,
  ) {
    if (RegExp(r'\b(anteontem|antes de ontem|day before yesterday)\b')
        .hasMatch(normalizedMessage)) {
      return const {'dateOffsetDays': -2};
    }
    if (RegExp(r'\b(hoje|hj|today|hoy|aujourd hui|aujourdhui|heute|oggi)\b')
        .hasMatch(normalizedMessage)) {
      return const {'dateOffsetDays': 0};
    }
    if (RegExp(r'\b(ontem|yesterday|ayer|hier|gestern|ieri)\b')
        .hasMatch(normalizedMessage)) {
      return const {'dateOffsetDays': -1};
    }

    final resolvedDate = _extractDailyStatusDate(normalizedMessage);
    if (resolvedDate != null) {
      return {'date': _formatIsoDate(resolvedDate)};
    }

    return const <String, dynamic>{};
  }

  static DateTime? _extractDailyStatusDate(String normalizedMessage) {
    final isoMatch = RegExp(r'\b(20\d{2})\s+(\d{1,2})\s+(\d{1,2})\b')
        .firstMatch(normalizedMessage);
    if (isoMatch != null) {
      return _validDate(
        int.tryParse(isoMatch.group(1) ?? ''),
        int.tryParse(isoMatch.group(2) ?? ''),
        int.tryParse(isoMatch.group(3) ?? ''),
      );
    }

    final dayMonthYearMatch = RegExp(
      r'\b(\d{1,2})\s+(?:de\s+)?(\d{1,2}|janeiro|jan|fevereiro|fev|marco|mar|abril|abr|maio|mai|junho|jun|julho|jul|agosto|ago|setembro|set|outubro|out|novembro|nov|dezembro|dez)\s+(?:de\s+)?(20\d{2})\b',
    ).firstMatch(normalizedMessage);
    if (dayMonthYearMatch != null) {
      return _validDate(
        int.tryParse(dayMonthYearMatch.group(3) ?? ''),
        _parseMonthToken(dayMonthYearMatch.group(2)),
        int.tryParse(dayMonthYearMatch.group(1) ?? ''),
      );
    }

    final dayMonthMatch = RegExp(
      r'\b(?:dia\s+)?(\d{1,2})\s+(?:de\s+)?(\d{1,2}|janeiro|jan|fevereiro|fev|marco|mar|abril|abr|maio|mai|junho|jun|julho|jul|agosto|ago|setembro|set|outubro|out|novembro|nov|dezembro|dez)\b',
    ).firstMatch(normalizedMessage);
    if (dayMonthMatch != null) {
      return _resolvePartialDate(
        day: int.tryParse(dayMonthMatch.group(1) ?? ''),
        month: _parseMonthToken(dayMonthMatch.group(2)),
      );
    }

    final dayOnlyMatch =
        RegExp(r'\bdia\s+(\d{1,2})\b').firstMatch(normalizedMessage);
    if (dayOnlyMatch != null) {
      return _resolvePartialDate(
        day: int.tryParse(dayOnlyMatch.group(1) ?? ''),
      );
    }

    return null;
  }

  static int? _parseMonthToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    final numeric = int.tryParse(token);
    if (numeric != null) {
      return numeric;
    }
    const months = {
      'janeiro': 1,
      'jan': 1,
      'fevereiro': 2,
      'fev': 2,
      'marco': 3,
      'mar': 3,
      'abril': 4,
      'abr': 4,
      'maio': 5,
      'mai': 5,
      'junho': 6,
      'jun': 6,
      'julho': 7,
      'jul': 7,
      'agosto': 8,
      'ago': 8,
      'setembro': 9,
      'set': 9,
      'outubro': 10,
      'out': 10,
      'novembro': 11,
      'nov': 11,
      'dezembro': 12,
      'dez': 12,
    };
    return months[token];
  }

  static DateTime? _resolvePartialDate({
    required int? day,
    int? month,
  }) {
    if (day == null) {
      return null;
    }
    final today = _dateOnly(DateTime.now());
    var year = today.year;
    var resolvedMonth = month ?? today.month;

    var date = _validDate(year, resolvedMonth, day);
    if (date == null) {
      return null;
    }
    if (!date.isAfter(today)) {
      return date;
    }

    if (month == null) {
      resolvedMonth -= 1;
      if (resolvedMonth < 1) {
        resolvedMonth = 12;
        year -= 1;
      }
      return _validDate(year, resolvedMonth, day);
    }

    return _validDate(year - 1, resolvedMonth, day);
  }

  static DateTime? _validDate(int? year, int? month, int? day) {
    if (year == null ||
        month == null ||
        day == null ||
        year < 2000 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return _dateOnly(date);
  }

  static String _formatIsoDate(DateTime date) {
    final normalized = _dateOnly(date);
    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }

  static double? _extractShortContextualMacroValue(String normalizedMessage) {
    final match = RegExp(
      r'^\s*(\d+(?:[,.]\d+)?)\s*(?:g|gramas?|grams?|g\s*/?\s*kg|gramas?\s*(?:por|p)?\s*(?:kg|quilo|kilo)|por\s*(?:kg|quilo|kilo)|p\s*/?\s*(?:kg|quilo|kilo)|per\s*kg)?\s*(?:por dia|no dia|ao dia|diario|diaria|daily)?\s*$',
    ).firstMatch(normalizedMessage);
    if (match == null) {
      return null;
    }
    return _tryParseDouble(match.group(1));
  }

  static _MacroTopic? _inferPendingMacroTopicFromContext(
    String conversationContext,
  ) {
    final normalizedContext = _normalizeLooseText(conversationContext);
    if (normalizedContext.isEmpty) {
      return null;
    }

    final blocks = RegExp(
      r'^(?:Humano|IA):\s[\s\S]*?(?=^(?:Humano|IA):\s|\z)',
      multiLine: true,
    ).allMatches(conversationContext).map((match) => match.group(0)!).toList();

    final candidateBlocks = blocks.isEmpty
        ? <String>[normalizedContext]
        : blocks.reversed.take(6).map(_normalizeLooseText).toList();

    for (final block in candidateBlocks) {
      final asksForMacroValue = RegExp(
        r'\b(qual|quanto|quantos|valor|gostaria|quer|prefere|specific|specifico|grams?|gramas?|g/kg)\b',
      ).hasMatch(block);
      if (!asksForMacroValue) {
        continue;
      }
      final topic = _detectMacroTopic(block);
      if (topic != null) {
        return topic;
      }
    }

    return _detectLastMacroTopic(normalizedContext);
  }

  static _MacroTopic? _detectMacroTopic(String normalizedText) {
    if (RegExp(r'\b(proteina|protein)\b').hasMatch(normalizedText)) {
      return _MacroTopic.protein;
    }
    if (RegExp(r'\b(carbo|carboidratos?|carbohidratos?|carbs?)\b')
        .hasMatch(normalizedText)) {
      return _MacroTopic.carbs;
    }
    if (RegExp(r'\b(gordura|gorduras|grasa|grasas|fat|fats)\b')
        .hasMatch(normalizedText)) {
      return _MacroTopic.fat;
    }
    return null;
  }

  static _MacroTopic? _detectLastMacroTopic(String normalizedText) {
    final matches = <({int start, _MacroTopic topic})>[];
    for (final match
        in RegExp(r'\b(proteina|protein)\b').allMatches(normalizedText)) {
      matches.add((start: match.start, topic: _MacroTopic.protein));
    }
    for (final match
        in RegExp(r'\b(carbo|carboidratos?|carbohidratos?|carbs?)\b')
            .allMatches(normalizedText)) {
      matches.add((start: match.start, topic: _MacroTopic.carbs));
    }
    for (final match in RegExp(r'\b(gordura|gorduras|grasa|grasas|fat|fats)\b')
        .allMatches(normalizedText)) {
      matches.add((start: match.start, topic: _MacroTopic.fat));
    }
    if (matches.isEmpty) {
      return null;
    }
    matches.sort((a, b) => b.start.compareTo(a.start));
    return matches.first.topic;
  }

  static int? _extractExplicitCaloriesTarget(String normalizedMessage) {
    const calorieTerm = r'(?:kcal|cal(?:oria|orias|oia|oias|orie|ories)s?)';
    final patterns = [
      RegExp(r'\b(\d{3,5})\s*' + calorieTerm + r'\b'),
      RegExp(calorieTerm + r'\s*(?:de|para|pra|a|em)?\s*(\d{3,5})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalizedMessage);
      if (match == null) {
        continue;
      }
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value >= 800 && value <= 10000) {
        return value;
      }
    }

    return null;
  }

  static Map<String, dynamic> _extractMacroPerKgTargets(
    String normalizedMessage,
  ) {
    final hasDailyTotalCue = RegExp(
      r'\b(total|totais|por dia|no dia|ao dia|diario|diaria|diarios|diarias|daily)\b',
    ).hasMatch(normalizedMessage);
    double? lowGramAsPerKg(double? value, double maxDailyTotal) {
      if (value == null || value <= 0 || value >= maxDailyTotal) {
        return null;
      }
      return hasDailyTotalCue ? null : value;
    }

    final proteinPerKg = _extractMacroNumber(
          normalizedMessage,
          RegExp(
            r'(\d+(?:[,.]\d+)?)\s*(?:g\s*/?\s*kg|gramas?\s*(?:por|p)?\s*(?:kg|quilo|kilo))\s+(?:de|of)\s*(?:proteina|protein)\b',
          ),
        ) ??
        _extractMacroNumberAfterTerm(
          normalizedMessage,
          RegExp(
            r'\b(?:proteina|protein)\b\s*(?:para|em|a|to|at|en|=|:)?\s*(\d+(?:[,.]\d+)?)\s*(?:g\s*/?\s*kg|gramas?\s*(?:por|p)?\s*(?:kg|quilo|kilo))',
          ),
        ) ??
        lowGramAsPerKg(
          _extractMacroNumber(
            normalizedMessage,
            RegExp(
              r'(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\s*(?:de\s*)?(?:proteina|protein)\b',
            ),
          ),
          30,
        ) ??
        lowGramAsPerKg(
          _extractMacroNumberAfterTerm(
            normalizedMessage,
            RegExp(
              r'\b(?:proteina|protein)\b\s*(?:para|em|a|to|at|en|=|:)?\s*(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\b',
            ),
          ),
          30,
        );
    final carbsPerKg = _extractMacroNumber(
          normalizedMessage,
          RegExp(
            r'(\d+(?:[,.]\d+)?)\s*(?:g\s*/?\s*kg|gramas?\s*(?:por|p)?\s*(?:kg|quilo|kilo))\s+(?:de|of)\s*(?:carbo|carboidratos?|carbohidratos?|carbs?)\b',
          ),
        ) ??
        _extractMacroNumberAfterTerm(
          normalizedMessage,
          RegExp(
            r'\b(?:carbo|carboidratos?|carbohidratos?|carbs?)\b\s*(?:para|em|a|to|at|en|=|:)?\s*(\d+(?:[,.]\d+)?)\s*(?:g\s*/?\s*kg|gramas?\s*(?:por|p)?\s*(?:kg|quilo|kilo))',
          ),
        ) ??
        lowGramAsPerKg(
          _extractMacroNumber(
            normalizedMessage,
            RegExp(
              r'(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\s*(?:de\s*)?(?:carbo|carboidratos?|carbohidratos?|carbs?)\b',
            ),
          ),
          80,
        ) ??
        lowGramAsPerKg(
          _extractMacroNumberAfterTerm(
            normalizedMessage,
            RegExp(
              r'\b(?:carbo|carboidratos?|carbohidratos?|carbs?)\b\s*(?:para|em|a|to|at|en|=|:)?\s*(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\b',
            ),
          ),
          80,
        );
    final fatPerKg = _extractMacroNumber(
          normalizedMessage,
          RegExp(
            r'(\d+(?:[,.]\d+)?)\s*(?:g\s*/?\s*kg|gramas?\s*(?:por|p)?\s*(?:kg|quilo|kilo))\s+(?:de|of)\s*(?:gordura|gorduras|grasa|grasas|fat|fats)\b',
          ),
        ) ??
        _extractMacroNumberAfterTerm(
          normalizedMessage,
          RegExp(
            r'\b(?:gordura|gorduras|grasa|grasas|fat|fats)\b\s*(?:para|em|a|to|at|en|=|:)?\s*(\d+(?:[,.]\d+)?)\s*(?:g\s*/?\s*kg|gramas?\s*(?:por|p)?\s*(?:kg|quilo|kilo))',
          ),
        ) ??
        lowGramAsPerKg(
          _extractMacroNumber(
            normalizedMessage,
            RegExp(
              r'(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\s*(?:de\s*)?(?:gordura|gorduras|grasa|grasas|fat|fats)\b',
            ),
          ),
          20,
        ) ??
        lowGramAsPerKg(
          _extractMacroNumberAfterTerm(
            normalizedMessage,
            RegExp(
              r'\b(?:gordura|gorduras|grasa|grasas|fat|fats)\b\s*(?:para|em|a|to|at|en|=|:)?\s*(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\b',
            ),
          ),
          20,
        );

    return <String, dynamic>{
      if (proteinPerKg != null) 'proteinPerKg': proteinPerKg,
      if (carbsPerKg != null) 'carbsPerKg': carbsPerKg,
      if (fatPerKg != null) 'fatPerKg': fatPerKg,
    };
  }

  static Map<String, dynamic> _extractMacroGramTargets(
    String normalizedMessage,
  ) {
    final proteinGrams = _extractMacroNumber(
      normalizedMessage,
      RegExp(
        r'(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\s*(?:de\s*)?(?:proteina|protein)\b',
      ),
    );
    final carbsGrams = _extractMacroNumber(
      normalizedMessage,
      RegExp(
        r'(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\s*(?:de\s*)?(?:carbo|carboidratos?|carbohidratos?|carbs?)\b',
      ),
    );
    final fatGrams = _extractMacroNumber(
      normalizedMessage,
      RegExp(
        r'(\d+(?:[,.]\d+)?)\s*(?:g|gramas?)\s*(?:de\s*)?(?:gordura|gorduras|grasa|grasas|fat|fats)\b',
      ),
    );

    return <String, dynamic>{
      if (proteinGrams != null) 'proteinGrams': proteinGrams,
      if (carbsGrams != null) 'carbsGrams': carbsGrams,
      if (fatGrams != null) 'fatGrams': fatGrams,
    };
  }

  static double? _extractMacroNumber(
    String normalizedMessage,
    RegExp pattern,
  ) {
    final match = pattern.firstMatch(normalizedMessage);
    if (match == null) {
      return null;
    }
    return _tryParseDouble(match.group(1));
  }

  static double? _extractMacroNumberAfterTerm(
    String normalizedMessage,
    RegExp pattern,
  ) {
    final match = pattern.firstMatch(normalizedMessage);
    if (match == null) {
      return null;
    }
    return _tryParseDouble(match.group(1));
  }

  static bool _isMacroRecalculationApproval(String normalizedMessage) {
    const shortApprovals = {
      'sim',
      'ok',
      'pode',
      'pode sim',
      'isso',
      'isso mesmo',
      'confirmo',
      'confirmar',
      'automatico',
      'automaticamente',
      'faca automatico',
      'faz automatico',
      'fazer automatico',
      'pode recalcular',
      'pode calcular',
      'pode ajustar',
      'sim recalcula',
      'sim recalcule',
      'sim automatico',
      'recalcule automatico',
      'recalcula automatico',
      'calcule automatico',
      'calcula automatico',
    };
    if (shortApprovals.contains(normalizedMessage)) {
      return true;
    }

    return _containsAnyTerm(normalizedMessage, const [
      'faca automaticamente',
      'faz automaticamente',
      'pode recalcular',
      'pode calcular automatico',
      'pode ajustar automatico',
      'recalcule automaticamente',
      'recalcula automaticamente',
      'calcule automaticamente',
      'calcula automaticamente',
      'do it automatically',
      'recalculate automatically',
    ]);
  }

  static bool isDietDefaultApproval(String userMessage) {
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty) {
      return false;
    }

    const shortApprovals = {
      'sim',
      'ok',
      'certo',
      'pode',
      'pode sim',
      'nao',
      'no',
      'nada',
      'nenhum',
      'nenhuma',
      'continue',
      'segue',
    };
    if (shortApprovals.contains(normalized)) {
      return true;
    }

    return _containsAnyTerm(normalized, const [
      'pode gerar',
      'pode seguir',
      'pode continuar',
      'pode montar',
      'pode fazer',
      'gera padrao',
      'gerar padrao',
      'dieta padrao',
      'plano padrao',
      'padrao',
      'default',
      'standard',
      'sem detalhes',
      'sem mais detalhes',
      'nao quero passar',
      'nao quero detalhes',
      'nao tenho detalhes',
      'sem restricao',
      'sem restricoes',
      'sem preferencia',
      'sem preferencias',
      'nada a adicionar',
      'nao tenho restricao',
      'nao tenho alergia',
      'tanto faz',
      'qualquer uma',
      'qualquer um',
    ]);
  }

  static String _removeAgentArtifacts(String rawContent) {
    var sanitized = AppAgentPendingAction.removeBlock(
      AppAgentUiHint.removeHintBlock(rawContent),
    );

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
    if (!isCreditExhaustedResponse(responseContent)) {
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

  static _PromptIntent _resolvePromptIntentFromCommandName(
    String commandName,
  ) {
    switch (commandName) {
      case getDailyNutritionStatus:
      case getWeeklyNutritionSummary:
      case getWeightStatus:
        return _PromptIntent.dailyStatus;
      case recalculateNutritionGoals:
      case getMacroTargetsStatus:
      case updateMacroTargetsPercentage:
      case updateMacroTargetsGrams:
      case updateMacroTargetsGramsPerKg:
        return _PromptIntent.macroGoals;
      case getDietGenerationPreferencesStatus:
      case updateDietGenerationPreferences:
      case generateNewDietPlan:
        return _PromptIntent.dietGeneration;
      case getGoalSetupStatus:
      case updateGoalSetupProfile:
      case updateGoalSetupPreferences:
        return _PromptIntent.profileSetup;
      default:
        return _PromptIntent.accountScoped;
    }
  }

  static _PromptIntent _resolvePromptIntentFromBasePrompt(String basePrompt) {
    final isFreeNutritionChatMode = basePrompt.contains(
      'Conversation mode: free nutrition chat.',
    );

    final pendingAction = AppAgentPendingAction.tryParse(basePrompt);
    if (pendingAction != null) {
      return _resolvePromptIntentFromCommandName(pendingAction.command.name);
    }

    if (basePrompt.contains('[APP_COMMAND_RESULTS_BEGIN]') ||
        basePrompt.contains('[APP_COMMAND_RESULT_BEGIN]')) {
      return _PromptIntent.commandResults;
    }

    if (basePrompt.contains(
      'Conversation mode: nutrition goal and macro target review',
    )) {
      return _PromptIntent.macroGoals;
    }

    final userText = _extractPromptUserRequest(basePrompt);
    final normalized = _normalizeRoutingText(userText);
    if (normalized.isEmpty || _isGreetingOnly(normalized)) {
      return _PromptIntent.simpleChat;
    }
    if (_looksLikeDailyStatusRequest(normalized)) {
      return _PromptIntent.dailyStatus;
    }
    if (_looksLikeMacroTargetsStatusRequest(normalized,
        conversationContext: basePrompt)) {
      return _PromptIntent.macroGoals;
    }
    if (_looksLikeDietGenerationRequest(normalized)) {
      return _PromptIntent.dietGeneration;
    }
    if (_looksLikeMacroGoalRequest(normalized)) {
      return _PromptIntent.macroGoals;
    }
    if (_looksLikeProfileSetupRequest(normalized)) {
      return _PromptIntent.profileSetup;
    }
    if (!isFreeNutritionChatMode && _isStandaloneFoodLoggingText(normalized)) {
      return _PromptIntent.foodLogging;
    }
    if (_looksLikeAccountScopedRequest(normalized)) {
      return _PromptIntent.accountScoped;
    }
    return _PromptIntent.simpleChat;
  }

  static _PromptIntent _resolvePromptIntentFromExecutionResults({
    required String originalUserMessage,
    required List<AppAgentExecutionResult> executionResults,
  }) {
    final userIntent = _resolvePromptIntentFromBasePrompt(
      'User request:\n$originalUserMessage',
    );
    if (userIntent != _PromptIntent.simpleChat &&
        userIntent != _PromptIntent.foodLogging) {
      return userIntent;
    }

    if (executionResults.isEmpty) {
      return _PromptIntent.commandResults;
    }
    return _resolvePromptIntentFromCommandName(
      executionResults.last.commandName,
    );
  }

  static String _promptIntentTag(_PromptIntent intent) {
    switch (intent) {
      case _PromptIntent.simpleChat:
        return 'simple_chat';
      case _PromptIntent.foodLogging:
        return 'food_logging';
      case _PromptIntent.dailyStatus:
        return 'daily_status';
      case _PromptIntent.macroGoals:
        return 'macro_goals';
      case _PromptIntent.dietGeneration:
        return 'diet_generation';
      case _PromptIntent.profileSetup:
        return 'profile_setup';
      case _PromptIntent.pendingAction:
        return 'pending_action';
      case _PromptIntent.commandResults:
        return 'command_results';
      case _PromptIntent.accountScoped:
        return 'account_scoped';
    }
  }

  static String _extractPromptUserRequest(String prompt) {
    final marker = RegExp(
      r'(User request|Mensagem do usuário|Pedido do usuário)\s*:\s*',
      caseSensitive: false,
    );
    final matches = marker.allMatches(prompt).toList();
    if (matches.isEmpty) {
      return prompt.trim();
    }
    return prompt.substring(matches.last.end).trim();
  }

  static String _normalizeRoutingText(String text) {
    var normalized = text.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _containsAnyRoutingTerm(
    String normalizedText,
    List<String> terms,
  ) {
    return terms.any((term) => normalizedText.contains(term));
  }

  static bool _isGreetingOnly(String normalizedText) {
    return RegExp(
      r'^(oi|ola|hello|hi|hey|hola|bonjour|salut|coucou|hallo|guten tag|guten morgen|guten abend|ciao|buongiorno|buonasera|bom dia|boa tarde|boa noite|buenos dias|buenas tardes|buenas noches)[\s!.?]*$',
    ).hasMatch(normalizedText);
  }

  static bool _looksLikeDailyStatusRequest(String normalizedText) {
    if (_looksLikeTotalVsRemainingQuestion(normalizedText) ||
        _looksLikeMacroTargetsStatusRequest(normalizedText)) {
      return false;
    }
    if (_looksLikeFoodListRequest(normalizedText)) {
      return true;
    }

    final explicitDateContext = _extractDailyStatusDate(normalizedText) != null;
    final asksAmount = RegExp(
      r'\b(quanto|quantas|qto|qtas|cuanto|cuantas|combien|wie viel|wie viele|wieviel|quante|posso comer|ainda posso|how much|how many|still eat)\b',
    ).hasMatch(normalizedText);
    final dayContext = RegExp(
          r'\b(hoje|hj|ontem|anteontem|today|yesterday|hoy|ayer|aujourd hui|aujourdhui|hier|heute|gestern|oggi|ieri|agora|ainda|resta|restam|sobrou|sobram|falta|faltam|quedan|queda|reste|restait|ubrig|rimane|rimaste|remaining|left)\b',
        ).hasMatch(normalizedText) ||
        explicitDateContext;
    final nutritionContext = RegExp(
      r'\b(caloria|calorias|calorie|calories|kalorien|kcal|macro|macros|proteina|proteine|protein|carbo|carboidrato|carbohidrato|gordura|grasa|graisse|fett|grassi|comer|eat|essen|mangiare)\b',
    ).hasMatch(normalizedText);
    final targetEditContext = RegExp(
      r'\b(meta|metas|objetivo|objetivos|target|goal|ajustar|mudar|alterar|editar|definir|change|update)\b',
    ).hasMatch(normalizedText);
    final suggestionContext = RegExp(
      r'\b(sugestao|sugestoes|sugerir|sugere|sugira|recomenda|recomendar|indica|indicar|ideia|opcao|opcoes|suggest|recommend|idea|option)\b',
    ).hasMatch(normalizedText);
    final mealSuggestionContext = RegExp(
      r'\b(lanche|snack|refeicao|comida|alimento|comer|meal|food)\b',
    ).hasMatch(normalizedText);
    final remainingBudgetContext = RegExp(
          r'\b(posso comer|ainda posso|ja posso|que eu posso|que posso|resta|restam|sobrou|sobram|falta|faltam|remaining|left|available)\b',
        ).hasMatch(normalizedText) ||
        RegExp(
          r'\b(com|dentro)\s+(as|das|minhas|os|dos|meus)?\s*(calorias|kcal|macros)\b',
        ).hasMatch(normalizedText);

    return !targetEditContext &&
        ((asksAmount && dayContext && nutritionContext) ||
            _looksLikeDailyEvaluationRequest(normalizedText) ||
            (suggestionContext &&
                mealSuggestionContext &&
                remainingBudgetContext) ||
            RegExp(
              r'^\s*(e\s*)?(calorias|kcal|proteina|carbo|carboidratos|gordura|macros)\s*\??\s*$',
            ).hasMatch(normalizedText));
  }

  static bool _looksLikeDailyEvaluationRequest(String normalizedText) {
    final explicitDateContext = _extractDailyStatusDate(normalizedText) != null;
    final relativeDayContext = RegExp(
      r'\b(hoje|hj|ontem|anteontem|today|yesterday|dia|day)\b',
    ).hasMatch(normalizedText);
    final dayContext = relativeDayContext || explicitDateContext;
    final nutritionContext = RegExp(
      r'\b(alimentacao|dieta|refeicao|refeicoes|comida|alimento|calorias?|kcal|macros?|proteina|carbo|gordura|nutrition|diet|meal|food)\b',
    ).hasMatch(normalizedText);
    final evaluationContext = RegExp(
      r'\b(foi boa|foi bom|foi ruim|boa|bom|ruim|bem|mal|avalie|avaliar|analise|analisar|analisa|como foi|good|bad|ok|evaluate|review|analyze)\b',
    ).hasMatch(normalizedText);
    final targetEditContext = RegExp(
      r'\b(meta|metas|objetivo|objetivos|target|goal|ajustar|mudar|alterar|editar|definir|change|update)\b',
    ).hasMatch(normalizedText);

    return dayContext &&
        (nutritionContext || explicitDateContext || relativeDayContext) &&
        evaluationContext &&
        !targetEditContext;
  }

  static bool _looksLikeTotalVsRemainingQuestion(String normalizedText) {
    final asksTotal = RegExp(r'\b(total|totais)\b').hasMatch(normalizedText);
    final asksRemaining = RegExp(
      r'\b(livre|livres|restante|restantes|saldo|ainda|remaining|left|available)\b',
    ).hasMatch(normalizedText);
    return asksTotal && asksRemaining;
  }

  static bool _looksLikeMacroTargetsStatusRequest(
    String normalizedText, {
    String conversationContext = '',
  }) {
    final normalizedContext = _normalizeLooseText(conversationContext);
    final asksAmount = RegExp(
      r'\b(quanto|quantas|qual|quais|cuanto|cuantas|combien|wie viel|wie viele|wieviel|quante|me diga|mostra|mostrar|ver|saber|how much|how many|what)\b',
    ).hasMatch(normalizedText);
    final calorieContext = RegExp(
      r'\b(caloria|calorias|calorie|calories|kalorien|kcal|macro|macros|proteina|proteine|protein|carbo|carboidrato|carbohidrato|gordura|grasa|graisse|fett|grassi|comer|consumir|eat|essen|mangiare|carbs|fat)\b',
    ).hasMatch(normalizedText);
    final totalCue = RegExp(
      r'\b(total|totais|diariamente|diario|diaria|diarios|diarias|por dia|no dia|ao dia|al dia|par jour|pro tag|al giorno|daily|per day|meta diaria|meta calorica|meta de calorias)\b',
    ).hasMatch(normalizedText);
    final explicitTargetsCue = RegExp(
      r'\b(metas atuais|macros atuais|alvos atuais|minhas metas|meus macros|quais sao minhas metas|quais sao meus macros|objetivo de calorias|meta calorica total|meta diaria)\b',
    ).hasMatch(normalizedText);
    final remainingCue = RegExp(
      r'\b(ainda|resta|restam|sobrou|sobram|falta|faltam|livre|livres|restante|restantes|quedan|queda|reste|restait|ubrig|rimane|rimaste|remaining|left|available|hoje|hj|ontem|today|yesterday|hoy|ayer|aujourdhui|heute|gestern|oggi|ieri)\b',
    ).hasMatch(normalizedText);

    if (explicitTargetsCue) {
      return true;
    }
    if (asksAmount && totalCue && calorieContext && !remainingCue) {
      return true;
    }

    final shortTotalQuestion = RegExp(
      r'^\s*(quanto|qual|me diga|e)?\s*(e\s*)?(o\s*)?total\s*(diario|diaria|por dia)?\s*$',
    ).hasMatch(normalizedText);
    if (!shortTotalQuestion) {
      return false;
    }

    return normalizedContext.isNotEmpty &&
        RegExp(
          r'\b(caloria|calorias|kcal|macro|macros|meta|metas|saldo|restante|livre|total|diario|diaria|daily)\b',
        ).hasMatch(normalizedContext);
  }

  static bool _looksLikeDietGenerationRequest(String normalizedText) {
    return RegExp(
          r'\b(gerar|gere|gera|criar|crie|cria|montar|monte|monta|fazer|faz|generate|create|build)\b.*\b(dieta|cardapio|plano alimentar|meal plan|refeicoes|refeicao|diet)\b',
        ).hasMatch(normalizedText) ||
        RegExp(
          r'\b(dieta|cardapio|plano alimentar|meal plan|diet)\b.*\b(nova|novo|gerar|gera|criar|cria|montar|monta|personalizada|plano)\b',
        ).hasMatch(normalizedText);
  }

  static bool _looksLikeMacroGoalRequest(String normalizedText) {
    return _containsAnyRoutingTerm(normalizedText, const [
          'cutting',
          'cut',
          'secar',
          'emagrecer',
          'perder peso',
          'perder gordura',
          'bulking',
          'bulk',
          'ganhar massa',
          'ganhar peso',
          'hipertrofia',
          'manter peso',
          'manutencao',
        ]) ||
        RegExp(
          r'\b(meta|metas|objetivo|objetivos|alvo|alvos|target|goal|macro|macros|caloria|calorias|kcal|proteina|carbo|carboidrato|gordura)\b.*\b(ajustar|ajuste|mudar|mude|alterar|altere|editar|definir|colocar|coloque|subir|aumentar|baixar|reduzir|recalcular|calcular|apply|save|update|change)\b',
        ).hasMatch(normalizedText) ||
        RegExp(
          r'\b(ajustar|ajuste|mudar|mude|alterar|altere|editar|definir|colocar|coloque|subir|aumentar|baixar|reduzir|recalcular|calcular|apply|save|update|change)\b.*\b(meta|metas|objetivo|objetivos|alvo|alvos|target|goal|macro|macros|caloria|calorias|kcal|proteina|carbo|carboidrato|gordura)\b',
        ).hasMatch(normalizedText) ||
        RegExp(
          r'\b\d+([,.]\d+)?\s*(g/kg|gramas?\s*(por|p/)?\s*(kg|quilo)|kcal|calorias?)\b',
        ).hasMatch(normalizedText);
  }

  static bool _looksLikeProfileSetupRequest(String normalizedText) {
    return RegExp(
      r'\b(configurar|configura|setup|definir|ajustar)\b.*\b(perfil|profile|dados|meta inicial|metas iniciais|objetivo inicial)\b',
    ).hasMatch(normalizedText);
  }

  static bool _looksLikeAccountScopedRequest(String normalizedText) {
    return _containsAnyRoutingTerm(normalizedText, const [
      'progresso',
      'semana',
      'weekly',
      'peso',
      'imc',
      'historico',
      'minha dieta',
      'meu plano',
      'metas atuais',
      'macros atuais',
    ]);
  }

  static bool _isStandaloneFoodLoggingText(String normalizedText) {
    if (normalizedText.isEmpty ||
        normalizedText.length > 180 ||
        normalizedText.contains('?')) {
      return false;
    }
    if (_isGreetingOnly(normalizedText)) {
      return false;
    }
    if (_looksLikeDailyStatusRequest(normalizedText) ||
        _looksLikeMacroGoalRequest(normalizedText) ||
        _looksLikeDietGenerationRequest(normalizedText)) {
      return false;
    }

    const foodTerms = [
      'arroz',
      'feijao',
      'frango',
      'carne',
      'ovo',
      'ovos',
      'pao',
      'leite',
      'banana',
      'maca',
      'batata',
      'macarrao',
      'queijo',
      'iogurte',
      'aveia',
      'whey',
      'cafe',
      'suco',
      'salada',
      'peixe',
      'pizza',
      'sanduiche',
      'chicken',
      'rice',
      'beans',
      'egg',
      'bread',
      'milk',
    ];
    final hasKnownFood = foodTerms.any(
      (term) => RegExp('\\b${RegExp.escape(term)}s?\\b').hasMatch(
        normalizedText,
      ),
    );
    final hasFoodVerb = RegExp(
      r'\b(comi|comer|comendo|almoco|almocei|jantar|jantei|lanche|lanchei|tomei|bebi|consumi|registra|registrar|adicione|adicionar)\b',
    ).hasMatch(normalizedText);

    return hasKnownFood || hasFoodVerb;
  }

  static bool _shouldAttachAppState(_PromptIntent intent) {
    switch (intent) {
      case _PromptIntent.simpleChat:
      case _PromptIntent.foodLogging:
        return false;
      case _PromptIntent.dailyStatus:
      case _PromptIntent.macroGoals:
      case _PromptIntent.dietGeneration:
      case _PromptIntent.profileSetup:
      case _PromptIntent.pendingAction:
      case _PromptIntent.commandResults:
      case _PromptIntent.accountScoped:
        return true;
    }
  }

  static bool _shouldUseSemanticActionGateway(String basePrompt) {
    if (basePrompt.contains('Conversation mode: free nutrition chat.')) {
      return false;
    }

    final userText = _extractPromptUserRequest(basePrompt);
    final normalized = _normalizeRoutingText(userText);
    if (normalized.isEmpty ||
        _isGreetingOnly(normalized) ||
        _isLowContextStandaloneMessage(_normalizeLooseText(userText))) {
      return false;
    }

    if (_looksLikeProfileDeclaration(normalized) ||
        _isStandaloneFoodLoggingText(normalized)) {
      return false;
    }

    return true;
  }

  static Future<String> buildFollowUpPrompt({
    required String originalUserMessage,
    required List<AppAgentExecutionResult> executionResults,
    required BuildContext context,
    String conversationContext = '',
  }) async {
    final appReplyLanguage = _promptLanguageTag(context);
    final promptIntent = _resolvePromptIntentFromExecutionResults(
      originalUserMessage: originalUserMessage,
      executionResults: executionResults,
    );
    final resultJson = jsonEncode(
      executionResults.map(_summarizeExecutionResultForPrompt).toList(),
    );
    final sanitizedConversationContext = conversationContext.trim().isEmpty
        ? ''
        : compactConversationContext(
            conversationContext,
            maxBlocks: 40,
            maxChars: 8000,
          );
    final currentAppStateJson = jsonEncode(
      _buildPromptStatePayloadForIntent(
        await _getCurrentAppStatePayload(context),
        promptIntent,
      ),
    );

    return '''
[APP_COMMAND_RESULTS_BEGIN]
$resultJson
[APP_COMMAND_RESULTS_END]
[APP_CURRENT_STATE_BEGIN]
$currentAppStateJson
[APP_CURRENT_STATE_END]
App reply language: $appReplyLanguage.
Prompt intent: ${_promptIntentTag(_PromptIntent.commandResults)}.
${sanitizedConversationContext.isEmpty ? '' : 'Current chat history, oldest to newest (accessible conversation context):\n$sanitizedConversationContext\n'}
User request:
$originalUserMessage
Rules: trust APP_COMMAND_RESULTS and APP_CURRENT_STATE. Return another app_command/app_commands only if one more app action is required; otherwise answer naturally without internal command names.
If errorMessage is "confirmation_required", do not mutate again; say nothing was saved yet and ask one short confirmation/target question.
Daily status: answer the exact remaining values asked. Macro target results: report only saved/current values. After successful macro updates or daily status, no edit_macros_ui hint.
Do not ask diet-personalization/meal-plan follow-ups unless the latest user request explicitly asked for a diet plan.
Reply in App reply language.
''';
  }

  static Future<String> buildPromptWithCurrentAppState({
    required BuildContext context,
    required String basePrompt,
  }) async {
    final appReplyLanguage = _promptLanguageTag(context);
    var promptIntent = _resolvePromptIntentFromBasePrompt(basePrompt);
    final authService = Provider.of<AuthService>(context, listen: false);
    if (promptIntent == _PromptIntent.simpleChat &&
        authService.isAuthenticated &&
        authService.token != null &&
        _shouldUseSemanticActionGateway(basePrompt)) {
      promptIntent = _PromptIntent.accountScoped;
    }
    final intentLine = 'Prompt intent: ${_promptIntentTag(promptIntent)}.';

    if (!_shouldAttachAppState(promptIntent)) {
      return '''
App reply language: $appReplyLanguage.
$intentLine
$basePrompt
''';
    }

    if (!authService.isAuthenticated || authService.token == null) {
      const currentAppStateJson = '{"auth":{"isAuthenticated":false}}';
      return '''
[APP_CURRENT_STATE_BEGIN]
$currentAppStateJson
[APP_CURRENT_STATE_END]
App reply language: $appReplyLanguage.
$intentLine
$basePrompt
''';
    }

    final currentAppStateJson = jsonEncode(
      _buildPromptStatePayloadForIntent(
        await _getCurrentAppStatePayload(context),
        promptIntent,
      ),
    );

    return '''
[APP_CURRENT_STATE_BEGIN]
$currentAppStateJson
[APP_CURRENT_STATE_END]
App reply language: $appReplyLanguage.
$intentLine
$basePrompt
''';
  }

  static String _promptLanguageTag(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (country != null && country.isNotEmpty) {
      return '$language-$country';
    }
    switch (language) {
      case 'pt':
        return 'pt-BR';
      case 'en':
        return 'en-US';
      case 'es':
        return 'es-ES';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'it':
        return 'it-IT';
      default:
        return language;
    }
  }

  static Map<String, dynamic> _buildPromptStatePayloadForIntent(
    Map<String, dynamic> state,
    _PromptIntent intent,
  ) {
    final fullState = _buildPromptStatePayload(state);
    final auth = (fullState['auth'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final goalSetup =
        (fullState['goalSetup'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final dietPreferences = (fullState['dietGenerationPreferences'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    switch (intent) {
      case _PromptIntent.simpleChat:
      case _PromptIntent.foodLogging:
        return _pruneNullEntries({
          'auth': {
            'isAuthenticated': auth['isAuthenticated'] == true,
          },
        });
      case _PromptIntent.dailyStatus:
      case _PromptIntent.accountScoped:
      case _PromptIntent.pendingAction:
      case _PromptIntent.commandResults:
        return _pruneNullEntries({
          'auth': auth,
        });
      case _PromptIntent.profileSetup:
      case _PromptIntent.macroGoals:
        return _pruneNullEntries({
          'auth': auth,
          'goalSetup': goalSetup,
        });
      case _PromptIntent.dietGeneration:
        return _pruneNullEntries({
          'auth': auth,
          'goalSetup': goalSetup,
          'dietGenerationPreferences': dietPreferences,
        });
    }
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
    final setupStatusValues = setupCompletionStatus.values.toList();
    final hasCompleteSetup = setupStatusValues.isNotEmpty &&
        setupStatusValues.every((v) => v == true);
    final hasConfiguredGoals =
        goalSetup['configurationStatus'] == 'configured' ||
            goalSetup['hasConfiguredGoals'] == true ||
            hasCompleteSetup;

    return _pruneNullEntries({
      'auth': {
        'isAuthenticated': auth['isAuthenticated'] == true,
        'userId': auth['userId'],
      },
      'goalSetup': _pruneNullEntries({
        'configurationStatus':
            hasConfiguredGoals ? 'configured' : 'needs_initial_setup',
        'configured': hasConfiguredGoals,
        'defaultMacroTargetsApplied':
            goalSetup['defaultMacroTargetsApplied'] == true ||
                !hasConfiguredGoals,
        if (hasConfiguredGoals)
          'profile': _pruneNullEntries({
            'sex': profile['sex'],
            'age': profile['age'],
            'weightKg': profile['weightKg'],
            'heightCm': profile['heightCm'],
            'activityLevel': profile['activityLevel'],
            'fitnessGoal': profile['fitnessGoal'],
          }),
        if (hasConfiguredGoals) 'dietType': goalSetup['dietType'],
        if (hasConfiguredGoals)
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
            'proteinPerKg': payload['proteinPerKg'],
            'fatPerKg': payload['fatPerKg'],
            'macroStrategy': payload['macroStrategy'],
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

  static bool isCreditExhaustedResponse(String responseContent) {
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
    final hasQuestionMark = userMessage.contains('?');
    final normalized = _normalizeLooseText(userMessage);
    if (normalized.isEmpty) {
      return false;
    }

    if (_isLowContextStandaloneMessage(normalized)) {
      return false;
    }

    if (const {
      'sim',
      'quero',
      'quero sim',
      'nao',
      'não',
      'certo',
    }.contains(normalized)) {
      return true;
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

    final firstWord = words.first;
    if ({
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
      'pode',
      'ele',
      'ela',
      'eles',
      'elas',
    }.contains(firstWord)) {
      return true;
    }

    if (hasQuestionMark) {
      return true;
    }

    if (_looksLikeProfileDeclaration(normalized)) {
      return false;
    }

    if (_isObviousStandaloneFoodLogging(normalized)) {
      return false;
    }

    return true;
  }

  static bool _isLowContextStandaloneMessage(String normalizedText) {
    return RegExp(
      r'^(oi|ola|hello|hi|hey|hola|bonjour|salut|coucou|hallo|guten tag|guten morgen|guten abend|ciao|buongiorno|buonasera|bom dia|boa tarde|boa noite|buenos dias|buenas tardes|buenas noches|valeu|obrigad[oa]|gracias|merci|danke|grazie|ok|okay|vale|daccord|beleza|blz|show|thanks|thank you)[\s!.?]*$',
    ).hasMatch(normalizedText);
  }

  static bool _looksLikeProfileDeclaration(String normalizedText) {
    if (normalizedText.contains('?')) {
      return false;
    }
    final hasProfileCue = _containsAnyTerm(normalizedText, const [
      'sou homem',
      'sou mulher',
      'tenho',
      'anos',
      'idade',
      'peso',
      'altura',
      'quilos',
      'kg',
    ]);
    final hasSetupCue = _containsAnyTerm(normalizedText, const [
      'ganhar peso',
      'perder peso',
      'manter peso',
      'atividade',
      'sedentario',
      'moderado',
    ]);
    return hasProfileCue && hasSetupCue;
  }

  static bool _isObviousStandaloneFoodLogging(String normalizedText) {
    if (normalizedText.contains('?') || normalizedText.length > 180) {
      return false;
    }
    if (_looksLikeSnackSuggestionRequest(normalizedText)) {
      return false;
    }
    if (_containsAnyTerm(normalizedText, const [
      'isso',
      'essa',
      'esse',
      'mesmo',
      'igual',
      'anterior',
      'ontem',
    ])) {
      return false;
    }

    final hasFoodVerb = RegExp(
      r'\b(comi|comer|comendo|almoco|almocei|jantar|jantei|lanchei|tomei|bebi|consumi|registra|registrar|adicione|adicionar)\b',
    ).hasMatch(normalizedText);
    final hasKnownFood = RegExp(
      r'\b(arroz|feijao|frango|carne|ovo|ovos|pao|leite|banana|maca|batata|macarrao|queijo|iogurte|aveia|whey|cafe|suco|salada|peixe|pizza|sanduiche|chicken|rice|beans|egg|bread|milk)\b',
    ).hasMatch(normalizedText);
    return hasFoodVerb || hasKnownFood;
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
      logAgentDebug('server_command_request', {
        'commandName': command.name,
        'arguments': command.arguments,
      });
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

      logAgentDebug('server_command_response', {
        'commandName': commandName,
        'success': success,
        'errorMessage': errorMessage,
        'responseKeys': response.keys.toList(),
        'stateKeys': state.keys.toList(),
        'payloadKeys': payload.keys.toList(),
      });

      return AppAgentExecutionResult(
        commandName: commandName,
        success: success,
        errorMessage: errorMessage,
        payload: payload,
      );
    } catch (error) {
      logAgentDebug('server_command_error', {
        'commandName': command.name,
        'error': error.toString(),
      });
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
    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    await mealsProvider.ready;
    await goalsProvider.ensureLoaded();

    final selectedDate = _resolveDailyStatusDate(
      command.arguments,
      fallbackDate: mealsProvider.selectedDate,
    )!;
    final snapshot = mealsProvider.getNutritionSnapshotForDate(selectedDate);
    final caloriesGoal =
        _tryParseInt(snapshot['calorieGoal']) ?? goalsProvider.caloriesGoal;
    final proteinGoal =
        _tryParseInt(snapshot['proteinGoal']) ?? goalsProvider.proteinGoal;
    final carbsGoal =
        _tryParseInt(snapshot['carbsGoal']) ?? goalsProvider.carbsGoal;
    final fatGoal = _tryParseInt(snapshot['fatGoal']) ?? goalsProvider.fatGoal;
    final meals = mealsProvider.getMealsForDate(selectedDate);
    final waterGlasses = _tryParseInt(snapshot['waterGlasses']) ??
        mealsProvider.getWaterGlassesForDate(selectedDate);
    final totalCalories = _tryParseInt(snapshot['calories']) ??
        meals.fold<int>(0, (sum, meal) => sum + meal.totalCalories);
    final totalProtein = _tryParseDouble(snapshot['protein']) ??
        meals.fold<double>(0, (sum, meal) => sum + meal.totalProtein);
    final totalCarbs = _tryParseDouble(snapshot['carbs']) ??
        meals.fold<double>(0, (sum, meal) => sum + meal.totalCarbs);
    final totalFat = _tryParseDouble(snapshot['fat']) ??
        meals.fold<double>(0, (sum, meal) => sum + meal.totalFat);
    final caloriesRemaining = caloriesGoal - totalCalories;
    final proteinRemaining = proteinGoal - totalProtein.toInt();
    final carbsRemaining = carbsGoal - totalCarbs.toInt();
    final fatRemaining = fatGoal - totalFat.toInt();

    return AppAgentExecutionResult(
      commandName: command.name,
      success: true,
      payload: {
        'selectedDate': selectedDate.toIso8601String(),
        'caloriesGoal': caloriesGoal,
        'proteinGoal': proteinGoal,
        'carbsGoal': carbsGoal,
        'fatGoal': fatGoal,
        'waterGoal':
            _tryParseInt(snapshot['waterGoal']) ?? mealsProvider.waterGoal,
        'hasData': snapshot['hasData'] == true,
        'hasServerSummary': snapshot['hasServerSummary'] == true,
        'caloriesConsumed': totalCalories,
        'proteinConsumed': _round1(totalProtein),
        'carbsConsumed': _round1(totalCarbs),
        'fatConsumed': _round1(totalFat),
        'waterConsumed': waterGlasses,
        'caloriesRemaining': caloriesRemaining,
        'proteinRemaining': proteinRemaining,
        'carbsRemaining': carbsRemaining,
        'fatRemaining': fatRemaining,
        'waterRemaining':
            ((_tryParseInt(snapshot['waterGoal']) ?? mealsProvider.waterGoal) -
                    waterGlasses)
                .clamp(
          0,
          _tryParseInt(snapshot['waterGoal']) ?? mealsProvider.waterGoal,
        ),
        'meals': meals
            .map((meal) => {
                  'type': meal.type.name,
                  'calories': meal.totalCalories,
                  'protein': _round1(meal.totalProtein),
                  'carbs': _round1(meal.totalCarbs),
                  'fat': _round1(meal.totalFat),
                  'foods': meal.foods
                      .map((food) => {
                            'name': food.name,
                            'calories': food.calories,
                          })
                      .toList(),
                })
            .toList(),
      },
    );
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
    final requestedMealsPerDay = _readRequestedMealsPerDay(command.arguments);
    if (requestedMealsPerDay != null) {
      await mealTypesProvider.setMealCount(requestedMealsPerDay);
      await mealTypesProvider.ensureLoaded();
    }

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
    final requestedMealsPerDay = _readRequestedMealsPerDay(command.arguments);
    if (requestedMealsPerDay != null) {
      final mealTypesProvider =
          Provider.of<MealTypesProvider>(context, listen: false);
      await mealTypesProvider.ensureLoaded();
      await mealTypesProvider.setMealCount(requestedMealsPerDay);
    }

    _applyDietGenerationPreferencesLocally(command, context);
    final result = await _executeServerStateCommand(command, context);
    _applyDietGenerationPreferencesLocally(command, context);
    return result;
  }

  static void _applyDietGenerationPreferencesLocally(
    AppAgentCommand command,
    BuildContext context,
  ) {
    final args = command.arguments;
    if (args.isEmpty) {
      return;
    }

    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final mealsPerDay = _readRequestedMealsPerDay(args);
    final hungriestMealTime = _normalizeMealWindow(
      _readFirstValue(
        args,
        const ['hungriestMealTime', 'hungriest_meal_time', 'hungriestMeal'],
      ),
    );
    final foodRestrictions = _extractDietRestrictionList(args);
    final favoriteFoods = _extractStringList(
      _readFirstValue(
        args,
        const [
          'favoriteFoods',
          'preferredFoods',
          'likedFoods',
          'foodPreferences',
        ],
      ),
    );
    final avoidedFoods = _extractStringList(
      _readFirstValue(
        args,
        const ['avoidedFoods', 'dislikedFoods', 'foodsToAvoid'],
      ),
    );
    final routineConsiderations = _extractStringList(
      _readFirstValue(
        args,
        const [
          'routineConsiderations',
          'routineNotes',
          'appetiteNotes',
          'healthConditions',
          'medicalConditions',
          'medicalIssues',
          'healthConsiderations',
          'conditions',
          'condicoesSaude',
          'problemasSaude',
        ],
      ),
    );
    final skipPreferenceStep = _tryParseBool(
      _readFirstValue(
        args,
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

    final hasAnyPreference = mealsPerDay != null ||
        hungriestMealTime != null ||
        foodRestrictions.isNotEmpty ||
        favoriteFoods.isNotEmpty ||
        avoidedFoods.isNotEmpty ||
        routineConsiderations.isNotEmpty ||
        skipPreferenceStep == true;
    if (!hasAnyPreference) {
      return;
    }

    dietProvider.updateDietGenerationPreferences(
      mealsPerDay: mealsPerDay,
      hungriestMealTime: hungriestMealTime,
      foodRestrictions: foodRestrictions.isEmpty ? null : foodRestrictions,
      favoriteFoods: favoriteFoods.isEmpty ? null : favoriteFoods,
      avoidedFoods: avoidedFoods.isEmpty ? null : avoidedFoods,
      routineConsiderations:
          routineConsiderations.isEmpty ? null : routineConsiderations,
      reviewedRestrictions:
          skipPreferenceStep == true || foodRestrictions.isNotEmpty
              ? true
              : null,
      reviewedFoodPreferences: skipPreferenceStep == true ||
              favoriteFoods.isNotEmpty ||
              avoidedFoods.isNotEmpty
          ? true
          : null,
      reviewedRoutineNeeds: skipPreferenceStep == true ||
              routineConsiderations.isNotEmpty ||
              hungriestMealTime != null
          ? true
          : null,
    );
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

  static bool shouldBlockAmbiguousGoalMutation(
    AppAgentCommand command,
    String originalUserMessage, {
    AppAgentPendingAction? approvedPendingAction,
  }) {
    if (!_isGoalMutationCommand(command.name)) {
      return false;
    }

    if (approvedPendingAction?.matchesCommand(command) == true) {
      return false;
    }

    return !_hasExplicitGoalMutationConsent(originalUserMessage);
  }

  static AppAgentExecutionResult buildBlockedGoalMutationResult(
    AppAgentCommand command,
  ) {
    return AppAgentExecutionResult(
      commandName: command.name,
      success: false,
      errorMessage: 'confirmation_required',
      payload: {
        'reason': 'confirmation_required',
        'blockedCommand': command.name,
        'proposedArguments': command.arguments,
        'guidance':
            'Do not change saved calorie or macro targets until the user confirms or provides explicit target numbers.',
      },
    );
  }

  static bool _isGoalMutationCommand(String commandName) {
    switch (commandName) {
      case recalculateNutritionGoals:
      case updateMacroTargetsPercentage:
      case updateMacroTargetsGrams:
      case updateMacroTargetsGramsPerKg:
        return true;
      default:
        return false;
    }
  }

  static bool _hasExplicitGoalMutationConsent(String userMessage) {
    final normalized = userMessage.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    if (AppAgentPendingAction._looksLikeExplicitGoalChange(userMessage)) {
      return true;
    }

    if (RegExp(r'\d').hasMatch(normalized)) {
      return true;
    }

    if (RegExp(
      r'\b(g/kg|por\s+(quilo|kg)|por\s+quilo\s+de\s+peso)\b',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return true;
    }

    if (RegExp(
      r'^\s*(sim|ok|okay|pode|pode sim|isso|isso mesmo|confirmo|confirmar|fa[çc]a isso|faz isso|fa[çc]a autom[aá]tico|faz autom[aá]tico|autom[aá]tico|automaticamente|recalcule autom[aá]tico|recalcula autom[aá]tico|recalcule automaticamente|recalcula automaticamente|aplica|aplique|aplicar|salva|salve|salvar|yes|do it|apply|save)\s*[.!?]*\s*$',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return true;
    }

    return RegExp(
      r'\b(pode aplicar|pode atualizar|pode recalcular|pode calcular|pode ajustar|aplica isso|aplique isso|salva isso|salve isso|fa[çc]a essa mudan[çc]a|confirmo essa mudan[çc]a|apply it|save it|update it|recalculate it)\b',
      caseSensitive: false,
    ).hasMatch(normalized);
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
