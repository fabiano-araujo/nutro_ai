import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/app_agent_service.dart';

void main() {
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

  test('only keeps prior conversation for contextual short replies', () {
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
