import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/app_agent_service.dart';

void main() {
  String iso(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  DateTime previousOccurrence({required int day, int? month}) {
    final today = DateTime.now();
    var year = today.year;
    var resolvedMonth = month ?? today.month;
    var candidate = DateTime(year, resolvedMonth, day);
    if (!candidate.isAfter(DateTime(today.year, today.month, today.day))) {
      return candidate;
    }
    if (month == null) {
      resolvedMonth -= 1;
      if (resolvedMonth < 1) {
        resolvedMonth = 12;
        year -= 1;
      }
    } else {
      year -= 1;
    }
    return DateTime(year, resolvedMonth, day);
  }

  test('parses app_commands with root-level fields from the model', () {
    const response = '''
Para configurar seus objetivos, preciso validar os dados.

{"app_commands":[
  {"app_command":"update_goal_setup_profile","sex":"male","age":28,"weight_kg":85,"height_cm":181},
  {"app_command":"update_goal_setup_preferences","activity":"moderate","goal":"weight_gain"}
]}
[APP_UI_HINT_BEGIN]{"actions":["configure_goals_ui"]}[APP_UI_HINT_END]
''';

    final batch = AppAgentCommand.tryParseBatch(response);

    expect(batch, isNotNull);
    expect(batch!.commands, hasLength(2));

    expect(batch.commands[0].name, 'update_goal_setup_profile');
    expect(batch.commands[0].arguments, <String, dynamic>{
      'sex': 'male',
      'age': 28,
      'weightKg': 85.0,
      'heightCm': 181.0,
    });

    expect(batch.commands[1].name, 'update_goal_setup_preferences');
    expect(batch.commands[1].arguments, <String, dynamic>{
      'activityLevel': 'moderatelyActive',
      'fitnessGoal': 'gainWeight',
    });
  });

  test('parses skipPreferenceStep for optional diet generation review', () {
    const response = '''
{"app_commands":[
  {"name":"update_diet_generation_preferences","skipPreferenceStep":true},
  {"name":"generate_new_diet_plan","arguments":{}}
]}
''';

    final batch = AppAgentCommand.tryParseBatch(response);

    expect(batch, isNotNull);
    expect(batch!.commands, hasLength(2));
    expect(batch.commands[0].name, 'update_diet_generation_preferences');
    expect(batch.commands[0].arguments, <String, dynamic>{
      'skipPreferenceStep': true,
    });
    expect(batch.commands[1].name, 'generate_new_diet_plan');
    expect(batch.commands[1].arguments, isEmpty);
  });

  test('parses pending app action hidden block', () {
    const response = '''
Posso recalcular suas metas para cutting com base no seu perfil.
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"loseWeight"}}}
[APP_PENDING_ACTION_END]
''';

    final pendingAction = AppAgentPendingAction.tryParse(response);

    expect(pendingAction, isNotNull);
    expect(
      pendingAction!.command.name,
      AppAgentService.recalculateNutritionGoals,
    );
    expect(pendingAction.command.arguments['fitnessGoal'], 'loseWeight');
    expect(
      AppAgentPendingAction.removeBlock(response),
      'Posso recalcular suas metas para cutting com base no seu perfil.',
    );
    expect(AppAgentCommand.containsCommandCandidate(response), isFalse);
    expect(AppAgentCommand.tryParseBatch(response), isNull);
  });

  test('keeps only trailing assistant pending action active', () {
    const assistantWithPending = '''
Quer que eu recalcule automaticamente?
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"gainWeightSlowly"}}}
[APP_PENDING_ACTION_END]
''';

    final active = AppAgentPendingAction.findLatestInTrailingAssistantTurn([
      {
        'isUser': true,
        'message': 'quero ganhar massa',
      },
      {
        'isUser': false,
        'message': assistantWithPending,
      },
    ]);
    expect(active, isNotNull);
    expect(active!.command.arguments['fitnessGoal'], 'gainWeightSlowly');

    final stale = AppAgentPendingAction.findLatestInTrailingAssistantTurn([
      {
        'isUser': false,
        'message': assistantWithPending,
      },
      {
        'isUser': true,
        'message': 'outra coisa',
      },
    ]);
    expect(stale, isNull);
  });

  test('infers pending macro recalculation from trailing assistant question',
      () {
    final pendingAction =
        AppAgentPendingAction.findLatestInTrailingAssistantTurn([
      {
        'isUser': true,
        'message': 'quero fazer um cutting',
      },
      {
        'isUser': false,
        'message':
            'Você quer fazer um cutting, certo? Seu objetivo atual no app é "ganhar peso lentamente". Para mudar para cutting, posso recalcular suas metas de nutrição. Posso seguir com isso?',
      },
    ]);

    expect(pendingAction, isNotNull);
    expect(
        pendingAction!.command.name, AppAgentService.recalculateNutritionGoals);
    expect(pendingAction.command.arguments['fitnessGoal'], 'loseWeight');
    expect(AppAgentPendingAction.isLikelyApproval('faça isso'), isTrue);
    expect(AppAgentPendingAction.isLikelyApproval('pão'), isFalse);
  });

  test('keeps unresolved pending action across an unrelated interruption', () {
    const assistantWithPending = '''
Posso recalcular suas metas para cutting com base no seu perfil. Posso seguir com isso?
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"loseWeight"}}}
[APP_PENDING_ACTION_END]
''';

    final pendingAction =
        AppAgentPendingAction.findLatestUnresolvedInConversation([
      {
        'isUser': true,
        'message': 'quero fazer cutting',
      },
      {
        'isUser': false,
        'message': assistantWithPending,
      },
      {
        'isUser': true,
        'message': 'antes disso, quantas calorias posso comer hoje?',
      },
      {
        'isUser': false,
        'message':
            'Hoje você ainda pode consumir 2910 kcal, 169g de proteína, 368g de carboidratos e 85g de gorduras.',
      },
    ]);

    expect(AppAgentPendingAction.isLikelyApproval('agora faça isso'), isTrue);
    expect(pendingAction, isNotNull);
    expect(
      pendingAction!.command.name,
      AppAgentService.recalculateNutritionGoals,
    );
    expect(pendingAction.command.arguments['fitnessGoal'], 'loseWeight');
  });

  test('does not reuse a pending action after a completion boundary', () {
    const assistantWithPending = '''
Posso recalcular suas metas para cutting com base no seu perfil. Posso seguir com isso?
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"loseWeight"}}}
[APP_PENDING_ACTION_END]
''';

    final pendingAction =
        AppAgentPendingAction.findLatestUnresolvedInConversation([
      {
        'isUser': true,
        'message': 'quero fazer cutting',
      },
      {
        'isUser': false,
        'message': assistantWithPending,
      },
      {
        'isUser': true,
        'message': 'faça isso',
      },
      {
        'isUser': false,
        'message':
            'Pronto, recalculei suas metas com uma recomendação padrão para o seu objetivo.',
      },
    ]);

    expect(pendingAction, isNull);
  });

  test('cancels unresolved pending action after user rejection', () {
    const assistantWithPending = '''
Posso recalcular suas metas para cutting com base no seu perfil. Posso seguir com isso?
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"loseWeight"}}}
[APP_PENDING_ACTION_END]
''';

    final pendingAction =
        AppAgentPendingAction.findLatestUnresolvedInConversation([
      {
        'isUser': true,
        'message': 'quero fazer cutting',
      },
      {
        'isUser': false,
        'message': assistantWithPending,
      },
      {
        'isUser': true,
        'message': 'não quero mais',
      },
      {
        'isUser': false,
        'message': 'Tudo bem, não vou alterar suas metas.',
      },
    ]);

    expect(AppAgentPendingAction.isLikelyApproval('não faça isso'), isFalse);
    expect(pendingAction, isNull);
  });

  test('infers pending macro target update from conversation context', () {
    final pendingAction =
        AppAgentPendingAction.findLatestInTrailingAssistantTurn([
      {
        'isUser': true,
        'message': 'ajuste minha dieta para 2000 calorias',
      },
      {
        'isUser': false,
        'message':
            'Posso atualizar suas metas para 2000 kcal e recalcular os macros. Quer que eu faça isso?',
      },
    ]);

    expect(pendingAction, isNotNull);
    expect(
        pendingAction!.command.name, AppAgentService.updateMacroTargetsGrams);
    expect(pendingAction.command.arguments['caloriesGoal'], 2000);
  });

  test('infers pending diet generation from conversation context', () {
    final pendingAction =
        AppAgentPendingAction.findLatestInTrailingAssistantTurn([
      {
        'isUser': true,
        'message': 'gere uma dieta com 4 refeições',
      },
      {
        'isUser': false,
        'message':
            'Posso gerar uma dieta personalizada com 4 refeições usando suas metas atuais. Posso seguir?',
      },
    ]);

    expect(pendingAction, isNotNull);
    expect(pendingAction!.command.name, AppAgentService.generateNewDietPlan);
    expect(pendingAction.command.arguments['mealsPerDay'], 4);
  });

  test('executes pending action when assistant says it is acting now', () {
    const response = '''
Você tem razão! Seu perfil está configurado para ganho de peso lento, não para manutenção. Para ajustar as metas para manutenção de peso, preciso recalcular com o objetivo correto. Vou fazer isso agora.
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"maintainWeight"}}}
[APP_PENDING_ACTION_END]
''';

    final pendingAction = AppAgentPendingAction.tryParse(response);
    expect(pendingAction, isNotNull);
    expect(
      pendingAction!.command.name,
      AppAgentService.recalculateNutritionGoals,
    );
    expect(pendingAction.command.arguments['fitnessGoal'], 'maintainWeight');
    expect(
      pendingAction.shouldExecuteImmediately(
        userMessage: 'Quero manter peso vc colocou ganhar lentamente',
        visibleAssistantText: AppAgentPendingAction.removeBlock(response),
      ),
      isTrue,
    );
    expect(
      AppAgentService.shouldBlockAmbiguousGoalMutation(
        pendingAction.toExecutionCommand(rawJson: '{}'),
        'Quero manter peso vc colocou ganhar lentamente',
      ),
      isFalse,
    );
  });

  test('does not treat a goal question as explicit mutation consent', () {
    const pendingResponse = '''
Posso recalcular suas metas para manutenção?
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"maintainWeight"}}}
[APP_PENDING_ACTION_END]
''';
    final pendingAction = AppAgentPendingAction.tryParse(pendingResponse);
    expect(pendingAction, isNotNull);

    expect(
      pendingAction!.shouldExecuteImmediately(
        userMessage: 'Isso é a quantidade para eu manter peso?',
        visibleAssistantText: AppAgentPendingAction.removeBlock(
          pendingResponse,
        ),
      ),
      isFalse,
    );

    expect(
      AppAgentService.shouldBlockAmbiguousGoalMutation(
        pendingAction.toExecutionCommand(rawJson: '{}'),
        'Isso é a quantidade para eu manter peso?',
      ),
      isTrue,
    );
  });

  test('does not execute conditional future wording without consent', () {
    const pendingResponse = '''
Se você quiser, vou recalcular suas metas para manutenção depois da sua confirmação.
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"maintainWeight"}}}
[APP_PENDING_ACTION_END]
''';
    final pendingAction = AppAgentPendingAction.tryParse(pendingResponse);
    expect(pendingAction, isNotNull);

    expect(
      pendingAction!.shouldExecuteImmediately(
        userMessage: 'isso é muito?',
        visibleAssistantText: AppAgentPendingAction.removeBlock(
          pendingResponse,
        ),
      ),
      isFalse,
    );
  });

  test('does not execute pending action when assistant asks confirmation', () {
    const pendingResponse = '''
Posso recalcular suas metas para cutting com base no seu perfil. Posso seguir com isso?
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"loseWeight"}}}
[APP_PENDING_ACTION_END]
''';
    final pendingAction = AppAgentPendingAction.tryParse(pendingResponse);
    expect(pendingAction, isNotNull);

    expect(
      pendingAction!.shouldExecuteImmediately(
        userMessage: 'quero fazer cutting',
        visibleAssistantText: AppAgentPendingAction.removeBlock(
          pendingResponse,
        ),
      ),
      isFalse,
    );
  });

  test('pending action approval bypasses ambiguous mutation block', () {
    const pendingResponse = '''
[APP_PENDING_ACTION_BEGIN]
{"app_command":{"name":"recalculate_nutrition_goals","arguments":{"fitnessGoal":"cutting"}}}
[APP_PENDING_ACTION_END]
''';
    final pendingAction = AppAgentPendingAction.tryParse(pendingResponse);
    expect(pendingAction, isNotNull);

    const modelCommand = AppAgentCommand(
      name: AppAgentService.recalculateNutritionGoals,
      arguments: <String, dynamic>{},
      rawJson: '{}',
    );

    expect(pendingAction!.matchesCommand(modelCommand), isTrue);
    expect(
      AppAgentService.shouldBlockAmbiguousGoalMutation(
        pendingAction.toExecutionCommand(rawJson: modelCommand.rawJson),
        'Calcule',
      ),
      isTrue,
    );
    expect(
      AppAgentService.shouldBlockAmbiguousGoalMutation(
        pendingAction.toExecutionCommand(rawJson: modelCommand.rawJson),
        'Calcule',
        approvedPendingAction: pendingAction,
      ),
      isFalse,
    );
  });

  test('keeps prior conversation for non-trivial chat turns', () {
    expect(
      AppAgentService.shouldIncludeConversationContext('Pode seguir'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('Qualquer uma'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('quero'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('Pode matar?'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('Qual a minha idade?'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext(
        'me dá uma sugestão de lanche com as calorias que eu já posso comer',
      ),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('aumente as proteinas'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('2 gramas'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('oi'),
      isFalse,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('hola'),
      isFalse,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('merci'),
      isFalse,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('pão com ovo'),
      isFalse,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext(
        'Sou homem, tenho 28 anos e quero ganhar peso lentamente.',
      ),
      isFalse,
    );
  });

  test('normalizes snake_case activity and slow gain goal variants', () {
    const response = '''
{"app_command":{"name":"update_goal_setup_preferences","arguments":{"activityLevel":"moderately_active","fitnessGoal":"slow_weight_gain"}}}
''';

    final command = AppAgentCommand.tryParse(response);

    expect(command, isNotNull);
    expect(command!.name, 'update_goal_setup_preferences');
    expect(command.arguments, <String, dynamic>{
      'activityLevel': 'moderatelyActive',
      'fitnessGoal': 'gainWeightSlowly',
    });
  });

  test('does not treat food json as an app command batch', () {
    const response = '''
{"mealType":"lunch","foods":[{"name":"carne","portion":"100 gramas","macros":{"calories":250,"protein":26,"carbohydrate":0,"fat":15}}]}
''';

    expect(AppAgentCommand.containsCommandCandidate(response), isFalse);
    expect(AppAgentCommand.tryParse(response), isNull);
    expect(AppAgentCommand.tryParseBatch(response), isNull);
  });

  test('does not treat nested foods arrays as top-level commands', () {
    const response = '''
Resposta da IA:
{"mealType":"breakfast","foods":[{"name":"pao","portion":"1 fatia","macros":{"calories":70,"protein":2.5,"carbohydrate":13,"fat":1}}]}
''';

    expect(AppAgentCommand.tryParseBatch(response), isNull);
  });

  test('does not treat multi-meal food json as an app command', () {
    const response = '''
{"meals":[
  {"mealType":"lunch","foods":[{"name":"arroz","portion":"1 colher","macros":{"calories":164,"protein":3,"carbohydrate":36,"fat":0.3}}]},
  {"mealType":"dinner","foods":[{"name":"cuscuz","portion":"1 prato","macros":{"calories":180,"protein":5,"carbohydrate":38,"fat":1}}]}
]}
''';

    expect(AppAgentCommand.containsCommandCandidate(response), isFalse);
    expect(AppAgentCommand.tryParse(response), isNull);
    expect(AppAgentCommand.tryParseBatch(response), isNull);
  });

  test('routes automatic approval back to macro recalculation context', () {
    const context = '''
User: eu quero ganhar massa agora, recalcule
Assistant: Para ganhar massa, normalmente é necessário superávit calórico e mais carboidratos. Confirme se quer que eu recalcule automaticamente com base no seu perfil.
''';
    const command = AppAgentCommand(
      name: AppAgentService.generateNewDietPlan,
      arguments: <String, dynamic>{},
      rawJson: '{}',
    );

    expect(
      AppAgentService.shouldTreatAsMacroRecalculationApproval(
        'faça automatico',
        context,
      ),
      isTrue,
    );
    expect(
      AppAgentService.shouldRedirectDietCommandToMacroRecalculation(
        command,
        'faça automatico',
        context,
      ),
      isTrue,
    );

    final fallbackCommand =
        AppAgentService.buildMacroRecalculationCommandFromContext(
      'faça automatico',
      context,
      rawJson: 'texto sem comando',
    );
    expect(fallbackCommand, isNotNull);
    expect(fallbackCommand!.name, AppAgentService.recalculateNutritionGoals);
    expect(fallbackCommand.arguments['fitnessGoal'], 'gainWeightSlowly');

    final shortConfirmation =
        AppAgentService.buildMacroRecalculationCommandFromContext(
      'sim',
      context,
      rawJson: 'texto sem comando',
    );
    expect(shortConfirmation, isNotNull);
    expect(shortConfirmation!.arguments['fitnessGoal'], 'gainWeightSlowly');
  });

  test('does not treat diet default approval as macro recalculation', () {
    const context = '''
User: gera uma dieta para mim
Assistant: Quer passar detalhes como restrições, alimentos preferidos ou rotina, ou prefere que eu gere uma dieta padrão?
''';

    expect(
      AppAgentService.shouldTreatAsMacroRecalculationApproval(
        'pode gerar',
        context,
      ),
      isFalse,
    );
  });

  test('builds calorie target fallback command from explicit goal text', () {
    final command = AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'quero comer 2000 caloias',
      rawJson: '',
    );

    expect(command, isNotNull);
    expect(command!.name, AppAgentService.updateMacroTargetsGrams);
    expect(command.arguments, <String, dynamic>{
      'caloriesGoal': 2000,
    });

    final adjustedDiet =
        AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'ajuste minha dieta para 2000 calorias',
      rawJson: '',
    );
    expect(adjustedDiet, isNotNull);
    expect(adjustedDiet!.arguments['caloriesGoal'], 2000);
  });

  test('routes daily nutrition status and evaluation dates', () {
    final yesterday =
        AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
      'minha alimentação de ontem foi boa?',
      rawJson: '',
    );
    expect(yesterday, isNotNull);
    expect(yesterday!.name, AppAgentService.getDailyNutritionStatus);
    expect(yesterday.arguments, <String, dynamic>{'dateOffsetDays': -1});

    final frenchYesterday =
        AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
      'combien de calories me restait-il hier ?',
      rawJson: '',
    );
    expect(frenchYesterday, isNotNull);
    expect(
      frenchYesterday!.arguments,
      <String, dynamic>{'dateOffsetDays': -1},
    );

    final dayBefore =
        AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
      'e anteontem, foi bom?',
      rawJson: '',
    );
    expect(dayBefore, isNotNull);
    expect(dayBefore!.arguments, <String, dynamic>{'dateOffsetDays': -2});

    final dayOnly =
        AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
      'minha alimentação do dia 10 foi boa?',
      rawJson: '',
    );
    expect(dayOnly, isNotNull);
    expect(dayOnly!.arguments['date'], iso(previousOccurrence(day: 10)));

    final slashDate =
        AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
      'como foi minha dieta em 20/04?',
      rawJson: '',
    );
    expect(slashDate, isNotNull);
    expect(
      slashDate!.arguments['date'],
      iso(previousOccurrence(day: 20, month: 4)),
    );

    final isoDate =
        AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
      'quantas calorias comi em 2026-04-20?',
      rawJson: '',
    );
    expect(isoDate, isNotNull);
    expect(isoDate!.arguments['date'], '2026-04-20');

    final foodList =
        AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
      'Quais alimentos',
      rawJson: '',
    );
    expect(foodList, isNotNull);
    expect(foodList!.name, AppAgentService.getDailyNutritionStatus);
    expect(foodList.arguments, isEmpty);
  });

  test('routes total daily target questions to macro targets status', () {
    final dailyTotal =
        AppAgentService.buildMacroTargetsStatusCommandFromUserMessage(
      'quantas calorias eu posso comer diariamente?',
      rawJson: '',
    );
    expect(dailyTotal, isNotNull);
    expect(dailyTotal!.name, AppAgentService.getMacroTargetsStatus);

    final germanTotal =
        AppAgentService.buildMacroTargetsStatusCommandFromUserMessage(
      'wie viele Kalorien darf ich pro Tag essen?',
      rawJson: '',
    );
    expect(germanTotal, isNotNull);
    expect(germanTotal!.name, AppAgentService.getMacroTargetsStatus);

    final italianTotal =
        AppAgentService.buildMacroTargetsStatusCommandFromUserMessage(
      'quante calorie posso mangiare al giorno?',
      rawJson: '',
    );
    expect(italianTotal, isNotNull);
    expect(italianTotal!.name, AppAgentService.getMacroTargetsStatus);

    expect(
      AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
        'quantas calorias eu posso comer diariamente?',
        rawJson: '',
      ),
      isNull,
    );

    const context = '''
Humano: isso é o total ou o livre?
IA: Os valores que informei são o saldo restante para hoje. Não é o total diário. Se quiser saber sua meta calórica total, me avise.
''';
    final totalFollowUp =
        AppAgentService.buildMacroTargetsStatusCommandFromUserMessage(
      'quanto é o total?',
      rawJson: '',
      conversationContext: context,
    );
    expect(totalFollowUp, isNotNull);
    expect(totalFollowUp!.name, AppAgentService.getMacroTargetsStatus);

    expect(
      AppAgentService.buildMacroTargetsStatusCommandFromUserMessage(
        'isso é o total ou o livre?',
        rawJson: '',
        conversationContext: context,
      ),
      isNull,
    );
    expect(
      AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
        'isso é o total ou o livre?',
        rawJson: '',
      ),
      isNull,
    );
  });

  test('treats tiny macro gram targets as grams per kg in macro edits', () {
    final command = AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'coloque 2 gramas de proteina',
      rawJson: '',
    );

    expect(command, isNotNull);
    expect(command!.name, AppAgentService.updateMacroTargetsGramsPerKg);
    expect(command.arguments, <String, dynamic>{
      'proteinPerKg': 2.0,
    });

    final dailyTotalCommand =
        AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'coloque 180 gramas de proteina',
      rawJson: '',
    );
    expect(dailyTotalCommand, isNotNull);
    expect(dailyTotalCommand!.name, AppAgentService.updateMacroTargetsGrams);
    expect(dailyTotalCommand.arguments['proteinGrams'], 180.0);
  });

  test('keeps explicit daily total macro grams as grams', () {
    final command = AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'coloque 2 gramas de proteina por dia',
      rawJson: '',
    );

    expect(command, isNotNull);
    expect(command!.name, AppAgentService.updateMacroTargetsGrams);
    expect(command.arguments['proteinGrams'], 2.0);
  });

  test('uses recent macro context for short numeric follow-up', () {
    const proteinContext = '''
Humano: aumentar as proteinas da minha dieta
IA: Qual valor de proteína você gostaria? Por exemplo, 1,8 g/kg (~154g) ou um número específico em gramas?
''';

    final proteinCommand =
        AppAgentService.buildMacroTargetsCommandFromContextualMessage(
      '2 gramas',
      proteinContext,
      rawJson: '',
    );

    expect(proteinCommand, isNotNull);
    expect(proteinCommand!.name, AppAgentService.updateMacroTargetsGramsPerKg);
    expect(proteinCommand.arguments, <String, dynamic>{
      'proteinPerKg': 2.0,
    });

    final dailyProteinCommand =
        AppAgentService.buildMacroTargetsCommandFromContextualMessage(
      '180 gramas',
      proteinContext,
      rawJson: '',
    );

    expect(dailyProteinCommand, isNotNull);
    expect(dailyProteinCommand!.name, AppAgentService.updateMacroTargetsGrams);
    expect(dailyProteinCommand.arguments, <String, dynamic>{
      'proteinGrams': 180.0,
    });

    const carbContext = '''
Humano: quero ajustar carbo
IA: Qual valor de carboidratos você gostaria? Pode ser em g/kg ou gramas totais.
''';

    final carbCommand =
        AppAgentService.buildMacroTargetsCommandFromContextualMessage(
      '4 gramas',
      carbContext,
      rawJson: '',
    );

    expect(carbCommand, isNotNull);
    expect(carbCommand!.name, AppAgentService.updateMacroTargetsGramsPerKg);
    expect(carbCommand.arguments, <String, dynamic>{
      'carbsPerKg': 4.0,
    });
  });

  test('routes tiny fat and carb gram targets as grams per kg', () {
    final command = AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'coloque 1 grama de gordura e 4 gramas de carbo',
      rawJson: '',
    );

    expect(command, isNotNull);
    expect(command!.name, AppAgentService.updateMacroTargetsGramsPerKg);
    expect(command.arguments, <String, dynamic>{
      'carbsPerKg': 4.0,
      'fatPerKg': 1.0,
    });
  });

  test('routes macro before kilo expression as grams per kg', () {
    const messages = [
      'vamos aumentar a quantidade de gordura para 1 grama kilo',
      'aumente gordura para 1g/kg',
      'subir gordura para 1 grama por quilo',
      'gordura em 1 grama',
      'set fat to 1 g/kg',
      'sube grasa a 1 grama kilo',
    ];

    for (final message in messages) {
      final command = AppAgentService.buildMacroTargetsCommandFromUserMessage(
        message,
        rawJson: '',
      );

      expect(command, isNotNull, reason: message);
      expect(
        command!.name,
        AppAgentService.updateMacroTargetsGramsPerKg,
        reason: message,
      );
      expect(command.arguments['fatPerKg'], 1.0, reason: message);
    }
  });

  test('routes carb-only and multiple macro per-kg edits together', () {
    final carbOnly = AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'aumente carbo para 4 gramas kilo',
      rawJson: '',
    );
    expect(carbOnly, isNotNull);
    expect(carbOnly!.name, AppAgentService.updateMacroTargetsGramsPerKg);
    expect(carbOnly.arguments, <String, dynamic>{
      'carbsPerKg': 4.0,
    });

    final twoMacros = AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'proteina 2g/kg e gordura 1g/kg',
      rawJson: '',
    );
    expect(twoMacros, isNotNull);
    expect(twoMacros!.name, AppAgentService.updateMacroTargetsGramsPerKg);
    expect(twoMacros.arguments, <String, dynamic>{
      'proteinPerKg': 2.0,
      'fatPerKg': 1.0,
    });

    final allMacros = AppAgentService.buildMacroTargetsCommandFromUserMessage(
      'proteina 2g/kg, carbo 4g/kg e gordura 1g/kg',
      rawJson: '',
    );
    expect(allMacros, isNotNull);
    expect(allMacros!.name, AppAgentService.updateMacroTargetsGramsPerKg);
    expect(allMacros.arguments, <String, dynamic>{
      'proteinPerKg': 2.0,
      'carbsPerKg': 4.0,
      'fatPerKg': 1.0,
    });
  });

  test('does not treat logged calories as a goal update', () {
    expect(
      AppAgentService.buildMacroTargetsCommandFromUserMessage(
        'comi 2000 calorias hoje',
        rawJson: '',
      ),
      isNull,
    );
  });

  test('detects macro advice questions without treating them as mutations', () {
    expect(
      AppAgentService.isMacroTargetAdviceQuestion(
        'seria interessante mais proteina?',
      ),
      isTrue,
    );
    expect(
      AppAgentService.isMacroTargetAdviceQuestion('devo subir carbo?'),
      isTrue,
    );
    expect(
      AppAgentService.isMacroTargetAdviceQuestion(
        'coloque 185g de proteina',
      ),
      isFalse,
    );
  });
}
